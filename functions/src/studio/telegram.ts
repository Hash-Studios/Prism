import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "../common";
import {isStudioWall} from "./process";
import {STUDIO_SERIES} from "./series";

export const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
export const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");

const MAX_HASHTAGS = 5;

/** "A winding road through ... trees.", the collection line and hashtags. Reads only the wall doc. */
export function studioPostCaption(wall: admin.firestore.DocumentData): string {
  const series = STUDIO_SERIES.find((s) => s.id === wall.seriesId);
  const prompt = typeof wall.aiPrompt === "string" ? wall.aiPrompt : "";
  // The prompt is "<subject>, <palette>. <style> <composition>". The subject alone is the short scene.
  const scene = series?.subjects.find((s) => prompt.startsWith(`${s.prompt}, `))?.prompt ??
    prompt.split(/[,.]/)[0].trim();
  const sentence = scene ? `${scene[0].toUpperCase()}${scene.slice(1)}.` : "";
  const collection = series ? `Part of the ${series.name} collection by @PrismWallpapers.` : "By @PrismWallpapers.";
  const tags = ["wallpaper", ...(Array.isArray(wall.tags) ? wall.tags.filter((tag) => typeof tag === "string") : [])]
    .map((tag) => tag.replace(/[^a-z0-9_]/gi, "").toLowerCase())
    .filter((tag, i, all) => tag !== "" && all.indexOf(tag) === i);
  const collectionLine = `${collection} Available now in the Prism Wallpapers app.`;
  const hashtagLines: string[] = [];
  for (const tag of tags) {
    if (hashtagLines.length >= MAX_HASHTAGS) break;
    const candidate = [...hashtagLines, `#${tag}`].join(" ");
    const suffix = [collectionLine, candidate].join("\n\n");
    if (suffix.length <= 1024) hashtagLines.push(`#${tag}`);
  }
  const suffix = [collectionLine, hashtagLines.join(" ")].filter(Boolean).join("\n\n");
  const sceneBudget = Math.max(0, 1024 - suffix.length - (suffix ? 2 : 0));
  const boundedSentence = sentence.length <= sceneBudget ? sentence : truncateUtf16(sentence, sceneBudget);
  return [boundedSentence, suffix].filter(Boolean).join("\n\n");
}

function truncateUtf16(value: string, maxLength: number): string {
  let truncated = value.slice(0, maxLength);
  const lastCodeUnit = truncated.charCodeAt(truncated.length - 1);
  if (lastCodeUnit >= 0xd800 && lastCodeUnit <= 0xdbff) truncated = truncated.slice(0, -1);
  return truncated;
}

/** The day in India, where the walls are reviewed, for example "2026-10-17". */
export function postDay(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Kolkata"}).format(now);
}

/** An upload allows 10 MB; a photo URL allows only 5 MB. */
export async function sendStudioPost(token: string, chatId: string, wall: admin.firestore.DocumentData): Promise<void> {
  const signal = AbortSignal.timeout(60_000);
  let image: Response;
  let imageBytes: ArrayBuffer;
  try {
    image = await fetch(str(wall.wallpaper_url), {signal});
    imageBytes = await image.arrayBuffer();
  } catch {
    throw new Error("Image download failed.");
  }
  if (!image.ok) throw new Error(`Image download failed: ${image.status}`);
  const form = new FormData();
  form.set("chat_id", chatId);
  form.set("caption", studioPostCaption(wall));
  form.set("photo", new Blob([imageBytes], {type: "image/jpeg"}), "wall.jpg");
  let res: Response;
  try {
    res = await fetch(`https://api.telegram.org/bot${token}/sendPhoto`, {method: "POST", body: form, signal});
  } catch {
    throw new Error("Telegram sendPhoto request failed.");
  }
  if (!res.ok) throw new Error(`Telegram sendPhoto failed: ${res.status}`);
  let result: unknown;
  try {
    result = await res.json();
  } catch {
    throw new Error("Telegram sendPhoto returned an invalid response.");
  }
  if (typeof result !== "object" || result === null || !("ok" in result) || result.ok !== true) {
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
    await sendStudioPost(token, chatId, wall);
  } catch (sendError) {
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

export const onStudioWallApproved = onDocumentUpdated(
  {document: "walls/{wallId}", region: REGION, timeoutSeconds: 300, secrets: [telegramBotToken, telegramChatId]},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after || before.review === true || after.review !== true) return;
    const wallId = event.params.wallId;
    try {
      const current = await db.collection("walls").doc(wallId).get();
      const wall = current.data();
      if (!wall || wall.review !== true || !(await isStudioWall(wallId, wall))) return;
      const posted = await postFirstStudioWallOfDay(
        wallId,
        wall,
        telegramBotToken.value(),
        telegramChatId.value(),
        new Date(event.time),
      );
      logger.info(posted ? "onStudioWallApproved: posted." : "onStudioWallApproved: today's post is taken.", {wallId});
    } catch {
      logger.error("onStudioWallApproved: post failed.", {wallId});
    }
  },
);
