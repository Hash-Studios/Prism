import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {DEFAULT_CATEGORY, DEFAULT_COLLECTION, detectLabels, mapLabelsToCategory} from "./wallCategory";
import {db, REGION} from "./common";
import {hasPaletteColors, wallColorsFor} from "./wallColors";
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

    const [colors, depth] = await Promise.all([
      hasPaletteColors(data.colors) ? undefined : wallColorsFor(wallId, data),
      data.depth == null ? wallDepthFor(wallId, {url: wallpaperUrl}) : undefined,
    ]);
    const extra: ImageFields = colors ? {colors} : {};
    await writeDepthIfAbsent(wallId, depth);

    if (data.category && data.category !== DEFAULT_CATEGORY) {
      logger.info("onWallCategorize: category already set", {wallId, category: data.category});
      if (Object.keys(extra).length > 0) {
        await db.collection("walls").doc(wallId).update(extra);
      }
      return;
    }

    try {
      const labels = await detectLabels(wallpaperUrl);

      if (labels.length === 0) {
        logger.warn("onWallCategorize: no labels detected from Vision API", {wallId});
        await updateWallpaperCategory(wallId, DEFAULT_CATEGORY, [DEFAULT_COLLECTION], extra);
        return;
      }

      const category = mapLabelsToCategory(labels);
      const collections = [DEFAULT_COLLECTION];

      logger.info("onWallCategorize: categorized wallpaper", {
        wallId,
        labels: labels.slice(0, 5),
        category,
      });

      await updateWallpaperCategory(wallId, category, collections, extra);
    } catch (error) {
      logger.error("onWallCategorize: failed to categorize wallpaper", {
        wallId,
        error: error instanceof Error ? error.message : String(error),
      });
      await updateWallpaperCategory(wallId, DEFAULT_CATEGORY, [DEFAULT_COLLECTION], extra);
    }
  },
);

type ImageFields = {colors?: string[]};

/**
 * The check runs for up to a minute, and an admin can set `depth` meanwhile. The transaction writes only when the
 * wall still has none. A failure is logged, so it cannot fail the colour or category write.
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
}
