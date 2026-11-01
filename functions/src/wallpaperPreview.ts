import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onRequest} from "firebase-functions/v2/https";
import {CALLABLE_REGIONS, db} from "./common";
import {getOwnedWallDelivery, verifyStoredUpload} from "./ownedAssetDelivery";
import {R2Storage, r2Secrets} from "./r2Storage";
import {readyDesktopCompanion} from "./studio/desktop";
import {isWotdEligible} from "./wallEligibility";
import {webCatalogDeps} from "./webCatalog";

/** A display derivative, never the original bytes or a signed original URL. */
export async function renderWallpaperPreview(bytes: Buffer): Promise<Buffer> {
  const {default: sharp} = await import("sharp");
  return sharp(bytes, {limitInputPixels: 100000000, animated: false})
    .rotate().resize({width: 2560, height: 2560, fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 90, mozjpeg: true}).toBuffer();
}

/** The web renditions of a desktop companion. The 2560 px originals stay in the app. */
export const DESKTOP_WEB_SIZES = {"desktop": {width: 1920, height: 1200}, "desktop-16x9": {width: 1920, height: 1080}} as const;
export type PreviewVariant = "phone" | keyof typeof DESKTOP_WEB_SIZES;

export async function renderDesktopWebRendition(bytes: Buffer, variant: keyof typeof DESKTOP_WEB_SIZES): Promise<Buffer> {
  const {default: sharp} = await import("sharp");
  const {width, height} = DESKTOP_WEB_SIZES[variant];
  return sharp(bytes, {limitInputPixels: 100000000, animated: false})
    .resize({width, height, fit: "inside", withoutEnlargement: true}).jpeg({quality: 85, mozjpeg: true}).toBuffer();
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

export async function loadWallpaperPreview(id: string, thumbnail: string, variant: PreviewVariant = "phone",
  version = ""): Promise<Buffer> {
  if (!/^[A-Za-z0-9_-]{1,200}$/.test(id) || !thumbnail || thumbnail.length > 2048) {
    throw new Error("Invalid preview identity");
  }
  const rows = await db.collection("walls").where("id", "==", id).limit(2).get();
  const wall = rows.docs[0]?.data();
  if (rows.size !== 1 || wall?.review !== true || wall.wallpaper_thumb !== thumbnail ||
      wall.is_streak_exclusive === true || wall.dropReserved === true || wall.dropWeek) {
    throw new Error("Preview unavailable");
  }
  if (variant !== "phone") return loadDesktopWebRendition(id, wall, variant, version);
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

/**
 * Desktop renditions are for the web only, so they follow the web gate: a premium-collection wall gets none, and a
 * failed Remote Config read refuses every request.
 */
async function loadDesktopWebRendition(id: string, wall: FirebaseFirestore.DocumentData,
  variant: keyof typeof DESKTOP_WEB_SIZES, version: string): Promise<Buffer> {
  if (!isWotdEligible(wall, await webCatalogDeps.premium())) throw new Error("Preview unavailable");
  const {original, wide, variant: published} = await readyDesktopCompanion(id, wall);
  if (published.v !== version) throw new Error("Preview unavailable");
  const source = variant === "desktop" ? original : wide;
  const storage = new R2Storage();
  const bytes = await storage.get("private", source.object);
  if (digest(bytes) !== source.sha256) throw new Error("Preview source mismatch");
  const cacheObject = `display-previews/${id}/${variant}-${source.sha256}.jpg`;
  const cached = await storedPreview(storage, cacheObject);
  if (cached) return cached;
  const rendition = await renderDesktopWebRendition(bytes, variant);
  try {
    await storage.put("private", cacheObject, rendition, {sha256: digest(rendition)}, "image/jpeg");
  } catch (error) {
    logger.warn("wallpaperPreview: could not store the desktop rendition", {id, error: String(error)});
  }
  return rendition;
}

export const wallpaperPreview = onRequest({region: CALLABLE_REGIONS, secrets: r2Secrets,
  memory: "1GiB", cpu: 1, concurrency: 8, maxInstances: 10, timeoutSeconds: 60}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  if (req.method !== "GET") {
    res.set("Allow", "GET").status(405).send("Method not allowed");
    return;
  }
  const {id, thumb, variant = "phone", v = ""} = req.query;
  if (typeof id !== "string" || typeof thumb !== "string" || typeof variant !== "string" || typeof v !== "string" ||
      !["phone", ...Object.keys(DESKTOP_WEB_SIZES)].includes(variant) ||
      (variant === "phone" ? v !== "" : !/^[a-f0-9]{16}$/.test(v)) ||
      Object.keys(req.query).some((key) => !["id", "thumb", "variant", "v"].includes(key))) {
    res.status(400).send("Invalid preview request");
    return;
  }
  try {
    const bytes = await loadWallpaperPreview(id, thumb, variant as PreviewVariant, v);
    // The bytes for one id and thumb never change, but a wall can be withdrawn, so only the device may keep them.
    res.set("Cache-Control", "private, max-age=31536000, immutable").type("jpeg").send(bytes);
  } catch {
    // The app keeps its thumbnail when a wall is missing, withheld, or storage is unavailable.
    res.status(404).send("Preview unavailable");
  }
});
