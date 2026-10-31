import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {
  coinTransactionDoc,
  db,
  int,
  readDailyCount,
  CALLABLE_REGIONS,
  str,
  utcDateString,
} from "./common";
import {approvedWall} from "./creatorProgress";
import {hash, isoWeek, weekStart} from "./creatorStatsHistory";
import {notificationCopyPayload} from "./notificationCatalog";
import {
  type PersonalPayload,
  type PushRecipient,
  sendToUser,
} from "./notificationHelper";
import {normalizeId, WALLPAPER_STATS} from "./viewStats";

export const TIP_AMOUNTS: readonly number[] = [10, 25, 50];
/** A real fan rarely tips more than a few creators a day. Five keeps one alt's daily output to 250 coins at most. */
export const TIPS_SENT_PER_DAY = 5;
/**
 * Below the 210 coins one honest account can earn a day from ads alone, so alts that pool coins into one creator
 * cannot out-earn a real user. The caps reset at 00:00 UTC, so a burst across midnight can reach twice this.
 */
export const TIP_COINS_RECEIVED_PER_DAY = 100;
const SENDER_MIN_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const WEEKS_KEPT = 9;

/** Overridable in tests. */
export const tipIo = {
  /** Account age, and whether it is a verified, non-guest sign-in. */
  async sender(uid: string): Promise<{createdMs: number; verified: boolean}> {
    const user = await admin.auth().getUser(uid);
    return {
      createdMs: Date.parse(user.metadata.creationTime),
      verified: user.emailVerified === true && !user.disabled &&
        user.providerData.some((provider) => !!provider.providerId && provider.providerId !== "anonymous"),
    };
  },
  /** True when the creator has no Auth user or it is disabled (banned). */
  async creatorDisabled(uid: string): Promise<boolean> {
    try {
      return (await admin.auth().getUser(uid)).disabled;
    } catch (err) {
      if ((err as {code?: string}).code === "auth/user-not-found") return true;
      throw err;
    }
  },
  notify: (
    payload: PersonalPayload,
    recipient: PushRecipient,
    pushEnabled: boolean,
  ): Promise<boolean> => sendToUser(payload, recipient, pushEnabled),
};

export interface TipResponse {
  success: boolean;
  changed: boolean;
  previousBalance: number;
  currentBalance: number;
  delta: number;
  amount: number;
  reason: string;
  transactionId: string;
  tipId: string;
  insufficientBalance: boolean;
}

type Tally = {count: number; coins: number};
type CreatorTips = Tally & {weeks: Record<string, Tally>; walls: Record<string, Tally>};

function tally(raw: unknown): Tally {
  const value = (typeof raw === "object" && raw !== null ? raw : {}) as Record<string, unknown>;
  return {count: Math.max(0, int(value.count, 0)), coins: Math.max(0, int(value.coins, 0))};
}

function tallies(raw: unknown): Record<string, Tally> {
  if (typeof raw !== "object" || raw === null) return {};
  return Object.fromEntries(Object.entries(raw as Record<string, unknown>).map(([key, value]) => [key, tally(value)]));
}

const add = (value: Tally, coins: number): Tally => ({count: value.count + 1, coins: value.coins + coins});

/** Adds one tip to the creator's totals. Weeks older than the stats window are dropped. */
export function addTip(raw: admin.firestore.DocumentData | undefined, amount: number, wallId: string,
  nowMs: number): CreatorTips {
  const keep = new Set(Array.from({length: WEEKS_KEPT}, (_, i) => isoWeek(weekStart(nowMs) - i * WEEK_MS)));
  const weeks = Object.fromEntries(Object.entries(tallies(raw?.weeks)).filter(([week]) => keep.has(week)));
  const week = isoWeek(nowMs);
  weeks[week] = add(weeks[week] ?? {count: 0, coins: 0}, amount);
  const walls = tallies(raw?.walls);
  if (wallId) walls[wallId] = add(walls[wallId] ?? {count: 0, coins: 0}, amount);
  return {...add(tally(raw), amount), weeks, walls};
}

function wallIdFrom(raw: unknown): string {
  if (raw === undefined || raw === null || raw === "") return "";
  if (typeof raw !== "string" || raw.length > 128 || raw.includes("/") || raw.trim() !== raw) {
    throw new HttpsError("invalid-argument", "wallId is invalid.");
  }
  return raw;
}

function statsIdOf(wall: admin.firestore.DocumentData): string {
  try {
    return normalizeId(wall.id);
  } catch {
    return "";
  }
}

const refused = (reason: string, previous = 0): TipResponse => ({
  success: false,
  changed: false,
  previousBalance: previous,
  currentBalance: previous,
  delta: 0,
  amount: 0,
  reason,
  transactionId: "",
  tipId: "",
  insufficientBalance: false,
});

function stored(data: admin.firestore.DocumentData, txId: string): TipResponse {
  const delta = int(data.delta, 0);
  return {
    success: true,
    changed: true,
    previousBalance: int(data.balanceBefore, 0),
    currentBalance: int(data.balanceAfter, 0),
    delta,
    amount: -delta,
    reason: str(data.reason),
    transactionId: txId,
    tipId: str(data.tipId),
    insufficientBalance: false,
  };
}

/** Moves a fixed coin tip from the caller to a creator, with both ledger entries, in one transaction. */
export const tipCreator = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10},
  async (
    request: CallableRequest<{
      creatorUid?: unknown;
      amount?: unknown;
      wallId?: unknown;
      requestId?: unknown;
    }>,
  ): Promise<TipResponse> => {
    const uid = str(request.auth?.uid);
    if (!uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to tip.");
    }
    const creatorUid = str(request.data?.creatorUid);
    if (creatorUid === "" || creatorUid.length > 128 || creatorUid.includes("/")) {
      throw new HttpsError("invalid-argument", "creatorUid is invalid.");
    }
    if (creatorUid === uid) {
      throw new HttpsError("invalid-argument", "tip_self");
    }
    const amount = request.data?.amount;
    if (typeof amount !== "number" || !TIP_AMOUNTS.includes(amount)) {
      throw new HttpsError("invalid-argument", "amount is invalid.");
    }
    const wallId = wallIdFrom(request.data?.wallId);
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) {
      throw new HttpsError("invalid-argument", "requestId is invalid.");
    }

    const senderKey = encodeURIComponent(uid).replace(/_/g, "%5F");
    const creatorKey = encodeURIComponent(creatorUid).replace(/_/g, "%5F");
    const tipId = `tip_${senderKey}_${requestId}`;
    const txId = `ctx_tip_${senderKey}_${requestId}`;
    const txRef = db.collection("coinTransactions").doc(txId);
    // A retry of a finished tip returns its result even if the creator or the day changed since.
    const done = await txRef.get();
    if (done.exists) return stored(done.data() ?? {}, txId);

    const nowMs = Date.now();
    const account = await tipIo.sender(uid);
    if (!account.verified) return refused("tip_sender_ineligible");
    if (!Number.isFinite(account.createdMs) || nowMs - account.createdMs < SENDER_MIN_AGE_MS) {
      return refused("tip_sender_too_new");
    }
    if (await tipIo.creatorDisabled(creatorUid)) return refused("tip_creator_unavailable");

    const senderRef = db.collection("usersv2").doc(uid);
    const creatorRef = db.collection("usersv2").doc(creatorUid);
    const creatorTxRef = db.collection("coinTransactions").doc(`ctx_tipin_${senderKey}_${requestId}`);
    const tipsRef = db.collection("creatorTips").doc(creatorUid);
    const wallRef = wallId ? db.collection("walls").doc(wallId) : null;

    let response: TipResponse | null = null;
    let notice: {payload: PersonalPayload; recipient: PushRecipient; push: boolean} | null = null;
    await db.runTransaction(async (tx) => {
      const nowMs = Date.now();
      const today = utcDateString(new Date(nowMs));
      const sentRef = db.collection("tipRateDaily").doc(`${senderKey}_${today}`);
      const receivedRef = db.collection("tipRateDaily").doc(`recv_${creatorKey}_${today}`);
      const pairRef = db.collection("tipRateDaily").doc(`pair_${senderKey}_${creatorKey}_${today}`);
      response = null;
      notice = null;
      const [
        txSnap, senderSnap, creatorSnap, barrierSnap, senderBarrierSnap, blockedBySnap, blockingSnap,
        sentSnap, receivedSnap, pairSnap, tipsSnap, wallSnap, approvedSnap,
      ] = await Promise.all([
        tx.get(txRef),
        tx.get(senderRef),
        tx.get(creatorRef),
        tx.get(db.collection("creatorDeletionState").doc(creatorUid)),
        tx.get(db.collection("creatorDeletionState").doc(uid)),
        tx.get(creatorRef.collection("blockedUsers").doc(uid)),
        tx.get(senderRef.collection("blockedUsers").doc(creatorUid)),
        tx.get(sentRef),
        tx.get(receivedRef),
        tx.get(pairRef),
        tx.get(tipsRef),
        wallRef ? tx.get(wallRef) : Promise.resolve(null),
        wallRef ? Promise.resolve(null) : tx.get(
          db.collection("walls").where("creatorUid", "==", creatorUid).where("review", "==", true).limit(20),
        ),
      ]);
      if (txSnap.exists) {
        response = stored(txSnap.data() ?? {}, txId);
        return;
      }
      const sender = senderSnap.data();
      if (!senderSnap.exists || !sender || sender.deleted === true || senderBarrierSnap.data()?.closed === true) {
        throw new HttpsError("not-found", "User profile was not found.");
      }
      const previous = int(sender.coins, 0);
      const creator = creatorSnap.data();
      if (!creatorSnap.exists || !creator || creator.deleted === true || barrierSnap.data()?.closed === true) {
        response = refused("tip_creator_unavailable", previous);
        return;
      }
      const wall = wallSnap?.data();
      if (wallRef && (!wall || !approvedWall(wall) || wall.creatorUid !== creatorUid)) {
        response = refused("tip_wall_invalid", previous);
        return;
      }
      let approvedPage = approvedSnap;
      while (approvedPage && approvedPage.size === 20 && !approvedPage.docs.some((doc) => approvedWall(doc.data()))) {
        approvedPage = await tx.get(db.collection("walls").where("creatorUid", "==", creatorUid)
          .where("review", "==", true).startAfter(approvedPage.docs[approvedPage.docs.length - 1]).limit(20));
      }
      if (approvedPage && !approvedPage.docs.some((doc) => approvedWall(doc.data()))) {
        response = refused("tip_creator_unavailable", previous);
        return;
      }
      if (blockedBySnap.exists || blockingSnap.exists) {
        response = refused("tip_blocked", previous);
        return;
      }
      const sentToday = readDailyCount(sentSnap, today);
      if (sentToday >= TIPS_SENT_PER_DAY) {
        response = refused("tip_daily_limit", previous);
        return;
      }
      if (readDailyCount(pairSnap, today) >= 1) {
        response = refused("tip_pair_limit", previous);
        return;
      }
      const received = receivedSnap.data()?.day === today ? tally(receivedSnap.data()) : {count: 0, coins: 0};
      if (received.coins + amount > TIP_COINS_RECEIVED_PER_DAY) {
        response = refused("tip_creator_limit", previous);
        return;
      }
      if (previous < amount) {
        response = {...refused("tip_insufficient_balance", previous), insufficientBalance: true};
        return;
      }

      const statsId = wall ? statsIdOf(wall) : "";
      const tipperRef = statsId ? db.collection("wallTippers").doc(hash(JSON.stringify([statsId, uid]))) : null;
      const tipperSnap = tipperRef ? await tx.get(tipperRef) : null;
      const at = admin.firestore.Timestamp.fromMillis(nowMs);
      const link = {tipId, wallId};
      const senderLedger = coinTransactionDoc({
        id: txId,
        userId: uid,
        at,
        delta: -amount,
        balanceBefore: previous,
        action: "tipSent",
        description: `Tip: ${amount} coins`,
        sourceTag: "tips.callable",
        reason: `tip_to_${creatorUid}`,
      });
      const creatorPrevious = int(creator.coins, 0);
      const creatorLedger = coinTransactionDoc({
        id: creatorTxRef.id,
        userId: creatorUid,
        at,
        delta: amount,
        balanceBefore: creatorPrevious,
        action: "tipReceived",
        description: `Tip: ${amount} coins`,
        sourceTag: "tips.callable",
        reason: `tip_from_${uid}`,
      });
      const receivedNow = add(received, amount);
      tx.update(senderRef, {coins: previous - amount});
      tx.update(creatorRef, {coins: creatorPrevious + amount});
      tx.set(txRef, {...senderLedger, ...link, counterpartyUid: creatorUid});
      tx.set(creatorTxRef, {...creatorLedger, ...link, counterpartyUid: uid});
      tx.set(sentRef, {day: today, count: sentToday + 1, senderUid: uid});
      tx.set(pairRef, {day: today, count: 1, senderUid: uid, creatorUid});
      tx.set(receivedRef, {day: today, ...receivedNow, creatorUid});
      tx.set(tipsRef, addTip(tipsSnap.data(), amount, wallId, nowMs));
      if (tipperRef && statsId && !tipperSnap?.exists) {
        tx.create(tipperRef, {wallId, at});
        tx.set(db.collection(WALLPAPER_STATS).doc(statsId),
          {tippers: admin.firestore.FieldValue.increment(1)}, {merge: true});
      }
      const first = receivedNow.count === 1;
      const payload = {
        ...notificationCopyPayload(first ?
          {kind: "tipReceived", senderName: str(sender.name) || str(sender.username) || "A Prism user",
            amount, wallTitle: str(wall?.title)} :
          {kind: "tipsReceived", tipCount: receivedNow.count, coins: receivedNow.coins}),
        data: {route: "creator_stats", url: "prism://creator-stats", notification_kind: "tip_received"},
        modifier: str(creator.email) || creatorUid,
        channelId: "gifts",
        docId: `tips_${hash(`${creatorUid}:${today}`).slice(0, 32)}`,
        pushOnly: true,
      } satisfies PersonalPayload;
      tx.set(db.collection("notifications").doc(payload.docId), {
        notification: {title: payload.title, body: payload.body},
        message: {kind: payload.message.kind, args: payload.message.args},
        data: {...payload.data, imageUrl: "", pageName: "", arguments: []},
        modifier: payload.modifier,
        pushHandled: true,
        createdAt: at,
      });
      notice = {payload, recipient: {uid: creatorUid, email: str(creator.email)}, push: first};
      response = {
        success: true,
        changed: true,
        previousBalance: previous,
        currentBalance: previous - amount,
        delta: -amount,
        amount,
        reason: senderLedger.reason as string,
        transactionId: txId,
        tipId,
        insufficientBalance: false,
      };
    });
    if (!response) throw new HttpsError("internal", "Tip did not finish.");

    const sent = notice as {payload: PersonalPayload; recipient: PushRecipient; push: boolean} | null;
    if (sent) {
      try {
        await tipIo.notify(sent.payload, sent.recipient, sent.push);
      } catch (err) {
        logger.warn("tipCreator: notification failed.", {err});
      }
    }
    return response;
  },
);
