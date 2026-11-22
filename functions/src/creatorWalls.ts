import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, int, readDailyCount, CALLABLE_REGIONS, REGION, str, utcDateString} from "./common";
import {approvedWall} from "./creatorProgress";
import {loadEconomy} from "./economy";
import {addTip} from "./tips";

/** Integer percent of the price that goes to the creator, rounded down. Code, not config: it is the promise to creators. */
export const CREATOR_SHARE_PERCENT = 70;
export const MIN_CREATOR_PRICE = 10;
export const MAX_CREATOR_PRICE = 1000;
export const UNLOCKS_PER_BUYER_PER_DAY = 10;
export const UNLOCKS_PER_PAIR_PER_DAY = 3;
/** Creator share a creator may receive in one UTC day. Bounds laundering through alts. */
export const CREATOR_SALE_COINS_PER_DAY = 500;
export const UNLOCKS = "creatorWallUnlocks";
export const SALES = "creatorSales";
export const SALE_DAILY = "creatorWallSaleDaily";
const MIN_ACCOUNT_AGE_MS = 7 * 24 * 60 * 60 * 1000;

export const creatorShareOf = (price: number): number => Math.floor(price * CREATOR_SHARE_PERCENT / 100);

/** The price a wall sells at, or 0 when it has none. */
export function creatorPriceOf(wall: admin.firestore.DocumentData | undefined): number {
  const price = wall?.creatorPrice;
  return typeof price === "number" && Number.isInteger(price) && price >= MIN_CREATOR_PRICE &&
    price <= MAX_CREATOR_PRICE ? price : 0;
}

export const unlockRef = (uid: string, wallDocId: string) =>
  db.collection("usersv2").doc(uid).collection(UNLOCKS).doc(wallDocId);

/** True when the marker grants this buyer the wall: it names the wall and was not refunded. */
export function unlockGrants(marker: admin.firestore.DocumentData | undefined, wall: admin.firestore.DocumentData,
  wallDocId: string): boolean {
  return !!marker && marker.wallDocId === wallDocId && marker.wallId === wall.id && marker.refundedAt === undefined;
}

const key = (uid: string) => encodeURIComponent(uid).replace(/_/g, "%5F");
const sha = (text: string) => createHash("sha256").update(text).digest("hex");

/** Overridable in tests. */
export const creatorWallIo = {
  async account(uid: string): Promise<{createdMs: number; verified: boolean}> {
    const user = await admin.auth().getUser(uid);
    return {
      createdMs: Date.parse(user.metadata.creationTime),
      verified: user.emailVerified === true && !user.disabled &&
        user.providerData.some((provider) => !!provider.providerId && provider.providerId !== "anonymous"),
    };
  },
  async disabled(uid: string): Promise<boolean> {
    try {
      return (await admin.auth().getUser(uid)).disabled;
    } catch (err) {
      if ((err as {code?: string}).code === "auth/user-not-found") return true;
      throw err;
    }
  },
};

/** Studio, AI, remix, live, streak and Drop walls, and walls from other providers, are never for sale. */
function originalUpload(wall: admin.firestore.DocumentData): boolean {
  return str(wall.wallpaper_provider).toLowerCase() === "prism" && wall.origin !== "studio" && wall.byStudio !== true &&
    wall.isAiGenerated !== true && !wall.aiGenerationId && !wall.remixOf && wall.kind !== "live" &&
    wall.is_streak_exclusive !== true && wall.dropReserved !== true && !wall.dropWeek && wall.heldForReview !== true &&
    wall.wallpaper_url === "";
}

/** An approved wall whose protected original is the creator's own private upload. */
function sellable(wall: admin.firestore.DocumentData, manifest: admin.firestore.DocumentData | undefined,
  wallRef: admin.firestore.DocumentReference, creatorUid: string): boolean {
  return originalUpload(wall) && approvedWall(wall) && wall.originalProtected === true &&
    manifest?.status === "ready" && manifest.canonicalPath === wallRef.path &&
    manifest.provenance?.kind === "owned" && manifest.provenance?.uid === creatorUid &&
    wall.originalObjectId === manifest.original?.objectId;
}

function wallDocIdFrom(raw: unknown): string {
  if (typeof raw !== "string" || raw === "" || raw.length > 128 || raw.includes("/") || raw.trim() !== raw ||
    raw === "." || raw === ".." || /^__.*__$/.test(raw)) {
    throw new HttpsError("invalid-argument", "wallId is invalid.");
  }
  return raw;
}

async function eligibleAccount(uid: string): Promise<"" | "ineligible" | "too_new"> {
  const account = await creatorWallIo.account(uid);
  if (!account.verified) return "ineligible";
  if (!Number.isFinite(account.createdMs) || Date.now() - account.createdMs < MIN_ACCOUNT_AGE_MS) return "too_new";
  return "";
}

export interface SetWallPriceResponse {success: boolean; reason: string; price: number}

/** Puts a price on, changes or removes (price 0) the price of the caller's own original upload. */
export const setWallPrice = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{wallId?: unknown; price?: unknown}>): Promise<SetWallPriceResponse> => {
    const uid = str(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");
    const wallDocId = wallDocIdFrom(request.data?.wallId);
    const price = request.data?.price;
    if (typeof price !== "number" || !Number.isInteger(price)) {
      throw new HttpsError("invalid-argument", "price is invalid.");
    }
    const economy = await loadEconomy();
    if (price !== 0 && !economy.creatorWalls.prices.includes(price)) {
      throw new HttpsError("invalid-argument", "price is invalid.");
    }
    const refused = (reason: string): SetWallPriceResponse => ({success: false, reason, price: 0});
    if (!economy.flags.creatorWallsEnabled) return refused("creator_wall_disabled");
    if (price !== 0) {
      const account = await eligibleAccount(uid);
      if (account) return refused(`creator_wall_seller_${account}`);
    }
    const email = str(request.auth?.token.email);
    const emailVerified = request.auth?.token.email_verified === true;
    const wallRef = db.collection("walls").doc(wallDocId);
    return db.runTransaction(async (tx) => {
      const [wallSnap, userSnap, barrierSnap] = await Promise.all([
        tx.get(wallRef),
        tx.get(db.collection("usersv2").doc(uid)),
        tx.get(db.collection("creatorDeletionState").doc(uid)),
      ]);
      const wall = wallSnap.data();
      if (!wall) return refused("creator_wall_unavailable");
      const owner = str(wall.creatorUid) ? wall.creatorUid === uid :
        emailVerified && email !== "" && wall.email === email;
      if (!owner) throw new HttpsError("permission-denied", "creator_wall_not_owner");
      if (!userSnap.exists || userSnap.data()?.deleted === true || barrierSnap.data()?.closed === true) {
        return refused("creator_wall_seller_ineligible");
      }
      if (price === 0) {
        if (wall.creatorPrice !== undefined) tx.update(wallRef, {creatorPrice: admin.firestore.FieldValue.delete()});
        return {success: true, reason: "creator_wall_price_removed", price: 0};
      }
      if (!originalUpload(wall)) return refused("creator_wall_not_original");
      if (wall.review === true) {
        const manifest = (await tx.get(db.collection("ownedAssets").doc(str(wall.id) || "-"))).data();
        if (!sellable(wall, manifest, wallRef, uid)) return refused("creator_wall_not_original");
      }
      const approved = await tx.get(db.collection("walls").where("creatorUid", "==", uid)
        .where("review", "==", true).limit(20));
      if (!approved.docs.some((doc) => approvedWall(doc.data())) && !(wall.review === true && approvedWall(wall))) {
        return refused("creator_wall_seller_no_approved_wall");
      }
      if (wall.creatorPrice !== price) tx.update(wallRef, {creatorPrice: price});
      return {success: true, reason: "creator_wall_price_set", price};
    });
  },
);

export interface UnlockResponse {
  success: boolean;
  changed: boolean;
  reason: string;
  previousBalance: number;
  currentBalance: number;
  delta: number;
  price: number;
  transactionId: string;
  insufficientBalance: boolean;
}

const refusal = (reason: string, balance = 0, price = 0): UnlockResponse => ({
  success: false, changed: false, reason, previousBalance: balance, currentBalance: balance, delta: 0, price,
  transactionId: "", insufficientBalance: false,
});

function storedUnlock(data: admin.firestore.DocumentData, txId: string): UnlockResponse {
  return {
    success: true, changed: true, reason: str(data.reason), previousBalance: int(data.balanceBefore, 0),
    currentBalance: int(data.balanceAfter, 0), delta: int(data.delta, 0), price: int(data.price, 0),
    transactionId: txId, insufficientBalance: false,
  };
}

/** One paid unlock of a creator wall: both balances, both ledger docs, the marker, the sales totals and the caps. */
export const unlockCreatorWall = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{wallId?: unknown; expectedPrice?: unknown; requestId?: unknown}>):
    Promise<UnlockResponse> => {
    const uid = str(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");
    const wallDocId = wallDocIdFrom(request.data?.wallId);
    const expectedPrice = request.data?.expectedPrice;
    if (typeof expectedPrice !== "number" || !Number.isInteger(expectedPrice) || expectedPrice < MIN_CREATOR_PRICE ||
      expectedPrice > MAX_CREATOR_PRICE) {
      throw new HttpsError("invalid-argument", "expectedPrice is invalid.");
    }
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");

    const buyerKey = key(uid);
    const txId = `ctx_cwbuy_${buyerKey}_${requestId}`;
    const txRef = db.collection("coinTransactions").doc(txId);
    const done = await txRef.get();
    if (done.exists) return storedUnlock(done.data() ?? {}, txId);

    const economy = await loadEconomy();
    if (!economy.flags.creatorWallsEnabled) return refusal("creator_wall_disabled");
    const account = await eligibleAccount(uid);
    if (account) return refusal(`creator_wall_buyer_${account}`);
    const wallRef = db.collection("walls").doc(wallDocId);
    const creatorUid = str((await wallRef.get()).data()?.creatorUid);
    if (!creatorUid || creatorUid.includes("/")) return refusal("creator_wall_unavailable");
    if (creatorUid === uid) return refusal("creator_wall_self");
    if (await creatorWallIo.disabled(creatorUid)) return refusal("creator_wall_unavailable");

    const creatorKey = key(creatorUid);
    const buyerRef = db.collection("usersv2").doc(uid);
    const creatorRef = db.collection("usersv2").doc(creatorUid);
    const creatorTxRef = db.collection("coinTransactions").doc(`ctx_cwsale_${buyerKey}_${requestId}`);
    const markerRef = unlockRef(uid, wallDocId);
    const salesRef = db.collection(SALES).doc(creatorUid);
    let response: UnlockResponse | null = null;
    await db.runTransaction(async (tx) => {
      const nowMs = Date.now();
      const today = utcDateString(new Date(nowMs));
      const buyerCapRef = db.collection(SALE_DAILY).doc(`buy_${buyerKey}_${today}`);
      const pairCapRef = db.collection(SALE_DAILY).doc(`pair_${buyerKey}_${creatorKey}_${today}`);
      const creatorCapRef = db.collection(SALE_DAILY).doc(`sell_${creatorKey}_${today}`);
      response = null;
      const [txSnap, buyerSnap, creatorSnap, buyerBarrier, creatorBarrier, blockedBy, blocking, markerSnap, wallSnap,
        buyerCap, pairCap, creatorCap, salesSnap] = await Promise.all([
        tx.get(txRef), tx.get(buyerRef), tx.get(creatorRef),
        tx.get(db.collection("creatorDeletionState").doc(uid)),
        tx.get(db.collection("creatorDeletionState").doc(creatorUid)),
        tx.get(creatorRef.collection("blockedUsers").doc(uid)),
        tx.get(buyerRef.collection("blockedUsers").doc(creatorUid)),
        tx.get(markerRef), tx.get(wallRef), tx.get(buyerCapRef), tx.get(pairCapRef), tx.get(creatorCapRef),
        tx.get(salesRef),
      ]);
      if (txSnap.exists) {
        response = storedUnlock(txSnap.data() ?? {}, txId);
        return;
      }
      const buyer = buyerSnap.data();
      if (!buyer || buyer.deleted === true || buyerBarrier.data()?.closed === true) {
        throw new HttpsError("not-found", "User profile was not found.");
      }
      const balance = Math.max(0, int(buyer.coins, 0));
      const wall = wallSnap.data();
      const price = creatorPriceOf(wall);
      if (wall && markerSnap.exists && unlockGrants(markerSnap.data(), wall, wallDocId)) {
        response = {...refusal("already_unlocked", balance, price), success: true};
        return;
      }
      const creator = creatorSnap.data();
      if (!wall || price === 0 || wall.creatorUid !== creatorUid || !creator || creator.deleted === true ||
        creatorBarrier.data()?.closed === true) {
        response = refusal("creator_wall_unavailable", balance);
        return;
      }
      const manifest = (await tx.get(db.collection("ownedAssets").doc(str(wall.id) || "-"))).data();
      if (!sellable(wall, manifest, wallRef, creatorUid)) {
        response = refusal("creator_wall_unavailable", balance);
        return;
      }
      if (blockedBy.exists || blocking.exists) {
        response = refusal("creator_wall_blocked", balance, price);
        return;
      }
      if (price !== expectedPrice) {
        response = refusal("creator_wall_price_changed", balance, price);
        return;
      }
      const boughtToday = readDailyCount(buyerCap, today);
      if (boughtToday >= UNLOCKS_PER_BUYER_PER_DAY) {
        response = refusal("creator_wall_daily_limit", balance, price);
        return;
      }
      const pairToday = readDailyCount(pairCap, today);
      if (pairToday >= UNLOCKS_PER_PAIR_PER_DAY) {
        response = refusal("creator_wall_pair_limit", balance, price);
        return;
      }
      const share = creatorShareOf(price);
      const soldToday = creatorCap.data()?.day === today ? Math.max(0, int(creatorCap.data()?.coins, 0)) : 0;
      if (soldToday + share > CREATOR_SALE_COINS_PER_DAY) {
        response = refusal("creator_wall_creator_limit", balance, price);
        return;
      }
      if (balance < price) {
        response = {...refusal("creator_wall_insufficient_balance", balance, price), insufficientBalance: true};
        return;
      }

      const at = admin.firestore.Timestamp.fromMillis(nowMs);
      const creatorBalance = Math.max(0, int(creator.coins, 0));
      const link = {wallId: wallDocId, price, creatorShare: share, unlockId: `${buyerKey}_${requestId}`};
      const buyerLedger = coinTransactionDoc({id: txId, userId: uid, at, delta: -price, balanceBefore: balance,
        action: "creatorWallUnlock", description: `Creator wall: ${price} coins`, sourceTag: "creatorWalls.unlock",
        reason: `creator_wall_${wallDocId}`});
      const creatorLedger = coinTransactionDoc({id: creatorTxRef.id, userId: creatorUid, at, delta: share,
        balanceBefore: creatorBalance, action: "creatorWallSale", description: `Wall sale: ${share} coins`,
        sourceTag: "creatorWalls.unlock", reason: `creator_wall_sale_${wallDocId}`});
      tx.update(buyerRef, {coins: balance - price});
      tx.update(creatorRef, {coins: creatorBalance + share});
      tx.set(txRef, {...buyerLedger, ...link, counterpartyUid: creatorUid});
      tx.set(creatorTxRef, {...creatorLedger, ...link, counterpartyUid: uid});
      tx.set(markerRef, {wallId: str(wall.id), wallDocId, creatorUid, price, creatorShare: share, transactionId: txId,
        unlockedAt: at});
      tx.set(buyerCapRef, {day: today, count: boughtToday + 1, buyerUid: uid});
      tx.set(pairCapRef, {day: today, count: pairToday + 1, buyerUid: uid, creatorUid});
      tx.set(creatorCapRef, {day: today, coins: soldToday + share, creatorUid});
      tx.set(salesRef, addTip(salesSnap.data(), share, wallDocId, nowMs));
      response = {success: true, changed: true, reason: buyerLedger.reason as string, previousBalance: balance,
        currentBalance: balance - price, delta: -price, price, transactionId: txId, insufficientBalance: false};
    });
    if (!response) throw new HttpsError("internal", "Unlock did not finish.");
    return response;
  },
);

/** Refunds one unlock of a deleted wall. A stamped marker is skipped, so a retry never pays twice. */
export async function refundUnlock(markerRef: admin.firestore.DocumentReference): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const marker = (await tx.get(markerRef)).data();
    const buyerUid = markerRef.parent.parent?.id ?? "";
    if (!marker || marker.refundedAt !== undefined || !buyerUid) return false;
    const price = Math.max(0, int(marker.price, 0));
    const share = Math.max(0, Math.min(price, int(marker.creatorShare, 0)));
    const creatorUid = str(marker.creatorUid);
    const buyerRef = db.collection("usersv2").doc(buyerUid);
    const creatorRef = creatorUid && !creatorUid.includes("/") ? db.collection("usersv2").doc(creatorUid) : null;
    const salesRef = creatorRef ? db.collection(SALES).doc(creatorUid) : null;
    const [buyerSnap, creatorSnap, salesSnap] = await Promise.all([
      tx.get(buyerRef), creatorRef ? tx.get(creatorRef) : null, salesRef ? tx.get(salesRef) : null,
    ]);
    const at = admin.firestore.Timestamp.now();
    const id = sha(markerRef.path + "\0" + str(marker.transactionId));
    const link = {wallId: str(marker.wallDocId), price, creatorShare: share, refundOf: str(marker.transactionId)};
    const buyer = buyerSnap.data();
    if (buyer && buyer.deleted !== true && price > 0) {
      const balance = Math.max(0, int(buyer.coins, 0));
      tx.update(buyerRef, {coins: balance + price});
      tx.set(db.collection("coinTransactions").doc(`ctx_cwrefund_${id}`), {...coinTransactionDoc({
        id: `ctx_cwrefund_${id}`, userId: buyerUid, at, delta: price, balanceBefore: balance,
        action: "creatorWallRefund", description: "Creator wall removed: refund", sourceTag: "creatorWalls.refund",
        reason: "creator_wall_removed"}), ...link, counterpartyUid: creatorUid});
    }
    const creator = creatorSnap?.data();
    if (creatorRef && creator && creator.deleted !== true && share > 0) {
      const balance = Math.max(0, int(creator.coins, 0));
      const taken = Math.min(share, balance);
      if (taken > 0) {
        tx.update(creatorRef, {coins: balance - taken});
        tx.set(db.collection("coinTransactions").doc(`ctx_cwreverse_${id}`), {...coinTransactionDoc({
          id: `ctx_cwreverse_${id}`, userId: creatorUid, at, delta: -taken, balanceBefore: balance,
          action: "creatorWallSaleReversal", description: "Creator wall removed: sale reversed",
          sourceTag: "creatorWalls.refund", reason: "creator_wall_removed"}), ...link, counterpartyUid: buyerUid});
      }
    }
    const sales = salesSnap?.data();
    if (salesRef && sales) {
      const walls = {...(typeof sales.walls === "object" && sales.walls !== null ? sales.walls : {})};
      const row = walls[link.wallId];
      if (row) {
        walls[link.wallId] = {count: Math.max(0, int(row.count, 0) - 1), coins: Math.max(0, int(row.coins, 0) - share)};
      }
      tx.update(salesRef, {count: Math.max(0, int(sales.count, 0) - 1), coins: Math.max(0, int(sales.coins, 0) - share),
        walls});
    }
    tx.update(markerRef, {refundedAt: at});
    return true;
  });
}

/** Every unlock of a deleted wall is refunded. Pages through the markers, so a retry resumes where it stopped. */
export async function refundDeletedWall(wallDocId: string): Promise<number> {
  let refunded = 0;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collectionGroup(UNLOCKS).where("wallDocId", "==", wallDocId).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      if (doc.data().refundedAt === undefined && await refundUnlock(doc.ref)) refunded++;
    }
    if (page.size < 100) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return refunded;
}

export const onCreatorWallDeleted = onDocumentDeleted({document: "walls/{wallId}", region: REGION, retry: true,
  cpu: "gcf_gen1"},
  async (event) => {
    const refunded = await refundDeletedWall(event.params.wallId);
    if (refunded > 0) logger.info("onCreatorWallDeleted: refunded buyers.", {wallId: event.params.wallId, refunded});
  });
