import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {DEFAULT_CATEGORY, DEFAULT_COLLECTION, detectLabels, mapLabelsToCategory} from "./wallCategory";
import {db, REGION} from "./common";
import {hasPaletteColors, wallColorsFor} from "./wallColors";
import {fileWallInCollection} from "./wallCollections";
import {falKey, type WallDepth, wallDepthFor} from "./wallDepth";

export const onWallCategorize = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: REGION,
    timeoutSeconds: 120,
    secrets: [falKey],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    const wallId = event.params.wallId;
    const wallpaperUrl = (data.wallpaper_url || data.wallpaper_thumb || "").toString().trim();

    if (!wallpaperUrl) {
      logger.warn("onWallCategorize: no wallpaper URL found", {wallId});
      return;
    }

    const [colors, depth, labels] = await Promise.all([
      hasPaletteColors(data.colors) ? undefined : wallColorsFor(wallId, data),
      data.depth == null ? wallDepthFor(wallId, {url: wallpaperUrl}) : undefined,
      detectLabelsIfAble(wallId, wallpaperUrl),
    ]);
    const extra: ImageFields = {...(colors ? {colors} : {}), ...(labels ? {visionLabels: labels} : {})};
    await writeDepthIfAbsent(wallId, depth);

    if (data.category && data.category !== DEFAULT_CATEGORY) {
      logger.info("onWallCategorize: category already set", {wallId, category: data.category});
      if (Object.keys(extra).length > 0) {
        await db.collection("walls").doc(wallId).update(extra);
      }
      return;
    }

    if (!labels || labels.length === 0) {
      logger.warn("onWallCategorize: no labels to categorize by", {wallId});
      await updateWallpaperCategory(wallId, DEFAULT_CATEGORY, [DEFAULT_COLLECTION], extra);
      return;
    }

    const category = mapLabelsToCategory(labels);
    logger.info("onWallCategorize: categorized wallpaper", {wallId, labels: labels.slice(0, 5), category});
    await updateWallpaperCategory(wallId, category, [DEFAULT_COLLECTION], extra);
  },
);

type ImageFields = {colors?: string[]; visionLabels?: string[]};

async function detectLabelsIfAble(wallId: string, wallpaperUrl: string): Promise<string[] | undefined> {
  try {
    return await detectLabels(wallpaperUrl);
  } catch (error) {
    logger.error("onWallCategorize: failed to detect labels", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}

/**
 * The check runs for up to a minute, and an admin can set `depth` meanwhile. A failure is logged, so it cannot fail
 * the colour or category write.
 */
async function writeDepthIfAbsent(wallId: string, depth: WallDepth | undefined): Promise<void> {
  if (!depth) {
    return;
  }
  try {
    const ref = db.collection("walls").doc(wallId);
    await db.runTransaction(async (tx) => {
      const wall = (await tx.get(ref)).data();
      if (wall && wall.depth == null) {
        tx.update(ref, {depth});
      }
    });
  } catch (error) {
    logger.warn("onWallCategorize: could not save depth", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

async function updateWallpaperCategory(
  wallId: string,
  category: string,
  collections: string[],
  extra: ImageFields,
): Promise<void> {
  await db.collection("walls").doc(wallId).update({
    category: category,
    collections: collections,
    categorizedAt: admin.firestore.FieldValue.serverTimestamp(),
    aiCategorized: true,
    ...extra,
  });

  logger.info("Wallpaper category updated", {wallId, category, collections});
  // The wall can be approved before the check ends. onWallApproved then had no category to file it by.
  await fileWallInCollection(db.collection("walls").doc(wallId));
}
