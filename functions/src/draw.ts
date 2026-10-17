import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {duplicateSpendResponse, isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, REGION, str} from "./common";
import {loadEconomy, weekBounds, weekKey, weightedPick} from "./economy";
import {type PersonalPayload, type PushRecipient, sendToUser} from "./notificationHelper";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const DRAWS = "draws";
const DRAW_TICKETS = "drawTickets";
const MAX_TICKETS_PER_WEEK = 5;
const DAY_MS = 86_400_000;
/** Settled draws this far back are checked for prize steps that failed. */
const RETRY_WEEKS = 4;
const PRIZE = {proMonths: 1, itemId: "frame_prism"};
const revenueCatSecret = defineSecret("REVENUECAT_SECRET_KEY");

/** Overridable in tests. */
export const drawIo = {
  /** A fixed `startMs` makes a retried grant end on the same day instead of adding a second month. */
  async grantPro(uid: string, startMs: number): Promise<void> {
    const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}` +
      "/entitlements/prism_v3_pro_access/promotional";
    const response = await fetch(url, {
      method: "POST",
      headers: {"Authorization": `Bearer ${revenueCatSecret.value()}`, "Content-Type": "application/json"},
      body: JSON.stringify({duration: "monthly", start_time_ms: startMs}),
    });
    if (!response.ok) throw new Error(`RevenueCat answered ${response.status}`);
  },
  notify: (payload: PersonalPayload, recipient: PushRecipient): Promise<boolean> => sendToUser(payload, recipient),
};

async function notifyWinner(uid: string, drawWeek: string, user: admin.firestore.DocumentData): Promise<void> {
  const email = str(user.email);
  await drawIo.notify({
    title: "You won the Prism Draw",
    body: "One month of Pro and the Prism frame are yours.",
    data: {route: "rewards"},
    // The in-app inbox lists personal notifications by the recipient's email.
    modifier: email || uid,
    channelId: "draw",
    docId: `draw_${drawWeek}_winner`,
  }, {uid, email, loggedOut: user.loggedIn === false, legacyToken: user.fcmToken});
}

/** When the draw of the week containing `nowMs` closes: the next Monday 00:00 UTC. */
export function nextCloseMs(nowMs: number): number {
  return weekBounds(nowMs).end;
}

/** The uid of a ticket holder, chosen with odds in line with their ticket count. Null with no tickets. */
export function pickWinner(tickets: Array<{uid: string; count: number}>, random: () => number): string | null {
  const holders = tickets.filter((t) => t.count > 0).sort((a, b) => (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));
  if (holders.length === 0) return null;
  return holders[weightedPick(holders.map((t) => ({weight: t.count})), random)].uid;
}

const num = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : 0;

export const buyDrawTicket = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<{requestId?: unknown}>) => {
    const callerUid = request.auth?.uid?.trim() ?? "";
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to buy a draw ticket.");
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");

    const config = await loadEconomy();
    const nowMs = Date.now();
    const key = weekKey(nowMs);
    const closesAt = nextCloseMs(nowMs);
    const price = config.spend.drawTicket;
    const txId = `ctx_draw_${callerUid}_${requestId}`;
    const userRef = db.collection(USERS).doc(callerUid);
    const txRef = db.collection(TRANSACTIONS).doc(txId);
    const drawRef = db.collection(DRAWS).doc(key);
    const ticketRef = db.collection(DRAW_TICKETS).doc(`${key}_${callerUid}`);
    let response: Record<string, unknown> = {
      success: false,
      changed: false,
      previousBalance: 0,
      currentBalance: 0,
      delta: 0,
      reason: "draw_disabled",
      transactionId: "",
      tickets: 0,
      weekKey: key,
      closesAt,
    };
    if (!config.flags.drawEnabled) return response;

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const txSnap = await tx.get(txRef);
      const drawSnap = await tx.get(drawRef);
      const ticketSnap = await tx.get(ticketRef);
      const balance = num(userSnap.data()?.coins);
      const isPremium = userSnap.data()?.premium === true;
      const owned = num(ticketSnap.data()?.count);
      const draw = drawSnap.data();
      const base = {...response, previousBalance: balance, currentBalance: balance, tickets: owned};
      if (txSnap.exists) {
        const original = txSnap.data() ?? {};
        response = duplicateSpendResponse(
          {...base, tickets: num(original.tickets), weekKey: str(original.weekKey) || key,
            closesAt: num(original.closesAt) || closesAt},
          original, balance, str(original.reason),
        );
        return;
      }
      if (isPremium) {
        response = {...base, reason: "draw_pro_not_eligible"};
        return;
      }
      if (draw && (draw.status !== "open" || nowMs >= num(draw.closesAt))) {
        response = {...base, reason: "draw_closed"};
        return;
      }
      if (owned >= MAX_TICKETS_PER_WEEK) {
        response = {...base, reason: "draw_ticket_limit"};
        return;
      }
      if (balance < price) {
        response = {...base, insufficientBalance: true, reason: "drawTicket_insufficient_balance"};
        return;
      }
      const tickets = owned + 1;
      tx.update(userRef, {coins: balance - price});
      if (!drawSnap.exists) {
        tx.set(drawRef, {
          weekKey: key, status: "open", closesAt, tickets: 1, participants: 1, prize: PRIZE,
        });
      } else {
        tx.update(drawRef, {
          "tickets": admin.firestore.FieldValue.increment(1),
          ...(ticketSnap.exists ? {} : {participants: admin.firestore.FieldValue.increment(1)}),
        });
      }
      if (ticketSnap.exists) tx.update(ticketRef, {count: admin.firestore.FieldValue.increment(1)});
      else tx.set(ticketRef, {weekKey: key, uid: callerUid, count: 1});
      tx.set(txRef, {
        ...coinTransactionDoc({
          id: txId,
          userId: callerUid,
          at: admin.firestore.Timestamp.now(),
          delta: -price,
          balanceBefore: balance,
          action: "drawTicket",
          description: "Prism Draw ticket",
          sourceTag: "draw.ticket.callable",
          reason: `draw_${key}`,
        }),
        tickets,
        weekKey: key,
        closesAt,
      });
      response = {
        ...base,
        success: true,
        changed: true,
        currentBalance: balance - price,
        delta: -price,
        reason: `draw_${key}`,
        transactionId: txId,
        tickets,
      };
    });
    return response;
  },
);

/** Phase 1: picks the winner and marks the draw settled. Does nothing when it is not open or has no tickets. */
async function closeDraw(key: string, nowMs: number, random: () => number): Promise<void> {
  const drawRef = db.collection(DRAWS).doc(key);
  const draw = (await drawRef.get()).data();
  if (!draw || draw.status !== "open") return;
  // The counters on the draw doc are for display. The ticket docs decide.
  const ticketSnap = await db.collection(DRAW_TICKETS).where("weekKey", "==", key).get();
  const winnerUid = pickWinner(ticketSnap.docs.map((d) => ({uid: str(d.data().uid), count: num(d.data().count)})), random);
  if (!winnerUid) return;
  const winner = (await db.collection(USERS).doc(winnerUid).get()).data() ?? {};
  const winnerName = str(winner.name) || str(winner.username) || "A Prism member";
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(drawRef)).data();
    if (current?.status !== "open") return;
    tx.update(drawRef, {status: "settled", winnerUid, winnerName, settledAt: nowMs});
  });
}

/** Phase 2: each prize step flips its own flag, so a later run redoes only what failed. */
async function grantPrize(key: string, nowMs: number): Promise<void> {
  const drawRef = db.collection(DRAWS).doc(key);
  const draw = (await drawRef.get()).data();
  if (!draw || draw.status !== "settled" || !str(draw.winnerUid)) return;
  const winnerUid = str(draw.winnerUid);
  const itemId = str(draw.prize?.itemId) || PRIZE.itemId;
  const errors: string[] = [];
  const step = async (flag: string, run: () => Promise<void>) => {
    try {
      await run();
      draw[flag] = true;
    } catch (err) {
      logger.error("settleDraw: a prize step failed.", {weekKey: key, flag, err});
      errors.push(`${flag}: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  if (draw.prizeItemGranted !== true) {
    await step("prizeItemGranted", async () => {
      const economyRef = db.collection(USERS).doc(winnerUid).collection("private").doc("economy");
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(drawRef)).data();
        const economy = await tx.get(economyRef);
        if (current?.prizeItemGranted === true) return;
        if (economy.exists) {
          const owned = economy.data()?.inventory?.owned?.[itemId] !== undefined;
          tx.update(economyRef, {
            ...(owned ? {} : {[`inventory.owned.${itemId}`]: nowMs}),
            rev: admin.firestore.FieldValue.increment(1),
          });
        } else {
          tx.set(economyRef, {rev: 1, inventory: {owned: {[itemId]: nowMs}}}, {merge: true});
        }
        tx.update(drawRef, {prizeItemGranted: true});
      });
    });
  }
  if (draw.prizeProGranted !== true) {
    await step("prizeProGranted", async () => {
      const startMs = await db.runTransaction(async (tx) => {
        const stored = num((await tx.get(drawRef)).data()?.prizeProStartMs);
        if (stored > 0) return stored;
        tx.update(drawRef, {prizeProStartMs: nowMs});
        return nowMs;
      });
      await drawIo.grantPro(winnerUid, startMs);
      await drawRef.update({prizeProGranted: true});
    });
  }
  if (draw.winnerNotified !== true && draw.prizeItemGranted === true && draw.prizeProGranted === true) {
    await step("winnerNotified", async () => {
      const user = (await db.collection(USERS).doc(winnerUid).get()).data() ?? {};
      await notifyWinner(winnerUid, key, user);
      await drawRef.update({winnerNotified: true});
    });
  }
  if (errors.length > 0) await drawRef.update({prizeGrantError: errors.join("; ")});
  else if (draw.prizeGrantError !== undefined) {
    await drawRef.update({prizeGrantError: admin.firestore.FieldValue.delete()});
  }
}

/** Settles last week's draw, then retries missing prize steps of the last four weeks. */
export async function runSettleDraw(nowMs: number, random: () => number = Math.random): Promise<void> {
  const lastWeekMs = nowMs - DAY_MS;
  await closeDraw(weekKey(lastWeekMs), nowMs, random);
  for (let ago = 0; ago < RETRY_WEEKS; ago += 1) {
    await grantPrize(weekKey(lastWeekMs - ago * 7 * DAY_MS), nowMs);
  }
}

export const settleDraw = onSchedule(
  {schedule: "10 0 * * 1", timeZone: "UTC", region: REGION, retryCount: 1, secrets: [revenueCatSecret]},
  async () => {
    await runSettleDraw(Date.now());
  },
);
