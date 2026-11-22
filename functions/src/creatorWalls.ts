import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, int, readDailyCount, CALLABLE_REGIONS, REGION, str, utcDateString} from "./common";
import {approvedWall} from "./creatorProgress";
import {isoWeek} from "./creatorStatsHistory";
import {loadEconomy} from "./economy";
import {ownedThumbnailUrl, stored, verifyStoredUploadRegistry} from "./ownedAssetDelivery";
import {addTip} from "./tips";
import {STUDIO_ACCOUNT} from "./studio/account";

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
  wallDocId: string, incarnation: {millis: number; nanos: number}): boolean {
  return !!marker && marker.wallDocId === wallDocId && marker.wallId === wall.id && marker.refundedAt === undefined &&
    marker.wallIncarnation === incarnation.millis && marker.wallIncarnationNanos === incarnation.nanos;
}

const key = (uid: string) => encodeURIComponent(uid).replace(/_/g, "%5F");
const sha = (text: string) => createHash("sha256").update(text).digest("hex");
const refundKey = (wallDocId: string, incarnation: {millis: number; nanos: number}) =>
  sha(`walls/${wallDocId}\0${incarnation.millis}:${incarnation.nanos}`);

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
  const aiMetadata = wall.aiMetadata;
  const hasAiMetadata = !!aiMetadata && (typeof aiMetadata !== "object" || Object.keys(aiMetadata).length > 0);
  return str(wall.wallpaper_provider).toLowerCase() === "prism" && wall.origin !== "studio" &&
    wall.byStudio !== true && wall.email !== STUDIO_ACCOUNT.email && !wall.studioRunId && !wall.studioCandidateId &&
    wall.isAiGenerated !== true && !wall.aiGenerationId && !hasAiMetadata && !wall.remixOf && wall.kind !== "live" &&
    wall.is_streak_exclusive !== true && wall.dropReserved !== true && !wall.dropWeek && wall.heldForReview !== true &&
    wall.wallpaper_url === "";
}

/** An approved wall whose protected original is the creator's own private upload. */
async function sellable(wall: admin.firestore.DocumentData, manifest: admin.firestore.DocumentData | undefined,
  wallRef: admin.firestore.DocumentReference, wallSnap: admin.firestore.DocumentSnapshot,
  creatorUid: string, aliases: admin.firestore.QuerySnapshot, tx: admin.firestore.Transaction): Promise<boolean> {
  if (!(originalUpload(wall) && approvedWall(wall) && wall.originalProtected === true &&
    aliases.size === 1 && aliases.docs[0].ref.path === wallRef.path && !!wallSnap.createTime &&
    manifest?.status === "ready" && manifest.canonicalPath === wallRef.path &&
    manifest.incarnation === wallSnap.createTime.toMillis() &&
    manifest.incarnationNanos === wallSnap.createTime.nanoseconds &&
    manifest.provenance?.kind === "owned" && manifest.provenance?.uid === creatorUid &&
    stored(manifest.original) && stored(manifest.thumb) && manifest.original.previewObjectId === undefined &&
    manifest.original.sourceKind === "owned" && manifest.original.uid === creatorUid &&
    manifest.thumb.sourceKind === "owned" && manifest.thumb.uid === creatorUid &&
    !!manifest.thumb.previewObjectId && manifest.original.objectId !== manifest.thumb.objectId &&
    manifest.original.object !== manifest.thumb.object && wall.originalObjectId === manifest.original.objectId &&
    manifest.original.sha256 !== manifest.thumb.sha256 &&
    wall.wallpaper_thumb === ownedThumbnailUrl(manifest.thumb) && wall.wallpaper_path === "" &&
    wall.wallpaper_sha === "" && wall.thumb_path === "" && wall.thumb_sha === "" &&
    Array.isArray(wall.collections) && wall.collections.every((entry: unknown) => typeof entry === "string"))) return false;
  try {
    await Promise.all([verifyStoredUploadRegistry(manifest.original, tx), verifyStoredUploadRegistry(manifest.thumb, tx)]);
  } catch {
    return false;
  }
  const sameHashRows = await Promise.all([
    tx.get(db.collection("ownedAssets").where("original.sha256", "==", manifest.original.sha256)),
    tx.get(db.collection("ownedAssets").where("thumb.sha256", "==", manifest.original.sha256)),
  ]);
  return !sameHashRows.flatMap((rows) => rows.docs)
    .some((doc) => doc.id !== wall.id && doc.data().status === "ready");
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
        const [manifestSnap, aliases] = await Promise.all([
          tx.get(db.collection("ownedAssets").doc(str(wall.id) || "-")),
          tx.get(db.collection("walls").where("id", "==", wall.id).limit(2)),
        ]);
        if (!await sellable(wall, manifestSnap.data(), wallRef, wallSnap, uid, aliases, tx)) {
          return refused("creator_wall_not_original");
        }
      }
      let hasApprovedWall = wall.review === true && approvedWall(wall);
      let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
      while (!hasApprovedWall) {
        let query = db.collection("walls").where("creatorUid", "==", uid).where("review", "==", true).limit(20);
        if (cursor) query = query.startAfter(cursor);
        const page = await tx.get(query);
        hasApprovedWall = page.docs.some((doc) => approvedWall(doc.data()));
        if (hasApprovedWall || page.size < 20) break;
        cursor = page.docs[page.size - 1];
      }
      if (!hasApprovedWall) {
        return refused("creator_wall_seller_no_approved_wall");
      }
      if (wall.creatorPrice !== price || !str(wall.creatorUid)) {
        tx.update(wallRef, {creatorPrice: price, ...(!str(wall.creatorUid) ? {creatorUid: uid} : {})});
      }
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

function replayUnlock(receiptSnap: admin.firestore.DocumentSnapshot, wallSnap: admin.firestore.DocumentSnapshot,
  markerSnap: admin.firestore.DocumentSnapshot, wallDocId: string, txId: string): UnlockResponse | null {
  if (!receiptSnap.exists) return null;
  const receipt = receiptSnap.data() ?? {};
  if (receipt.wallId !== wallDocId) throw new HttpsError("already-exists", "requestId was used for another wall.");
  const wall = wallSnap.data();
  const marker = markerSnap.data();
  if (wall && wallSnap.createTime && int(receipt.wallIncarnation, -1) === wallSnap.createTime.toMillis() &&
    int(receipt.wallIncarnationNanos, -1) === wallSnap.createTime.nanoseconds && marker?.transactionId === txId &&
    unlockGrants(marker, wall, wallDocId,
      {millis: wallSnap.createTime.toMillis(), nanos: wallSnap.createTime.nanoseconds})) {
    return storedUnlock(receipt, txId);
  }
  return refusal("creator_wall_unavailable");
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
    const requestedWallRef = db.collection("walls").doc(wallDocId);
    const requestedMarkerRef = unlockRef(uid, wallDocId);
    const replay = await db.runTransaction(async (tx) => {
      const [done, wallSnap, markerSnap] = await Promise.all([
        tx.get(txRef), tx.get(requestedWallRef), tx.get(requestedMarkerRef),
      ]);
      return replayUnlock(done, wallSnap, markerSnap, wallDocId, txId);
    });
    if (replay) return replay;

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
        response = replayUnlock(txSnap, wallSnap, markerSnap, wallDocId, txId);
        return;
      }
      const buyer = buyerSnap.data();
      if (!buyer || buyer.deleted === true || buyerBarrier.data()?.closed === true) {
        throw new HttpsError("not-found", "User profile was not found.");
      }
      const balance = Math.max(0, int(buyer.coins, 0));
      const wall = wallSnap.data();
      const price = creatorPriceOf(wall);
      if (wall && markerSnap.exists && wallSnap.createTime && unlockGrants(markerSnap.data(), wall, wallDocId,
        {millis: wallSnap.createTime.toMillis(), nanos: wallSnap.createTime.nanoseconds})) {
        response = {...refusal("already_unlocked", balance, price), success: true};
        return;
      }
      if (markerSnap.exists && markerSnap.data()?.refundedAt === undefined) {
        response = refusal("creator_wall_unavailable", balance, price);
        return;
      }
      const creator = creatorSnap.data();
      if (!wall || price === 0 || wall.creatorUid !== creatorUid || !creator || creator.deleted === true ||
        creatorBarrier.data()?.closed === true) {
        response = refusal("creator_wall_unavailable", balance);
        return;
      }
      const [manifestSnap, aliases] = await Promise.all([
        tx.get(db.collection("ownedAssets").doc(str(wall.id) || "-")),
        tx.get(db.collection("walls").where("id", "==", wall.id).limit(2)),
      ]);
      const manifest = manifestSnap.data();
      if (!await sellable(wall, manifest, wallRef, wallSnap, creatorUid, aliases, tx)) {
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
      const wallCreated = wallSnap.createTime;
      if (!wallCreated) {
        response = refusal("creator_wall_unavailable", balance, price);
        return;
      }
      const creatorBalance = Math.max(0, int(creator.coins, 0));
      const link = {wallId: wallDocId, price, creatorShare: share, unlockId: `${buyerKey}_${requestId}`,
        wallIncarnation: wallCreated.toMillis(), wallIncarnationNanos: wallCreated.nanoseconds};
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
      tx.set(markerRef, {wallId: str(wall.id), wallDocId, creatorUid, price, creatorShare: share,
        wallIncarnation: wallCreated.toMillis(), wallIncarnationNanos: wallCreated.nanoseconds,
        pendingRefundKey: refundKey(wallDocId, {millis: wallCreated.toMillis(), nanos: wallCreated.nanoseconds}),
        transactionId: txId, unlockedAt: at});
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
export async function refundUnlock(markerRef: admin.firestore.DocumentReference,
  incarnation: {millis: number; nanos: number}, pendingKey: string): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const marker = (await tx.get(markerRef)).data();
    const buyerUid = markerRef.parent.parent?.id ?? "";
    if (!marker || marker.refundedAt !== undefined || !buyerUid || marker.pendingRefundKey !== pendingKey ||
      marker.wallIncarnation !== incarnation.millis || marker.wallIncarnationNanos !== incarnation.nanos) return false;
    const price = Math.max(0, int(marker.price, 0));
    const share = Math.max(0, Math.min(price, int(marker.creatorShare, 0)));
    const creatorUid = str(marker.creatorUid);
    const buyerRef = db.collection("usersv2").doc(buyerUid);
    const creatorRef = creatorUid && !creatorUid.includes("/") ? db.collection("usersv2").doc(creatorUid) : null;
    const salesRef = creatorRef ? db.collection(SALES).doc(creatorUid) : null;
    const [buyerSnap, creatorSnap, salesSnap, buyerBarrier, creatorBarrier] = await Promise.all([
      tx.get(buyerRef), creatorRef ? tx.get(creatorRef) : null, salesRef ? tx.get(salesRef) : null,
      tx.get(db.collection("creatorDeletionState").doc(buyerUid)),
      creatorUid ? tx.get(db.collection("creatorDeletionState").doc(creatorUid)) : null,
    ]);
    const at = admin.firestore.Timestamp.now();
    const id = sha(markerRef.path + "\0" + str(marker.transactionId));
    const link = {wallId: str(marker.wallDocId), price, creatorShare: share, refundOf: str(marker.transactionId)};
    const buyer = buyerSnap.data();
    const buyerActive = !!buyer && buyer.deleted !== true && buyerBarrier.data()?.closed !== true;
    if (buyerActive && price > 0) {
      const balance = Math.max(0, int(buyer.coins, 0));
      tx.update(buyerRef, {coins: balance + price});
      tx.set(db.collection("coinTransactions").doc(`ctx_cwrefund_${id}`), {...coinTransactionDoc({
        id: `ctx_cwrefund_${id}`, userId: buyerUid, at, delta: price, balanceBefore: balance,
        action: "creatorWallRefund", description: "Creator wall removed: refund", sourceTag: "creatorWalls.refund",
        reason: "creator_wall_removed"}), ...link, counterpartyUid: creatorUid});
    }
    const creator = creatorSnap?.data();
    if (buyerActive && creatorRef && creator && creator.deleted !== true &&
      creatorBarrier?.data()?.closed !== true && share > 0) {
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
    if (buyerActive && salesRef && sales) {
      const walls = {...(typeof sales.walls === "object" && sales.walls !== null ? sales.walls : {})};
      const row = walls[link.wallId];
      if (row) {
        walls[link.wallId] = {count: Math.max(0, int(row.count, 0) - 1), coins: Math.max(0, int(row.coins, 0) - share)};
      }
      const weeks = {...(typeof sales.weeks === "object" && sales.weeks !== null ? sales.weeks : {})};
      const week = marker.unlockedAt instanceof admin.firestore.Timestamp ? isoWeek(marker.unlockedAt.toMillis()) :
        str(marker.saleWeek);
      if (week && weeks[week]) {
        weeks[week] = {count: Math.max(0, int(weeks[week].count, 0) - 1),
          coins: Math.max(0, int(weeks[week].coins, 0) - share)};
      }
      tx.update(salesRef, {count: Math.max(0, int(sales.count, 0) - 1), coins: Math.max(0, int(sales.coins, 0) - share),
        walls, weeks});
    }
    tx.update(markerRef, {refundedAt: at, pendingRefundKey: admin.firestore.FieldValue.delete()});
    return true;
  });
}

/** Every unlock of a deleted wall is refunded. Pages through the markers, so a retry resumes where it stopped. */
export async function refundDeletedWall(wallDocId: string,
  incarnation: {millis: number; nanos: number}): Promise<number> {
  let refunded = 0;
  const pendingKey = refundKey(wallDocId, incarnation);
  for (;;) {
    const page = await db.collectionGroup(UNLOCKS).where("pendingRefundKey", "==", pendingKey).limit(100).get();
    for (const doc of page.docs) {
      const marker = doc.data();
      if (marker.wallIncarnation === incarnation.millis && marker.wallIncarnationNanos === incarnation.nanos &&
        marker.refundedAt === undefined && await refundUnlock(doc.ref, incarnation, pendingKey)) refunded++;
    }
    if (page.size < 100) break;
  }
  return refunded;
}

const deletedWallOptions = {document: "walls/{wallId}", region: REGION, retry: true, cpu: "gcf_gen1" as const,
  timeoutSeconds: 540};

export const onCreatorWallDeleted = onDocumentDeleted(deletedWallOptions, async (event) => {
  const created = event.data?.createTime;
  if (!created) throw new HttpsError("failed-precondition", "Deleted wall incarnation is unavailable.");
  const refunded = await refundDeletedWall(event.params.wallId,
    {millis: created.toMillis(), nanos: created.nanoseconds});
  if (refunded > 0) logger.info("onCreatorWallDeleted: refunded buyers.", {wallId: event.params.wallId, refunded});
});
