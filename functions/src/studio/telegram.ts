import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "../common";
import {isStudioWall} from "./process";
import {STUDIO_SERIES} from "./series";

// The bot posts the first Studio wall approved each day to the Telegram channel: the image and a caption.
export const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
export const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");

const MAX_HASHTAGS = 5;

/** "A winding road through ... trees.", the collection line and hashtags. Reads only the wall doc. */
export function studioPostCaption(wall: admin.firestore.DocumentData): string {
  const series = STUDIO_SERIES.find((s) => s.id === wall.seriesId);
  const prompt = str(wall.aiPrompt);
  // The prompt is "<subject>, <palette>. <style> <composition>". The subject alone is the short scene.
  const scene = series?.subjects.find((s) => prompt.startsWith(`${s.prompt}, `))?.prompt ??
    prompt.split(/[,.]/)[0].trim();
  const sentence = scene ? `${scene[0].toUpperCase()}${scene.slice(1)}.` : "";
  const collection = series ? `Part of the ${series.name} collection by @PrismWallpapers.` : "By @PrismWallpapers.";
  const tags = ["wallpaper", ...(Array.isArray(wall.tags) ? wall.tags : [])]
    .map((tag) => String(tag).replace(/[^a-z0-9_]/gi, "").toLowerCase())
    .filter((tag, i, all) => tag !== "" && all.indexOf(tag) === i)
    .slice(0, MAX_HASHTAGS);
  return [sentence, `${collection} Available now in the Prism Wallpapers app.`, tags.map((t) => `#${t}`).join(" ")]
    .filter(Boolean).join("\n\n");
}

/** The day in India, where the walls are reviewed, for example "2026-10-17". */
export function postDay(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Kolkata"}).format(now);
}

/** Uploads the image as a photo with the caption. An upload allows 10 MB; a photo URL allows only 5 MB. */
export async function sendStudioPost(token: string, chatId: string, wall: admin.firestore.DocumentData): Promise<void> {
  const image = await fetch(str(wall.wallpaper_url));
  if (!image.ok) throw new Error(`Image download failed: ${image.status}`);
  const form = new FormData();
  form.set("chat_id", chatId);
  form.set("caption", studioPostCaption(wall));
  form.set("photo", new Blob([await image.arrayBuffer()], {type: "image/jpeg"}), "wall.jpg");
  const res = await fetch(`https://api.telegram.org/bot${token}/sendPhoto`, {method: "POST", body: form});
  if (!res.ok) throw new Error(`Telegram sendPhoto failed: ${res.status} ${await res.text()}`);
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
  try {
    await claim.create({wallId, claimedAt: admin.firestore.FieldValue.serverTimestamp()});
  } catch (err) {
    if ((err as {code?: number}).code === 6) return false; // ALREADY_EXISTS: today's post is taken.
    throw err;
  }
  try {
    await sendStudioPost(token, chatId, wall);
  } catch (err) {
    await claim.delete();
    throw err;
  }
  return true;
}

/** When a Studio wall is approved, it becomes the day's Telegram post if it is the first one that day. */
export const onStudioWallApproved = onDocumentUpdated(
  {document: "walls/{wallId}", region: REGION, secrets: [telegramBotToken, telegramChatId]},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after || before.review === true || after.review !== true) return;
    const wallId = event.params.wallId;
    if (!(await isStudioWall(wallId, after))) return;
    try {
      const posted = await postFirstStudioWallOfDay(wallId, after, telegramBotToken.value(), telegramChatId.value());
      logger.info(posted ? "onStudioWallApproved: posted." : "onStudioWallApproved: today's post is taken.", {wallId});
    } catch (err) {
      logger.error("onStudioWallApproved: post failed.", {wallId, err: String(err)});
    }
  },
);
