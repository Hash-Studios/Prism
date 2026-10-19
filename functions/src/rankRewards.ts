import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, int, CALLABLE_REGIONS} from "./common";
import {type EconomyConfig, grantXp, loadEconomy} from "./economy";
import {SHOP_CATALOG} from "./shopCatalog";

export interface RankRewardPlan {
  owned: Readonly<Record<string, number>>;
  added: readonly string[];
}

export function inventoryOwned(privateData: Record<string, unknown>): Record<string, number> {
  const inventory = privateData.inventory;
  const raw = inventory && typeof inventory === "object" && "owned" in inventory ? inventory.owned : null;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  return Object.fromEntries(Object.entries(raw).filter((entry): entry is [string, number] =>
    typeof entry[1] === "number" && Number.isFinite(entry[1])));
}

export function rankRewardsFor(
  lifetimeXp: number,
  owned: Readonly<Record<string, number>>,
  config: EconomyConfig,
  nowMs: number,
): RankRewardPlan {
  const nextOwned = {...owned};
  const added: string[] = [];
  for (const item of SHOP_CATALOG) {
    if (!item.rankReward || Object.prototype.hasOwnProperty.call(nextOwned, item.id)) continue;
    const rank = config.xp.ranks.find((candidate) => candidate.id === item.rankReward);
    if (!rank || !Number.isFinite(lifetimeXp) || lifetimeXp < rank.min) continue;
    nextOwned[item.id] = nowMs;
    added.push(item.id);
  }
  return {owned: nextOwned, added};
}

export const reconcileRankRewards = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10},
  async (request: CallableRequest<unknown>) => {
    const uid = request.auth?.uid?.trim() ?? "";
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to receive rank rewards.");
    if (request.data != null && (typeof request.data !== "object" || Array.isArray(request.data) ||
      Object.keys(request.data).some((key) => key !== "sourceTag") ||
      ("sourceTag" in request.data && (typeof request.data.sourceTag !== "string" || request.data.sourceTag.length > 200)))) {
      throw new HttpsError("invalid-argument", "Rank rewards require no inputs.");
    }
    const config = await loadEconomy();
    const nowMs = Date.now();
    const userRef = db.collection("usersv2").doc(uid);
    const privateRef = userRef.collection("private").doc("economy");
    return db.runTransaction(async (tx) => {
      const [userSnap, privateSnap] = await Promise.all([tx.get(userRef), tx.get(privateRef)]);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const userData = userSnap.data() ?? {};
      const privateData = privateSnap.data() ?? {};
      const plan = rankRewardsFor(userData.xp ?? 0, inventoryOwned(privateData), config, nowMs);
      const inventoryChanged = plan.added.length > 0;
      const rev = int(privateData.rev, 0) + (inventoryChanged ? 1 : 0);
      if (inventoryChanged) tx.set(privateRef, {rev, inventory: {owned: plan.owned}}, {merge: true});
      return {success: true, rev, owned: Object.keys(plan.owned), added: plan.added, inventoryChanged,
        ...grantXp(userData, 0, nowMs)};
    });
  },
);
