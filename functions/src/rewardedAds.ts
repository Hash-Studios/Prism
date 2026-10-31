import {createHash, randomBytes} from "node:crypto";
import * as admin from "firebase-admin";
import {HttpsError, onCall, onRequest, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, utcDateString} from "./common";
import {loadEconomy} from "./economy";
import {applyQuestEvent, buildQuestState} from "./questCatalog";
import {GoogleSsvVerifier, SsvInvalid} from "./admobSsv";

const SHOW_MS = 600_000;
const GRACE_MS = 86_400_000;
const ID = /^[A-Za-z0-9_-]{8,64}$/;
const digest = (value: string) => createHash("sha256").update(value).digest("hex");
const sessionRef = (uid: string, requestId: string) => db.doc(`rewardedAdSessions/${digest(`${uid}:${requestId}`)}`);
const options = {region: "us-central1", cors: true, maxInstances: 10};
type Pending = Record<string, number>;
export function liveReservations(raw: unknown, now: number): Pending {
  const result: Pending = {};
  if (raw && typeof raw === "object") {
    for (const [id, until] of Object.entries(raw)) {
      if (typeof until === "number" && until >= now) result[id] = until;
    }
  }
  return result;
}

export function rewardedConfig() {
  const android = process.env.REWARDED_AD_ANDROID_UNIT_ID ?? "";
  const ios = process.env.REWARDED_AD_IOS_UNIT_ID ?? "";
  const rewardType = process.env.REWARDED_AD_GOOGLE_REWARD_TYPE ?? "";
  const amount = process.env.REWARDED_AD_GOOGLE_REWARD_AMOUNT ?? "";
  const validUnit = (unit: string) => /^ca-app-pub-\d{16}\/\d{10}$/.test(unit) && !unit.startsWith("ca-app-pub-3940256099942544/");
  return {android, ios, rewardType, amount,
    enabled: process.env.REWARDED_AD_ENABLED === "true" && validUnit(android) && validUnit(ios) &&
      /^[A-Za-z0-9_. -]{1,64}$/.test(rewardType) && /^[1-9]\d{0,8}$/.test(amount)};
}

function caller(request: CallableRequest<unknown>): string {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return request.auth.uid;
}
function identifier(value: unknown): string {
  if (typeof value !== "string" || !ID.test(value)) throw new HttpsError("invalid-argument", "Invalid request/session ID.");
  return value;
}
function fields(data: unknown, allowed: string[]): Record<string, unknown> {
  if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Invalid fields.");
  }
  return data as Record<string, unknown>;
}
async function userInTransaction(tx: admin.firestore.Transaction, uid: string) {
  const ref = db.doc(`usersv2/${uid}`);
  const user = await tx.get(ref);
  const barrier = await tx.get(db.doc(`creatorDeletionState/${uid}`));
  if (!user.exists || user.data()?.deleted === true || barrier.exists) {
    throw new HttpsError("not-found", "User profile unavailable.");
  }
  return {ref, data: user.data() ?? {}};
}

export const beginRewardedSession = onCall(options, async (request: CallableRequest<unknown>) => {
  const uid = caller(request);
  const data = fields(request.data, ["requestId", "placement", "platform"]);
  const requestId = identifier(data.requestId);
  if (typeof data.placement !== "string" || !/^[A-Za-z0-9_.-]{1,120}$/.test(data.placement) ||
      (data.platform !== "android" && data.platform !== "ios")) throw new HttpsError("invalid-argument", "Invalid placement/platform.");
  const config = rewardedConfig();
  const economy = await loadEconomy();
  const now = Date.now();
  const day = utcDateString(new Date(now));
  const ref = sessionRef(uid, requestId);
  const rateRef = db.doc(`coinAdRateDaily/${uid}_${day}`);
  const lockRef = db.doc(`rewardedAdUsers/${uid}`);
  return db.runTransaction(async (tx) => {
    await userInTransaction(tx, uid);
    const old = await tx.get(ref);
    const rate = (await tx.get(rateRef)).data() ?? {};
    const lock = (await tx.get(lockRef)).data() ?? {};
    const pending = liveReservations(rate.reservations, now);
    const adsRemaining = Math.max(0, economy.award.rewardedAdMaxPerDay - int(rate.count) - Object.keys(pending).length);
    if (old.exists) {
      const saved = old.data()!;
      if (saved.placement !== data.placement || saved.platform !== data.platform) {
        throw new HttpsError("invalid-argument", "requestId already used with different fields.");
      }
      return saved.reservation;
    }
    const unavailable = (reason: string, retryAtMs?: number) => ({version: 1, status: "unavailable", reason,
      adsRemaining, ...(retryAtMs === undefined ? {} : {retryAtMs})});
    if (!config.enabled) return unavailable("disabled");
    if (int(lock.showBeforeMs) > now) return unavailable("active_session", int(lock.showBeforeMs));
    if (adsRemaining === 0) return unavailable("daily_limit");
    const cooldownUntil = Math.max(int(rate.lastAt) + 20_000, int(lock.cooldownUntilMs));
    if (cooldownUntil > now) return unavailable("cooldown", cooldownUntil);
    const rewardCoins = int(rate.count) + Object.keys(pending).length === 0 ?
      economy.award.rewardedAdFirstOfDay : economy.award.rewardedAd;
    const reservation = {version: 1, status: "reserved", sessionId: ref.id, userId: uid,
      customData: `${ref.id}.${randomBytes(24).toString("base64url")}`, adUnitId: config[data.platform as "android" | "ios"],
      rewardCoins, showBeforeMs: now + SHOW_MS, callbackBeforeMs: now + SHOW_MS + GRACE_MS, adsRemaining: adsRemaining - 1};
    tx.set(ref, {uid, requestId, placement: data.placement, platform: data.platform, day, createdAtMs: now,
      ...reservation, reservation, rewardType: config.rewardType, rewardAmount: config.amount});
    tx.set(rateRef, {...rate, reservations: {...pending, [ref.id]: reservation.callbackBeforeMs}, lastAt: now});
    tx.set(lockRef, {sessionId: ref.id, showBeforeMs: reservation.showBeforeMs});
    return reservation;
  });
});

export const getRewardedSession = onCall(options, async (request: CallableRequest<unknown>) => {
  const uid = caller(request);
  const data = fields(request.data, ["sessionId", "requestId"]);
  if ((data.sessionId === undefined) === (data.requestId === undefined)) throw new HttpsError("invalid-argument", "Supply one ID.");
  const ref = data.sessionId === undefined ? sessionRef(uid, identifier(data.requestId)) :
    db.doc(`rewardedAdSessions/${identifier(data.sessionId)}`);
  const economy = await loadEconomy();
  return db.runTransaction(async (tx) => {
    const user = await userInTransaction(tx, uid);
    const saved = (await tx.get(ref)).data();
    if (!saved || saved.uid !== uid) throw new HttpsError("not-found", "Session unavailable.");
    const now = Date.now();
    const rate = (await tx.get(db.doc(`coinAdRateDaily/${uid}_${utcDateString(new Date(now))}`))).data() ?? {};
    return {version: 1, sessionId: ref.id, status: saved.status === "settled" ? "settled" :
      now > saved.callbackBeforeMs ? "expired" : "reserved", rewardCoins: saved.rewardCoins,
    ...(saved.transactionId ? {transactionId: saved.transactionId} : {}), currentBalance: int(user.data.coins),
    adsRemaining: Math.max(0, economy.award.rewardedAdMaxPerDay - int(rate.count) - Object.keys(liveReservations(rate.reservations, now)).length)};
  });
});

export async function settleVerifiedReward(params: URLSearchParams): Promise<void> {
  const required = ["ad_network", "ad_unit", "custom_data", "reward_amount", "reward_item", "timestamp", "transaction_id", "user_id"];
  const allowed = new Set([...required, "signature", "key_id"]);
  if (required.some((name) => !params.get(name)) || [...params.keys()].some((key) => !allowed.has(key)) ||
      !/^\d{1,16}$/.test(params.get("timestamp")!) || !/^[A-Za-z0-9_-]{1,200}$/.test(params.get("transaction_id")!) ||
      !/^\d{1,30}$/.test(params.get("ad_network")!)) throw new SsvInvalid("invalid callback fields");
  const [id, token, extra] = params.get("custom_data")!.split(".");
  if (!/^[a-f0-9]{64}$/.test(id) || !/^[A-Za-z0-9_-]{32}$/.test(token ?? "") || extra !== undefined) throw new SsvInvalid("invalid custom data");
  const economy = await loadEconomy();
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const ref = db.doc(`rewardedAdSessions/${id}`);
    const session = (await tx.get(ref)).data();
    if (!session) throw new SsvInvalid("unknown session");
    const timestamp = Number(params.get("timestamp"));
    if (session.customData !== `${id}.${token}` || session.uid !== params.get("user_id") ||
        ![session.adUnitId, String(session.adUnitId).split("/").pop()].includes(params.get("ad_unit")) ||
        session.rewardType !== params.get("reward_item") || session.rewardAmount !== params.get("reward_amount") ||
        timestamp < session.createdAtMs || timestamp > session.showBeforeMs || timestamp > now + 60_000) throw new SsvInvalid("callback mismatch");
    const googleId = params.get("transaction_id")!;
    const receiptRef = db.doc(`rewardedAdGoogleTransactions/${digest(googleId)}`);
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.sessionId !== id) throw new SsvInvalid("transaction reused");
      return;
    }
    if (session.status === "settled") throw new SsvInvalid("session already settled");
    if (now > session.callbackBeforeMs) throw new SsvInvalid("callback expired");
    const userRef = db.doc(`usersv2/${session.uid}`);
    const user = await tx.get(userRef);
    const barrier = await tx.get(db.doc(`creatorDeletionState/${session.uid}`));
    if (!user.exists || user.data()?.deleted === true || barrier.exists) return;
    const rateRef = db.doc(`coinAdRateDaily/${session.uid}_${session.day}`);
    const rate = (await tx.get(rateRef)).data() ?? {};
    const privateRef = db.doc(`usersv2/${session.uid}/private/economy`);
    const privateData = (await tx.get(privateRef)).data() ?? {};
    const lockRef = db.doc(`rewardedAdUsers/${session.uid}`);
    const lock = (await tx.get(lockRef)).data() ?? {};
    const pending = liveReservations(rate.reservations, now);
    delete pending[id];
    const data = user.data()!;
    const transactionId = `ssv_${id}`;
    const adsToday = typeof data.coinState?.adsToday?.day === "string" && data.coinState.adsToday.day > session.day ?
      data.coinState.adsToday : {day: session.day, count: int(rate.count) + 1};
    tx.update(userRef, {coins: int(data.coins) + session.rewardCoins,
      coinState: {...data.coinState, adsToday}});
    tx.set(rateRef, {...rate, count: int(rate.count) + 1, reservations: pending, lastAt: now});
    tx.set(lockRef, {...lock, cooldownUntilMs: now + 20_000,
      ...(lock.sessionId === id ? {showBeforeMs: 0} : {})});
    tx.set(privateRef, {rev: int(privateData.rev) + 1,
      quests: applyQuestEvent(buildQuestState(privateData.quests, now, data.premium === true), "watch_ad", economy).state}, {merge: true});
    tx.set(db.doc(`coinTransactions/${transactionId}`), coinTransactionDoc({id: transactionId, userId: session.uid,
      at: admin.firestore.Timestamp.fromMillis(now), delta: session.rewardCoins, balanceBefore: int(data.coins),
      action: "rewardedAd", sourceTag: session.placement, reason: "google_ssv", description: "Verified rewarded ad"}));
    tx.update(ref, {status: "settled", transactionId});
    tx.set(receiptRef, {sessionId: id});
  });
}

const verifier = new GoogleSsvVerifier();
export const admobRewardedSsv = onRequest({region: "us-central1", maxInstances: 10}, async (request, response) => {
  if (request.method !== "GET") {
    response.status(405).send("GET required"); return;
  }
  try {
    const raw = request.originalUrl.split("?")[1] ?? "";
    await settleVerifiedReward(await verifier.verify(raw));
    response.status(200).send("OK");
  } catch (error) {
    response.status(error instanceof SsvInvalid ? 400 : 503).send(error instanceof SsvInvalid ? "Invalid callback" : "Retry later");
  }
});
