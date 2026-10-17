import {isDeepStrictEqual} from "node:util";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, REGION} from "./common";
import {dayKey, grantXp, loadEconomy, randomInt, weekKey, xpForCoins} from "./economy";
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

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const EVENT_RATE = "questEventRate";
const DAY_MS = 86_400_000;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
const EVENT_ID_HISTORY = 20;
const CALLABLE_OPTIONS = {region: REGION, cors: true, maxInstances: 10};

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
async function runProgress(uid: string, event: QuestEvent | null, eventId: string | null, ignoredReason: string, nowMs: number) {
  const config = await loadEconomy();
  const today = dayKey(nowMs);
  const userRef = db.collection(USERS).doc(uid);
  const privateRef = privateEconomyRef(uid);
  const rateRef = event ? db.collection(EVENT_RATE).doc(`${uid}_${today}_${event}`) : null;

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const privateSnap = await tx.get(privateRef);
    const rateSnap = rateRef ? await tx.get(rateRef) : null;
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

    if (stateChanged) writePrivate(tx, privateRef, rev + 1, {quests: state});
    if (awarded.length > 0) {
      tx.update(userRef, {coins: currentBalance, ...grantXp(userData, totalXp, nowMs)});
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

    return {
      success: true,
      changed: awarded.length > 0,
      quests: state,
      awarded,
      previousBalance,
      currentBalance,
      delta: totalCoins,
      reason,
      rev: stateChanged ? rev + 1 : rev,
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

/** Counts one event for `uid` from a function that already saw it. Never throws: quests must not break the caller. */
export async function progressQuestForUser(uid: string, event: QuestEvent, nowMs = Date.now()): Promise<void> {
  try {
    await runProgress(uid, event, null, "quest_synced", nowMs);
  } catch (err) {
    logger.warn("Could not record the quest event.", {event, err});
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
      const userSnap = await tx.get(userRef);
      const privateSnap = await tx.get(privateRef);
      const chestSnap = await tx.get(chestRef);
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
          previousBalance: balance,
          currentBalance: balance,
          delta: 0,
          reason: "quest_chest_replay",
          transactionId: chestRef.id,
          rev,
        };
      }
      if (state.chestOpened) return refused("quest_chest_already_opened");
      if (!state.items.every((item) => item.claimed)) return refused("quest_chest_locked");

      const doubled = state.bonus.claimed;
      const base = randomInt(config.award.questChestMin, config.award.questChestMax);
      const coins = doubled ? base * 2 : base;
      const rawInventory = privateData.inventory as {owned?: Record<string, unknown>} | undefined;
      const owned = rawInventory?.owned ?? {};
      const cosmetic = Math.random() < config.award.questChestCosmeticChance ?
        pickChestCosmetic(Object.keys(owned)) : null;
      const currentBalance = balance + coins;
      const nextState: QuestState = {...state, chestOpened: true, chestDoubled: doubled};
      const at = admin.firestore.Timestamp.fromMillis(nowMs);

      tx.update(userRef, {coins: currentBalance, ...grantXp(userData, xpForCoins(coins, config), nowMs)});
      writePrivate(tx, privateRef, rev + 1, {
        quests: nextState,
        ...(cosmetic ? {inventory: {...rawInventory, owned: {...owned, [cosmetic.id]: nowMs}}} : {}),
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
      };
    });
  },
);
