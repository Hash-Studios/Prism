import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {DEFAULT_CATEGORY, detectLabelsInImage, mapLabelsToCategory} from "./wallCategory";
import {REGION} from "./common";
import {fetchImageBuffer, hasPaletteColors, trustedWallImageUrl, wallColorsFor} from "./wallColors";
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
    maxInstances: 2,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data || !event.data) {
      return;
    }

    const wallId = event.params.wallId;
    const current = event.data.ref ? (await event.data.ref.get()).data() ?? data : data;
    const trustedOriginal = trustedWallImageUrl(current, "original");
    const trustedThumb = trustedWallImageUrl(current, "thumb");
    const wallpaperUrl = trustedOriginal ?? trustedThumb ?? "";

    if (!wallpaperUrl) {
      logger.warn("onWallCategorize: no wallpaper URL found", {wallId});
      return;
    }

    const trustedWall = {
      ...current,
      wallpaper_url: trustedOriginal ?? "",
      wallpaper_thumb: trustedThumb ?? "",
    };
    const [colors, depth, spatial, labels] = await Promise.all([
      hasPaletteColors(current.colors) ? undefined : wallColorsFor(wallId, trustedWall),
      current.depth == null ? wallDepthFor(wallId, {url: wallpaperUrl}) : undefined,
      current.spatial == null ? wallSpatialFor(wallId, {url: trustedThumb || wallpaperUrl}) : undefined,
      detectLabelsIfAble(wallId, wallpaperUrl),
    ]);
    await writeWallCategorization({wallId, initial: event.data,
      category: labels?.length ? mapLabelsToCategory(labels) : DEFAULT_CATEGORY, colors, depth, spatial, labels});
  },
);

async function detectLabelsIfAble(wallId: string, wallpaperUrl: string): Promise<string[] | undefined> {
  try {
    return await detectLabelsInImage(await fetchImageBuffer(wallpaperUrl));
  } catch (error) {
    logger.error("onWallCategorize: failed to detect labels", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}
