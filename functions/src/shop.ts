import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {coinTransactionDoc, db, REGION} from "./common";
import {type EconomyConfig, loadEconomy, rankFor} from "./economy";
import {type CosmeticSlot, shopItem, type ShopItem, shopPrice, slotFor} from "./shopCatalog";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const CALLABLE_OPTIONS = {region: REGION, cors: true, maxInstances: 10};

export type ShopRefusal = "shop_item_owned" | "shop_item_pro_only" | "shop_item_rank_locked" | "shop_item_expired";

export interface ShopBuyer {
  premium: boolean;
  xp: number;
  owned: readonly string[];
}

/** Why `user` cannot buy `item` right now, or null. Balance is checked by the caller. Pro gets no discount. */
export function shopRefusal(item: ShopItem, user: ShopBuyer, config: EconomyConfig, nowMs: number): ShopRefusal | null {
  if (user.owned.includes(item.id)) return "shop_item_owned";
  if (item.proOnly && !user.premium) return "shop_item_pro_only";
  if (item.minRank) {
    const needed = config.xp.ranks.find((r) => r.id === item.minRank);
    if (!needed || rankFor(user.xp, config).min < needed.min) return "shop_item_rank_locked";
  }
  if (item.founders && !(nowMs < Date.parse(config.flags.foundersUntil))) return "shop_item_expired";
  return null;
}

function uid(request: CallableRequest<unknown>): string {
  const value = request.auth?.uid?.trim() ?? "";
  if (!value) throw new HttpsError("unauthenticated", "Sign in to use the shop.");
  return value;
}

function record(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === "object" && !Array.isArray(raw) ? raw as Record<string, unknown> : {};
}

function ownedMap(privateData: Record<string, unknown> | undefined): Record<string, number> {
  const raw = record(record(privateData?.inventory).owned);
  const owned: Record<string, number> = {};
  for (const [id, at] of Object.entries(raw)) {
    if (typeof at === "number") owned[id] = at;
  }
  return owned;
}

function balanceOf(data: Record<string, unknown>): number {
  return typeof data.coins === "number" && Number.isFinite(data.coins) ? Math.trunc(data.coins) : 0;
}

function equippedOf(data: Record<string, unknown>): Partial<Record<CosmeticSlot, string>> {
  const raw = record(data.cosmetics);
  const out: Partial<Record<CosmeticSlot, string>> = {};
  if (typeof raw.frame === "string") out.frame = raw.frame;
  if (typeof raw.nameGlow === "string") out.nameGlow = raw.nameGlow;
  return out;
}

export const purchaseShopItem = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{itemId?: unknown; requestId?: unknown}>) => {
    const callerUid = uid(request);
    const {itemId, requestId} = request.data ?? {};
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    const item = typeof itemId === "string" ? shopItem(itemId) : undefined;
    if (!item) throw new HttpsError("invalid-argument", "Unknown shop item.");
    const config = await loadEconomy();
    const price = shopPrice(item, config);
    const userRef = db.collection(USERS).doc(callerUid);
    const privateRef = userRef.collection("private").doc("economy");
    const txId = `ctx_shop_${callerUid}_${requestId}`;
    const txRef = db.collection(TRANSACTIONS).doc(txId);
    const emptyResponse = {
      success: false,
      changed: false,
      previousBalance: 0,
      currentBalance: 0,
      delta: 0,
      insufficientBalance: false,
      reason: "",
      transactionId: "",
      itemId: item.id,
      owned: [] as string[],
    };
    let response = emptyResponse;

    await db.runTransaction(async (tx) => {
      response = {...emptyResponse};
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const privateSnap = await tx.get(privateRef);
      const txSnap = await tx.get(txRef);
      const data = userSnap.data() ?? {};
      const privateData = privateSnap.data();
      const owned = ownedMap(privateData);
      const balance = balanceOf(data);
      const current = {previousBalance: balance, currentBalance: balance, owned: Object.keys(owned)};
      if (txSnap.exists) {
        const original = txSnap.data() ?? {};
        response = {
          ...response,
          ...current,
          success: true,
          previousBalance: Number(original.balanceBefore) || 0,
          currentBalance: Number(original.balanceAfter) || 0,
          delta: Number(original.delta) || 0,
          reason: "duplicate",
          transactionId: txId,
        };
        return;
      }
      const nowMs = Date.now();
      const xp = typeof data.xp === "number" ? data.xp : 0;
      const refusal = shopRefusal(item, {premium: data.premium === true, xp, owned: current.owned}, config, nowMs);
      if (refusal) {
        response = {...response, ...current, reason: refusal};
        return;
      }
      if (balance < price) {
        response = {...response, ...current, insufficientBalance: true, reason: "shopItem_insufficient_balance"};
        return;
      }
      const nextOwned = {...owned, [item.id]: nowMs};
      const rev = typeof privateData?.rev === "number" ? privateData.rev : 0;
      tx.update(userRef, {coins: balance - price});
      tx.set(privateRef, {rev: rev + 1, inventory: {owned: nextOwned}}, {merge: true});
      tx.set(txRef, coinTransactionDoc({
        id: txId,
        userId: callerUid,
        at: admin.firestore.Timestamp.now(),
        delta: -price,
        balanceBefore: balance,
        action: "shopItem",
        description: item.name,
        sourceTag: "shop.purchase.callable",
        reason: `shop_${item.id}`,
      }));
      response = {
        ...response,
        success: true,
        changed: true,
        previousBalance: balance,
        currentBalance: balance - price,
        delta: -price,
        reason: `shop_${item.id}`,
        transactionId: txId,
        owned: Object.keys(nextOwned),
      };
    });
    return response;
  },
);

export const equipCosmetic = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{slot?: unknown; itemId?: unknown}>) => {
    const callerUid = uid(request);
    const {slot, itemId} = request.data ?? {};
    if (slot !== "frame" && slot !== "nameGlow") throw new HttpsError("invalid-argument", "slot is invalid.");
    if (itemId !== null && typeof itemId !== "string") throw new HttpsError("invalid-argument", "itemId is invalid.");
    const item = itemId === null ? null : shopItem(itemId) ?? null;
    if (itemId !== null && (!item || slotFor(item.kind) !== slot)) {
      throw new HttpsError("invalid-argument", "Item does not fit this slot.");
    }
    const userRef = db.collection(USERS).doc(callerUid);
    const privateRef = userRef.collection("private").doc("economy");
    let response: {success: boolean; reason: string; cosmetics: Partial<Record<CosmeticSlot, string>>} = {
      success: false, reason: "", cosmetics: {},
    };

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const privateSnap = await tx.get(privateRef);
      const data = userSnap.data() ?? {};
      const equipped = equippedOf(data);
      if (item) {
        if (!(item.id in ownedMap(privateSnap.data()))) {
          response = {success: false, reason: "equip_not_owned", cosmetics: equipped};
          return;
        }
        if (item.proOnly && data.premium !== true) {
          response = {success: false, reason: "equip_pro_required", cosmetics: equipped};
          return;
        }
      }
      const next = {...equipped};
      if (item) next[slot] = item.id;
      else delete next[slot];
      tx.update(userRef, {[`cosmetics.${slot}`]: item ? item.id : admin.firestore.FieldValue.delete()});
      response = {success: true, reason: item ? "equipped" : "cleared", cosmetics: next};
    });
    return response;
  },
);
