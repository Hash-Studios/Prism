import * as admin from "firebase-admin";
import {isDeepStrictEqual} from "node:util";
import {db} from "./common";
import {DEFAULT_CATEGORY, DEFAULT_COLLECTION} from "./wallCategory";
import {collectionFor} from "./wallCollections";
import {premiumCollections} from "./wallOfTheDay";
import {type WallDepth} from "./wallDepth";
import {type WallSpatial} from "./wallSpatial";

/** Both entrypoints commit remote image results against the same incarnation and unchanged source. */
export async function writeWallCategorization(input: {
  wallId: string;
  initial: admin.firestore.DocumentSnapshot;
  category: string;
  labels?: string[];
  colors?: string[];
  depth?: WallDepth;
  spatial?: WallSpatial;
  replaceClassification?: boolean;
}): Promise<{category: string} | null> {
  const before = input.initial.data();
  const createTime = input.initial.createTime;
  if (!before || !createTime) return null;
  const premium = await premiumCollections();
  return db.runTransaction(async (tx) => {
    const ref = db.collection("walls").doc(input.wallId);
    const snap = await tx.get(ref);
    const wall = snap.data();
    const sourceFields = ["id", "email", "wallpaper_url", "wallpaper_thumb", "wallpaper_path", "wallpaper_sha",
      "thumb_path", "thumb_sha", "originalProtected", "originalObjectId"];
    if (!wall || !snap.createTime?.isEqual(createTime) ||
      sourceFields.some((key) => !isDeepStrictEqual(wall[key], before[key]))) return null;

    const unchanged = (key: string) => isDeepStrictEqual(wall[key], before[key]);
    const patch: admin.firestore.UpdateData<admin.firestore.DocumentData> = {};
    const classificationUnchanged = ["category", "aiCategorized", "categorizedAt"].every(unchanged);
    const canClassify = classificationUnchanged && (input.replaceClassification ||
      (!wall.category || wall.category === DEFAULT_CATEGORY) && wall.aiCategorized !== true);
    if (canClassify) {
      Object.assign(patch, {category: input.category, aiCategorized: true,
        categorizedAt: admin.firestore.FieldValue.serverTimestamp()});
      if (wall.collections == null && unchanged("collections")) patch.collections = [DEFAULT_COLLECTION];
      // File in this same transaction only when collections were not edited during analysis.
      if (unchanged("collections")) {
        const target = collectionFor({...wall, ...patch});
        if (target && !premium.includes(target)) patch.collections = [DEFAULT_COLLECTION, target];
      }
    }
    if (input.colors && unchanged("colors")) patch.colors = input.colors;
    if (input.depth && wall.depth == null && unchanged("depth")) patch.depth = input.depth;
    if (input.spatial && wall.spatial == null && unchanged("spatial")) patch.spatial = input.spatial;
    if (input.labels && unchanged("visionLabels")) patch.visionLabels = input.labels;
    if (Object.keys(patch).length > 0) tx.update(ref, patch);
    return {category: typeof patch.category === "string" ? patch.category : wall.category ?? DEFAULT_CATEGORY};
  });
}
