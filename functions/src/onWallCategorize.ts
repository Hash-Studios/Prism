import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {DEFAULT_CATEGORY, detectLabels, mapLabelsToCategory} from "./wallCategory";
import {REGION} from "./common";
import {hasPaletteColors, wallColorsFor} from "./wallColors";
import {falKey, wallDepthFor} from "./wallDepth";
import {wallSpatialFor} from "./wallSpatial";
import {r2Secrets} from "./r2Storage";
import {writeWallCategorization} from "./wallCategorizationWrite";

export const onWallCategorize = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: REGION,
    timeoutSeconds: 120,
    concurrency: 1,
    secrets: [falKey, ...r2Secrets],
    retry: true,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data || !event.data) {
      return;
    }

    const wallId = event.params.wallId;
    const wallpaperUrl = (data.wallpaper_url || data.wallpaper_thumb || "").toString().trim();

    if (!wallpaperUrl) {
      logger.warn("onWallCategorize: no wallpaper URL found", {wallId});
      return;
    }

    const [colors, depth, spatial, labels] = await Promise.all([
      hasPaletteColors(data.colors) ? undefined : wallColorsFor(wallId, data),
      data.depth == null ? wallDepthFor(wallId, {url: wallpaperUrl}) : undefined,
      data.spatial == null ? wallSpatialFor(wallId, {url: wallpaperUrl}) : undefined,
      detectLabelsIfAble(wallId, wallpaperUrl),
    ]);
    await writeWallCategorization({wallId, initial: event.data,
      category: labels?.length ? mapLabelsToCategory(labels) : DEFAULT_CATEGORY, colors, depth, spatial, labels});
  },
);

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
