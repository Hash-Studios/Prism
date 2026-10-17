import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {REGION, str} from "../common";
import {isStudioWall} from "./process";
import {STUDIO_SERIES} from "./series";

// The bot sends each approved Studio wall to one chat, as a social post draft: the full-size image and a caption.
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

/**
 * Sends the full-size image as a file, so Telegram does not compress it, with the caption. Telegram fetches only
 * GIF, PDF and ZIP files by URL, so the image is downloaded and uploaded.
 */
export async function sendStudioPost(token: string, chatId: string, wall: admin.firestore.DocumentData): Promise<void> {
  const image = await fetch(str(wall.wallpaper_url));
  if (!image.ok) throw new Error(`Image download failed: ${image.status}`);
  const name = str(wall.title).replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "").toLowerCase() || "prism-wall";
  const form = new FormData();
  form.set("chat_id", chatId);
  form.set("caption", studioPostCaption(wall));
  form.set("document", new Blob([await image.arrayBuffer()], {type: "image/jpeg"}), `${name}.jpg`);
  const res = await fetch(`https://api.telegram.org/bot${token}/sendDocument`, {method: "POST", body: form});
  if (!res.ok) throw new Error(`Telegram sendDocument failed: ${res.status} ${await res.text()}`);
}

/** Sends the wall once. The `telegramSentAt` stamp stops a second send from the trigger or the backfill script. */
export async function postStudioWall(
  ref: admin.firestore.DocumentReference,
  wall: admin.firestore.DocumentData,
  token: string,
  chatId: string,
): Promise<boolean> {
  if (wall.telegramSentAt != null) return false;
  await sendStudioPost(token, chatId, wall);
  await ref.update({telegramSentAt: admin.firestore.FieldValue.serverTimestamp()});
  return true;
}

/** When a Studio wall is approved, the bot sends its post draft. */
export const onStudioWallApproved = onDocumentUpdated(
  {document: "walls/{wallId}", region: REGION, secrets: [telegramBotToken, telegramChatId]},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const ref = event.data?.after?.ref;
    if (!before || !after || !ref || before.review === true || after.review !== true) return;
    const wallId = event.params.wallId;
    if (!(await isStudioWall(wallId, after))) return;
    try {
      await postStudioWall(ref, after, telegramBotToken.value(), telegramChatId.value());
      logger.info("onStudioWallApproved: post draft sent.", {wallId});
    } catch (err) {
      logger.error("onStudioWallApproved: post draft not sent.", {wallId, err: String(err)});
    }
  },
);
