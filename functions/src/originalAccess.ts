import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onCall, HttpsError, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, REGION} from "./common";
import {loadEconomy, type EconomyConfig} from "./economy";
import {parseCollectionList} from "./wallOfTheDay";
import {signOriginalDelivery} from "./ownedAssetDelivery";

type Action = "download" | "set" | "edit" | "live";
type Delivery = {url: string; expiresAt: number; generation: string};
type Input = {assetId?: unknown; action?: unknown; assets?: unknown; requestId?: unknown; mode?: unknown; maxCoins?: unknown};

function priceOriginal(isPremium: boolean, action: Action, data: admin.firestore.DocumentData,
  privateData: admin.firestore.DocumentData, economy: EconomyConfig) {
  const grace = Math.max(0, int(privateData.graceDownloadsUsed));
  let basis = "coins";
  let cost = isPremium ? economy.spend.premiumWallpaperDownload : economy.spend.wallpaperDownload;
  if (data.premium === true) {
    basis = "pro"; cost = 0;
  } else if (isPremium && int(privateData.passes?.premiumPassUntil) > Date.now()) {
    basis = "pass"; cost = 0;
  } else if (!isPremium && (action === "download" || action === "set") &&
      grace < economy.award.graceDownloads) {
    basis = "grace"; cost = 0;
  } else if (cost === 0) basis = "free";
  return {basis, cost, grace};
}

export const originalAccessDelivery = {
  sign: async (assetId: string): Promise<Delivery> => {
    try {
      return await signOriginalDelivery(assetId);
    } catch {
      throw new HttpsError("unavailable", "Original delivery is unavailable. Retry with the same requestId.");
    }
  },
};

async function classification(): Promise<string[]> {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const parameter = template.parameters?.premiumCollections;
    if (Object.keys(parameter?.conditionalValues ?? {}).length > 0) throw new Error("conditional classification");
    const value = parameter?.defaultValue as {value?: unknown} | undefined;
    if (typeof value?.value !== "string" || !value.value.trim()) throw new Error("missing classification");
    if (value.value.trim().startsWith("[")) {
      const parsed: unknown = JSON.parse(value.value);
      if (!Array.isArray(parsed) || parsed.some((entry: unknown) => typeof entry !== "string")) {
        throw new Error("invalid classification");
      }
    }
    return parseCollectionList(value.value);
  } catch {
    throw new HttpsError("unavailable", "Original access classification is unavailable.");
  }
}

export const resolveOriginalAccess = onCall({region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<Input>) => {
    const uid = request.auth?.uid;
    if (!uid || request.auth?.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to access originals.");
    }
    const {assetId, action, assets, requestId, mode = "acquire", maxCoins} = request.data ?? {};
    const batch = assets !== undefined;
    const items = (batch ? assets : [{assetId, action}]) as {assetId: string; action: Action}[];
    if (!Array.isArray(items) || items.length < 1 || items.length > 2 ||
        (batch && (assetId !== undefined || action !== undefined)) ||
        items.some((item) => !item || typeof item !== "object" ||
          typeof item.assetId !== "string" || !/^[A-Za-z0-9_-]{1,200}$/.test(item.assetId) ||
          typeof item.action !== "string" || !(batch ? ["set"] : ["download", "set", "edit", "live"]).includes(item.action) ||
          (batch && Object.keys(item).some((key) => key !== "assetId" && key !== "action"))) ||
        new Set(items.map((item) => item.assetId)).size !== items.length ||
        typeof requestId !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(requestId) ||
        (mode !== "quote" && mode !== "acquire") ||
        (maxCoins !== undefined && (typeof maxCoins !== "number" || !Number.isSafeInteger(maxCoins) || maxCoins < 0))) {
      throw new HttpsError("invalid-argument", "Invalid original access request.");
    }
    const [premium, economy] = await Promise.all([classification(), loadEconomy()]);
    // Sign before any debit: signing failures leave the balance and grace allowance untouched.
    const deliveries = mode === "acquire" ? await Promise.all(items.map((item) => originalAccessDelivery.sign(item.assetId))) : [];
    if (deliveries.some((delivery) => !delivery.url.startsWith("https://") || !delivery.generation ||
        !Number.isFinite(delivery.expiresAt) || delivery.expiresAt <= Date.now() ||
        delivery.expiresAt > Date.now() + 5 * 60_000)) {
      throw new HttpsError("unavailable", "Invalid original delivery.");
    }
    const transactionId = `ctx_original_${createHash("sha256").update(`${uid}:${requestId}`).digest("hex")}`;
    const receiptRef = db.collection("coinTransactions").doc(transactionId);
    const userRef = db.collection("usersv2").doc(uid);
    const privateRef = userRef.collection("private").doc("economy");
    return db.runTransaction(async (tx) => {
      const user = await tx.get(userRef);
      const privateSnap = await tx.get(privateRef);
      const receiptSnap = await tx.get(receiptRef);
      const data = user.data() ?? {};
      const privateData = privateSnap.data() ?? {};
      const currentBalance = Math.max(0, int(data.coins));
      let graceUsed = Math.max(0, int(privateData.graceDownloadsUsed));
      const checked: {assetId: string; originalAction: Action; generation: string;
        isPremium: boolean; basis: string; cost: number}[] = [];
      for (let index = 0; index < items.length; index++) {
        const {assetId, action: originalAction} = items[index];
        const delivery = deliveries[index];
        const walls = await tx.get(db.collection("walls").where("id", "==", assetId).limit(2));
        const manifest = await tx.get(db.collection("ownedAssets").doc(assetId));
        if (delivery && delivery.expiresAt <= Date.now() + 1_000) {
          throw new HttpsError("unavailable", "Original delivery expired. Retry with the same requestId.");
        }
        const wallSnap = walls.docs[0];
        const wall = wallSnap?.data();
        const owned = manifest.data();
        const original = owned?.original;
        const generation = original?.generation;
        if (walls.size !== 1 || wall?.review !== true || wall.originalProtected !== true ||
            typeof generation !== "string" || !generation || wall.originalGeneration !== generation ||
            owned?.status !== "ready" || (delivery && generation !== delivery.generation) ||
            !wallSnap.createTime || owned.canonicalPath !== wallSnap.ref.path ||
            owned.incarnation !== wallSnap.createTime.toMillis() ||
            owned.incarnationNanos !== wallSnap.createTime.nanoseconds || wall.wallpaper_url !== "" ||
            typeof original.path !== "string" || !original.path || typeof original.sha !== "string" || !original.sha ||
            typeof owned.thumb?.path !== "string" || !owned.thumb.path ||
            typeof owned.thumb?.sha !== "string" || !owned.thumb.sha ||
            wall.wallpaper_path !== original.path || wall.wallpaper_sha !== original.sha ||
            wall.thumb_path !== owned.thumb.path || wall.thumb_sha !== owned.thumb.sha) {
          throw new HttpsError("failed-precondition", "Protected original is unavailable or has changed.");
        }
        if (wall.is_streak_exclusive === true || wall.dropReserved === true || wall.dropWeek) {
          throw new HttpsError("permission-denied", "This original requires a separate entitlement.");
        }
        if (!user.exists) throw new HttpsError("not-found", "User profile was not found.");
        if (!Array.isArray(wall.collections) || wall.collections.some((entry: unknown) => typeof entry !== "string")) {
          throw new HttpsError("failed-precondition", "Original collection classification is invalid.");
        }
        const isPremium = wall.collections.some((entry: string) => premium.includes(entry.trim()));
        const {basis, cost} = priceOriginal(isPremium, originalAction, data,
          {...privateData, graceDownloadsUsed: graceUsed}, economy);
        if (basis === "grace") graceUsed++;
        checked.push({assetId, originalAction, generation, isPremium, basis, cost});
      }
      const cost = checked.reduce((total, item) => total + item.cost, 0);
      const basis = checked.every((item) => item.basis === checked[0].basis) ? checked[0].basis : "mixed";
      const first = checked[0];
      const delivery = deliveries[0];
      const grants = items.map((item, index) => ({...item, ...deliveries[index]}));
      const identity = checked.map(({assetId, originalAction, generation, isPremium}) =>
        ({assetId, originalAction, generation, isPremium}));
      const receipt = receiptSnap.data();
      if (receipt) {
        if (receipt.userId !== uid || receipt.batch !== batch ||
            !Array.isArray(receipt.identities) || receipt.identities.length !== identity.length ||
            identity.some((item, index) => {
              const saved = receipt.identities[index];
              return !saved || saved.assetId !== item.assetId || saved.originalAction !== item.originalAction ||
                saved.generation !== item.generation || saved.isPremium !== item.isPremium;
            }) || receipt.requestId !== requestId ||
            receipt.status !== "completed" || receipt.originalAccess !== true || receipt.revoked === true ||
            !Array.isArray(receipt.bases) || receipt.bases.length !== items.length ||
            (receipt.bases.includes("pro") && data.premium !== true) ||
            (receipt.bases.includes("pass") && int(privateData.passes?.premiumPassUntil) <= Date.now()) ||
            typeof receipt.retryUntil !== "number" || receipt.retryUntil <= Date.now()) {
          throw new HttpsError("failed-precondition", "Original access receipt is invalid or revoked.");
        }
        if (mode === "quote") {
          return {status: "quoted" as const, ...(batch ? {} : {assetId: first.assetId,
            action: first.originalAction, generation: first.generation}),
          requiredCoins: 0, currentBalance, basis: receipt.basis};
        }
        return {status: "granted" as const, ...(batch ? {grants} : {...items[0], ...delivery}), transactionId,
          currentBalance, chargedCoins: receipt.chargedCoins, basis: receipt.basis};
      }
      if (mode === "quote") {
        return {status: "quoted" as const, ...(batch ? {} : {assetId: first.assetId,
          action: first.originalAction, generation: first.generation}),
        requiredCoins: cost, currentBalance, basis};
      }
      if (!delivery) throw new HttpsError("unavailable", "Original delivery is unavailable.");
      if (maxCoins !== undefined && cost > maxCoins) {
        return {status: "price_changed" as const, requiredCoins: cost, currentBalance};
      }
      if (currentBalance < cost) return {status: "insufficient_balance" as const, requiredCoins: cost, currentBalance};
      if (graceUsed !== Math.max(0, int(privateData.graceDownloadsUsed))) {
        tx.set(privateRef, {graceDownloadsUsed: graceUsed}, {merge: true});
      }
      if (cost > 0) tx.update(userRef, {coins: currentBalance - cost});
      // A signed bearer URL cannot be recalled. Generic refunds must refuse all original receipts.
      tx.create(receiptRef, {...coinTransactionDoc({id: transactionId, userId: uid,
        at: admin.firestore.Timestamp.now(), delta: -cost, balanceBefore: currentBalance,
        action: "originalAccess", description: "Protected original access", sourceTag: "original.resolve",
        reason: "original_access_issued"}), originalAccess: true, batch, identities: identity,
      bases: checked.map((item) => item.basis), assetId: first.assetId, originalAction: first.originalAction,
      generation: delivery.generation, requestId, chargedCoins: cost, basis, isPremium: first.isPremium, issuedAt: Date.now(),
      retryUntil: Date.now() + 5 * 60_000});
      return {status: "granted" as const, ...(batch ? {grants} : {...items[0], ...delivery}), transactionId,
        currentBalance: currentBalance - cost, chargedCoins: cost, basis};
    });
  });
