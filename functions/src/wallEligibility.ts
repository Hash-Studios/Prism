import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db} from "./common";
import {getOwnedWallDelivery} from "./ownedAssetDelivery";

const DEFAULT_PREMIUM_COLLECTIONS = [
  "space",
  "abstract",
  "flat",
  "mesh gradients",
  "fluids",
];
/** Approved walls with a private original: the only walls that 3.8.0 clients list and can set. */
export const protectedWalls = () =>
  db
    .collection("walls")
    .where("review", "==", true)
    .where("originalProtected", "==", true)
    .where("wallpaper_url", "==", "")
    .where("wallpaper_path", "==", "")
    .where("wallpaper_sha", "==", "")
    .where("thumb_path", "==", "")
    .where("thumb_sha", "==", "");

/** Walls that a free user cannot open are never the free daily pick. Unconverted walls cannot be set, so they are not either. */
export function isWotdEligible(
  wall: admin.firestore.DocumentData,
  premiumCollections: string[],
): boolean {
  if (wall.originalProtected !== true || wall.is_streak_exclusive === true || wall.dropReserved === true || wall.dropWeek) return false;
  if (!Array.isArray(wall.collections) || wall.collections.some((entry) => typeof entry !== "string")) return false;
  const collections: string[] = wall.collections;
  return !collections.some((c) =>
    premiumCollections.includes(String(c).trim()),
  );
}

export async function readyWall(wallId: string, premium: string[], data?: admin.firestore.DocumentData): Promise<boolean> {
  if (!wallId || wallId.includes("/")) return false;
  const wall = data ?? (await db.collection("walls").doc(wallId).get()).data();
  if (!wall || wall.review !== true || !isWotdEligible(wall, premium)) return false;
  try {
    await getOwnedWallDelivery(typeof wall.id === "string" ? wall.id : wallId);
    return true;
  } catch (error) {
    if (!(error instanceof Error) || !["Owned wall unavailable", "Invalid wall identity"].includes(error.message)) throw error;
    logger.warn("wall_of_the_day: protected wall has no ready delivery.", {wallId});
    return false;
  }
}

/** Parses the app's Remote Config list format: `["a", "b"]` or `a, b`. */
export function parseCollectionList(raw: string): string[] {
  return raw
    .replace(/["[\]]/g, "")
    .split(",")
    .map((e) => e.trim())
    .filter((e) => e.length > 0);
}

export async function premiumCollections(): Promise<string[]> {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const value = (
      template.parameters?.premiumCollections?.defaultValue as
        { value?: string } | undefined
    )?.value;
    const parsed = value ? parseCollectionList(value) : [];
    return parsed.length > 0 ? parsed : DEFAULT_PREMIUM_COLLECTIONS;
  } catch (err) {
    logger.warn(
      "Could not read premiumCollections from Remote Config; using the app defaults.",
      {err},
    );
    return DEFAULT_PREMIUM_COLLECTIONS;
  }
}

export const SIMILAR_FIELDS = ["id", "review", "createdAt", "colors", "visionLabels", "collections", "category", "spatial",
  "depth", "originalProtected", "is_streak_exclusive", "dropReserved", "dropWeek", "wallpaper_thumb"];
