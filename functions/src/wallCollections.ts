import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {DEFAULT_COLLECTION} from "./wallCategory";
import {refreshMoods} from "./wallMoods";
import {premiumCollections} from "./wallEligibility";

/**
 * The collection that a wall category files a community wall into. A collection in the Remote Config premium list is
 * skipped when the wall is filed, because the app locks every wall in it for free users.
 */
const CATEGORY_COLLECTIONS = new Map<string, string>([
  ["Nature", "landscapes"],
  ["Landscape", "landscapes"],
  ["Space", "space"],
  ["Galaxy", "space"],
  ["Anime", "illustrations"],
  ["Dark", "amoled"],
  ["Abstract", "abstract"],
  ["Gradient", "gradients"],
]);

export function categoryCollection(category: unknown): string | null {
  return typeof category === "string" ? CATEGORY_COLLECTIONS.get(category) ?? null : null;
}

/** True when the wall has collections and each one is community. */
export function isCommunityOnly(collections: unknown): boolean {
  return Array.isArray(collections) && collections.length > 0 &&
    collections.every((c) => str(c).toLowerCase() === DEFAULT_COLLECTION);
}

/** The collection of an approved wall that is only in community, from its category. Null when there is none. */
export function collectionFor(wall: admin.firestore.DocumentData | undefined): string | null {
  return wall?.review === true && isCommunityOnly(wall.collections) ? categoryCollection(wall.category) : null;
}

/**
 * Adds the collection of the wall's category to an approved wall that is only in community. Returns the collection,
 * or null when the wall stays as it is. A failure is logged and returns null.
 */
export async function fileWallInCollection(ref: admin.firestore.DocumentReference | undefined): Promise<string | null> {
  if (!ref) return null;
  try {
    return await db.runTransaction(async (tx) => {
      const target = collectionFor((await tx.get(ref)).data());
      if (!target || (await premiumCollections()).includes(target)) return null;
      tx.update(ref, {collections: [DEFAULT_COLLECTION, target]});
      return target;
    });
  } catch (err) {
    logger.warn("fileWallInCollection: could not file the wall.", {wallId: ref.id, err});
    return null;
  }
}

/**
 * Gives each collection the cover and sort time of its newest approved wall when that wall is newer than the last
 * edit. A collection with no newer wall keeps its cover. Returns the names of the collections it changed.
 */
export async function refreshCollectionCovers(): Promise<string[]> {
  const changed: string[] = [];
  for (const doc of (await db.collection("collections").get()).docs) {
    const name = str(doc.data()?.name).toLowerCase();
    if (!name) continue;
    const [newest] = (await db.collection("walls")
      .where("collections", "array-contains", name)
      .where("review", "==", true)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get()).docs;
    const wall = newest?.data();
    const createdAt = wall?.createdAt;
    const thumb = str(wall?.wallpaper_thumb);
    const lastEditTime = doc.data()?.lastEditTime;
    if (!(createdAt instanceof admin.firestore.Timestamp) || !thumb ||
      (lastEditTime instanceof admin.firestore.Timestamp && lastEditTime.toMillis() >= createdAt.toMillis())) {
      continue;
    }
    await doc.ref.update({thumb1: thumb, lastEditTime: createdAt});
    changed.push(name);
  }
  return changed;
}

export const refreshCollections = onSchedule(
  {
    schedule: "0 4 * * *", // 04:00 UTC, after the wall of the day
    timeZone: "UTC",
    region: REGION,
    retryCount: 2,
  },
  async () => {
    const changed = await refreshCollectionCovers();
    logger.info("refreshCollections: covers refreshed.", {changed});
    const moods = await refreshMoods();
    logger.info("refreshCollections: moods written.", {moods});
  },
);
