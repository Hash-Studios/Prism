import assert from "node:assert/strict";
import crypto, {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {db} from "../common";
import {assertFits, DARK_STILL_TAILS, GRID_DETAIL_BUDGET, GRID_LINES, gridContent, gridVisionDecision, PANORAMA_LINES, panoramaPanels, rotate, SET_MIN, SET_SIZE, setContent, STILL_TAILS, stillCaption, stillContent, THEMES, themedStillContent, wallhavenCandidates, wallhavenDetails, wallhavenThemeCandidates, YOUTH_TAG, type WallhavenWall} from "../social/content";
import {applyPress, contentHash, defaultBuilders, handleTelegramUpdate, JITTER_MS, loadSocialConfig, measurePosts, normalizePostText, prepareDay, prepareFor, publishDue, scheduledAt, socialPrepare, socialTelegramWebhook, uncertaintyHash, type SocialConfig, type SocialDeps} from "../social/jobs";
import {callbackData, parsePress, socialBotToken, socialOwnerChatId, telegramClient, type Telegram, webhookSecret} from "../social/telegram";
import {R2Storage} from "../r2Storage";
import {oauthHeader, xClient, xWeightedLength, XError, type XClient, type XOwnPost} from "../social/x";
import {postDay} from "../studio/telegram";
import {installFakeDb, type Doc} from "./fakeDb";

const sha = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

// ---------- x.ts ----------

test("oauthHeader matches Twitter's documented OAuth 1.0a signature", () => {
  const header = oauthHeader("POST", "https://api.twitter.com/1.1/statuses/update.json?include_entities=true", {
    apiKey: "xvz1evFS4wEEPTGEFPHBog",
    apiSecret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
    token: "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
    tokenSecret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE",
  }, "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg", "1318622958",
  {status: "Hello Ladies + Gentlemen, a signed OAuth request!"});
  assert.ok(header.includes("oauth_signature=\"hCtSmYh%2BiHYCEqBWrE7C7hYmtUk%3D\""), header);
});

test("xWeightedLength counts plain text, URLs and emoji", () => {
  assert.equal(xWeightedLength("abc"), 3);
  assert.equal(xWeightedLength("see https://example.com/some/long/path?x=1 ok"), 4 + 23 + 3);
  assert.equal(xWeightedLength("🤩"), 2);
});

// ---------- content.ts ----------

test("panoramaPanels cuts three panels and counts flat ones", async () => {
  const noisy = await sharp({create: {width: 2560, height: 1600, channels: 3, background: {r: 128, g: 128, b: 128},
    noise: {type: "gaussian", mean: 128, sigma: 40}}}).jpeg().toBuffer();
  const result = await panoramaPanels(noisy);
  assert.equal(result.jpegs.length, 3);
  const metas = await Promise.all(result.jpegs.map((j) => sharp(j).metadata()));
  assert.deepEqual(metas.map((m) => m.width), [853, 853, 854]);
  assert.deepEqual(metas.map((m) => m.height), [1600, 1600, 1600]);
  assert.equal(result.flat, 0);

  const solid = await sharp({create: {width: 2560, height: 1600, channels: 3, background: {r: 20, g: 40, b: 60}}})
    .jpeg().toBuffer();
  assert.equal((await panoramaPanels(solid)).flat, 3);
});

test("gridVisionDecision applies the grid safety rules", () => {
  const all = (v: string) => ({adult: v, racy: v, violence: v, medical: v});
  const U = "VERY_UNLIKELY";
  // Sketchy walls: only adult VERY_LIKELY rejects; adult POSSIBLE or LIKELY posts with the sensitive flag.
  assert.deepEqual(gridVisionDecision({...all(U), adult: "VERY_LIKELY"}), {ok: false, reason: "adult"});
  assert.deepEqual(gridVisionDecision({...all(U), adult: "POSSIBLE"}), {ok: true, sensitive: true});
  assert.deepEqual(gridVisionDecision({...all(U), adult: "LIKELY"}), {ok: true, sensitive: true});
  for (const key of ["adult", "racy", "violence", "medical"]) {
    assert.equal(gridVisionDecision({...all(U), [key]: "UNKNOWN"}).ok, false, `${key} UNKNOWN`);
    const missing: Record<string, unknown> = all(U);
    delete missing[key];
    assert.equal(gridVisionDecision(missing).ok, false, `${key} missing`);
  }
  assert.equal(gridVisionDecision(null).ok, false);
  assert.deepEqual(gridVisionDecision({...all(U), violence: "LIKELY"}), {ok: false, reason: "violence_or_medical"});
  assert.deepEqual(gridVisionDecision({...all(U), racy: "VERY_LIKELY"}), {ok: true, sensitive: true});
  assert.deepEqual(gridVisionDecision(all(U)), {ok: true, sensitive: false});
});

test("YOUTH_TAG matches youth-coded tags only", () => {
  for (const tag of ["loli", "school uniform", "Schoolgirl", "teen", "teenage", "teenagers", "minors",
    "students", "schoolboy", "schoolboys", "school-uniform", "young boys", "young girls"]) assert.ok(YOUTH_TAG.test(tag), tag);
  for (const tag of ["landscape", "anime"]) assert.ok(!YOUTH_TAG.test(tag), tag);
});

async function gridDeps(candidates: Array<{id: string; purity: string}>, tags: Record<string, string[]> = {}) {
  const jpeg = await sharp({create: {width: 40, height: 60, channels: 3, background: {r: 90, g: 10, b: 10}}})
    .jpeg().toBuffer();
  return {
    annotate: async () => ({safeSearchAnnotation: {adult: "VERY_UNLIKELY", racy: "VERY_UNLIKELY",
      violence: "VERY_UNLIKELY", medical: "VERY_UNLIKELY"}}) as never,
    candidates: async () => candidates,
    details: async (id: string): Promise<WallhavenWall> => ({id,
      purity: candidates.find((c) => c.id === id)?.purity ?? "sfw",
      path: `https://w.wallhaven.cc/full/${id}.jpg`, tags: tags[id] ?? ["nature"]}),
    download: async () => jpeg,
  };
}

test("gridContent picks three, limits sketchy, drops youth tags and excluded ids", async () => {
  const candidates = [
    {id: "s1", purity: "sketchy"}, {id: "s2", purity: "sketchy"}, {id: "s3", purity: "sketchy"},
    {id: "s4", purity: "sketchy"}, {id: "w1", purity: "sfw"}, {id: "w2", purity: "sfw"},
  ];
  const deps = await gridDeps(candidates, {s1: ["loli"]});
  const content = await gridContent("2026-11-12", new Set(["s3"]), {sketchyPerPost: 1, blockedTags: []}, deps);
  assert.ok(content);
  assert.equal(content.media.length, 3);
  assert.equal(content.source.kind, "wallhaven");
  const ids = content.source.ids;
  assert.ok(!ids.includes("s1") && !ids.includes("s3"), ids.join());
  assert.ok(ids.filter((id) => id.startsWith("s")).length <= 1);
  assert.equal(content.replyText, "", "no paid link reply");

  const few = await gridDeps([{id: "w1", purity: "sfw"}, {id: "w2", purity: "sfw"}, {id: "s1", purity: "sketchy"}],
    {s1: ["loli"]});
  assert.equal(await gridContent("2026-11-12", new Set(), {sketchyPerPost: 1, blockedTags: []}, few), null);
});

// ---------- telegram.ts ----------

test("parsePress accepts only the owner's press with well-formed data", () => {
  const update = (fromId: number, data: string) => ({update_id: 7, callback_query: {id: "cb1", from: {id: fromId},
    message: {message_id: 5, chat: {id: 42}}, data}});
  const data = "a:2026-11-12_am:0123456789ab";
  assert.equal(parsePress(update(99, data), "42"), null);
  assert.deepEqual(parsePress(update(42, data), "42"), {updateId: 7, callbackId: "cb1", messageId: 5,
    action: "approve", postId: "2026-11-12_am", hash: "0123456789ab"});
  assert.equal(parsePress(update(42, "a:bad"), "42"), null);
  assert.equal(parsePress(update(42, "z:2026-11-12_am:0123456789ab"), "42"), null);
});

// ---------- jobs.ts ----------

test("normalizePostText decodes entities and strips the trailing t.co link", () => {
  assert.equal(normalizePostText("Hello &amp; bye https://t.co/AbC123"), "Hello & bye");
});

function installSocialDb(t: TestContext, seed: Record<string, Doc> = {},
  options: {failCommitAt?: number} = {}) {
  const store = installFakeDb(t, seed, undefined, options);
  t.mock.method(logger, "error", () => undefined);
  t.mock.method(logger, "warn", () => undefined);
  // fakeDb has no batch. Writes apply on commit.
  t.mock.method(db, "batch", () => {
    const ops: Array<() => Promise<void>> = [];
    return {
      set: (ref: {set: (d: Doc) => Promise<void>}, data: Doc) => void ops.push(() => ref.set(data)),
      commit: async () => {
        for (const op of ops) await op();
      },
    };
  });
  return store;
}

const HASH = "0123456789abcdef0123456789abcdef";
const press = (action: "approve" | "flag" | "skip" | "retry" | "drop", hash = HASH.slice(0, 12)) =>
  ({updateId: 1, callbackId: "c", messageId: 7, action, postId: "p1", hash});

test("applyPress honors the hash and moves the status", async (t) => {
  const store = installSocialDb(t, {
    "socialPosts/p1": {status: "pending_approval", contentHash: HASH},
    "socialPosts/p2": {status: "approved", contentHash: HASH},
    "socialPosts/p3": {status: "uncertain", contentHash: HASH, attemptId: "A", dispatchedAt: 1},
  });
  await applyPress(press("approve", "ffffffffffff"));
  assert.equal(store.get("socialPosts/p1")?.status, "pending_approval");

  await applyPress(press("approve"));
  assert.equal(store.get("socialPosts/p1")?.status, "approved");

  await applyPress({...press("skip"), postId: "p2"});
  assert.equal(store.get("socialPosts/p2")?.status, "skipped");

  await applyPress({...press("retry", uncertaintyHash(HASH, "A").slice(0, 12)), postId: "p3"});
  assert.equal(store.get("socialPosts/p3")?.status, "approved");
  assert.ok(!("attemptId" in (store.get("socialPosts/p3") as Doc)));
  // A retry gets a fresh window, so an old slot does not expire it at once.
  const retried = (store.get("socialPosts/p3")?.scheduledAt as {toMillis(): number}).toMillis();
  assert.ok(Date.now() - retried < 60_000);
});

test("plain Approve posts no flag; Approve + flag works only on a pending grid", async (t) => {
  const media = [{sha256: "a", alt: "1", sensitive: false, suggestFlag: true}, {sha256: "b", alt: "2", sensitive: false}];
  const hash = contentHash(media.map((m) => m.sha256), "t", "", media.map(({alt, sensitive}) => ({alt, sensitive})));
  const grid = {pipeline: "grid", status: "pending_approval", contentHash: hash, media, text: "t", replyText: ""};
  const gridPress = (action: "approve" | "flag") => press(action, hash.slice(0, 12));
  const store = installSocialDb(t, {
    "socialPosts/p1": grid, "socialPosts/p2": {...grid, media: media.map((m) => ({...m, suggestFlag: false}))},
    "socialPosts/p3": {...grid, pipeline: "panorama"}, "socialPosts/p4": {...grid, status: "approved"},
  });
  assert.equal(await applyPress(gridPress("approve")), "Approved.");
  assert.deepEqual((store.get("socialPosts/p1")?.media as Doc[]).map((m) => m.sensitive), [false, false]);
  assert.equal(store.get("socialPosts/p1")?.contentHash, hash);
  // No suggestion: the owner's flag covers every image.
  assert.equal(await applyPress({...gridPress("flag"), postId: "p2"}), "Approved with flag.");
  assert.deepEqual((store.get("socialPosts/p2")?.media as Doc[]).map((m) => m.sensitive), [true, true]);
  for (const id of ["p3", "p4"]) {
    assert.match(await applyPress({...gridPress("flag"), postId: id}), /^Nothing to do/);
  }
  assert.equal(parsePress({update_id: 1, callback_query: {id: "c", from: {id: 42}, message: {chat: {id: 42}, message_id: 3},
    data: "f:p1:0123456789ab"}}, "42")?.action, "flag");
});

const NOW = new Date("2026-11-12T10:00:00+05:30");
const MIN = 60_000;
const BYTES = Buffer.from("fake-jpeg-bytes");
const TEXT = "Today's finds";
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const config = (patch: Partial<SocialConfig> = {}): SocialConfig => ({enabled: true, dryRun: false,
  autoApprove: {panorama: true, still: true}, slots: {am: true, noon: true, set: true, eve: true, night: true},
  sketchyPerPost: 2, blockedTags: [], blockedIds: [], ...patch});

function fakeX(opts: {create?: () => Promise<string>; own?: () => XOwnPost[]} = {}) {
  const creates: Array<{text: string; options: {mediaIds?: string[]; replyTo?: string}}> = [];
  const calls: string[] = [];
  let n = 0;
  const x: XClient = {
    async uploadImage() {
      calls.push("upload");
      return "M1";
    },
    async setMediaMetadata() {
      calls.push("meta");
    },
    async createPost(text, options) {
      calls.push("create");
      creates.push({text, options});
      if (opts.create && creates.length === 1) return opts.create();
      return n++ === 0 ? "T1" : "R1";
    },
    async me() {
      calls.push("me");
      return "U1";
    },
    async ownPostsSince() {
      calls.push("own");
      return opts.own?.() ?? [];
    },
    async metrics() {
      return {};
    },
  };
  return {x, creates, calls};
}

const deps = (x: XClient | null, now: Date, cfg = config()): SocialDeps => ({now, config: cfg, telegram: null, x,
  storage: {get: async () => BYTES, put: async () => undefined} as never});

const postDoc = (patch: Doc = {}): Doc => {
  const post = {
    day: postDay(NOW), slot: "am", pipeline: "still", status: "approved", scheduledAt: ts(NOW.getTime() - 30 * MIN),
    media: [{r2Key: "social/a.jpg", sha256: sha(BYTES), bytes: BYTES.length, alt: "alt", sensitive: false}],
    text: TEXT, replyText: "Get it in Prism: https://prismwalls.com/x", contentHash: HASH,
    source: {kind: "prism", ids: ["W1"]},
    // A posted doc always has postedAt; publish reads posted docs by it.
    ...(patch.status === "posted" ? {postedAt: ts(NOW.getTime() - 20 * MIN)} : {}), ...patch,
  };
  post.contentHash = contentHash(post.media.map((m) => m.sha256), post.text, post.replyText,
    post.media.map(({alt, sensitive}) => ({alt, sensitive})));
  return post;
};
const PATH = `socialPosts/${postDay(NOW)}_am`;
const later = (min: number) => new Date(NOW.getTime() + min * MIN);

test("publishDue posts, records the wall as seen, then posts the reply", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(creates.length, 1);
  assert.deepEqual(creates[0].options, {mediaIds: ["M1"]});
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(store.get(PATH)?.tweetId, "T1");
  assert.equal(store.get("socialSeen/prism_W1")?.id, "W1");

  await publishDue(deps(x, later(1)));
  assert.equal(creates.length, 2);
  assert.equal(creates[1].options.replyTo, "T1");
  assert.equal(store.get(PATH)?.replyStatus, "posted");
  assert.equal(store.get(PATH)?.replyId, "R1");
});

test("publishDue never resends an uncertain create and marks it uncertain after 30 minutes", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, creates} = fakeX({create: async () => {
    throw new XError("x", 0, true);
  }});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "posting");
  await publishDue(deps(x, later(11)));
  assert.equal(store.get(PATH)?.status, "posting");
  await publishDue(deps(x, later(31)));
  assert.equal(store.get(PATH)?.status, "uncertain");
  assert.equal(creates.length, 1);
});

test("publishDue reconciles an uncertain create against the account's own posts", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, creates} = fakeX({
    create: async () => {
      throw new XError("x", 0, true);
    },
    own: () => [{id: "T9", text: `${TEXT} https://t.co/xyz`, createdAt: NOW.toISOString(), mediaCount: 1, mediaIds: ["M1"], replyTo: null}],
  });
  await publishDue(deps(x, NOW));
  await publishDue(deps(x, later(11)));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(store.get(PATH)?.tweetId, "T9");
  assert.equal(creates.length, 1);
});

test("publishDue puts a rate-limited post back to approved", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x} = fakeX({create: async () => {
    throw new XError("x", 429);
  }});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "approved");
  assert.ok(!("tweetId" in (store.get(PATH) as Doc)));
});

test("publishDue skips an expired post without calling X", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({scheduledAt: ts(NOW.getTime() - 3 * 60 * MIN)})});
  const {x, calls} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "skipped");
  assert.equal(store.get(PATH)?.error, "expired");
  assert.deepEqual(calls, []);
});

test("publishDue in dry run marks dry_run and does not call X", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, calls} = fakeX();
  await publishDue(deps(x, NOW, config({dryRun: true})));
  assert.equal(store.get(PATH)?.status, "dry_run");
  assert.deepEqual(calls, []);
});

test("publishDue returns a stale posting doc with no dispatch to approved", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "posting", attemptId: "A1",
    attemptAt: ts(NOW.getTime() - 11 * MIN)})});
  const {x, calls} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "approved");
  assert.deepEqual(calls, []);
});


test("gridContent rejects youth variants before downloading", async () => {
  for (const tag of ["teenage", "teenagers", "minors", "students", "schoolboy", "schoolboys",
    "school-uniform", "young boys", "young girls"]) {
    const d = await gridDeps([{id: "bad", purity: "sfw"}, {id: "w1", purity: "sfw"}, {id: "w2", purity: "sfw"}],
      {bad: [tag]});
    assert.equal(await gridContent("2026-11-12", new Set(), {sketchyPerPost: 2, blockedTags: []}, d), null, tag);
  }
});

test("Telegram transport errors never expose the bot token", async () => {
  const client = telegramClient("SECRET", "42", async () => {
    throw new Error("network https://api.telegram.org/botSECRET/sendMessage");
  });
  await assert.rejects(client.sendText("hello"), (err: Error) => {
    assert.ok(!err.message.includes("SECRET"));
    assert.match(err.message, /Telegram/);
    return true;
  });
});

test("X retains 429 classification even when the error response body fails", async () => {
  const client = xClient({apiKey: "a", apiSecret: "s", token: "t", tokenSecret: "s"}, async () =>
    ({ok: false, status: 429, text: async () => {
      throw new Error("SECRET");
    }}) as unknown as Response);
  await assert.rejects(client.createPost("hello", {}), (err: XError) => {
    assert.equal(err.status, 429);
    assert.equal(err.retryable, true);
    assert.equal(err.uncertain, false);
    return true;
  });
});

test("X sanitizes failures while reading a successful response", async () => {
  const client = xClient({apiKey: "a", apiSecret: "s", token: "t", tokenSecret: "s"}, async () =>
    ({ok: true, status: 200, text: async () => {
      throw new Error("SECRET");
    }}) as unknown as Response);
  await assert.rejects(client.createPost("hello", {}), (err: XError) => {
    assert.equal(err.uncertain, true);
    assert.ok(!err.message.includes("SECRET"));
    return true;
  });
});

test("X own-post reconciliation reads all pages and expands reply links", async () => {
  const urls: string[] = [];
  const pages = [
    {data: [{id: "1", text: "Get https://t.co/a", entities: {urls: [
      {url: "https://t.co/a", expanded_url: "https://prismwalls.com/x"},
    ]}}], meta: {next_token: "next"}},
    {data: [{id: "2", text: "wall https://t.co/photo", attachments: {media_keys: ["3_123"]}, entities: {urls: [
      {url: "https://t.co/photo", expanded_url: "https://x.com/u/status/2/photo/1"},
    ]}}]},
  ];
  const client = xClient({apiKey: "a", apiSecret: "s", token: "t", tokenSecret: "s"}, async (url) => {
    urls.push(String(url));
    return Response.json(pages[urls.length - 1]);
  });
  const own = await client.ownPostsSince("u", NOW);
  assert.equal(own.length, 2);
  assert.equal(new URL(urls[1]).searchParams.get("pagination_token"), "next");
  assert.equal(own[0].text, "Get https://prismwalls.com/x");
  assert.equal(own[1].text, "wall https://t.co/photo");
  assert.deepEqual(own[1].mediaIds, ["123"]);
});

test("X refuses incomplete or looping timeline reads instead of reporting no match", async () => {
  for (const page of [{errors: [{message: "partial"}]}, {meta: {next_token: "same"}}]) {
    const client = xClient({apiKey: "a", apiSecret: "s", token: "t", tokenSecret: "s"}, async () => Response.json(page));
    await assert.rejects(client.ownPostsSince("u", NOW), XError);
  }
});

test("stale approval and retry buttons cannot decide a different uncertain attempt", async (t) => {
  const store = installSocialDb(t, {"socialPosts/p1": {status: "uncertain", contentHash: HASH, attemptId: "new"}});
  await applyPress(press("approve"));
  assert.equal(store.get("socialPosts/p1")?.status, "uncertain");
  await applyPress(press("retry", uncertaintyHash(HASH, "old").slice(0, 12)));
  assert.equal(store.get("socialPosts/p1")?.status, "uncertain");
  await applyPress(press("retry", uncertaintyHash(HASH, "new").slice(0, 12)));
  assert.equal(store.get("socialPosts/p1")?.status, "approved");
  store.set("socialPosts/p1", {status: "posted", contentHash: HASH, replyStatus: "uncertain", replyAttemptId: "new"});
  await applyPress(press("retry", uncertaintyHash(HASH, "new").slice(0, 12)));
  assert.equal(store.get("socialPosts/p1")?.replyStatus, "uncertain");
  await applyPress(press("retry", uncertaintyHash(HASH, "new", true).slice(0, 12)));
  assert.equal(store.get("socialPosts/p1")?.replyStatus, undefined);
});

test("publisher rejects edited metadata and unapproved grids", async (t) => {
  const changed = postDoc();
  (changed.media as Array<{sensitive: boolean}>)[0].sensitive = true;
  const store = installSocialDb(t, {[PATH]: changed});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "failed");
  assert.equal(store.get(PATH)?.error, "content_changed");
  store.set(PATH, postDoc({pipeline: "grid"}));
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "pending_approval");
  assert.equal(creates.length, 0);
});

test("an old upload worker cannot dispatch after its attempt was recovered", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, creates} = fakeX();
  const upload = x.uploadImage;
  x.uploadImage = async (jpeg) => {
    await publishDue(deps(x, later(11)));
    return upload(jpeg);
  };
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "approved");
  assert.equal(creates.length, 0);
});

test("a rate limit clears stale dispatch state before a later upload crash", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x} = fakeX({create: async () => {
    throw new XError("rate", 429);
  }});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "approved");
  assert.equal(store.get(PATH)?.dispatchedAt, undefined);
});

test("old queue entries expire and reconcile beyond yesterday", async (t) => {
  const store = installSocialDb(t, {
    [PATH]: postDoc({day: "2026-11-01", scheduledAt: ts(NOW.getTime() - 10 * 86400000)}),
    "socialPosts/old": postDoc({day: "2026-11-01", status: "posting", attemptId: "A",
      attemptAt: ts(NOW.getTime() - 40 * MIN), dispatchedAt: ts(NOW.getTime() - 40 * MIN)}),
  });
  const {x} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "skipped");
  assert.equal(store.get("socialPosts/old")?.status, "uncertain");
});

test("one new main post does not starve later replies or reconciles", async (t) => {
  const store = installSocialDb(t, {
    [PATH]: postDoc(),
    "socialPosts/reply": postDoc({status: "posted", tweetId: "OLD", scheduledAt: ts(NOW.getTime() - 20 * MIN)}),
    "socialPosts/unknown": postDoc({status: "posting", attemptId: "A", attemptAt: ts(NOW.getTime() - 40 * MIN),
      dispatchedAt: ts(NOW.getTime() - 40 * MIN), scheduledAt: ts(NOW.getTime() - 10 * MIN)}),
  });
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(store.get("socialPosts/reply")?.replyStatus, "posted");
  assert.equal(store.get("socialPosts/unknown")?.status, "uncertain");
  assert.equal(creates.length, 2);
});

test("reconciliation rejects identical captions with different media and unrelated replies", async (t) => {
  const store = installSocialDb(t, {
    [PATH]: postDoc({status: "posting", attemptId: "A", attemptAt: ts(NOW.getTime() - 40 * MIN),
      dispatchedAt: ts(NOW.getTime() - 40 * MIN), mediaIds: ["expected"]}),
    "socialPosts/reply": postDoc({status: "posted", tweetId: "OLD", replyStatus: "posting", replyAttemptId: "R",
      replyDispatchedAt: ts(NOW.getTime() - 40 * MIN)}),
  });
  const {x} = fakeX({own: () => [
    {id: "wrong", text: TEXT, createdAt: later(-40).toISOString(), mediaCount: 1, mediaIds: ["different"], replyTo: null},
    {id: "comment", text: "Thanks!", createdAt: later(-40).toISOString(), mediaCount: 0, replyTo: "OLD"},
  ]});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "uncertain");
  assert.equal(store.get("socialPosts/reply")?.replyStatus, "uncertain");
});

test("dry run never creates a pending link reply", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "posted", tweetId: "OLD"})});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW, config({dryRun: true})));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(creates.length, 0);
});

test("an accepted create with a failed Firestore commit reconciles without resending", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()}, {failCommitAt: 3});
  const {x, creates} = fakeX({own: () => [{id: "T1", text: TEXT, createdAt: NOW.toISOString(),
    mediaCount: 1, mediaIds: ["M1"], replyTo: null}]});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "posting");
  await publishDue(deps(x, later(11)));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(store.get(PATH)?.tweetId, "T1");
  assert.equal(store.get("socialSeen/prism_W1")?.id, "W1");
  assert.equal(creates.length, 1);
});

test("sensitive metadata refusal prevents publication but normal alt failure is optional", async (t) => {
  const sensitive = postDoc();
  (sensitive.media as Array<{sensitive: boolean}>)[0].sensitive = true;
  sensitive.contentHash = contentHash([sha(BYTES)], TEXT, String(sensitive.replyText), [{alt: "alt", sensitive: true}]);
  const store = installSocialDb(t, {[PATH]: sensitive});
  const {x, creates} = fakeX();
  x.setMediaMetadata = async () => {
    throw new XError("refused", 400);
  };
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "failed");
  assert.equal(creates.length, 0);
  store.set(PATH, postDoc());
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(creates.length, 1);
});

test("failed uncertain alerts are retried until delivered", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "uncertain", attemptId: "A"})});
  let attempts = 0;
  const tg: Telegram = {sendPhotos: async () => undefined, sendText: async () => undefined,
    answer: async () => undefined, markDone: async () => undefined, setWebhook: async () => undefined,
    sendButtons: async () => {
      if (++attempts === 1) throw new Error("offline");
    }};
  const d = {...deps(fakeX().x, NOW), telegram: tg};
  await publishDue(d);
  assert.equal(store.get(PATH)?.alertHash, undefined);
  await publishDue(d);
  assert.equal(store.get(PATH)?.alertHash, uncertaintyHash(String(store.get(PATH)?.contentHash), "A"));
  await publishDue(d);
  assert.equal(attempts, 2);
});

test("build failures never persist or log signed URLs", async (t) => {
  const store = installSocialDb(t);
  const messages: unknown[][] = [];
  t.mock.method(logger, "error", (...args: unknown[]) => {
    messages.push(args);
  });
  const broken = async () => {
    throw new Error("https://private/image?secret=TOKEN");
  };
  await prepareDay(deps(null, NOW), {grid: broken, panorama: broken, still: broken, set: broken});
  assert.equal(store.get(PATH)?.error, "build_failed");
  assert.ok(!JSON.stringify([...store]).includes("TOKEN"));
  assert.ok(!JSON.stringify(messages).includes("TOKEN"));
});

test("publish honors slot disables and post-prepare blocklist changes", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc()});
  const {x, creates} = fakeX();
  const disabled = config();
  disabled.slots.am = false;
  await publishDue(deps(x, NOW, disabled));
  assert.equal(store.get(PATH)?.status, "approved");
  await publishDue(deps(x, NOW, config({blockedIds: ["W1"]})));
  assert.equal(store.get(PATH)?.status, "skipped");
  assert.equal(creates.length, 0);
});

test("invalid config cannot enable still auto-approval or coerce a sketchy limit", async (t) => {
  installSocialDb(t, {"socialConfig/current": {enabled: true, dryRun: false,
    sketchyPerPost: null, autoApprove: {still: "false"}}});
  const cfg = await loadSocialConfig();
  assert.equal(cfg.autoApprove.still, false);
  assert.equal(cfg.sketchyPerPost, 2);
});

test("publisher retries a failed preview without requiring a new queue document", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "pending_approval", approval: {required: true}})});
  let photos = 0;
  let buttons = 0;
  const tg: Telegram = {sendPhotos: async () => {
    if (++photos === 1) throw new Error("offline");
  },
  sendButtons: async () => {
    buttons++;
  }, sendText: async () => undefined, answer: async () => undefined,
  markDone: async () => undefined, setWebhook: async () => undefined};
  const d = {...deps(null, NOW), telegram: tg};
  await publishDue(d);
  assert.equal(store.get(PATH)?.previewSentAt, undefined);
  await publishDue(d);
  assert.ok(store.get(PATH)?.previewSentAt);
  assert.equal(buttons, 1);
  assert.equal(store.get(PATH)?.status, "pending_approval");
});

test("publisher rechecks grid tag blocks added after preparation", async (t) => {
  const p = postDoc({pipeline: "grid", source: {kind: "wallhaven", ids: ["a", "b", "c"], tags: ["nature", "banned"]}});
  p.approval = {required: true, decision: "approve", approvedHash: p.contentHash};
  const store = installSocialDb(t, {[PATH]: p});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW, config({blockedTags: ["BANNED"]})));
  assert.equal(store.get(PATH)?.status, "skipped");
  assert.equal(creates.length, 0);
});

test("missing reply metrics retry without overwriting an existing main sample", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "posted", tweetId: "T", replyId: "R",
    postedAt: ts(NOW.getTime() - 2 * 86400000), metrics: {post: {h24: {likes: 1}}}})});
  const {x} = fakeX();
  const metrics = {impressions: 10, likes: 99, reposts: 0, replies: 0, quotes: 0, bookmarks: 0,
    linkClicks: 0, profileClicks: 0};
  x.metrics = async () => ({T: metrics, R: metrics});
  assert.equal(await measurePosts(deps(x, NOW)), 1);
  const sampled = store.get(PATH)?.metrics as {post: {h24: {likes: number}}; reply: {h24: {likes: number}}};
  assert.equal(sampled.post.h24.likes, 1);
  assert.equal(sampled.reply.h24.likes, 99);
});

test("an accepted reply with a failed Firestore commit reconciles without a second reply", async (t) => {
  const p = postDoc({status: "posted", tweetId: "P"});
  const store = installSocialDb(t, {[PATH]: p}, {failCommitAt: 2});
  const {x, creates} = fakeX({own: () => [{id: "R", text: String(p.replyText), createdAt: NOW.toISOString(),
    mediaCount: 0, replyTo: "P"}]});
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.replyStatus, "posting");
  await publishDue(deps(x, later(11)));
  assert.equal(store.get(PATH)?.replyStatus, "posted");
  assert.equal(store.get(PATH)?.replyId, "R");
  assert.equal(creates.length, 1);
});

test("prepare surfaces queue write failures so the scheduler can retry", async (t) => {
  installSocialDb(t);
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    const result = collection(name);
    if (name !== "socialPosts") return result;
    const doc = result.doc.bind(result);
    result.doc = ((id: string) => {
      const ref = doc(id);
      ref.create = async () => {
        throw Object.assign(new Error("unavailable"), {code: 14});
      };
      return ref;
    }) as typeof result.doc;
    return result;
  });
  const build = async () => ({pipeline: "still" as const, source: {kind: "prism" as const, ids: ["W"]},
    media: [{jpeg: BYTES, alt: "alt", sensitive: false}], text: "wall", replyText: "link"});
  await assert.rejects(prepareDay(deps(null, NOW), {grid: build, panorama: build, still: build, set: build}), /unavailable/);
});

test("metrics still measure an old queue document reconciled recently", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({day: "2026-01-01", status: "posted", tweetId: "T",
    postedAt: ts(NOW.getTime() - 86400000)})});
  const {x} = fakeX();
  x.metrics = async () => ({T: {impressions: 10, likes: 2, reposts: 0, replies: 0, quotes: 0, bookmarks: 0,
    linkClicks: 0, profileClicks: 0}});
  assert.equal(await measurePosts(deps(x, NOW)), 1);
  const metrics = store.get(PATH)?.metrics as {post: {h24: {likes: number}}};
  assert.equal(metrics.post.h24.likes, 2);
});

test("publish never replies to a post older than the reply window", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "posted", tweetId: "OLD",
    postedAt: ts(NOW.getTime() - 4 * 86_400_000)})});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.replyStatus, undefined);
  assert.equal(creates.length, 0);
});

test("Sunday night waits for the run after Wall of the Day is picked", async (t) => {
  const store = installSocialDb(t);
  const slots: string[] = [];
  const build = async (_day: string, _exclude: Set<string>, slot: string) => {
    slots.push(slot);
    return {pipeline: "still" as const, source: {kind: "prism" as const, ids: [`W-${slot}`]},
      media: [{jpeg: BYTES, alt: "alt", sensitive: false}], text: "wall", replyText: "link"};
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  const sunday = (hour: string) => new Date(`2026-11-15T${hour}:00:00+05:30`);
  // Saturday's 22:00 run prepares Sunday, but not the Wall of the Day post.
  await prepareDay(deps(null, new Date("2026-11-14T22:00:00+05:30")), builders);
  assert.deepEqual(slots, ["am", "noon", "eve"]);
  assert.equal(store.get("socialPosts/2026-11-15_am")?.day, "2026-11-15");
  await prepareDay(deps(null, sunday("07")), builders);
  assert.deepEqual(slots, ["am", "noon", "eve"]);
  await prepareDay(deps(null, sunday("10")), builders);
  assert.deepEqual(slots, ["am", "noon", "eve", "night"]);
  assert.equal(store.get("socialPosts/2026-11-15_night")?.slot, "night");
});

test("runs from 21:00 IST prepare tomorrow; earlier runs prepare today", () => {
  assert.equal(prepareFor(new Date("2026-11-12T07:00:00+05:30")), "2026-11-12");
  assert.equal(prepareFor(new Date("2026-11-12T20:59:00+05:30")), "2026-11-12");
  assert.equal(prepareFor(new Date("2026-11-12T22:00:00+05:30")), "2026-11-13");
  assert.equal(prepareFor(new Date("2026-11-30T23:59:00+05:30")), "2026-12-01");
  assert.equal(prepareFor(new Date("2026-12-31T21:00:00+05:30")), "2027-01-01");
  assert.equal(prepareFor(new Date("2028-02-28T21:00:00+05:30")), "2028-02-29");
  assert.equal(prepareFor(new Date("2026-11-13T00:00:00+05:30")), "2026-11-13");
  // UTC instants stay on the same IST rule through northern DST transitions.
  assert.equal(prepareFor(new Date("2026-03-08T15:30:00Z")), "2026-03-09");
  assert.equal(prepareFor(new Date("2026-11-01T15:29:59Z")), "2026-11-01");
});

test("next-day preparation reserves walls in unfinished posts across days", async (t) => {
  installSocialDb(t, Object.fromEntries(["pending_approval", "approved", "posting", "uncertain"].map((status, i) =>
    [`socialPosts/2026-11-12_${i}`, postDoc({status, source: {kind: "prism", ids: [status]}})])));
  const now = new Date("2026-11-12T22:00:00+05:30");
  const excluded: Set<string>[] = [];
  const build = async (_day: string, exclude: Set<string>) => {
    excluded.push(new Set(exclude));
    return null;
  };
  await prepareDay(deps(null, now), {grid: build, panorama: build, still: build, set: build});
  assert.equal(excluded.length, 4);
  for (const id of ["pending_approval", "approved", "posting", "uncertain"]) assert.ok(excluded[0].has(id), id);
});

test("morning catch-up retries empty or failed night-before builds, not owner skips or X failures", async (t) => {
  const store = installSocialDb(t);
  const cfg = config({slots: {am: true, noon: true, set: false, eve: false, night: false}});
  let fail = true;
  const build = async (_day: string, _exclude: Set<string>, slot: string) => {
    if (fail) {
      if (slot === "am") throw new Error("offline");
      return null;
    }
    return {pipeline: "still" as const, source: {kind: "prism" as const, ids: [slot]},
      media: [{jpeg: BYTES, alt: "wall", sensitive: false}], text: "wall", replyText: ""};
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  await prepareDay(deps(null, new Date("2026-11-11T22:00:00+05:30"), cfg), builders);
  assert.equal(store.get(PATH)?.error, "build_failed");
  assert.equal(store.get("socialPosts/2026-11-12_noon")?.error, "no_content");
  fail = false;
  assert.deepEqual(await prepareDay(deps(null, NOW, cfg), builders), ["2026-11-12_am", "2026-11-12_noon"]);
  store.set(PATH, postDoc({status: "skipped", error: "owner_skipped"}));
  store.set("socialPosts/2026-11-12_noon", postDoc({slot: "noon", status: "failed", error: "create_refused"}));
  assert.deepEqual(await prepareDay(deps(null, NOW, cfg), builders), []);
});

test("night-before previews retry without early publication or expiry", async (t) => {
  const now = new Date("2026-12-31T22:00:00+05:30");
  const due = scheduledAt("2027-01-01", "am", () => 0.5);
  const path = "socialPosts/2027-01-01_am";
  const post = postDoc({day: "2027-01-01", status: "pending_approval", scheduledAt: ts(due.getTime()),
    replyText: "", approval: {required: true}});
  const store = installSocialDb(t, {[path]: post});
  let photos = 0;
  const tg: Telegram = {sendPhotos: async () => {
    if (++photos === 1) throw new Error("offline");
  }, sendButtons: async () => undefined, sendText: async () => undefined, answer: async () => undefined,
  markDone: async () => undefined, setWebhook: async () => undefined};
  const {x, creates} = fakeX();
  await publishDue({...deps(x, now), telegram: tg});
  assert.equal(store.get(path)?.previewSentAt, undefined);
  await publishDue({...deps(x, now), telegram: tg});
  assert.ok(store.get(path)?.previewSentAt);
  assert.equal(photos, 2);
  assert.equal(creates.length, 0);
  assert.equal(await applyPress({...press("approve", String(post.contentHash).slice(0, 12)),
    postId: "2027-01-01_am"}), "Approved.");
  await publishDue(deps(x, new Date(due.getTime() - 1)));
  assert.equal(store.get(path)?.status, "approved");
  assert.equal(creates.length, 0);
  await publishDue(deps(x, due));
  assert.equal(store.get(path)?.status, "posted");
  assert.equal(creates.length, 1);
  store.set(path, post);
  await publishDue(deps(x, new Date(due.getTime() + 2 * 3_600_000 + 1)));
  assert.equal(store.get(path)?.error, "expired");
});

test("a post with no reply text never sends a reply", async (t) => {
  const store = installSocialDb(t, {[PATH]: postDoc({status: "posted", tweetId: "T", replyText: ""})});
  const {x, creates} = fakeX();
  await publishDue(deps(x, NOW));
  assert.equal(store.get(PATH)?.replyStatus, undefined);
  assert.equal(creates.length, 0);
});

const pressUpdate = (data: string, from = "42") =>
  ({update_id: 9, callback_query: {id: "cb", from: {id: Number(from)}, message: {message_id: 77, chat: {id: 42}}, data}});

test("a webhook press applies at once, answers, and replaces the buttons", async (t) => {
  const store = installSocialDb(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH, approval: {required: true}}});
  const answers: string[] = [];
  const done: Array<[number, string]> = [];
  const tg: Telegram = {sendPhotos: async () => undefined, sendButtons: async () => undefined, sendText: async () => undefined,
    answer: async (_id, text) => {
      answers.push(text);
    },
    markDone: async (id, text) => {
      done.push([id, text]);
    },
    setWebhook: async () => undefined};
  await handleTelegramUpdate(pressUpdate(`a:p1:${HASH.slice(0, 12)}`), tg, "42");
  assert.equal(store.get("socialPosts/p1")?.status, "approved");
  assert.deepEqual(answers, ["Approved."]);
  assert.deepEqual(done, [[77, "p1: Approved ✅"]]);

  // Another user's press changes nothing and gets no answer.
  store.set("socialPosts/p2", {status: "pending_approval", contentHash: HASH, approval: {required: true}});
  await handleTelegramUpdate({...pressUpdate(`a:p2:${HASH.slice(0, 12)}`, "99")}, tg, "42");
  assert.equal(store.get("socialPosts/p2")?.status, "pending_approval");
  assert.equal(answers.length, 1);

  // A stale press answers but keeps the buttons.
  await handleTelegramUpdate(pressUpdate("a:p2:ffffffffffff"), tg, "42");
  assert.equal(store.get("socialPosts/p2")?.status, "pending_approval");
  assert.equal(done.length, 1);
});

test("the webhook secret is stable per token and differs between tokens", () => {
  assert.equal(webhookSecret("a"), webhookSecret("a"));
  assert.notEqual(webhookSecret("a"), webhookSecret("b"));
  assert.match(webhookSecret("a"), /^[a-f0-9]{48}$/);
});

const BOT_TOKEN = "test-bot-token";
function webhookSetup(t: TestContext, seed: Record<string, Doc> = {}) {
  const store = installSocialDb(t, seed);
  t.mock.method(socialBotToken, "value", () => BOT_TOKEN);
  t.mock.method(socialOwnerChatId, "value", () => "42");
  const calls: Array<{method: string; body: Record<string, unknown>}> = [];
  t.mock.method(globalThis, "fetch", async (url: string | URL | Request, options?: RequestInit) => {
    calls.push({method: String(url).split("/").pop() ?? "", body: JSON.parse(String(options?.body))});
    return new Response(JSON.stringify({ok: true, result: true}));
  });
  const send = async (body: unknown, secret: string | null = webhookSecret(BOT_TOKEN), method = "POST") => {
    const statuses: number[] = [];
    await socialTelegramWebhook({body, method, headers: {},
      get: (name: string) => name.toLowerCase() === "x-telegram-bot-api-secret-token" ? secret ?? undefined : undefined,
    } as Parameters<typeof socialTelegramWebhook>[0], {
      sendStatus: (status: number) => statuses.push(status),
    } as unknown as Parameters<typeof socialTelegramWebhook>[1]);
    assert.equal(statuses.length, 1);
    return statuses[0];
  };
  return {store, calls, send};
}

test("the HTTP webhook rejects wrong secrets and methods before applying a press", async (t) => {
  const {store, calls, send} = webhookSetup(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH}});
  const update = pressUpdate(`a:p1:${HASH.slice(0, 12)}`);
  for (const secret of [null, "", "wrong", "0".repeat(48), "é".repeat(48), `${webhookSecret(BOT_TOKEN)}x`]) {
    assert.equal(await send(update, secret), 403);
  }
  assert.equal(await send(update, webhookSecret(BOT_TOKEN), "GET"), 403);
  assert.equal(store.get("socialPosts/p1")?.status, "pending_approval");
  assert.equal(calls.length, 0);
  assert.equal(await send(update), 200);
  assert.equal(store.get("socialPosts/p1")?.status, "approved");
  assert.deepEqual(calls.map((call) => call.method), ["answerCallbackQuery", "editMessageText"]);
  assert.deepEqual(calls[1].body, {chat_id: "42", message_id: 77, text: "p1: Approved ✅"});
});

test("an empty bot token cannot authenticate with its publicly computable hash", async (t) => {
  const {store, calls, send} = webhookSetup(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH}});
  t.mock.method(socialBotToken, "value", () => "");
  assert.equal(await send(pressUpdate(`a:p1:${HASH.slice(0, 12)}`), webhookSecret("")), 403);
  assert.equal(store.get("socialPosts/p1")?.status, "pending_approval");
  assert.deepEqual(calls, []);
});

test("equal-length webhook secrets use the timing-safe comparison", async (t) => {
  const {send} = webhookSetup(t);
  const compare = t.mock.method(crypto, "timingSafeEqual");
  assert.equal(await send({}, "0".repeat(48)), 403);
  assert.equal(await send({}), 200);
  assert.equal(compare.mock.callCount(), 2);
  for (const call of compare.mock.calls) {
    assert.deepEqual(call.arguments.map((bytes) => bytes.byteLength), [48, 48]);
  }
});

test("the HTTP webhook ignores non-owner, wrong-chat, and malformed updates", async (t) => {
  const {store, calls, send} = webhookSetup(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH}});
  const update = pressUpdate(`a:p1:${HASH.slice(0, 12)}`);
  for (const body of [null, {}, {message: {}}, pressUpdate(update.callback_query.data, "99"),
    {...update, callback_query: {...update.callback_query, message: {message_id: 77, chat: {id: 99}}}},
    pressUpdate("a:p1:bad")]) {
    assert.equal(await send(body), 200);
  }
  assert.equal(store.get("socialPosts/p1")?.status, "pending_approval");
  assert.deepEqual(calls, []);
});

test("a thrown transaction error still returns 200 without a decision", async (t) => {
  const {store, calls, send} = webhookSetup(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH}});
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("offline");
  });
  assert.equal(await send(pressUpdate(`a:p1:${HASH.slice(0, 12)}`)), 200);
  assert.equal(store.get("socialPosts/p1")?.status, "pending_approval");
  assert.deepEqual(calls, []);
});

test("stalled Telegram acknowledgements expire within the webhook deadline", async (t) => {
  const {store, send} = webhookSetup(t, {"socialPosts/p1": {status: "pending_approval", contentHash: HASH}});
  const timeouts: number[] = [];
  t.mock.method(AbortSignal, "timeout", (ms: number) => {
    timeouts.push(ms);
    return AbortSignal.abort(new Error("timeout"));
  });
  t.mock.method(globalThis, "fetch", async (_url: unknown, options?: RequestInit) => {
    options?.signal?.throwIfAborted();
    throw new Error("expected an aborted request");
  });
  assert.equal(await send(pressUpdate(`a:p1:${HASH.slice(0, 12)}`)), 200);
  assert.equal(store.get("socialPosts/p1")?.status, "approved");
  assert.deepEqual(timeouts, [5000, 5000]);
  assert.ok(timeouts.reduce((sum, ms) => sum + ms, 0) < Number(socialTelegramWebhook.__endpoint.timeoutSeconds) * 1000);
});

test("duplicate webhook deliveries cannot repeat approvals or main/reply retry decisions", async (t) => {
  const {store, send} = webhookSetup(t);
  for (const action of ["a", "s", "r", "d", "reply-r", "reply-d"]) {
    const reply = action.startsWith("reply-");
    const code = action.slice(-1);
    const uncertain = code === "r" || code === "d";
    store.set("socialPosts/p1", {contentHash: HASH, status: uncertain ? reply ? "posted" : "uncertain" : "pending_approval",
      ...(reply ? {replyStatus: "uncertain", replyAttemptId: "A"} : uncertain ? {attemptId: "A"} : {})});
    const hash = uncertain ? uncertaintyHash(HASH, "A", reply) : HASH;
    const update = pressUpdate(`${code}:p1:${hash.slice(0, 12)}`);
    await Promise.all([send(update), send(update)]);
    const decided = store.get("socialPosts/p1");
    assert.equal(decided?.status, reply ? "posted" : code === "s" || code === "d" ? "skipped" : "approved");
    if (reply) assert.equal(decided?.replyStatus, code === "d" ? "dropped" : undefined);
    await send(update);
    assert.deepEqual(store.get("socialPosts/p1"), decided, action);
    if (code === "r") {
      store.set("socialPosts/p1", {...decided, ...(reply ? {replyStatus: "uncertain", replyAttemptId: "B"} :
        {status: "uncertain", attemptId: "B"})});
      const nextAttempt = store.get("socialPosts/p1");
      await send(update);
      assert.deepEqual(store.get("socialPosts/p1"), nextAttempt, `${action}: stale retry cannot retry a new attempt`);
    }
  }
});

test("prepare registers the v2 regional alias on every run and survives registration failure", async (t) => {
  const {store, calls} = webhookSetup(t, {"socialConfig/current": {...config({dryRun: true, slots: {am: false, noon: false, set: false, eve: true, night: false}})}});
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {GCLOUD_PROJECT: "test-project", FIREBASE_CONFIG: JSON.stringify({projectId: "fallback-project"}),
    R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview", R2_PREVIEW_BASE_URL: "https://images.example.com"});
  t.mock.method(logger, "info", () => undefined);
  t.mock.method(globalThis, "fetch", async (url: unknown, options?: RequestInit) => {
    calls.push({method: String(url).split("/").pop() ?? "", body: JSON.parse(String(options?.body))});
    return new Response(JSON.stringify({ok: false}), {status: 500});
  });
  t.mock.method(R2Storage.prototype, "put", async () => true);
  t.mock.method(defaultBuilders, "still", async () => ({pipeline: "still", source: {kind: "prism", ids: ["W"]},
    media: [{jpeg: BYTES, alt: "alt", sensitive: false}], text: "wall", replyText: ""}));
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-12-31T22:00:00+05:30").getTime()});
  await socialPrepare.run({scheduleTime: NOW.toISOString()});
  assert.equal(store.get("socialPosts/2027-01-01_eve")?.status, "approved");
  delete process.env.GCLOUD_PROJECT;
  await socialPrepare.run({scheduleTime: NOW.toISOString()});
  assert.equal(store.has("socialPosts/2026-12-31_eve"), false);
  assert.deepEqual(store.get("socialState/dryRunSeen"), {day: "2027-01-01", ids: ["W"]});
  assert.deepEqual(calls.filter((call) => call.method === "setWebhook"), ["test-project", "fallback-project"].map((project) => ({method: "setWebhook", body: {
    url: `https://asia-south1-${project}.cloudfunctions.net/socialTelegramWebhook`,
    secret_token: webhookSecret(BOT_TOKEN), allowed_updates: ["callback_query"],
  }})));
  assert.equal(socialPrepare.__endpoint.scheduleTrigger?.schedule, "0 7,10,22 * * *");
  assert.equal(socialPrepare.__endpoint.scheduleTrigger?.timeZone, "Asia/Kolkata");
  assert.equal(socialTelegramWebhook.__endpoint.platform, "gcfv2");
  assert.deepEqual(socialTelegramWebhook.__endpoint.region, ["asia-south1"]);
  assert.deepEqual(socialTelegramWebhook.__endpoint.httpsTrigger?.invoker, ["public"]);
  assert.equal(store.has("socialState/telegram"), false);
});

test("slot times spread evenly within 15 minutes either side", () => {
  const base = Date.parse("2026-11-12T09:30:00+05:30");
  assert.equal(scheduledAt("2026-11-12", "am", () => 0).getTime(), base - JITTER_MS);
  assert.equal(scheduledAt("2026-11-12", "am", () => 0.5).getTime(), base);
  assert.equal(scheduledAt("2026-11-12", "am", () => 0.999999).getTime() <= base + JITTER_MS, true);
  assert.equal(JITTER_MS, 15 * 60_000);
});

test("a dry-run trigger rebuilds unposted posts with new walls; a live run never does", async (t) => {
  const day = postDay(NOW);
  const store = installSocialDb(t, {
    [`socialPosts/${day}_am`]: postDoc({slot: "am", status: "dry_run", source: {kind: "prism", ids: ["OLD"]}}),
    [`socialPosts/${day}_noon`]: postDoc({slot: "noon", status: "posted", tweetId: "T", source: {kind: "prism", ids: ["LIVE"]}}),
  });
  const excluded: string[][] = [];
  const build = async (_day: string, exclude: Set<string>, slot: string) => {
    excluded.push([...exclude]);
    return {pipeline: "still" as const, source: {kind: "prism" as const, ids: [`NEW-${slot}`]},
      media: [{jpeg: BYTES, alt: "alt", sensitive: false}], text: "wall", replyText: ""};
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  await prepareDay(deps(null, NOW, config({dryRun: true})), builders);
  const am = store.get(`socialPosts/${day}_am`);
  assert.deepEqual((am?.source as {ids: string[]}).ids, ["NEW-am"]);
  assert.ok(excluded[0].includes("OLD"), "the replaced wall is not picked again");
  assert.equal(store.get(`socialPosts/${day}_noon`)?.status, "posted", "a posted doc is never rebuilt");

  const before = JSON.stringify(store.get(`socialPosts/${day}_am`));
  await prepareDay(deps(null, NOW, config({dryRun: false})), builders);
  assert.equal(JSON.stringify(store.get(`socialPosts/${day}_am`)), before, "a live run keeps existing posts");
});

test("dry-run rebuild preserves a post claimed after the prepare query", async (t) => {
  for (const unknown of [false, true]) {
    await t.test(unknown ? "unknown create" : "accepted create", async (t) => {
      const store = installSocialDb(t, {[PATH]: postDoc()});
      const {x, creates} = fakeX(unknown ? {create: async () => {
        throw new XError("unknown", 0, true);
      }} : {});
      const collection = db.collection.bind(db);
      t.mock.method(db, "collection", (name: string) => {
        const result = collection(name);
        if (name !== "socialPosts") return result;
        const where = result.where.bind(result);
        result.where = ((field, op, value) => {
          const query = where(field, op, value);
          if (field === "day") {
            const get = query.get.bind(query);
            query.get = async () => {
              const snapshot = await get();
              await publishDue(deps(x, NOW));
              return snapshot;
            };
          }
          return query;
        }) as typeof result.where;
        return result;
      });
      let builds = 0;
      const build = async () => {
        builds++;
        return null;
      };
      await prepareDay(deps(null, NOW, config({dryRun: true,
        slots: {am: true, noon: false, set: false, eve: false, night: false}})), {grid: build, panorama: build, still: build, set: build});
      assert.equal(creates.length, 1);
      assert.equal(store.get(PATH)?.status, unknown ? "posting" : "posted");
      assert.ok(store.get(PATH)?.dispatchedAt);
      assert.equal(builds, 0, "the claimed slot must not be rebuilt");
    });
  }
});

test("dry-run rebuild preserves uncertain history after owner drop or retry", async (t) => {
  for (const action of ["drop", "retry"] as const) {
    await t.test(action, async (t) => {
      const store = installSocialDb(t, {[PATH]: postDoc()});
      const {x} = fakeX({create: async () => {
        throw new XError("unknown", 0, true);
      }});
      await publishDue(deps(x, NOW));
      await publishDue(deps(x, later(31)));
      assert.equal(store.get(PATH)?.status, "uncertain");
      const post = store.get(PATH) as Doc;
      await applyPress({...press(action, uncertaintyHash(String(post.contentHash), String(post.attemptId)).slice(0, 12)),
        postId: PATH.split("/")[1]});
      assert.equal(store.get(PATH)?.status, action === "drop" ? "skipped" : "approved");
      const before = store.get(PATH);
      let builds = 0;
      const build = async () => {
        builds++;
        return null;
      };
      await prepareDay(deps(null, NOW, config({dryRun: true,
        slots: {am: true, noon: false, set: false, eve: false, night: false}})), {grid: build, panorama: build, still: build, set: build});
      assert.deepEqual(store.get(PATH), before);
      assert.equal(builds, 0);
    });
  }
});

test("repeated dry runs never show a wall from any earlier run that day", async (t) => {
  const store = installSocialDb(t);
  const pool = "ABCDEFGHIJKLMN".split("");
  // Like the toplist: always the first wall that is not excluded.
  const build = async (_day: string, exclude: Set<string>, slot: string) => {
    const id = pool.find((wall) => !exclude.has(wall));
    return id ? {pipeline: "still" as const, source: {kind: "prism" as const, ids: [id]},
      media: [{jpeg: BYTES, alt: slot, sensitive: false}], text: "wall", replyText: ""} : null;
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  const shown: string[] = [];
  // The repeat showed on the third run: A, B, A. Three runs prove every earlier run is remembered.
  for (let run = 0; run < 3; run++) {
    const now = new Date(run === 0 ? "2026-11-11T22:00:00+05:30" : "2026-11-12T07:00:00+05:30");
    await prepareDay(deps(null, now, config({dryRun: true})), builders);
    for (const [key, doc] of store) {
      if (key.startsWith("socialPosts/")) shown.push(...(doc.source as {ids: string[]}).ids);
    }
  }
  assert.equal(new Set(shown).size, shown.length, `a wall came back: ${shown.join(",")}`);
  assert.equal(shown.length, 12);
});

test("a failed dry-run history save cannot erase the previous preview's ids", async (t) => {
  const day = postDay(NOW);
  const store = installSocialDb(t, {
    [PATH]: postDoc({source: {kind: "prism", ids: ["A"]}}),
    "socialState/dryRunSeen": {day, ids: ["B"]},
  });
  const collection = db.collection.bind(db);
  let fail = true;
  t.mock.method(db, "collection", (name: string) => {
    const result = collection(name);
    if (name !== "socialState") return result;
    const doc = result.doc.bind(result);
    result.doc = ((id: string) => {
      const ref = doc(id);
      const set = ref.set.bind(ref);
      if (id === "dryRunSeen") {
        ref.set = (async (...args: Parameters<typeof set>) => {
          if (fail) {
            fail = false;
            throw new Error("history unavailable");
          }
          return set(...args);
        }) as typeof ref.set;
      }
      return ref;
    }) as typeof result.doc;
    return result;
  });
  const build = async (_day: string, exclude: Set<string>) => {
    const id = ["A", "B", "C"].find((wall) => !exclude.has(wall));
    return id ? {pipeline: "still" as const, source: {kind: "prism" as const, ids: [id]},
      media: [{jpeg: BYTES, alt: "wall", sensitive: false}], text: "wall", replyText: ""} : null;
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  const dry = deps(null, NOW, config({dryRun: true,
    slots: {am: true, noon: false, set: false, eve: false, night: false}}));
  await assert.rejects(prepareDay(dry, builders), /history unavailable/);
  await prepareDay(dry, builders);
  assert.deepEqual((store.get(PATH)?.source as {ids: string[]}).ids, ["C"]);
});

test("live preparation ignores dry-run history and does not change it", async (t) => {
  const history = {day: postDay(NOW), ids: ["A"]};
  const store = installSocialDb(t, {"socialState/dryRunSeen": history});
  const build = async (_day: string, exclude: Set<string>) => {
    assert.ok(!exclude.has("A"));
    return {pipeline: "still" as const, source: {kind: "prism" as const, ids: ["A"]},
      media: [{jpeg: BYTES, alt: "wall", sensitive: false}], text: "wall", replyText: ""};
  };
  await prepareDay(deps(null, NOW, config({slots: {am: true, noon: false, set: false, eve: false, night: false}})),
    {grid: build, panorama: build, still: build, set: build});
  assert.deepEqual((store.get(PATH)?.source as {ids: string[]}).ids, ["A"]);
  assert.deepEqual(store.get("socialState/dryRunSeen"), history);
});

test("dry-run history resets when the prepared day changes at 21:00 IST", async (t) => {
  const before = new Date("2026-11-12T15:29:59Z");
  const after = new Date("2026-11-12T15:30:00Z");
  assert.notEqual(prepareFor(before), prepareFor(after));
  const store = installSocialDb(t, {"socialState/dryRunSeen": {day: prepareFor(before), ids: ["A"]}});
  const build = async (_day: string, exclude: Set<string>) => {
    const id = exclude.has("A") ? "B" : "A";
    return {pipeline: "still" as const, source: {kind: "prism" as const, ids: [id]},
      media: [{jpeg: BYTES, alt: "wall", sensitive: false}], text: "wall", replyText: ""};
  };
  const builders = {grid: build, panorama: build, still: build, set: build};
  const cfg = config({dryRun: true, slots: {am: true, noon: false, set: false, eve: false, night: false}});
  await prepareDay(deps(null, before, cfg), builders);
  assert.deepEqual((store.get(`socialPosts/${prepareFor(before)}_am`)?.source as {ids: string[]}).ids, ["B"]);
  await prepareDay(deps(null, after, cfg), builders);
  assert.deepEqual((store.get(`socialPosts/${prepareFor(after)}_am`)?.source as {ids: string[]}).ids, ["A"]);
  await prepareDay(deps(null, after, cfg), builders);
  assert.deepEqual(store.get("socialState/dryRunSeen"), {day: prepareFor(after), ids: ["A"]});
});

test("Wallhaven reads four search pages, deduplicates, and keeps the detail budget", async (t) => {
  const requests: URL[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const url = new URL(String(input));
    assert.equal(url.origin, "https://wallhaven.cc");
    requests.push(url);
    // Page 1 of each range repeats the same ids, so deduplication is visible; page 2 adds new ones.
    const page2 = url.searchParams.get("page") === "2" ? `${url.searchParams.get("topRange")}x` : "";
    return {ok: true, json: async () => ({data: Array.from({length: 24}, (_, i) =>
      ({id: `w${page2}${i}`, purity: "sfw"}))})} as Response;
  });
  const candidates = await wallhavenCandidates();
  assert.equal(candidates.length, 72);
  assert.deepEqual(requests.map((url) => [url.searchParams.get("topRange"), url.searchParams.get("page")]),
    [["3d", "1"], ["1w", "1"], ["3d", "2"], ["1w", "2"]]);
  const budget = GRID_DETAIL_BUDGET;
  const d = await gridDeps(candidates, Object.fromEntries(candidates.slice(0, budget).map(({id}) => [id, ["loli"]])));
  const details = t.mock.fn(d.details);
  // Safe walls exist later, but rejection-heavy pools deliberately stop at the request budget.
  assert.equal(await gridContent("2026-11-12", new Set(), {sketchyPerPost: 2, blockedTags: []},
    {...d, details}), null);
  assert.equal(details.mock.callCount(), budget);
  details.mock.resetCalls();
  const content = await gridContent("2026-11-12", new Set(candidates.slice(0, budget).map(({id}) => id)),
    {sketchyPerPost: 2, blockedTags: []}, {...d, details});
  assert.deepEqual(content?.source.ids, candidates.slice(budget, budget + 3).map(({id}) => id));
  assert.equal(details.mock.callCount(), 3, "excluded ids do not consume the detail budget");
});

test("new toplist pages cannot starve the original weekly fallback of its detail budget", async (t) => {
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const query = new URL(String(input)).searchParams;
    const weekly = query.get("topRange") === "1w";
    const second = query.get("page") === "2";
    const count = second ? 24 : weekly ? 3 : 12;
    const prefix = second ? "reject2" : weekly ? "safe" : "reject1";
    return {ok: true, json: async () => ({data: Array.from({length: count}, (_, i) =>
      ({id: `${prefix}${i}`, purity: "sfw"}))})} as Response;
  });
  const candidates = await wallhavenCandidates();
  const d = await gridDeps(candidates, Object.fromEntries(candidates.filter(({id}) => id.startsWith("reject"))
    .map(({id}) => [id, ["loli"]])));
  const details = t.mock.fn(d.details);
  const content = await gridContent("2026-11-12", new Set(), {sketchyPerPost: 2, blockedTags: []}, {...d, details});
  assert.deepEqual(content?.source.ids, ["safe0", "safe1", "safe2"]);
  assert.equal(details.mock.callCount(), 15);
});

test("caption lists hold 14 lines, no grid or panorama line repeats, and every caption fits on X", () => {
  for (const lines of [GRID_LINES, PANORAMA_LINES, STILL_TAILS, DARK_STILL_TAILS]) assert.equal(lines.length, 14);
  for (const lines of [GRID_LINES, PANORAMA_LINES]) assert.equal(new Set(lines).size, 14);
  for (const line of [...GRID_LINES, ...PANORAMA_LINES]) assert.ok(xWeightedLength(line) <= 280, line);
  assert.ok(!GRID_LINES.some((line) => /https?:|#/.test(line)), "grid captions carry no link or hashtag");
});

test("still captions are the lowercase title over a tail, and only dark walls get AMOLED tags", () => {
  const days = Array.from({length: 14}, (_, i) => `2026-11-${String(10 + i).padStart(2, "0")}`);
  const light = days.map((day) => stillCaption("Rose Arch · Sunrise", day, 0, false));
  const dark = days.map((day) => stillCaption("Deep Lure · Jade", day, 0, true));
  assert.ok(light.every((text) => text.startsWith("rose arch · sunrise")));
  assert.ok(!light.some((text) => /amoled|oled/i.test(text)), "a light wall never claims AMOLED");
  assert.ok(dark.some((text) => text.includes("#amoled")));
  assert.ok(light.includes("rose arch · sunrise"), "some posts are the title alone");
  // Two stills on one day (eve salt 0, night salt 1) never share a tail line unless both are blank.
  for (const day of days) {
    const [a, b] = [stillCaption("X", day, 0, true), stillCaption("X", day, 1, true)];
    assert.ok(a !== b || a === "x");
  }
});

test("stillContent ignores malformed titles and supports non-Studio WOTD walls", async (t) => {
  const day = "2026-11-15";
  const store = installSocialDb(t);
  const jpeg = await sharp({create: {width: 4, height: 6, channels: 3, background: "black"}}).jpeg().toBuffer();
  t.mock.method(globalThis, "fetch", async () => new Response(new Uint8Array(jpeg)));
  for (const origin of ["studio", "user"]) {
    for (const title of [undefined, null, 42, {name: "Bad title"}, "", "  ", "Deep Lure · Jade"]) {
      store.set("walls/W1", {review: true, origin, title, aiPrompt: "Quiet water, at night", wallpaper_url: "https://example.test/wall.jpg"});
      store.set("wall_of_the_day/current", {wallId: "W1", date: ts(Date.parse(`${day}T00:00:00Z`))});
      const content = await stillContent(day, new Set(), {wotd: true, salt: 0});
      assert.ok(content);
      const expected = typeof title === "string" && title.trim() ? title.toLowerCase() :
        origin === "studio" ? "quiet water" : "wall of the day";
      assert.equal(content.text, `wall of the day ✨\n${expected}\nlock screen or home screen?`);
      assertFits(content);
    }
  }
});

test("still and WOTD captions bound long titles by weighted length without splitting code points", async (t) => {
  const day = "2026-11-15";
  const store = installSocialDb(t);
  const jpeg = await sharp({create: {width: 4, height: 6, channels: 3, background: "black"}}).jpeg().toBuffer();
  t.mock.method(globalThis, "fetch", async () => new Response(new Uint8Array(jpeg)));
  for (const title of ["A".repeat(300), "山".repeat(150), "🌌".repeat(150)]) {
    store.set("walls/W1", {review: true, title, wallpaper_url: "https://example.test/wall.jpg"});
    store.set("wall_of_the_day/current", {wallId: "W1", date: ts(Date.parse(`${day}T00:00:00Z`))});
    const content = await stillContent(day, new Set(), {wotd: true, salt: 0});
    assert.ok(content);
    assertFits(content);
    assert.ok(content.text.endsWith("\nlock screen or home screen?"));
    assert.ok(!/\p{Cs}/u.test(content.text), "no broken surrogate pair");
    for (let salt = 0; salt < 14; salt++) {
      for (const dark of [false, true]) {
        const text = stillCaption(title, day, salt, dark);
        assertFits({...content, text});
        assert.ok(!/\p{Cs}/u.test(text));
      }
    }
  }
});

test("approval hashes and reconciliation preserve multiline captions, punctuation, emoji and hashtags", async (t) => {
  const text = "deep lure · jade ✨ & <light>\n#amoled #wallpaper";
  const post = postDoc({text, replyText: "", approval: {required: true}});
  const store = installSocialDb(t, {[PATH]: {...post, status: "pending_approval"}});
  await applyPress({...press("approve", String(post.contentHash).slice(0, 12)), postId: PATH.split("/")[1]});
  assert.equal((store.get(PATH)?.approval as Doc).approvedHash, post.contentHash);
  const {x, creates} = fakeX({
    create: async () => {
      throw new XError("x", 0, true);
    },
    own: () => [{id: "T9", text: "deep lure · jade ✨ &amp; &lt;light&gt;\n#amoled #wallpaper\nhttps://t.co/xyz",
      createdAt: NOW.toISOString(), mediaCount: 1, mediaIds: ["M1"], replyTo: null}],
  });
  await publishDue(deps(x, NOW));
  await publishDue(deps(x, later(11)));
  assert.equal(store.get(PATH)?.status, "posted");
  assert.equal(store.get(PATH)?.tweetId, "T9");
  assert.equal(creates.length, 1);
  assert.equal(creates[0].text, text);
  assert.notEqual(contentHash([sha(BYTES)], text.replace("\n", " "), ""), contentHash([sha(BYTES)], text, ""));
});

test("a failed page-2 search keeps the page-1 walls; a failed page-1 search still fails", async (t) => {
  let failPage = "2";
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const query = new URL(String(input)).searchParams;
    if (query.get("page") === failPage) return {ok: false, status: 429, json: async () => ({})} as Response;
    return {ok: true, json: async () => ({data: [{id: `${query.get("topRange")}p${query.get("page")}`, purity: "sfw"}]})} as
      Response;
  });
  assert.deepEqual((await wallhavenCandidates()).map(({id}) => id), ["3dp1", "1wp1"]);
  failPage = "1";
  await assert.rejects(wallhavenCandidates());
});

test("a pool where the first 15 candidates fail still fills the grid", async () => {
  const candidates = Array.from({length: 20}, (_, i) => ({id: `c${i}`, purity: "sketchy"}));
  const d = await gridDeps(candidates, Object.fromEntries(candidates.slice(0, 16).map(({id}) => [id, ["loli"]])));
  const content = await gridContent("2026-11-12", new Set(), {sketchyPerPost: 3, blockedTags: []}, d);
  assert.deepEqual(content?.source.ids, ["c16", "c17", "c18"]);
});

test("Grid checks documents the current adult thresholds", () => {
  const docs = readFileSync(resolve(__dirname, "../../../docs/features/x-posting.md"), "utf8")
    .split("## Grid checks\n")[1].split("\n## ")[0];
  assert.ok(docs.includes("`adult` VERY_LIKELY rejects"));
  assert.ok(docs.includes("**Approve + flag**"));
  assert.ok(!docs.includes("`adult` POSSIBLE or LIKELY sets X's sensitive flag"));
  assert.ok(!docs.includes("`adult` POSSIBLE or higher rejects"));
});

test("Wallhaven never requests NSFW and caps a rejection-heavy run at 34 API calls", async (t) => {
  const requests: URL[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const url = new URL(String(input));
    assert.equal(url.origin, "https://wallhaven.cc");
    requests.push(url);
    if (url.pathname.endsWith("/search")) {
      assert.equal(url.searchParams.get("purity"), "110");
      return Response.json({data: [{id: "nsfw", purity: "nsfw"},
        ...Array.from({length: 40}, (_, i) => ({id: `w${i}`, purity: "sfw"}))]});
    }
    return Response.json({data: {purity: "sfw", tags: [{name: "loli"}]}});
  });
  const candidates = await wallhavenCandidates();
  assert.ok(!candidates.some(({id}) => id === "nsfw"));
  const d = await gridDeps(candidates);
  assert.equal(await gridContent("2026-11-12", new Set(), {sketchyPerPost: 2, blockedTags: []},
    {...d, details: wallhavenDetails}), null);
  assert.equal(requests.filter((url) => url.pathname.endsWith("/search")).length, 4);
  assert.equal(requests.filter((url) => url.pathname.includes("/w/")).length, 30);
  assert.equal(requests.length, 34);
  assert.ok(requests.length < 45);
});

test("grid rejects NSFW or changed detail purity before downloading", async (t) => {
  const d = await gridDeps([{id: "bad", purity: "sfw"}, {id: "s1", purity: "sketchy"},
    {id: "s2", purity: "sketchy"}, {id: "s3", purity: "sketchy"},
    {id: "w1", purity: "sfw"}, {id: "w2", purity: "sfw"}]);
  for (const purity of ["nsfw", "sketchy", "unknown"]) {
    const download = t.mock.fn(d.download);
    const content = await gridContent("2026-11-12", new Set(), {sketchyPerPost: 1, blockedTags: []}, {...d,
      download, details: async (id) => ({...await d.details(id), ...(id === "bad" ? {purity} : {})})});
    assert.deepEqual(content?.source.ids, ["s1", "w1", "w2"]);
    assert.equal(download.mock.callCount(), 3);
  }
});

test("Approve + flag flags the suggested images, reaches X, and metadata errors block posting", async (t) => {
  const d = await gridDeps([{id: "s1", purity: "sketchy"}, {id: "s2", purity: "sketchy"},
    {id: "w1", purity: "sfw"}]);
  for (const failure of [0, 400, 429, 500, "network"] as const) {
    await t.test(String(failure), async (t) => {
      const store = installSocialDb(t);
      const captions: string[] = [];
      const cfg = config({slots: {am: true, noon: false, set: false, eve: false, night: false}});
      const stored = new Map<string, Buffer>();
      const metadata: Array<{metadata: {sensitive_media_warning?: {adult_content: boolean}}}> = [];
      let uploads = 0;
      let creates = 0;
      const x = xClient({apiKey: "a", apiSecret: "s", token: "t", tokenSecret: "s"}, async (input, init) => {
        const path = new URL(String(input)).pathname;
        if (path === "/2/media/upload") return Response.json({data: {id: `M${++uploads}`}});
        if (path === "/2/media/metadata") {
          const body = JSON.parse(String(init?.body));
          metadata.push(body);
          // Fail on the second sensitive image, after the first flag already succeeded.
          if (metadata.length === 2 && failure) {
            if (failure === "network") throw new Error("offline");
            return new Response("refused", {status: failure});
          }
          return Response.json({});
        }
        assert.equal(path, "/2/tweets");
        creates++;
        assert.deepEqual(JSON.parse(String(init?.body)).media.media_ids, ["M1", "M2", "M3"]);
        return Response.json({data: {id: "T1"}});
      });
      const tg: Telegram = {sendPhotos: async (caption) => {
        captions.push(caption);
      },
      sendText: async () => undefined, sendButtons: async () => undefined, answer: async () => undefined,
      markDone: async () => undefined, setWebhook: async () => undefined};
      const run: SocialDeps = {...deps(x, NOW, cfg), telegram: tg, storage: {
        put: async (_bucket, key, bytes) => {
          stored.set(key, bytes);
          return true;
        },
        get: async (_bucket, key) => {
          const bytes = stored.get(key);
          assert.ok(bytes);
          return Buffer.from(bytes);
        },
      }};
      let checked = 0;
      const made = await prepareDay(run, {grid: (day, exclude) => gridContent(day, exclude, cfg, {...d,
        annotate: async () => ({safeSearchAnnotation: {adult: ["POSSIBLE", "LIKELY", "VERY_UNLIKELY"][checked++],
          racy: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", medical: "VERY_UNLIKELY"}}) as never}),
      panorama: async () => null, still: async () => null, set: async () => null});
      assert.equal(made.length, 1);
      const path = `socialPosts/${made[0]}`;
      const post = store.get(path);
      assert.ok(post);
      const media = post.media as Array<{sha256: string; alt: string; sensitive: boolean}>;
      // Vision only suggests. Nothing is flagged until the owner says so.
      assert.deepEqual(media.map((m) => m.sensitive), [false, false, false]);
      assert.ok(captions[0].includes("Vision suggests a flag on: 2 of 3"));
      const previewHash = String(post.contentHash);
      assert.equal(await applyPress({...press("flag", previewHash.slice(0, 12)), postId: made[0]}), "Approved with flag.");
      const flagged = store.get(path) as Doc;
      const flaggedMedia = flagged.media as Array<{sha256: string; alt: string; sensitive: boolean}>;
      assert.deepEqual(flaggedMedia.map((m) => m.sensitive), [true, true, false]);
      assert.equal(flagged.contentHash, contentHash(flaggedMedia.map((m) => m.sha256), String(post.text), "",
        flaggedMedia.map(({alt, sensitive}) => ({alt, sensitive}))));
      assert.notEqual(flagged.contentHash, previewHash);
      assert.equal((flagged.approval as Doc).approvedHash, flagged.contentHash);
      // The old buttons no longer match the flagged content.
      assert.equal(await applyPress({...press("approve", previewHash.slice(0, 12)), postId: made[0]}),
        "This post changed or is gone.");
      store.set(path, {...store.get(path), scheduledAt: ts(NOW.getTime())});
      await publishDue(run);
      assert.deepEqual(metadata.slice(0, 2).map((m) => m.metadata.sensitive_media_warning),
        [{adult_content: true}, {adult_content: true}]);
      assert.equal(creates, failure ? 0 : 1);
      assert.equal(store.get(path)?.status, failure === 400 ? "failed" : failure ? "approved" : "posted");
      if (!failure) assert.equal(metadata[2].metadata.sensitive_media_warning, undefined);
    });
  }
});

test("the grid stops at its deadline, even with a check in flight", async () => {
  const candidates = Array.from({length: 10}, (_, i) => ({id: `s${i}`, purity: "sfw"}));
  const d = await gridDeps(candidates);
  let downloads = 0;
  const slow = {...d, deadlineMs: 50, download: async () => {
    // The first download passes; the second hangs far past the deadline.
    if (++downloads === 1) return d.download();
    return new Promise<Buffer>(() => undefined);
  }};
  const started = Date.now();
  assert.equal(await gridContent("2026-11-12", new Set(), {sketchyPerPost: 2, blockedTags: []}, slow), null);
  assert.ok(Date.now() - started < 2000, "returned at the deadline, not after the hanging download");
  assert.equal(downloads, 2);
});

test("flag approval rejects stored content changed since the preview", async (t) => {
  const original = postDoc({pipeline: "grid", status: "pending_approval", replyText: ""});
  const store = installSocialDb(t, {[PATH]: {...original, text: "not the previewed text"}});
  const before = store.get(PATH);
  assert.equal(await applyPress({...press("flag", String(original.contentHash).slice(0, 12)),
    postId: PATH.split("/")[1]}), "This post changed or is gone.");
  assert.deepEqual(store.get(PATH), before);
});

test("legacy grid preview retries show existing flags and plain approval preserves them", async (t) => {
  const original = postDoc({pipeline: "grid", status: "pending_approval", replyText: "",
    media: [{r2Key: "social/a.jpg", sha256: sha(BYTES), bytes: BYTES.length, alt: "alt", sensitive: true}],
    approval: {required: true}});
  const store = installSocialDb(t, {[PATH]: original});
  const captions: string[] = [];
  const buttons: Parameters<Telegram["sendButtons"]>[1][] = [];
  const tg: Telegram = {sendPhotos: async (caption) => {
    captions.push(caption);
  }, sendButtons: async (_text, choices) => {
    buttons.push(choices);
    if (buttons.length === 1) throw new Error("offline");
  }, sendText: async () => undefined, answer: async () => undefined,
  markDone: async () => undefined, setWebhook: async () => undefined};
  const run = {...deps(null, NOW), telegram: tg};
  await publishDue(run);
  assert.equal(store.get(PATH)?.previewSentAt, undefined);
  await publishDue(run);
  assert.ok(store.get(PATH)?.previewSentAt);
  assert.ok(captions.every((caption) => caption.includes("Sensitive flags: 1")));
  assert.ok(captions.every((caption) => caption.includes("Vision suggests a flag on: 0 of 1")));
  assert.deepEqual(buttons[1].map((b) => [b.label, b.action]),
    [["Approve", "approve"], ["Approve + flag", "flag"], ["Skip", "skip"]]);
  for (const b of buttons[1]) {
    const data = callbackData(b.action, b.postId, b.hash);
    assert.ok(Buffer.byteLength(data) <= 64);
    assert.equal(parsePress(pressUpdate(data), "42")?.action, b.action);
  }
  await applyPress({...press("approve", String(original.contentHash).slice(0, 12)), postId: PATH.split("/")[1]});
  assert.equal(store.get(PATH)?.contentHash, original.contentHash);
  const {x, creates} = fakeX();
  const metadata: boolean[] = [];
  x.setMediaMetadata = async (_id, _alt, sensitive) => {
    metadata.push(sensitive);
  };
  await publishDue(deps(x, NOW));
  assert.deepEqual(metadata, [true]);
  assert.equal(creates.length, 1);
});

test("flag and plain approval races keep the first decision and its matching hash", async (t) => {
  for (const first of ["flag", "approve"] as const) {
    await t.test(first, async (t) => {
      const post = postDoc({pipeline: "grid", status: "pending_approval", replyText: ""});
      const store = installSocialDb(t, {[PATH]: post});
      const makePress = (action: "approve" | "flag" | "skip") =>
        ({...press(action, String(post.contentHash).slice(0, 12)), postId: PATH.split("/")[1]});
      const results = await Promise.all([applyPress(makePress(first)),
        applyPress(makePress(first === "flag" ? "approve" : "flag"))]);
      assert.equal(results[0], first === "flag" ? "Approved with flag." : "Approved.");
      assert.match(results[1], first === "flag" ? /changed or is gone/ : /Nothing to do/);
      const decided = store.get(PATH) as Doc;
      assert.equal((decided.approval as Doc).approvedHash, decided.contentHash);
      assert.equal((decided.media as Doc[])[0].sensitive, first === "flag");
      if (first === "flag") {
        for (const action of ["approve", "flag", "skip"] as const) {
          assert.equal(await applyPress(makePress(action)), "This post changed or is gone.");
        }
        assert.deepEqual(store.get(PATH), decided);
      }
      const {x, creates} = fakeX();
      await publishDue(deps(x, NOW, config({dryRun: true})));
      assert.equal(store.get(PATH)?.status, "dry_run");
      assert.equal(creates.length, 0);
    });
  }
});

test("flag is a no-op for every non-pending state and for non-grids", async (t) => {
  const store = installSocialDb(t);
  for (const pipeline of ["grid", "panorama", "still"]) {
    for (const status of ["pending_approval", "approved", "posting", "posted", "uncertain", "skipped", "failed", "dry_run"]) {
      if (pipeline === "grid" && status === "pending_approval") continue;
      const post = postDoc({pipeline, status});
      store.set(PATH, post);
      assert.match(await applyPress({...press("flag", String(post.contentHash).slice(0, 12)),
        postId: PATH.split("/")[1]}), /^Nothing to do/);
      assert.deepEqual(store.get(PATH), post);
    }
  }
});

// ---------- weekly themed set and themed stills ----------

/** Wallhaven deps where every id downloads its own noise image, except ids listed in `same` share one picture. */
async function themeDeps(candidates: Array<{id: string; purity: string}>, opts: {same?: string[];
  flagHint?: string[]} = {}) {
  const shared = await sharp({create: {width: 90, height: 160, channels: 3, background: {r: 0, g: 0, b: 0},
    noise: {type: "gaussian", mean: 128, sigma: 60}}}).jpeg().toBuffer();
  const images = new Map<string, Buffer>();
  for (const {id} of candidates) {
    images.set(id, opts.same?.includes(id) ? shared : await sharp({create: {width: 90, height: 160, channels: 3,
      background: {r: 0, g: 0, b: 0}, noise: {type: "gaussian", mean: 128, sigma: 60}}}).jpeg().toBuffer());
  }
  const queries: string[] = [];
  return {
    queries,
    candidates: async (query: string) => {
      queries.push(query);
      return candidates;
    },
    details: async (id: string): Promise<WallhavenWall> => ({id, purity: candidates.find((c) => c.id === id)?.purity ?? "sfw",
      path: `https://w.wallhaven.cc/full/${id}.jpg`, tags: ["landscape"]}),
    download: async (url: string) => images.get(url.split("/").pop()!.replace(".jpg", ""))!,
    annotate: async (jpeg: Buffer) => ({safeSearchAnnotation: {adult: opts.flagHint?.some((id) => images.get(id) === jpeg) ?
      "POSSIBLE" : "VERY_UNLIKELY", racy: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", medical: "VERY_UNLIKELY"}}) as never,
  };
}

test("a set takes 12 SFW walls of one theme, without flag hints, sketchy walls or re-uploads", async () => {
  const candidates = [{id: "k1", purity: "sketchy"}, ...Array.from({length: 20}, (_, i) => ({id: `w${i}`, purity: "sfw"}))];
  const d = await themeDeps(candidates, {same: ["w0", "w1"], flagHint: ["w2"]});
  const content = await setContent("2026-11-14", new Set(["w3"]), {blockedTags: []}, d);
  assert.ok(content);
  assert.equal(content.pipeline, "set");
  assert.equal(content.media.length, SET_SIZE);
  for (const id of ["k1", "w1", "w2", "w3"]) assert.ok(!content.source.ids.includes(id), id);
  assert.ok(content.source.ids.includes("w0"), "the first copy of a re-upload stays");
  assert.ok(content.media.every((m) => m.sensitive === false && !m.suggestFlag));
  const theme = rotate(THEMES, "2026-11-14");
  assert.deepEqual(d.queries, [theme.query]);
  assert.equal(content.text, `12 ${theme.name} wallpapers\nwhich one is yours? 👇`);
  assertFits(content);

  // Fewer than SET_MIN passing walls makes no set.
  const few = await themeDeps(Array.from({length: SET_MIN - 1}, (_, i) => ({id: `f${i}`, purity: "sfw"})));
  assert.equal(await setContent("2026-11-14", new Set(), {blockedTags: []}, few), null);
});

test("Saturdays rotate through every theme before one repeats", () => {
  const saturdays = Array.from({length: THEMES.length}, (_, i) =>
    new Date(Date.parse("2026-11-14T00:00:00Z") + i * 7 * 86_400_000).toISOString().slice(0, 10));
  assert.equal(new Set(saturdays.map((day) => rotate(THEMES, day).name)).size, THEMES.length);
});

test("theme searches ask Wallhaven for SFW portrait walls by all-time favourites", async (t) => {
  const requests: URL[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    requests.push(new URL(String(input)));
    return {ok: true, json: async () => ({data: [{id: "a1", purity: "sfw"}, {id: "n1", purity: "nsfw"}]})} as Response;
  });
  assert.deepEqual(await wallhavenThemeCandidates("sunset -women"), [{id: "a1", purity: "sfw"}]);
  assert.deepEqual(requests.map((url) => [url.searchParams.get("q"), url.searchParams.get("purity"),
    url.searchParams.get("sorting"), url.searchParams.get("ratios"), url.searchParams.get("page")]),
  [["sunset -women", "100", "favorites", "portrait", "1"], ["sunset -women", "100", "favorites", "portrait", "2"]]);
});

test("a themed still is the top unposted wall of a theme other than the set's", async () => {
  const d = await themeDeps([{id: "top", purity: "sfw"}, {id: "next", purity: "sfw"}], {flagHint: ["next"]});
  const day = "2026-11-14";
  const eve = await themedStillContent(day, new Set(), {blockedTags: []}, 0, d);
  assert.deepEqual(eve?.source, {kind: "wallhaven", ids: ["top"], tags: ["landscape"]});
  assert.ok(eve?.text.startsWith(rotate(THEMES, day, 3).name));
  assert.equal(await themedStillContent(day, new Set(["top"]), {blockedTags: []}, 1, d), null,
    "a wall with a flag hint never becomes a still");
  const themes = [rotate(THEMES, day).query, rotate(THEMES, day, 3).query, rotate(THEMES, day, 5).query];
  assert.equal(new Set(themes).size, 3);
  assert.deepEqual(d.queries, themes.slice(1));
});

test("the set slot runs on Saturdays only, and every Wallhaven post waits for approval", async (t) => {
  const store = installSocialDb(t);
  const slots: string[] = [];
  const build = (kind: "prism" | "wallhaven") => async (_day: string, _exclude: Set<string>, slot: string) => {
    slots.push(slot);
    return {pipeline: "still" as const, source: {kind, ids: [`W-${slot}`]},
      media: [{jpeg: BYTES, alt: "alt", sensitive: false}], text: "wall", replyText: ""};
  };
  const builders = {grid: build("wallhaven"), panorama: build("prism"), still: build("wallhaven"), set: build("wallhaven")};
  await prepareDay(deps(null, NOW), builders);
  assert.deepEqual(slots, ["am", "noon", "eve", "night"], "Thursday has no set");
  slots.length = 0;
  // Friday's 22:00 run prepares Saturday, set included.
  await prepareDay(deps(null, new Date("2026-11-13T22:00:00+05:30")), builders);
  assert.deepEqual(slots, ["am", "noon", "set", "eve", "night"]);
  assert.equal(store.get("socialPosts/2026-11-14_set")?.status, "pending_approval");
  assert.equal(store.get("socialPosts/2026-11-14_eve")?.status, "pending_approval", "a Wallhaven still needs the owner");
  assert.equal(store.get("socialPosts/2026-11-14_noon")?.status, "approved", "auto-approved Prism posts stay so");
  const at = (store.get("socialPosts/2026-11-14_set")?.scheduledAt as admin.firestore.Timestamp).toMillis();
  assert.ok(Math.abs(at - Date.parse("2026-11-14T15:00:00+05:30")) <= JITTER_MS);
});

test("the still builder falls back to a Studio wall when Wallhaven fails", async (t) => {
  const store = installSocialDb(t);
  const jpeg = await sharp({create: {width: 4, height: 6, channels: 3, background: "black"}}).jpeg().toBuffer();
  store.set("walls/S1", {review: true, origin: "studio", title: "Deep Lure · Jade", aiPrompt: "Quiet water",
    wallpaper_url: "https://example.test/wall.jpg"});
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) =>
    String(input).startsWith("https://wallhaven.cc") ? new Response("busy", {status: 429}) :
      new Response(new Uint8Array(jpeg)));
  const content = await defaultBuilders.still("2026-11-12", new Set(), "eve", config());
  assert.deepEqual(content?.source, {kind: "prism", ids: ["S1"]});
});

test("Telegram splits a set into even albums with the caption on the first", async () => {
  const calls: Array<{method: string; form: FormData}> = [];
  const client = telegramClient("T", "42", async (url, init) => {
    calls.push({method: String(url).split("/").pop()!, form: init?.body as FormData});
    return new Response(JSON.stringify({ok: true, result: {}}));
  });
  const photos = Array.from({length: 11}, (_, i) => Buffer.from(`p${i}`));
  await client.sendPhotos("caption", photos);
  assert.deepEqual(calls.map((c) => c.method), ["sendMediaGroup", "sendMediaGroup"]);
  const media = calls.map((c) => JSON.parse(String(c.form.get("media"))));
  assert.deepEqual(media.map((m) => m.length), [6, 5]);
  assert.equal(media[0][0].caption, "caption");
  assert.ok(media.flat().filter((m) => m.caption).length === 1);
  calls.length = 0;
  await client.sendPhotos("one", [Buffer.from("x")]);
  assert.deepEqual(calls.map((c) => c.method), ["sendPhoto"]);
  assert.equal(calls[0].form.get("caption"), "one");
});
