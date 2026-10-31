import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "../common";
import {PermanentOwnedAssetError, signOriginalDelivery} from "../ownedAssetDelivery";
import {r2Secrets} from "../r2Storage";
import {isStudioWall} from "./isStudioWall";
import {STUDIO_ACCOUNT} from "./account";
import {parseStudioSource} from "./assetSource";
import {STUDIO_SERIES} from "./series";

// The bot posts the first Studio wall approved each day to the Telegram channel: the image and a caption.
export const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
export const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");

const MAX_HASHTAGS = 5;
class PermanentStudioPostError extends Error {}

function responseError(message: string, status: number): Error {
  return status >= 400 && status < 500 && status !== 408 && status !== 429 ?
    new PermanentStudioPostError(`${message}: ${status}`) : new Error(`${message}: ${status}`);
}

/** "A winding road through ... trees.", the collection line and hashtags. Reads only the wall doc. */
export function studioPostCaption(wall: admin.firestore.DocumentData): string {
  const series = STUDIO_SERIES.find((s) => s.id === wall.seriesId);
  const prompt = typeof wall.aiPrompt === "string" ? wall.aiPrompt : "";
  const subject = series?.subjects.find((s) => prompt.startsWith(`${s.prompt}, `));
  const scene = (series?.duoReveal ? subject?.title : subject?.prompt) ??
    prompt.split(/[,.]/)[0].trim();
  const sentence = scene ? `${scene[0].toUpperCase()}${scene.slice(1)}.` : "";
  const collection = series ? `Part of the ${series.name} collection by @PrismWallpapers.` : "By @PrismWallpapers.";
  const tags = ["wallpaper", ...(Array.isArray(wall.tags) ? wall.tags.filter((tag) => typeof tag === "string") : [])]
    .map((tag) => tag.replace(/[^a-z0-9_]/gi, "").toLowerCase())
    .filter((tag, i, all) => tag !== "" && all.indexOf(tag) === i)
    .slice(0, MAX_HASHTAGS);
  // ponytail: no 1024-character caption cap; catalog scenes and tags keep captions near 250 characters.
  return [sentence, `${collection} Available now in the Prism Wallpapers app.`, tags.map((t) => `#${t}`).join(" ")]
    .filter(Boolean).join("\n\n");
}

/** Telegram may have posted the photo, so the day must stay claimed to avoid a second post. */
const uncertain = (message: string) => Object.assign(new Error(message), {uncertain: true});

/** The day in India, where the walls are reviewed, for example "2026-10-17". */
export function postDay(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Kolkata"}).format(now);
}

/**
 * Where the bot reads the image. A converted wall has an empty `wallpaper_url`, so the bot uses a short-lived signed
 * URL of the private original. An unconverted wall still has its public worker URL.
 */
export async function studioImageUrl(wallId: string, wall: admin.firestore.DocumentData): Promise<string> {
  if (wall.originalProtected === true) {
    try {
      return (await signOriginalDelivery(wallId)).url;
    } catch (error) {
      if (error instanceof Error && ["Invalid wall identity", "Owned wall unavailable"].includes(error.message)) {
        throw new PermanentStudioPostError("Studio wall has no valid original delivery.");
      }
      throw error;
    }
  }
  const url = str(wall.wallpaper_url);
  if (!url) throw new PermanentStudioPostError("Studio wall has no readable image.");
  return url;
}

/** Uploads the image as a photo with the caption. An upload allows 10 MB; a photo URL allows only 5 MB. */
export async function sendStudioPost(token: string, chatId: string, wall: admin.firestore.DocumentData,
  imageUrl = str(wall.wallpaper_url)): Promise<void> {
  const signal = AbortSignal.timeout(60_000);
  let image: Response;
  let imageBytes: ArrayBuffer;
  try {
    image = await fetch(imageUrl, {signal});
    imageBytes = await image.arrayBuffer();
  } catch {
    throw new Error("Image download failed.");
  }
  if (!image.ok) throw responseError("Image download failed", image.status);
  const form = new FormData();
  form.set("chat_id", chatId);
  form.set("caption", studioPostCaption(wall));
  form.set("photo", new Blob([imageBytes], {type: "image/jpeg"}), "wall.jpg");
  let res: Response;
  try {
    res = await fetch(`https://api.telegram.org/bot${token}/sendPhoto`, {method: "POST", body: form, signal});
  } catch {
    throw uncertain("Telegram sendPhoto request failed.");
  }
  if (!res.ok) throw responseError("Telegram sendPhoto failed", res.status);
  let result: unknown;
  try {
    result = await res.json();
  } catch {
    throw uncertain("Telegram sendPhoto returned an invalid response.");
  }
  if (typeof result !== "object" || result === null || !("ok" in result) || result.ok !== true) {
    if (result && typeof result === "object" && "error_code" in result && typeof result.error_code === "number") {
      throw responseError("Telegram sendPhoto was not accepted", result.error_code);
    }
    throw new Error("Telegram sendPhoto was not accepted.");
  }
}

/**
 * Posts the wall only when no other wall has the day. The claim doc `studioTelegramPosts/{day}` makes this atomic,
 * so of many walls approved at once only the first one posts. A failed send frees the day for the next approval.
 */
export async function postFirstStudioWallOfDay(
  wallId: string,
  wall: admin.firestore.DocumentData,
  token: string,
  chatId: string,
  now = new Date(),
): Promise<boolean> {
  const claim = db.collection("studioTelegramPosts").doc(postDay(now));
  let writeTime: admin.firestore.Timestamp;
  try {
    ({writeTime} = await claim.create({wallId, claimedAt: admin.firestore.FieldValue.serverTimestamp()}));
  } catch (err) {
    if ((err as {code?: number}).code === 6) return false; // ALREADY_EXISTS: today's post is taken.
    throw err;
  }
  try {
    await sendStudioPost(token, chatId, wall, await studioImageUrl(wallId, wall));
  } catch (sendError) {
    if ((sendError as {uncertain?: boolean}).uncertain) throw sendError;
    try {
      await claim.delete({lastUpdateTime: writeTime});
    } catch (cleanupError) {
      const code = (cleanupError as {code?: number}).code;
      if (code !== 5 && code !== 9) throw new Error("Telegram post failed and claim cleanup failed.");
    }
    throw sendError;
  }
  return true;
}

/** When a Studio wall is approved, it becomes the day's Telegram post if it is the first one that day. */
export const onStudioWallApproved = onDocumentUpdated(
  {document: "walls/{wallId}", region: REGION, timeoutSeconds: 300, retry: true,
    secrets: [telegramBotToken, telegramChatId, ...r2Secrets]},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after || before.review === true || after.review !== true) return;
    const wallId = event.params.wallId;
    try {
      const current = await db.collection("walls").doc(wallId).get();
      const wall = current.data();
      if (!wall || !current.createTime || !event.data?.after.createTime ||
          !current.createTime.isEqual(event.data.after.createTime) ||
          wall.review !== true || wall.email !== STUDIO_ACCOUNT.email ||
          (wall.originalProtected !== true && !parseStudioSource(wall)) ||
          !(await isStudioWall(wallId, wall))) return;
      const posted = await postFirstStudioWallOfDay(
        wallId,
        wall,
        telegramBotToken.value(),
        telegramChatId.value(),
        new Date(event.time),
      );
      logger.info(posted ? "onStudioWallApproved: posted." : "onStudioWallApproved: today's post is taken.", {wallId});
    } catch (err) {
      logger.error("onStudioWallApproved: post failed.", {wallId});
      if (!(err as {uncertain?: boolean}).uncertain && !(err instanceof PermanentStudioPostError) &&
          !(err instanceof PermanentOwnedAssetError)) throw new Error("Studio Telegram post failed; retry approval.");
    }
  },
);
