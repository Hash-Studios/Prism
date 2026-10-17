import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {STUDIO_SERIES} from "../studio/series";
import {studioPrompt} from "../studio/plan";
import {postDay, postFirstStudioWallOfDay, studioPostCaption} from "../studio/telegram";
import {installFakeDb} from "./fakeDb";

test("the caption is the subject scene, the collection line and up to five hashtags", () => {
  const series = STUDIO_SERIES.find((s) => s.id === "paper-worlds");
  assert.ok(series);
  const subject = series.subjects.find((s) => s.id === "autumn-road");
  const palette = series.palettes.find((p) => p.id === "autumn");
  assert.ok(subject && palette);
  const caption = studioPostCaption({
    seriesId: series.id,
    aiPrompt: studioPrompt(series, subject, palette),
    tags: ["illustration", "paper", "autumn", "road", "Nature", "extra"],
  });
  assert.equal(caption,
    "A winding road through layered autumn hills and round trees.\n\n" +
    "Part of the Paper Worlds collection by @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n" +
    "#wallpaper #illustration #paper #autumn #road");
});

test("an unknown series falls back to the prompt up to its first comma", () => {
  assert.equal(studioPostCaption({seriesId: "gone", aiPrompt: "a red kite, sunset palette. Style.", tags: ["kite"]}),
    "A red kite.\n\nBy @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n#wallpaper #kite");
});

/** Fakes the image download and Telegram. Returns the chat ids of the posts that reached Telegram. */
function fakeTelegram(t: TestContext, ok = () => true): string[] {
  const posts: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string, init?: {body?: FormData}) => {
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    if (!ok()) return new Response("down", {status: 502});
    posts.push(String(init?.body?.get("chat_id")));
    return new Response("{}");
  });
  return posts;
}

const wall = {wallpaper_url: "https://cdn.example/w.jpg", seriesId: "paper-worlds", aiPrompt: "a kite", tags: []};
const morning = new Date("2026-10-17T03:00:00Z");

test("only the first wall approved in a day is posted, and the next day posts again", async (t) => {
  const store = installFakeDb(t);
  const posts = fakeTelegram(t);
  const results = await Promise.all(["w1", "w2", "w3"].map((id) =>
    postFirstStudioWallOfDay(id, wall, "token", "-100", morning)));
  assert.deepEqual(results.filter(Boolean).length, 1);
  assert.deepEqual(posts, ["-100"]);
  assert.equal(await postFirstStudioWallOfDay("w4", wall, "token", "-100", new Date("2026-10-18T03:00:00Z")), true);
  assert.equal(posts.length, 2);
  assert.ok(store.has("studioTelegramPosts/2026-10-17") && store.has("studioTelegramPosts/2026-10-18"));
});

test("a failed send frees the day for the next approval", async (t) => {
  installFakeDb(t);
  let up = false;
  const posts = fakeTelegram(t, () => up);
  await assert.rejects(postFirstStudioWallOfDay("w1", wall, "token", "-100", morning), /502/);
  up = true;
  assert.equal(await postFirstStudioWallOfDay("w2", wall, "token", "-100", morning), true);
  assert.equal(posts.length, 1);
});

test("the day turns at midnight in India, not UTC", () => {
  assert.equal(postDay(new Date("2026-10-17T18:29:00Z")), "2026-10-17");
  assert.equal(postDay(new Date("2026-10-17T18:31:00Z")), "2026-10-18");
});
