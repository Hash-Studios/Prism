import {isDeepStrictEqual} from "node:util";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, CALLABLE_REGIONS} from "./common";
import {
  dayKey, type EconomyConfig, grantXp, isPrice, loadEconomy, randomInt, type WheelSegment, weekKey, weightedPick,
  xpReceipt, type XpReceipt,
} from "./economy";
import {isValidRequestId, optionalLabel, resolveWheelPrize, type WheelPrize} from "./coinsCallables";
import {
  applyQuestEvent,
  buildQuestState,
  maxTargetFor,
  QUEST_EVENTS,
  CLIENT_QUEST_EVENTS,
  type QuestEvent,
  type QuestState,
} from "./questCatalog";
import {pickChestCosmetic} from "./shopCatalog";
import {inventoryOwned, rankRewardsFor} from "./rankRewards";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const EVENT_RATE = "questEventRate";
const DAY_MS = 86_400_000;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
const EVENT_ID_HISTORY = 20;
const CALLABLE_OPTIONS = {region: CALLABLE_REGIONS, cors: true, maxInstances: 10};

function callerUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid?.trim() ?? "";
  if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");
  return uid;
}

const privateEconomyRef = (uid: string) => db.collection(USERS).doc(uid).collection("private").doc("economy");

/** Create the private doc when missing; always bump `rev`. */
function writePrivate(
  tx: admin.firestore.Transaction,
  ref: admin.firestore.DocumentReference,
  rev: number,
  fields: Record<string, unknown>,
): void {
  tx.set(ref, {...fields, rev}, {merge: true});
}

interface ProgressQuestRequest { event?: unknown; eventId?: unknown; requestId?: unknown }

interface Awarded { id: string; coins: number; xp: number }

/** `event` null means sync only; `ignoredReason` is then the reply reason. */
async function runProgress(uid: string, event: QuestEvent | null, eventId: string | null, ignoredReason: string, nowMs: number,
  pendingFavourite?: admin.firestore.DocumentReference) {
  const config = await loadEconomy();
  const today = dayKey(nowMs);
  const userRef = db.collection(USERS).doc(uid);
  const privateRef = privateEconomyRef(uid);
  const rateRef = event ? db.collection(EVENT_RATE).doc(`${uid}_${today}_${event}`) : null;

  return db.runTransaction(async (tx) => {
    if (pendingFavourite) {
      const pending = await tx.get(pendingFavourite);
      if (!pending.exists) return null;
      // Order recovery against account deletion before it can recreate private state.
      const deletion = await tx.get(db.collection("creatorDeletionState").doc(uid));
      if (deletion.data()?.closed === true) {
        tx.delete(pendingFavourite);
        return null;
      }
      const acceptedAt = pending.data()?.acceptedAt;
      // Favourite quests are daily only. Never rewind the user's current state to recover yesterday's work.
      if (!(acceptedAt instanceof admin.firestore.Timestamp) || dayKey(acceptedAt.toMillis()) !== today ||
          dayKey(Date.now()) !== today) {
        tx.delete(pendingFavourite);
        return null;
      }
    }
    const [userSnap, privateSnap, rateSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(privateRef),
      rateRef ? tx.get(rateRef) : null,
    ]);
    if (pendingFavourite && (!userSnap.exists || userSnap.data()?.deleted === true)) {
      tx.delete(pendingFavourite);
      return null;
    }
    if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");

    const userData = userSnap.data() as admin.firestore.DocumentData;
    const privateData = privateSnap.data() ?? {};
    const previousBalance = int(userData.coins, 0);
    let state: QuestState = buildQuestState(privateData.quests, nowMs, userData.premium === true);
    let reason = ignoredReason;
    let awarded: Awarded[] = [];

    if (event && rateRef && rateSnap) {
      const rate = rateSnap.data() ?? {};
      const count = int(rate.count, 0);
      const seen: string[] = Array.isArray(rate.eventIds) ?
        rate.eventIds.filter((id): id is string => typeof id === "string") : [];
      const cap = Math.max(2, 2 * maxTargetFor(event));
      if (eventId && seen.includes(eventId)) {
        reason = "quest_event_duplicate";
      } else if (count >= cap) {
        reason = "quest_event_rate_limited";
      } else {
        tx.set(rateRef, {
          count: count + 1,
          expireAt: admin.firestore.Timestamp.fromMillis(nowMs + 2 * DAY_MS),
          eventIds: eventId ? [...seen, eventId].slice(-EVENT_ID_HISTORY) : seen,
        });
        const applied = applyQuestEvent(state, event, config);
        state = applied.state;
        awarded = applied.completed.map(({id, coins, xp}) => ({id, coins, xp}));
        reason = awarded.length > 0 ? "quest_completed" : "quest_progressed";
      }
    }

    const totalCoins = awarded.reduce((sum, a) => sum + a.coins, 0);
    const totalXp = awarded.reduce((sum, a) => sum + a.xp, 0);
    const currentBalance = previousBalance + totalCoins;
    const rev = int(privateData.rev, 0);
    const stateChanged = !privateSnap.exists || !isDeepStrictEqual(privateData.quests, state);
    const nextXp = awarded.length > 0 ? grantXp(userData, totalXp, nowMs) : null;
    const rewards = nextXp ? rankRewardsFor(nextXp.xp, inventoryOwned(privateData), config, nowMs) : null;
    const privateChanged = stateChanged || (rewards?.added.length ?? 0) > 0;

    if (privateChanged) {
      writePrivate(tx, privateRef, rev + 1, {
        ...(stateChanged ? {quests: state} : {}),
        ...(rewards && rewards.added.length > 0 ? {inventory: {owned: rewards.owned}} : {}),
      });
    }
    if (awarded.length > 0) {
      tx.update(userRef, {coins: currentBalance, ...nextXp});
      const at = admin.firestore.Timestamp.fromMillis(nowMs);
      let balanceBefore = previousBalance;
      for (const award of awarded) {
        const scopeKey = award.id === state.weekly.id ? weekKey(nowMs) : today;
        const id = `ctx_quest_${uid}_${scopeKey}_${award.id}`;
        tx.set(db.collection(TRANSACTIONS).doc(id), coinTransactionDoc({
          id,
          userId: uid,
          at,
          delta: award.coins,
          balanceBefore,
          action: "quest",
          description: `Quest complete (+${award.coins})`,
          sourceTag: "quests.progress.callable",
          reason: `quest_${award.id}`,
        }));
        balanceBefore += award.coins;
      }
    }

    // Consuming the durable work and paying the quest share a commit, including duplicate/rate-limited no-ops.
    if (pendingFavourite) tx.delete(pendingFavourite);
    return {
      success: true,
      changed: awarded.length > 0,
      quests: state,
      awarded,
      previousBalance,
      currentBalance,
      delta: totalCoins,
      reason,
      rev: privateChanged ? rev + 1 : rev,
      ...xpReceipt(nextXp ?? userData, nowMs, totalXp),
    };
  });
}

export const progressQuest = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<ProgressQuestRequest>) => {
    const uid = callerUid(request);
    const rawEvent = request.data?.event;
    if (rawEvent != null && !QUEST_EVENTS.includes(rawEvent as QuestEvent)) {
      throw new HttpsError("invalid-argument", "event is invalid.");
    }
    const rawEventId = request.data?.eventId;
    if (rawEventId != null && (typeof rawEventId !== "string" || rawEventId.length < 8 || rawEventId.length > 64)) {
      throw new HttpsError("invalid-argument", "eventId is invalid.");
    }
    const eventId = typeof rawEventId === "string" ? rawEventId : null;
    const allowed = rawEvent != null && CLIENT_QUEST_EVENTS.includes(rawEvent as QuestEvent);
    return runProgress(
      uid,
      allowed ? rawEvent as QuestEvent : null,
      eventId,
      rawEvent != null && !allowed ? "quest_event_server_only" : "quest_synced",
      Date.now(),
    );
  },
);

/**
 * Counts one event for `uid` from a function that already saw it. `eventId` names the source event, so a retried
 * trigger or callable counts once. Never throws: quests must not break action/view callers. A false result lets
 * a retryable trigger keep durable work pending. `pendingFavourite` is consumed atomically with quest progress.
 */
export async function progressQuestForUser(uid: string, event: QuestEvent, eventId: string, nowMs = Date.now(),
  pendingFavourite?: admin.firestore.DocumentReference): Promise<boolean> {
  try {
    if (pendingFavourite && event !== "favourite") throw new Error("Only favourite events have durable pending work.");
    await runProgress(uid, event, eventId, "quest_synced", nowMs, pendingFavourite);
    return true;
  } catch (err) {
    logger.warn("Could not record the quest event.", {event, err});
    return false;
  }
}

interface OpenQuestChestRequest { requestId?: unknown }

export const openQuestChest = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<OpenQuestChestRequest>) => {
    const uid = callerUid(request);
    const requestId = request.data?.requestId;
    if (typeof requestId !== "string" || !REQUEST_ID_PATTERN.test(requestId)) {
      throw new HttpsError("invalid-argument", "requestId is invalid.");
    }

    const config = await loadEconomy();
    const nowMs = Date.now();
    const today = dayKey(nowMs);
    const userRef = db.collection(USERS).doc(uid);
    const privateRef = privateEconomyRef(uid);
    const chestRef = db.collection(TRANSACTIONS).doc(`ctx_questChest_${uid}_${today}`);

    return db.runTransaction(async (tx) => {
      const [userSnap, privateSnap, chestSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(privateRef),
        tx.get(chestRef),
      ]);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");

      const userData = userSnap.data() as admin.firestore.DocumentData;
      const privateData = privateSnap.data() ?? {};
      const balance = int(userData.coins, 0);
      const rev = int(privateData.rev, 0);
      const state = buildQuestState(privateData.quests, nowMs, userData.premium === true);
      const refused = (reason: string) => ({
        success: false,
        changed: false,
        quests: state,
        previousBalance: balance,
        currentBalance: balance,
        delta: 0,
        reason,
        rev,
        ...xpReceipt(userData, nowMs),
      });

      if (chestSnap.exists) {
        const stored = chestSnap.data() ?? {};
        if (stored.requestId !== requestId) return refused("quest_chest_already_opened");
        return {
          success: true,
          changed: false,
          coins: int(stored.coins, 0),
          itemId: typeof stored.itemId === "string" ? stored.itemId : null,
          doubled: stored.doubled === true,
          quests: state,
          previousBalance: int(stored.balanceBefore, balance),
          currentBalance: int(stored.balanceAfter, balance),
          delta: int(stored.delta, 0),
          reason: "quest_chest_replay",
          transactionId: chestRef.id,
          rev,
          ...xpReceipt(userData, nowMs),
        };
      }
      if (state.chestOpened) return refused("quest_chest_already_opened");
      if (!state.items.every((item) => item.claimed)) return refused("quest_chest_locked");

      const doubled = state.bonus.claimed;
      const base = randomInt(config.award.questChestMin, config.award.questChestMax);
      const coins = doubled ? base * 2 : base;
      const nextXp = grantXp(userData, config.xp.activities.questChest, nowMs);
      const rewards = rankRewardsFor(nextXp.xp, inventoryOwned(privateData), config, nowMs);
      const owned = rewards.owned;
      const cosmetic = Math.random() < config.award.questChestCosmeticChance ?
        pickChestCosmetic(Object.keys(owned)) : null;
      const currentBalance = balance + coins;
      const nextState: QuestState = {...state, chestOpened: true, chestDoubled: doubled};
      const at = admin.firestore.Timestamp.fromMillis(nowMs);

      tx.update(userRef, {coins: currentBalance, ...nextXp});
      writePrivate(tx, privateRef, rev + 1, {
        quests: nextState,
        ...(cosmetic || rewards.added.length > 0 ? {
          inventory: {owned: {...owned, ...(cosmetic ? {[cosmetic.id]: nowMs} : {})}},
        } : {}),
      });
      tx.set(chestRef, {
        ...coinTransactionDoc({
          id: chestRef.id,
          userId: uid,
          at,
          delta: coins,
          balanceBefore: balance,
          action: "questChest",
          description: `Daily quest chest (+${coins})`,
          sourceTag: "quests.chest.callable",
          reason: "quest_chest",
        }),
        requestId,
        coins,
        doubled,
        itemId: cosmetic?.id ?? null,
      });

      return {
        success: true,
        changed: true,
        coins,
        itemId: cosmetic?.id ?? null,
        doubled,
        quests: nextState,
        previousBalance: balance,
        currentBalance,
        delta: coins,
        reason: "quest_chest",
        transactionId: chestRef.id,
        rev: rev + 1,
        ...xpReceipt(nextXp, nowMs, config.xp.activities.questChest),
      };
    });
  },
);

/** What the chest row shows. Derived from today's quests and the config; nothing extra is stored. */
export interface DailyChestStatus { opened: boolean; free: boolean; price: number }

export type DailyChestRefusal =
  "daily_chest_already_opened" | "daily_chest_price_changed" | "daily_chest_insufficient_balance";

export type DailyChestPlan =
  | {ok: false; reason: DailyChestRefusal}
  | {ok: true; free: boolean; cost: number};

interface DailyChestDay {
  quests: QuestState;
  /** `coinTransactions/ctx_questChest_{uid}_{dayKey}`. Both this callable and 3.6.0 `openQuestChest` write it. */
  receipt: admin.firestore.DocumentData | undefined;
  config: EconomyConfig;
}

interface DailyChestFields {
  previousBalance: number;
  currentBalance: number;
  delta: number;
  reason: string;
  transactionId: string;
  insufficientBalance: boolean;
  status: DailyChestStatus;
}

export interface DailyChestWin extends DailyChestFields {
  success: true;
  changed: true;
  cost: number;
  free: boolean;
  doubled: boolean;
  slot: number;
  prize: WheelPrize;
  slots: WheelSegment[];
}

interface DailyChestRefused extends DailyChestFields { success: false; changed: false }

/** Every reply carries the next quest state and its `rev`, so the client adopts both. */
export type DailyChestReply = (DailyChestWin | DailyChestRefused) & {quests: QuestState; rev: number} & XpReceipt;

export function dailyChestStatus({quests, receipt, config}: DailyChestDay): DailyChestStatus {
  return {
    opened: quests.chestOpened || receipt !== undefined,
    free: quests.items.every((item) => item.claimed),
    price: config.spend.dailyChest,
  };
}

/** Whether the chest may open and what it costs. The cost never exceeds `maxCost`. */
export function planDailyChest(input: DailyChestDay & {balance: number; maxCost: number}): DailyChestPlan {
  const {opened, free, price} = dailyChestStatus(input);
  if (opened) return {ok: false, reason: "daily_chest_already_opened"};
  const cost = free ? 0 : price;
  if (cost > input.maxCost) return {ok: false, reason: "daily_chest_price_changed"};
  if (input.balance < cost) return {ok: false, reason: "daily_chest_insufficient_balance"};
  return {ok: true, free, cost};
}

/** The win this `requestId` stored. A 3.6.0 receipt has no `replay`, so it never matches. */
export function storedDailyChestWin(
  receipt: admin.firestore.DocumentData | undefined,
  requestId: string,
): DailyChestWin | null {
  return receipt?.requestId === requestId && receipt.replay ? receipt.replay as DailyChestWin : null;
}

/** Rolls the slot and resolves the prize. The bonus quest doubles the coins; a cosmetic stays one item. */
export function rollDailyChest(
  config: EconomyConfig,
  quests: QuestState,
  owned: readonly string[],
  random: () => number = Math.random,
): {slot: number; doubled: boolean; prize: WheelPrize} {
  const slots = config.award.dailyChest;
  const slot = weightedPick(slots, random);
  const prize = resolveWheelPrize(slots[slot], owned, random);
  const doubled = quests.bonus.claimed;
  return {slot, doubled, prize: doubled ? {...prize, coins: prize.coins * 2} : prize};
}

export const openDailyChest = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{requestId?: unknown; maxCost?: unknown; sourceTag?: unknown}>) => {
    const uid = callerUid(request);
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    const maxCost = request.data?.maxCost;
    if (!isPrice(maxCost)) throw new HttpsError("invalid-argument", "maxCost is invalid.");
    const sourceTag = optionalLabel(request.data?.sourceTag) ?? "quests.daily_chest.callable";

    const config = await loadEconomy();
    const nowMs = Date.now();
    const userRef = db.collection(USERS).doc(uid);
    const privateRef = privateEconomyRef(uid);
    const chestRef = db.collection(TRANSACTIONS).doc(`ctx_questChest_${uid}_${dayKey(nowMs)}`);

    return db.runTransaction<DailyChestReply>(async (tx) => {
      const [userSnap, privateSnap, chestSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(privateRef),
        tx.get(chestRef),
      ]);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");

      const userData = userSnap.data() as admin.firestore.DocumentData;
      const privateData = privateSnap.data() ?? {};
      const balance = int(userData.coins, 0);
      const rev = int(privateData.rev, 0);
      const quests = buildQuestState(privateData.quests, nowMs, userData.premium === true);
      const receipt = chestSnap.data();
      const day = {quests, receipt, config};

      // The stored win with the live balance, status and quests: other spends or quest progress may have come between.
      const stored = storedDailyChestWin(receipt, requestId);
      if (stored) {
        return {
          ...stored, previousBalance: balance, currentBalance: balance, delta: 0, status: dailyChestStatus(day), quests, rev,
          ...xpReceipt(userData, nowMs),
        };
      }
      const plan = planDailyChest({...day, balance, maxCost});
      if (!plan.ok) {
        return {
          success: false,
          changed: false,
          previousBalance: balance,
          currentBalance: balance,
          delta: 0,
          reason: plan.reason,
          transactionId: "",
          insufficientBalance: plan.reason === "daily_chest_insufficient_balance",
          status: dailyChestStatus(day),
          quests,
          rev,
          ...xpReceipt(userData, nowMs),
        };
      }

      const nextXp = grantXp(userData, config.xp.activities.questChest, nowMs);
      const rewards = rankRewardsFor(nextXp.xp, inventoryOwned(privateData), config, nowMs);
      const owned = rewards.owned;
      const {slot, doubled, prize} = rollDailyChest(config, quests, Object.keys(owned));
      const delta = prize.coins - plan.cost;
      const currentBalance = balance + delta;
      const nextQuests: QuestState = {...quests, chestOpened: true, chestDoubled: doubled};
      const win: DailyChestWin = {
        success: true,
        changed: true,
        previousBalance: balance,
        currentBalance,
        delta,
        reason: "daily_chest",
        transactionId: chestRef.id,
        insufficientBalance: false,
        status: dailyChestStatus({...day, quests: nextQuests}),
        cost: plan.cost,
        free: plan.free,
        doubled,
        slot,
        prize,
        slots: config.award.dailyChest,
      };

      tx.update(userRef, {coins: currentBalance, ...nextXp});
      writePrivate(tx, privateRef, rev + 1, {
        quests: nextQuests,
        ...(prize.itemId || rewards.added.length > 0 ? {
          inventory: {owned: {...owned, ...(prize.itemId ? {[prize.itemId]: nowMs} : {})}},
        } : {}),
      });
      tx.set(chestRef, {
        ...coinTransactionDoc({
          id: chestRef.id,
          userId: uid,
          at: admin.firestore.Timestamp.fromMillis(nowMs),
          delta,
          balanceBefore: balance,
          action: "questChest",
          description: `Daily chest (${delta >= 0 ? "+" : ""}${delta})`,
          sourceTag,
          reason: "daily_chest",
        }),
        requestId,
        cost: plan.cost,
        free: plan.free,
        doubled,
        slot,
        prize,
        coins: prize.coins,
        itemId: prize.itemId,
        replay: win,
      });
      return {
        ...win, quests: nextQuests, rev: rev + 1, ...xpReceipt(nextXp, nowMs, config.xp.activities.questChest),
      };
    });
  },
);
