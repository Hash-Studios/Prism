import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, REGION} from "./common";
import {
  bumpDaily,
  claimRateDoc,
  normalizeId,
  RATE_DOC_TTL_MS,
  WALLPAPER_STATS,
} from "./viewStats";

const ACTION_FIELDS = {download: "downloads", set: "sets", share: "shares"} as const;
type WallAction = keyof typeof ACTION_FIELDS;

const WALL_ACTION_RATE = "wallActionRate";
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
    region: REGION,
    cors: true,
    maxInstances: 10,
  },
  async (request: CallableRequest<{wallId?: string; action?: string}>): Promise<{counted: boolean}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to record an action.");
    const wallId = normalizeId(request.data?.wallId ?? "");
    const action = normalizeAction(request.data?.action);

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
    return {counted: true};
  },
);

/** `+1` for a new favourite and `-1` for a removed one. Updates of an existing favourite change nothing. */
export function favouriteDelta(
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
): number {
  if (!before === !after) return 0;
  return after ? 1 : -1;
}

/** Keeps `wallpaper_stats.favs` equal to the number of users that favourited the wallpaper. */
export const onFavouriteWritten = onDocumentWritten(
  {
    document: "usersv2/{uid}/images/{wallId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const delta = favouriteDelta(before, after);
    if (delta === 0) return;
    const provider = String((after ?? before)?.provider ?? "").trim().toLowerCase();
    if (!PRISM_PROVIDERS.has(provider)) return;

    let wallId: string;
    try {
      wallId = normalizeId(String((after ?? before)?.id ?? event.params.wallId));
    } catch {
      return;
    }

    const statsRef = db.collection(WALLPAPER_STATS).doc(wallId);
    await db.runTransaction(async (tx) => {
      const favs = (await tx.get(statsRef)).data()?.favs;
      const current = typeof favs === "number" && Number.isFinite(favs) ? favs : 0;
      tx.set(statsRef, {favs: Math.max(0, current + delta)}, {merge: true});
    });
    if (delta > 0) {
      await bumpDaily(wallId, "favs", Date.now()).catch((err: unknown) => {
        logger.warn("Could not record the daily favourite.", {err});
      });
    }
  },
);
