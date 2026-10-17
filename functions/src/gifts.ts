import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, int, readDailyCount, REGION, str, utcDateString} from "./common";
import {loadEconomy} from "./economy";
import {type PersonalPayload, type PushRecipient, sendToUser} from "./notificationHelper";

const PASS_MS = 24 * 60 * 60 * 1000;
export const GIFTS_PER_DAY = 3;
const SENDER_MIN_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Overridable in tests. */
export const giftIo = {
  async accountCreatedMs(uid: string): Promise<number> {
    return Date.parse((await admin.auth().getUser(uid)).metadata.creationTime);
  },
  notify: (payload: PersonalPayload, recipient: PushRecipient): Promise<boolean> => sendToUser(payload, recipient),
};

interface GiftResponse {
  success: boolean;
  changed: boolean;
  previousBalance: number;
  currentBalance: number;
  delta: number;
  reason: string;
  transactionId: string;
  insufficientBalance: boolean;
  expiresAt: number;
}

/** Pays coins to give another user a 24 hour Premium pass. */
export const giftPremiumPass = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<{recipientUid?: unknown; requestId?: unknown}>): Promise<GiftResponse> => {
    const uid = str(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in to gift a pass.");
    const recipientUid = str(request.data?.recipientUid);
    if (recipientUid === "" || recipientUid.length > 128 || recipientUid.includes("/")) {
      throw new HttpsError("invalid-argument", "recipientUid is invalid.");
    }
    if (recipientUid === uid) throw new HttpsError("invalid-argument", "gift_self");
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");

    const price = (await loadEconomy()).spend.giftPremiumPass;
    const nowMs = Date.now();
    const createdMs = await giftIo.accountCreatedMs(uid);
    if (!Number.isFinite(createdMs) || nowMs - createdMs < SENDER_MIN_AGE_MS) {
      return {
        success: false, changed: false, previousBalance: 0, currentBalance: 0, delta: 0,
        reason: "gift_sender_too_new", transactionId: "", insufficientBalance: false, expiresAt: 0,
      };
    }
    const today = utcDateString(new Date(nowMs));
    const txId = `ctx_gift_${uid}_${requestId}`;
    const senderRef = db.collection("usersv2").doc(uid);
    const recipientRef = db.collection("usersv2").doc(recipientUid);
    const economyRef = recipientRef.collection("private").doc("economy");
    const rateRef = db.collection("giftRateDaily").doc(`${uid}_${today}`);
    const receivedRef = db.collection("giftRateDaily").doc(`recv_${recipientUid}_${today}`);
    const blockRef = recipientRef.collection("blockedUsers").doc(uid);
    const txRef = db.collection("coinTransactions").doc(txId);

    let response: GiftResponse | null = null;
    let notice: {senderName: string; recipientEmail: string} | null = null;
    await db.runTransaction(async (tx) => {
      response = null;
      notice = null;
      const [senderSnap, recipientSnap, economySnap, rateSnap, receivedSnap, blockSnap, txSnap] = await Promise.all([
        tx.get(senderRef), tx.get(recipientRef), tx.get(economyRef), tx.get(rateRef), tx.get(receivedRef),
        tx.get(blockRef), tx.get(txRef),
      ]);
      if (!senderSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const sender = senderSnap.data() ?? {};
      const previous = int(sender.coins, 0);
      const base: GiftResponse = {
        success: false,
        changed: false,
        previousBalance: previous,
        currentBalance: previous,
        delta: 0,
        reason: "",
        transactionId: "",
        insufficientBalance: false,
        expiresAt: 0,
      };

      if (txSnap.exists) {
        const stored = txSnap.data() ?? {};
        response = {
          ...base,
          success: true,
          changed: true,
          previousBalance: int(stored.balanceBefore, previous),
          currentBalance: int(stored.balanceAfter, previous),
          delta: int(stored.delta, 0),
          reason: str(stored.reason),
          transactionId: txId,
          expiresAt: int(stored.expiresAt, 0),
        };
        return;
      }

      const recipient = recipientSnap.data();
      if (!recipientSnap.exists || !recipient || recipient.deleted === true) {
        throw new HttpsError("not-found", "gift_recipient_not_found");
      }
      if (recipient.premium === true) {
        response = {...base, reason: "gift_recipient_premium"};
        return;
      }
      if (blockSnap.exists) {
        response = {...base, reason: "gift_blocked"};
        return;
      }
      if (readDailyCount(receivedSnap, today) >= 1) {
        response = {...base, reason: "gift_recipient_limit"};
        return;
      }
      const sentToday = readDailyCount(rateSnap, today);
      if (sentToday >= GIFTS_PER_DAY) {
        response = {...base, reason: "gift_daily_limit"};
        return;
      }
      if (previous < price) {
        response = {...base, insufficientBalance: true, reason: "giftPremiumPass_insufficient_balance"};
        return;
      }

      const economy = economySnap.data() ?? {};
      const passes = (typeof economy.passes === "object" && economy.passes !== null ? economy.passes : {}) as
        Record<string, unknown>;
      const expiresAt = nowMs + PASS_MS;
      const current = previous - price;
      const reason = `gift_to_${recipientUid}`;
      const ledger = coinTransactionDoc({
        id: txId,
        userId: uid,
        at: admin.firestore.Timestamp.fromMillis(nowMs),
        delta: -price,
        balanceBefore: previous,
        action: "giftPremiumPass",
        description: "Gift: 24 h Pro pass",
        sourceTag: "gifts.pass.callable",
        reason,
      });
      tx.update(senderRef, {coins: current});
      tx.set(txRef, {...ledger, expiresAt});
      tx.set(rateRef, {day: today, count: sentToday + 1});
      tx.set(receivedRef, {day: today, count: 1});
      tx.set(economyRef, {rev: int(economy.rev, 0) + 1, passes: {...passes, premiumPassUntil: expiresAt}}, {merge: true});
      notice = {
        senderName: str(sender.name) || str(sender.username) || "A Prism user",
        recipientEmail: str(recipient.email),
      };
      response = {
        ...base,
        success: true,
        changed: true,
        currentBalance: current,
        delta: -price,
        reason,
        transactionId: txId,
        expiresAt,
      };
    });
    if (!response) throw new HttpsError("internal", "Gift did not finish.");

    const sent = notice as {senderName: string; recipientEmail: string} | null;
    if (sent) {
      try {
        await giftIo.notify({
          title: `${sent.senderName} sent you a 24-hour Pro pass`,
          body: "Premium collections and premium walls are open until tomorrow.",
          data: {route: "rewards"},
          modifier: recipientUid,
          channelId: "gifts",
          docId: `gift_${uid}_${requestId}`,
        }, {uid: recipientUid, email: sent.recipientEmail});
      } catch (err) {
        logger.warn("giftPremiumPass: notification failed.", {err});
      }
    }
    return response;
  },
);
