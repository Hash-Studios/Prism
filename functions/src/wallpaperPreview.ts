import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onRequest} from "firebase-functions/v2/https";
import {CALLABLE_REGIONS, db} from "./common";
import {getOwnedWallDelivery, verifyStoredUpload} from "./ownedAssetDelivery";
import {R2Storage, r2Secrets} from "./r2Storage";

/** A display derivative, never the original bytes or a signed original URL. */
export async function renderWallpaperPreview(bytes: Buffer): Promise<Buffer> {
  const {default: sharp} = await import("sharp");
  return sharp(bytes, {limitInputPixels: 100000000, animated: false})
    .rotate().resize({width: 2560, height: 2560, fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 90, mozjpeg: true}).toBuffer();
}

const digest = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

/** Where a wall's rendered preview is kept: beside the originals, private, one per wall and original digest. */
export const previewCacheObject = (id: string, originalSha256: string) => `display-previews/${id}/${originalSha256}.jpg`;

/** The stored preview, or null when it is missing or its bytes do not match the digest it was stored with. */
async function storedPreview(storage: R2Storage, object: string): Promise<Buffer | null> {
  const [head, bytes] = await Promise.all([storage.head("private", object).catch(() => null),
    storage.get("private", object).catch(() => null)]);
  if (!head || !bytes || head.sha256 !== digest(bytes)) return null;
  return bytes;
}

export async function loadWallpaperPreview(id: string, thumbnail: string): Promise<Buffer> {
  if (!/^[A-Za-z0-9_-]{1,200}$/.test(id) || !thumbnail || thumbnail.length > 2048) {
    throw new Error("Invalid preview identity");
  }
  const rows = await db.collection("walls").where("id", "==", id).limit(2).get();
  const wall = rows.docs[0]?.data();
  if (rows.size !== 1 || wall?.review !== true || wall.wallpaper_thumb !== thumbnail ||
      wall.is_streak_exclusive === true || wall.dropReserved === true || wall.dropWeek) {
    throw new Error("Preview unavailable");
  }
  const {original, thumb} = await getOwnedWallDelivery(id);
  if (original.previewObjectId || !thumb.previewObjectId || original.objectId === thumb.objectId) {
    throw new Error("Invalid preview source");
  }
  await verifyStoredUpload(original);
  const storage = new R2Storage();
  const bytes = await storage.get("private", original.object);
  if (digest(bytes) !== original.sha256) {
    throw new Error("Preview source mismatch");
  }
  const cacheObject = previewCacheObject(id, original.sha256);
  const cached = await storedPreview(storage, cacheObject);
  if (cached) return cached;
  const preview = await renderWallpaperPreview(bytes);
  try {
    await storage.put("private", cacheObject, preview, {sha256: digest(preview)}, "image/jpeg");
  } catch (error) {
    logger.warn("wallpaperPreview: could not store the rendered preview", {id, error: String(error)});
  }
  return preview;
}

export const wallpaperPreview = onRequest({region: CALLABLE_REGIONS, secrets: r2Secrets,
  memory: "1GiB", cpu: 1, concurrency: 8, maxInstances: 10, timeoutSeconds: 60}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  if (req.method !== "GET") {
    res.set("Allow", "GET").status(405).send("Method not allowed");
    return;
  }
  const {id, thumb} = req.query;
  if (typeof id !== "string" || typeof thumb !== "string" ||
      Object.keys(req.query).some((key) => key !== "id" && key !== "thumb")) {
    res.status(400).send("Invalid preview request");
    return;
  }
  try {
    const bytes = await loadWallpaperPreview(id, thumb);
    // The bytes for one id and thumb never change, but a wall can be withdrawn, so only the device may keep them.
    res.set("Cache-Control", "private, max-age=31536000, immutable").type("jpeg").send(bytes);
  } catch {
    // The app keeps its thumbnail when a wall is missing, withheld, or storage is unavailable.
    res.status(404).send("Preview unavailable");
  }
});
