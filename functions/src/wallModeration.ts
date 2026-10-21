import * as admin from "firebase-admin";
import type {ImageAnnotatorClient} from "@google-cloud/vision";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION, str} from "./common";
import {
  duplicateCheck,
  imageSignature,
  type KnownSignature,
  STUDIO_LOGO_MIN_SCORE,
  STUDIO_VISION_LONG_EDGE,
  visionCheck,
  type VisionResult,
} from "./studio/gates";
import {isStudioWall} from "./studio/isStudioWall";
import {fetchImageBuffer} from "./wallColors";

/** Flags are signals for the reviewer. Nothing is rejected on them. */
export type ModerationFlag = "duplicate" | "web_match" | "text" | "logo" | "unsafe";

export interface Moderation {
  v: 1;
  flags: ModerationFlag[];
  duplicate: {wallId: string; similarity: number; thumb: string} | null;
  web: Array<{url: string; host: string}>;
  words: string[];
  logos: string[];
  unsafe: string[];
}

type WebImages = Array<{url?: string | null}> | null;

/** The part of a Vision WEB_DETECTION response that moderation reads. */
export interface WebDetection {
  fullMatchingImages?: WebImages;
  pagesWithMatchingImages?: Array<{url?: string | null; fullMatchingImages?: WebImages}> | null;
}

export type ModerationVisionResult = VisionResult & {webDetection?: WebDetection | null};

/** Sends a JPEG to Vision. Throws when the call fails. */
export type ModerationAnnotate = (jpeg: Buffer) => Promise<ModerationVisionResult>;

export interface ModerationDeps {
  fetchImage: (url: string) => Promise<Buffer>;
  annotate: ModerationAnnotate;
}

const MAX_WEB = 5;
const MAX_WORDS = 10;
const MAX_LOGOS = 5;
const OWN_HOSTS = ["raw.githubusercontent.com", "githubusercontent.com", "prismwalls.com"];
const UNSAFE_PREFIX = "unsafe_";

function webMatches(web: WebDetection | null | undefined): Moderation["web"] {
  const pages = (web?.pagesWithMatchingImages ?? []).filter((page) => (page.fullMatchingImages ?? []).length > 0);
  const urls = (pages.length > 0 ? pages : web?.fullMatchingImages ?? []).map((entry) => str(entry.url));
  const seen = new Set<string>();
  const matches: Moderation["web"] = [];
  for (const url of urls) {
    let host: string;
    try {
      host = new URL(url).hostname.toLowerCase().replace(/^www\./, "");
    } catch {
      continue;
    }
    if (seen.has(url) || OWN_HOSTS.some((own) => host === own || host.endsWith(`.${own}`))) continue;
    seen.add(url);
    matches.push({url, host});
  }
  return matches.slice(0, MAX_WEB);
}

/** The reviewer signals from a duplicate hit and a Vision result. Pure: no Firestore, no network. */
export function buildModeration(
  duplicate: Moderation["duplicate"],
  vision: ModerationVisionResult,
): Moderation {
  const check = visionCheck(vision);
  const web = webMatches(vision.webDetection);
  const details = check.details as {words: string[]; logos: Array<{description: string; score: number}>};
  const text = check.reasons.includes("text");
  const logos = details.logos
    .filter((logo) => logo.score >= STUDIO_LOGO_MIN_SCORE && logo.description !== "")
    .map((logo) => logo.description)
    .slice(0, MAX_LOGOS);
  const unsafe = check.reasons.filter((r) => r.startsWith(UNSAFE_PREFIX)).map((r) => r.slice(UNSAFE_PREFIX.length));
  const flags: ModerationFlag[] = [
    ...(duplicate ? ["duplicate" as const] : []),
    ...(web.length > 0 ? ["web_match" as const] : []),
    ...(text ? ["text" as const] : []),
    ...(logos.length > 0 ? ["logo" as const] : []),
    ...(unsafe.length > 0 ? ["unsafe" as const] : []),
  ];
  return {
    v: 1,
    flags,
    duplicate,
    web,
    words: text ? details.words.slice(0, MAX_WORDS) : [],
    logos,
    unsafe,
  };
}

let visionClient: ImageAnnotatorClient | undefined;

const annotateForModeration: ModerationAnnotate = async (jpeg) => {
  const {ImageAnnotatorClient} = await import("@google-cloud/vision");
  visionClient ??= new ImageAnnotatorClient();
  const [result] = await visionClient.annotateImage({
    image: {content: jpeg},
    features: [
      {type: "SAFE_SEARCH_DETECTION"},
      {type: "TEXT_DETECTION"},
      {type: "LOGO_DETECTION", maxResults: 5},
      {type: "WEB_DETECTION", maxResults: 10},
    ],
  });
  if (result.error?.code) throw new Error(`Vision error ${result.error.code}: ${result.error.message ?? ""}`);
  return result;
};

const defaultDeps: ModerationDeps = {fetchImage: (url) => fetchImageBuffer(url), annotate: annotateForModeration};

/** The first of the wall's image URLs that downloads and decodes. */
export async function readWallImage(
  wallId: string,
  data: admin.firestore.DocumentData,
  fetchImage: ModerationDeps["fetchImage"],
): Promise<{bytes: Buffer; signature: string} | null> {
  const urls = [data.wallpaper_url, data.wallpaper_thumb]
    .map(str)
    .filter((url, index, all) => url !== "" && all.indexOf(url) === index);
  for (const url of urls) {
    try {
      const bytes = await fetchImage(url);
      return {bytes, signature: await imageSignature(bytes)};
    } catch (error) {
      logger.warn("onWallModerate: could not read image", {
        wallId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
  return null;
}

async function loadKnownSignatures(wallId: string): Promise<KnownSignature[]> {
  const [walls, studio] = await Promise.all([
    db.collection("wallSignatures").select("signature", "wallId").get(),
    db.collection("studioSignatures").select("signature", "wallId").get(),
  ]);
  return [...walls.docs, ...studio.docs]
    .map((doc) => ({signature: str(doc.data().signature), wallId: str(doc.data().wallId)}))
    .filter((known) => known.wallId !== "" && known.wallId !== wallId);
}

async function duplicateOf(signature: string, wallId: string): Promise<Moderation["duplicate"]> {
  const check = duplicateCheck(signature, await loadKnownSignatures(wallId));
  const matched = check.details.nearestWallId;
  if (!check.reasons.includes("duplicate") || typeof matched !== "string") return null;
  let thumb = "";
  try {
    thumb = str((await db.collection("walls").doc(matched).get()).data()?.wallpaper_thumb);
  } catch (error) {
    logger.warn("onWallModerate: could not read the matched wall", {
      wallId,
      matched,
      error: error instanceof Error ? error.message : String(error),
    });
  }
  return {wallId: matched, similarity: check.details.nearestSimilarity as number, thumb};
}

async function visionJpeg(bytes: Buffer): Promise<Buffer> {
  const sharp = (await import("sharp")).default;
  return sharp(bytes)
    .resize({width: STUDIO_VISION_LONG_EDGE, height: STUDIO_VISION_LONG_EDGE, fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 85})
    .toBuffer();
}

/**
 * Attaches copyright and duplicate signals to a new community wall for the reviewer. It never rejects or hides a wall.
 * A wall with no `moderation` field was not checked.
 */
export async function moderateWall(
  wallId: string,
  data: admin.firestore.DocumentData,
  deps: ModerationDeps = defaultDeps,
): Promise<void> {
  if (data.moderation != null || await isStudioWall(wallId, data)) return;

  const image = await readWallImage(wallId, data, deps.fetchImage);
  if (!image) {
    logger.warn("onWallModerate: no readable image", {wallId});
    return;
  }

  const duplicate = await duplicateOf(image.signature, wallId);
  await db.collection("wallSignatures").doc(wallId).set({
    signature: image.signature,
    wallId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let moderation: Moderation;
  try {
    moderation = buildModeration(duplicate, await deps.annotate(await visionJpeg(image.bytes)));
  } catch (error) {
    logger.error("onWallModerate: Vision check failed", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
    return;
  }

  try {
    await db.collection("walls").doc(wallId).update({
      moderation: {...moderation, checkedAt: admin.firestore.FieldValue.serverTimestamp()},
    });
  } catch (error) {
    if ((error as {code?: unknown}).code !== 5) throw error;
    logger.info("onWallModerate: wall was deleted before the check ended", {wallId});
    return;
  }
  logger.info("onWallModerate: checked wall", {wallId, flags: moderation.flags});
}

export const onWallModerate = onDocumentCreated(
  {document: "walls/{wallId}", region: REGION, timeoutSeconds: 120, memory: "512MiB", concurrency: 1},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    await moderateWall(event.params.wallId, data);
  },
);
