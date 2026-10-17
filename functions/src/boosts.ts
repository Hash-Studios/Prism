import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, int, REGION, str} from "./common";
import {loadEconomy} from "./economy";
import {mergeBoosted} from "./trending";

const BOOST_MS = 24 * 60 * 60 * 1000;
export const MAX_ACTIVE_BOOSTS = 10;

interface BoostResponse {
  success: boolean;
  changed: boolean;
  previousBalance: number;
  currentBalance: number;
  delta: number;
  reason: string;
  transactionId: string;
  insufficientBalance: boolean;
  endsAt: number;
  nextFreeAt?: number;
}

/** Pays coins to put an approved wall at the front of Trending for 24 hours. */
export const boostWall = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<{wallId?: unknown; requestId?: unknown}>): Promise<BoostResponse> => {
    const uid = str(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in to boost a wallpaper.");
    const wallId = str(request.data?.wallId);
    if (wallId === "" || wallId.length > 200 || wallId.includes("/")) {
      throw new HttpsError("invalid-argument", "wallId is invalid.");
    }
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");

    const price = (await loadEconomy()).spend.boostWall;
    const nowMs = Date.now();
    const txId = `ctx_boost_${uid}_${requestId}`;
    const userRef = db.collection("usersv2").doc(uid);
    const wallRef = db.collection("walls").doc(wallId);
    const boostRef = db.collection("boosts").doc(wallId);
    const txRef = db.collection("coinTransactions").doc(txId);
    const trendingRef = db.collection("trending").doc("current");
    const activeQuery = db.collection("boosts").where("endsAt", ">", nowMs).limit(MAX_ACTIVE_BOOSTS);

    let response: BoostResponse | null = null;
    await db.runTransaction(async (tx) => {
      response = null;
      const [userSnap, wallSnap, boostSnap, txSnap, trendingSnap, activeSnap] = await Promise.all([
        tx.get(userRef), tx.get(wallRef), tx.get(boostRef), tx.get(txRef), tx.get(trendingRef), tx.get(activeQuery),
      ]);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const user = userSnap.data() ?? {};
      const previous = int(user.coins, 0);
      const base: BoostResponse = {
        success: false,
        changed: false,
        previousBalance: previous,
        currentBalance: previous,
        delta: 0,
        reason: "",
        transactionId: "",
        insufficientBalance: false,
        endsAt: 0,
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
          endsAt: int(stored.endsAt, 0),
        };
        return;
      }

      const wall = wallSnap.data();
      if (!wallSnap.exists || !wall) throw new HttpsError("not-found", "boost_wall_not_found");
      if (wall.review !== true) {
        response = {...base, reason: "boost_wall_not_approved"};
        return;
      }
      const owner = str(wall.email).toLowerCase();
      if (owner === "" || owner !== str(user.email).toLowerCase() || wall.origin === "studio") {
        throw new HttpsError("permission-denied", "boost_not_owner");
      }
      if (int(boostSnap.data()?.endsAt, 0) > nowMs) {
        response = {...base, reason: "boost_active"};
        return;
      }
      if (activeSnap.size >= MAX_ACTIVE_BOOSTS) {
        const nextFreeAt = Math.min(...activeSnap.docs.map((doc) => int(doc.data().endsAt, 0)));
        response = {...base, reason: "boost_slots_full", nextFreeAt};
        return;
      }
      if (previous < price) {
        response = {...base, insufficientBalance: true, reason: "boostWall_insufficient_balance"};
        return;
      }

      const endsAt = nowMs + BOOST_MS;
      const reason = `boost_${wallId}`;
      const current = previous - price;
      const ledger = coinTransactionDoc({
        id: txId,
        userId: uid,
        at: admin.firestore.Timestamp.fromMillis(nowMs),
        delta: -price,
        balanceBefore: previous,
        action: "boostWall",
        description: "Boost wallpaper",
        sourceTag: "boosts.purchase.callable",
        reason,
      });
      const ids = trendingSnap.data()?.wallIds;
      tx.update(userRef, {coins: current});
      tx.set(txRef, {...ledger, endsAt});
      tx.set(boostRef, {wallId, uid, startsAt: nowMs, endsAt});
      tx.update(wallRef, {boostedUntil: endsAt});
      tx.set(trendingRef, {wallIds: mergeBoosted([wallId], Array.isArray(ids) ? ids.map(String) : [])}, {merge: true});
      response = {
        ...base,
        success: true,
        changed: true,
        currentBalance: current,
        delta: -price,
        reason,
        transactionId: txId,
        endsAt,
      };
    });
    if (!response) throw new HttpsError("internal", "Boost did not finish.");
    return response;
  },
);
