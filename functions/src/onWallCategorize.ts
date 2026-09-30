import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {DEFAULT_CATEGORY, DEFAULT_COLLECTION, detectLabels, mapLabelsToCategory} from "./wallCategory";
import {db, REGION} from "./common";

export const onWallCategorize = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: REGION,
    timeoutSeconds: 120,
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

    if (data.category && data.category !== DEFAULT_CATEGORY) {
      logger.info("onWallCategorize: category already set", {wallId, category: data.category});
      return;
    }

    try {
      const labels = await detectLabels(wallpaperUrl);

      if (labels.length === 0) {
        logger.warn("onWallCategorize: no labels detected from Vision API", {wallId});
        await updateWallpaperCategory(wallId, DEFAULT_CATEGORY, [DEFAULT_COLLECTION]);
        return;
      }

      const category = mapLabelsToCategory(labels);
      const collections = [DEFAULT_COLLECTION];

      logger.info("onWallCategorize: categorized wallpaper", {
        wallId,
        labels: labels.slice(0, 5),
        category,
      });

      await updateWallpaperCategory(wallId, category, collections);
    } catch (error) {
      logger.error("onWallCategorize: failed to categorize wallpaper", {
        wallId,
        error: error instanceof Error ? error.message : String(error),
      });
      await updateWallpaperCategory(wallId, DEFAULT_CATEGORY, [DEFAULT_COLLECTION]);
    }
  },
);

async function updateWallpaperCategory(
  wallId: string,
  category: string,
  collections: string[],
): Promise<void> {
  await db.collection("walls").doc(wallId).update({
    category: category,
    collections: collections,
    categorizedAt: admin.firestore.FieldValue.serverTimestamp(),
    aiCategorized: true,
  });

  logger.info("Wallpaper category updated", {wallId, category, collections});
}
