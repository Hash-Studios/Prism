import {db} from "../common";
import {isStudioWall} from "../studio/process";
import {postStudioWall, studioPostCaption} from "../studio/telegram";

// Sends a post draft for every approved Studio wall that has none yet. Dry run prints the captions.
// Usage: TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... npm run studio:posts [-- --apply]
async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const token = process.env.TELEGRAM_BOT_TOKEN ?? "";
  const chatId = process.env.TELEGRAM_CHAT_ID ?? "";
  if (apply && (!token || !chatId)) throw new Error("Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.");
  const snap = await db.collection("walls").where("origin", "==", "studio").where("review", "==", true).get();
  const docs = snap.docs.sort((a, b) => (a.data().createdAt?.toMillis?.() ?? 0) - (b.data().createdAt?.toMillis?.() ?? 0));
  let sent = 0;
  for (const doc of docs) {
    const wall = doc.data();
    if (wall.telegramSentAt != null || !(await isStudioWall(doc.id, wall))) continue;
    if (!apply) {
      console.log(`--- ${doc.id} ${wall.title}\n${studioPostCaption(wall)}\n`);
      continue;
    }
    if (await postStudioWall(doc.ref, wall, token, chatId)) sent++;
    await new Promise((resolve) => setTimeout(resolve, 3000)); // Telegram allows about 20 messages a minute to a group.
  }
  console.log(apply ? `Sent ${sent}.` : "Dry run. Add -- --apply to send.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
