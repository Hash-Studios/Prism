import * as admin from "firebase-admin";
import {isDeepStrictEqual} from "node:util";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, REGION, CALLABLE_REGIONS, utcDateString} from "./common";
import {
  bumpDaily,
  claimRateDoc,
  normalizeId,
  RATE_DOC_TTL_MS,
  WALLPAPER_STATS,
  WALLPAPER_STATS_DAILY,
} from "./viewStats";
import {progressQuestForUser, progressWallpaperActionQuest, type Awarded} from "./quests";
import {dayKey} from "./economy";

const ACTION_FIELDS = {download: "downloads", set: "sets", share: "shares"} as const;
type WallAction = keyof typeof ACTION_FIELDS;

const WALL_ACTION_RATE = "wallActionRate";
export const FAVOURITE_AGGREGATION_GATE = "maintenance/favouriteAggregation";
/** `usersv2/*\/images` also holds wallhaven and pexels favourites, which are not Prism walls. */
const PRISM_PROVIDERS = new Set(["prism", "wall_of_the_day", "walloftheday"]);

function normalizeAction(raw: unknown): WallAction {
  if (typeof raw !== "string" || !Object.prototype.hasOwnProperty.call(ACTION_FIELDS, raw)) {
    throw new HttpsError("invalid-argument", "action must be download, set or share.");
  }
  return raw as WallAction;
}

/**
 * Counts one download, set or share of a wallpaper per user and day. The counters show on the wallpaper and feed
 * the trending job. They are display data, never a source of coins.
 */
export const recordWallpaperAction = onCall(
  {
    region: CALLABLE_REGIONS,
    cors: true,
    maxInstances: 10,
  },
  async (request: CallableRequest<{wallId?: string; action?: string; requestId?: unknown}>) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to record an action.");
    const wallId = normalizeId(request.data?.wallId ?? "");
    const action = normalizeAction(request.data?.action);

    const requestId = request.data?.requestId;
    if (requestId !== undefined) {
      if (typeof requestId !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) {
        throw new HttpsError("invalid-argument", "requestId is invalid.");
      }
      return recordReceiptedAction(uid, wallId, action, requestId);
    }

    const rateRef = db.collection(WALL_ACTION_RATE).doc(`${uid}_${wallId}_${action}`);
    const rateSnap = await rateRef.get();
    const lastAt = rateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
    const now = Date.now();
    if (lastAt && now - lastAt.toMillis() < RATE_DOC_TTL_MS) return {counted: false};

    const claimed = await claimRateDoc(rateRef, rateSnap, {
      lastAt: admin.firestore.Timestamp.fromMillis(now),
      expireAt: admin.firestore.Timestamp.fromMillis(now + RATE_DOC_TTL_MS),
    });
    if (!claimed) return {counted: false};

    const field = ACTION_FIELDS[action];
    await db.collection(WALLPAPER_STATS).doc(wallId).set({
      [field]: admin.firestore.FieldValue.increment(1),
      lastEventAt: admin.firestore.Timestamp.fromMillis(now),
    }, {merge: true});
    await bumpDaily(wallId, field, now).catch((err: unknown) => {
      logger.warn("Could not record the daily wallpaper action.", {err});
    });
    const eventId = `${uid}_${wallId}_${dayKey(now)}`;
    if (action === "share") {
      await progressQuestForUser(uid, "share", eventId, now);
    } else {
      // `set_wall` and the weekly quest count a set or a save, once per wall a day.
      await progressQuestForUser(uid, "set_wallpaper", eventId, now);
      if (action === "download") await progressQuestForUser(uid, "download", eventId, now);
    }
    return {counted: true};
  },
);

async function recordReceiptedAction(uid: string, wallId: string, action: WallAction, requestId: string) {
  const receiptRef = db.collection("usersv2").doc(uid).collection("wallActionReceipts").doc(requestId);
  const rateRef = db.collection(WALL_ACTION_RATE).doc(`${uid}_${wallId}_${action}`);
  const now = Date.now();
  const accepted = await db.runTransaction(async (tx) => {
    const [receipt, rate, user, deletion] = await Promise.all([
      tx.get(receiptRef), tx.get(rateRef), tx.get(db.collection("usersv2").doc(uid)),
      tx.get(db.collection("creatorDeletionState").doc(uid)),
    ]);
    if (!user.exists || user.data()?.deleted === true || deletion.data()?.closed === true) {
      throw new HttpsError("failed-precondition", "This account is unavailable.");
    }
    if (receipt.exists) {
      const stored = receipt.data() ?? {};
      if (stored.wallId !== wallId || stored.action !== action) {
        throw new HttpsError("invalid-argument", "requestId already belongs to another action.");
      }
      return {counted: stored.counted === true, acceptedAt: stored.acceptedAt as number};
    }
    const lastAt = rate.data()?.lastAt as admin.firestore.Timestamp | undefined;
    const counted = !lastAt || now - lastAt.toMillis() >= RATE_DOC_TTL_MS;
    tx.set(receiptRef, {wallId, action, counted, acceptedAt: now});
    if (counted) {
      tx.set(rateRef, {
        lastAt: admin.firestore.Timestamp.fromMillis(now),
        expireAt: admin.firestore.Timestamp.fromMillis(now + RATE_DOC_TTL_MS),
      });
      const field = ACTION_FIELDS[action];
      tx.set(db.collection(WALLPAPER_STATS).doc(wallId), {
        [field]: admin.firestore.FieldValue.increment(1), lastEventAt: admin.firestore.Timestamp.fromMillis(now),
      }, {merge: true});
      const day = utcDateString(new Date(now)).replace(/-/g, "");
      tx.set(db.collection(WALLPAPER_STATS_DAILY).doc(`${day}_${wallId}`), {
        wallId, day, [field]: admin.firestore.FieldValue.increment(1),
        expireAt: admin.firestore.Timestamp.fromMillis(now + 14 * 86_400_000),
      }, {merge: true});
    }
    return {counted, acceptedAt: now};
  });
  const questAwards: Awarded[] = [];
  let questReceiptComplete = true;
  if (accepted.counted) {
    const events = action === "share" ? ["share"] as const :
      action === "download" ? ["set_wallpaper", "download"] as const : ["set_wallpaper"] as const;
    for (const event of events) {
      const awards = await progressWallpaperActionQuest(uid, event,
        `${uid}_${wallId}_${dayKey(accepted.acceptedAt)}`, accepted.acceptedAt, receiptRef.collection("events").doc(event));
      if (awards === null) questReceiptComplete = false;
      else questAwards.push(...awards);
    }
  }
  return {counted: accepted.counted, questAwards, questCoins: questAwards.reduce((sum, award) => sum + award.coins, 0),
    questReceiptId: requestId, questReceiptComplete};
}

export function isPrismFavourite(pathId: string, data: admin.firestore.DocumentData | undefined): boolean {
  return data?.id === pathId && typeof data.provider === "string" && PRISM_PROVIDERS.has(data.provider.toLowerCase());
}

/** Reconciles live unique membership. Existing aggregate drift is not repaired without a separate migration. */
export const onFavouriteWritten = onDocumentWritten(
  {
    document: "usersv2/{uid}/images/{wallId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const before = isPrismFavourite(event.params.wallId, event.data?.before.data());
    const after = isPrismFavourite(event.params.wallId, event.data?.after.data());
    if (!before && !after) return;
    let wallId: string;
    try {
      wallId = normalizeId(event.params.wallId);
    } catch {
      return;
    }

    const statsRef = db.collection(WALLPAPER_STATS).doc(wallId);
    const contributionRef = statsRef.collection("favouriteContributions").doc(event.params.uid);
    const pendingQuests = contributionRef.collection("pendingQuests");
    const now = Date.now();
    const day = utcDateString(new Date(now)).replace(/-/g, "");
    await db.runTransaction(async (tx) => {
      const gate = (await tx.get(db.doc(FAVOURITE_AGGREGATION_GATE))).data();
      if (gate?.phase !== "ready" || typeof gate.epoch !== "string" || !gate.epoch) {
        throw new Error("Favourite contribution backfill must finish before aggregation can run.");
      }
      // A full membership query includes every case alias and conflicts with concurrent favourite writes.
      const [images, contribution, stats] = await Promise.all([
        tx.get(db.collection("usersv2").doc(event.params.uid).collection("images")),
        tx.get(contributionRef), tx.get(statsRef),
      ]);
      const active = images.docs.some((doc) => {
        try {
          return normalizeId(doc.id) === wallId && isPrismFavourite(doc.id, doc.data());
        } catch {
          return false;
        }
      });
      const previous = contribution.data();
      const changed = active !== (previous?.epoch === gate.epoch && previous?.active === true);
      const previousSequence = previous?.sequence;
      const sequence = (Number.isSafeInteger(previousSequence) ? previousSequence : 0) + (changed ? 1 : 0);
      const acceptedAt = changed ? admin.firestore.Timestamp.fromMillis(now) : previous?.acceptedAt;
      const source = images.docs.find((doc) => doc.id === event.params.wallId);
      const sourceMs = Date.parse(event.time);
      const acceptQuest = active && previous?.questSequence !== sequence && !before && after &&
        acceptedAt instanceof admin.firestore.Timestamp && dayKey(acceptedAt.toMillis()) === dayKey(now) &&
        Number.isFinite(sourceMs) && dayKey(sourceMs) === dayKey(now) &&
        source && isPrismFavourite(source.id, source.data()) && source.createTime && event.data?.after.createTime &&
        source.createTime.isEqual(event.data.after.createTime) &&
        isDeepStrictEqual(source.updateTime, event.data.after.updateTime);
      if (!changed && !acceptQuest) return;
      tx.set(contributionRef, {active, sequence, epoch: gate.epoch,
        ...(active ? {acceptedAt} : {}), ...(acceptQuest ? {questSequence: sequence} : {}),
      }, {merge: true});
      if (changed) {
        const favs = stats.data()?.favs;
        const current = typeof favs === "number" && Number.isFinite(favs) ? favs : 0;
        tx.set(statsRef, {favs: Math.max(0, current + (active ? 1 : -1))}, {merge: true});
        if (active) {
          tx.set(db.collection(WALLPAPER_STATS_DAILY).doc(`${day}_${wallId}`), {
            wallId, day, favs: admin.firestore.FieldValue.increment(1),
            expireAt: admin.firestore.Timestamp.fromMillis(now + 14 * 86_400_000),
          }, {merge: true});
        }
      }
      if (acceptQuest) tx.set(pendingQuests.doc(String(sequence)), {acceptedAt});
    });
    // Read again even when membership did not change: a previous invocation may have committed only the stats.
    const pending = await pendingQuests.limit(25).get();
    for (const quest of pending.docs) {
      if (!await progressQuestForUser(event.params.uid, "favourite",
        `${event.params.uid}_${wallId}_${quest.id}`, Date.now(), quest.ref)) {
        throw new Error("Could not recover the accepted favourite quest event.");
      }
    }
    if (pending.size === 25 && !(await pendingQuests.limit(1).get()).empty) {
      throw new Error("Accepted favourite quest recovery has more pending work to retry.");
    }
  },
);
