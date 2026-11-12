import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {aiCommunityId} from "../aiWallSource";
import {uploadFileKey, uploadPathKey} from "../completedWallUpload";
import {isGithubRawUrl, onWallSubmitted} from "../onWallSubmitted";
import {removeRemixOfIfUnchanged} from "../wallRemix";
import {type Doc, installFakeDb} from "./fakeDb";

const RAW = "https://raw.githubusercontent.com/owner/walls/main";

function setup(t: TestContext, owner: Doc | null, wall: Doc) {
  t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "maker", email: "maker@example.com", emailVerified: true}));
  const store = installFakeDb(t, {
    "walls/w1": wall,
    ...(owner ? {"usersv2/maker": {email: "maker@example.com", ...owner}} : {}),
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
    "usersv2/adm1/private/session": {
      fcmToken: "admin-token", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "admin-token",
    },
  });
  const pushes: Array<{token?: string; notification?: {title?: string; body?: string}; data?: Record<string, string>; android?: {notification?: {imageUrl?: string}}}> = [];
  t.mock.method(admin.messaging(), "send", async (message: typeof pushes[number]) => {
    pushes.push(message);
    return "id";
  });
  return {store, pushes};
}

const fire = async (store: Map<string, Doc>) => {
  const snapshot = await db.doc("walls/w1").get();
  return onWallSubmitted.run({
    params: {wallId: "w1"},
    data: {...snapshot, data: () => store.get("walls/w1")},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
};

const wall = (extra: Doc = {}): Doc => ({
  email: "maker@example.com", by: "Fake Admin", userPhoto: "https://evil.example/p.png", review: false,
  wallpaper_url: `${RAW}/a.jpg`, wallpaper_thumb: `${RAW}/thumb_a.jpg`, ...extra,
});

test("the submission trigger binds STUDIO_SECRET and the R2 secrets", () => {
  assert.deepEqual(onWallSubmitted.__endpoint.secretEnvironmentVariables?.map(({key}) => key),
    ["STUDIO_SECRET", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY"]);
  assert.equal(onWallSubmitted.__endpoint.availableMemoryMb, 512);
  assert.equal(onWallSubmitted.__endpoint.concurrency, 1);
  assert.equal(onWallSubmitted.__endpoint.eventTrigger?.retry, true);
});

test("by and userPhoto are rewritten from the owner's profile", async (t) => {
  const {store} = setup(t, {name: "Real Maker", username: "RealMaker", profilePhoto: "https://p/real.png", premium: true}, wall());
  await fire(store);
  assert.equal(store.get("walls/w1")?.by, "Real Maker");
  assert.equal(store.get("walls/w1")?.userPhoto, "https://p/real.png");
});

test("the username fills in when the profile has no name, and nothing is written when both match", async (t) => {
  const first = setup(t, {username: "RealMaker", profilePhoto: "https://p/real.png"}, wall());
  await fire(first.store);
  assert.equal(first.store.get("walls/w1")?.by, "RealMaker");

  const updates: Doc[] = [];
  const matching = installFakeDb(t, {
    "usersv2/maker": {email: "maker@example.com", name: "Real Maker", profilePhoto: "https://p/real.png"},
  });
  const sameWall = wall({by: "Real Maker", userPhoto: "https://p/real.png"});
  matching.set("walls/w1", sameWall);
  await onWallSubmitted.run({
    params: {wallId: "w1"},
    data: {data: () => sameWall, ref: {update: async (update: Doc) => updates.push(update)}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.deepEqual(updates, []);
});

test("a wall of an unknown owner keeps its fields", async (t) => {
  const {store} = setup(t, null, wall());
  await fire(store);
  assert.equal(store.get("walls/w1")?.by, "Fake Admin");
});

test("a premium submission notifies the admins and a free one does not", async (t) => {
  const premium = setup(t, {name: "Maker", premium: true}, wall());
  await fire(premium.store);
  assert.deepEqual(premium.pushes.map((push) => push.token), ["admin-token"]);
  assert.deepEqual(premium.pushes[0].data, {route: "content_report", channel_id: "posts", push_kind: "moderation"});
  assert.deepEqual(premium.pushes[0].notification, {title: "Moderation update", body: "Open Prism to review."});
  assert.equal(premium.pushes[0].android?.notification?.imageUrl, undefined);

  const free = setup(t, {name: "Maker", premium: false}, wall());
  await fire(free.store);
  assert.deepEqual(free.pushes, []);
});

test("an image link outside the GitHub raw host is stripped", async (t) => {
  const {store} = setup(t, {name: "Maker", premium: true}, wall({wallpaper_url: "https://evil.example/a.jpg"}));
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, "");
});

function withGithubRepo(t: TestContext, values: {GH_REPO_WALLS?: string | null; GH_USERNAME?: string | null} = {}) {
  const previous = {GH_REPO_WALLS: process.env.GH_REPO_WALLS, GH_USERNAME: process.env.GH_USERNAME};
  if (values.GH_REPO_WALLS === null) delete process.env.GH_REPO_WALLS;
  else process.env.GH_REPO_WALLS = values.GH_REPO_WALLS ?? "walls";
  if (values.GH_USERNAME === null) delete process.env.GH_USERNAME;
  else process.env.GH_USERNAME = values.GH_USERNAME ?? "owner";
  t.after(() => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
}

function stillProof(path: string, sha: string, url: string, uid = "maker"): Record<string, Doc> {
  const file = {path, sha, sourceKind: "github" as const};
  const record = {
    uid, repo: "walls", path, sha, sourceKind: "github", generation: "generation-1",
    weeklyQuotaCharged: true, uploadWeek: "2026-W01",
    createdAt: admin.firestore.Timestamp.fromMillis(1),
  };
  return {
    [`githubUploads/${uploadFileKey("walls", file)}`]: record,
    [`githubUploadIntents/${uploadPathKey("walls", file)}`]: {
      ...record, status: "complete", blobSha: sha, uploadId: `upload-${path}`,
      response: {sourceKind: "github", content: {path, sha, download_url: url}},
    },
  };
}

test("a still wall keeps GitHub raw images that match the caller's completed upload intents", async (t) => {
  withGithubRepo(t);
  const sha = "a".repeat(40);
  const thumbSha = "b".repeat(40);
  const originalUrl = `${RAW}/a.jpg`;
  const thumbUrl = `${RAW}/thumb_a.jpg`;
  const {store} = setup(t, {name: "Maker"}, wall({
    wallpaper_url: originalUrl, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: thumbUrl, thumb_path: "thumb_a.jpg", thumb_sha: thumbSha, thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries({
    ...stillProof("a.jpg", sha, originalUrl),
    ...stillProof("thumb_a.jpg", thumbSha, thumbUrl),
  })) store.set(key, value);
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, originalUrl);
  assert.equal(store.get("walls/w1")?.wallpaper_thumb, thumbUrl);
  assert.equal(store.get("walls/w1")?.wallpaper_path, "a.jpg");
  assert.equal(store.get("walls/w1")?.thumb_path, "thumb_a.jpg");
});

test("an AI flag with a non-Worker generation id does not skip still-upload proof", async (t) => {
  withGithubRepo(t);
  const {store} = setup(t, {name: "Maker"}, wall({isAiGenerated: true, aiGenerationId: "gen_notasource"}));
  await fire(store);
  const current = store.get("walls/w1")!;
  assert.equal(current.wallpaper_url, "");
  assert.equal(current.wallpaper_path, "");
  assert.equal(current.wallpaper_sha, "");
  assert.equal(current.wallpaper_thumb, "");
  assert.equal(current.thumb_path, "");
  assert.equal(current.thumb_sha, "");
});

test("a still wall strips GitHub raw images when the walls repo is not configured", async (t) => {
  withGithubRepo(t, {GH_REPO_WALLS: null});
  const sha = "a".repeat(40);
  const {store} = setup(t, {name: "Maker"}, wall({
    wallpaper_url: `${RAW}/a.jpg`, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: `${RAW}/thumb_a.jpg`, thumb_path: "thumb_a.jpg", thumb_sha: "b".repeat(40),
    thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries({
    ...stillProof("a.jpg", sha, `${RAW}/a.jpg`),
    ...stillProof("thumb_a.jpg", "b".repeat(40), `${RAW}/thumb_a.jpg`),
  })) store.set(key, value);
  await fire(store);
  const current = store.get("walls/w1")!;
  assert.equal(current.wallpaper_url, "");
  assert.equal(current.wallpaper_path, "");
  assert.equal(current.wallpaper_sha, "");
  assert.equal(current.wallpaper_thumb, "");
});

test("a still wall strips GitHub raw images when the GitHub username is not configured", async (t) => {
  withGithubRepo(t, {GH_USERNAME: null});
  const sha = "a".repeat(40);
  const {store} = setup(t, {name: "Maker"}, wall({
    wallpaper_url: `${RAW}/a.jpg`, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: `${RAW}/thumb_a.jpg`, thumb_path: "thumb_a.jpg", thumb_sha: "b".repeat(40),
    thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries({
    ...stillProof("a.jpg", sha, `${RAW}/a.jpg`),
    ...stillProof("thumb_a.jpg", "b".repeat(40), `${RAW}/thumb_a.jpg`),
  })) store.set(key, value);
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, "");
  assert.equal(store.get("walls/w1")?.wallpaper_thumb, "");
});

test("a still wall strips a GitHub raw URL whose owner is not the configured walls owner", async (t) => {
  withGithubRepo(t);
  const sha = "a".repeat(40);
  const foreign = "https://raw.githubusercontent.com/evil/walls/main/a.jpg";
  const {store} = setup(t, {name: "Maker"}, wall({
    wallpaper_url: foreign, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: `${RAW}/thumb_a.jpg`, thumb_path: "thumb_a.jpg", thumb_sha: "b".repeat(40),
    thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries({
    ...stillProof("a.jpg", sha, `${RAW}/a.jpg`),
    ...stillProof("thumb_a.jpg", "b".repeat(40), `${RAW}/thumb_a.jpg`),
  })) store.set(key, value);
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, "");
  assert.equal(store.get("walls/w1")?.wallpaper_path, "");
  assert.equal(store.get("walls/w1")?.wallpaper_thumb, `${RAW}/thumb_a.jpg`);
});

test("a still wall strips GitHub raw images that have no path or sha", async (t) => {
  withGithubRepo(t);
  const {store} = setup(t, {name: "Maker"}, wall());
  await fire(store);
  const current = store.get("walls/w1")!;
  assert.equal(current.wallpaper_url, "");
  assert.equal(current.wallpaper_path, "");
  assert.equal(current.wallpaper_sha, "");
  assert.equal(current.wallpaper_thumb, "");
  assert.equal(current.thumb_path, "");
  assert.equal(current.thumb_sha, "");
});

test("a still wall strips GitHub raw images that have no caller-owned completed intent", async (t) => {
  withGithubRepo(t);
  const sha = "a".repeat(40);
  const {store} = setup(t, {name: "Maker"}, wall({
    wallpaper_url: `${RAW}/a.jpg`, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: `${RAW}/thumb_a.jpg`, thumb_path: "thumb_a.jpg", thumb_sha: "b".repeat(40),
    thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries(stillProof("a.jpg", sha, `${RAW}/a.jpg`, "attacker"))) {
    store.set(key, value);
  }
  await fire(store);
  const current = store.get("walls/w1")!;
  assert.equal(current.wallpaper_url, "");
  assert.equal(current.wallpaper_path, "");
  assert.equal(current.wallpaper_sha, "");
  assert.equal(current.wallpaper_thumb, "");
  assert.equal(current.thumb_path, "");
  assert.equal(current.thumb_sha, "");
});

test("only https links on raw.githubusercontent.com pass the host check", () => {
  assert.equal(isGithubRawUrl(`${RAW}/a.jpg`), true);
  assert.equal(isGithubRawUrl("http://raw.githubusercontent.com/o/r/m/a.jpg"), false);
  assert.equal(isGithubRawUrl("https://raw.githubusercontent.com.evil.example/a.jpg"), false);
  assert.equal(isGithubRawUrl("https://evil.example/raw.githubusercontent.com/a.jpg"), false);
  assert.equal(isGithubRawUrl("not a url"), false);
  assert.equal(isGithubRawUrl(undefined), false);
});

const GEN = "gen_mlt7o22q_7a9688a037a47de6";
const ASSETS = "https://prismwalls.com/api/ai/assets";
const aiRecord = {generationId: GEN, userId: "maker", width: 1179, height: 2048,
  imageUrl: `${ASSETS}/ai/original/${GEN}.png`, watermarkedImageUrl: `${ASSETS}/ai/public/${GEN}.png`};
const aiWall = (extra: Doc = {}) => wall({id: aiCommunityId(GEN), isAiGenerated: true, aiGenerationId: GEN,
  wallpaper_url: aiRecord.imageUrl, wallpaper_thumb: aiRecord.watermarkedImageUrl, ...extra});

function workerRecords(t: TestContext, response: () => Response) {
  const previous = process.env.STUDIO_SECRET;
  process.env.STUDIO_SECRET = "studio-secret";
  t.after(() => {
    if (previous === undefined) delete process.env.STUDIO_SECRET;
    else process.env.STUDIO_SECRET = previous;
  });
  const requests: Array<{url: string; secret: string | null}> = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    requests.push({url: String(input), secret: new Headers(init?.headers).get("x-studio-secret")});
    return response();
  });
  return requests;
}

test("a user AI wall gets a server receipt of its Worker record, and the first receipt stays", async (t) => {
  const requests = workerRecords(t, () => new Response(JSON.stringify(aiRecord), {status: 200}));
  const {store} = setup(t, {name: "Maker"}, aiWall({userId: "attacker", imageUrl: "https://evil.example/a.png",
    watermarkedImageUrl: "https://evil.example/thumb.png"}));
  await fire(store);
  assert.deepEqual(requests, [{url: `https://prismwalls.com/api/ai/studio/generation-records/${GEN}`, secret: "studio-secret"}]);
  const {recordedAt, ...receipt} = store.get(`aiGenerationReceipts/${GEN}`) as Doc;
  assert.ok(recordedAt instanceof admin.firestore.Timestamp);
  assert.deepEqual(receipt, {generationId: GEN, userId: "maker", imageUrl: aiRecord.imageUrl,
    watermarkedImageUrl: aiRecord.watermarkedImageUrl});

  store.set(`aiGenerationReceipts/${GEN}`, {...receipt, userId: "first"});
  await fire(store);
  assert.equal(store.get(`aiGenerationReceipts/${GEN}`)?.userId, "first");
});

for (const id of ["AI2B83C297CF7C420FF33FA03823705EA95", "AIGENMLT7O22"]) {
  test(`submission captures provenance for the app's ${id} identity`, async (t) => {
    workerRecords(t, () => new Response(JSON.stringify(aiRecord), {status: 200}));
    const {store} = setup(t, {name: "Maker"}, aiWall({id, wallpaper_url: aiRecord.watermarkedImageUrl}));
    await fire(store);
    assert.equal(store.get(`aiGenerationReceipts/${GEN}`)?.generationId, GEN);
    assert.equal(store.get(`aiGenerationReceipts/${GEN}`)?.userId, "maker");
  });
}

test("a failed receipt create does not stop premium admin notifications or owner sync", async (t) => {
  workerRecords(t, () => new Response(JSON.stringify(aiRecord), {status: 200}));
  const {store, pushes} = setup(t, {name: "Real Maker", premium: true}, aiWall());
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    if (name !== "aiGenerationReceipts") return collection(name);
    const receipts = collection(name);
    const getDoc = receipts.doc.bind(receipts);
    t.mock.method(receipts, "doc", (id: string) => {
      const ref = getDoc(id);
      t.mock.method(ref, "create", async () => {
        throw new Error("temporary receipt create failure");
      });
      return ref;
    });
    return receipts;
  });

  await fire(store);

  assert.equal(store.has(`aiGenerationReceipts/${GEN}`), false);
  assert.equal(store.get("walls/w1")?.by, "Real Maker");
  assert.deepEqual(pushes.map((push) => push.token), ["admin-token"]);
  assert.deepEqual(pushes[0].data, {route: "content_report", channel_id: "posts", push_kind: "moderation"});
});

test("an AI wall without a Worker record, or with a failed read, gets no receipt and is still synced", async (t) => {
  for (const response of [() => new Response(JSON.stringify({error: "generation_not_found"}), {status: 404}),
    () => new Response(null, {status: 503})]) {
    workerRecords(t, response);
    const {store} = setup(t, {name: "Real Maker"}, aiWall());
    await fire(store);
    assert.equal(store.has(`aiGenerationReceipts/${GEN}`), false);
    assert.equal(store.get("walls/w1")?.by, "Real Maker");
  }
});

test("a wall that is not a Worker AI wall reads no record", async (t) => {
  const requests = workerRecords(t, () => new Response(JSON.stringify(aiRecord), {status: 200}));
  const {store} = setup(t, {name: "Maker"}, wall({isAiGenerated: true, aiGenerationId: GEN}));
  await fire(store);
  assert.deepEqual(requests, []);
  assert.equal(store.has(`aiGenerationReceipts/${GEN}`), false);
});

const remixOriginal = (extra: Doc = {}): Doc => ({
  email: "other@example.com", title: "Dunes", review: true, isAiGenerated: true, aiPrompt: "neon dunes", ...extra,
});
const remixWall = (remixOf: string, extra: Doc = {}) => wall({isAiGenerated: true, remixOf, ...extra});

test("a remix of an approved AI wall keeps its remixOf", async (t) => {
  const {store} = setup(t, {name: "Maker"}, remixWall("orig"));
  store.set("walls/orig", remixOriginal());
  await fire(store);
  assert.equal(store.get("walls/w1")?.remixOf, "orig");
});

const unverifiedRemixes: Array<[string, Doc, Doc | null]> = [
  ["a remixOf to the wall itself", remixWall("w1"), null],
  ["a remixOf to a missing original", remixWall("gone"), null],
  ["a remixOf to an original that is not approved", remixWall("orig"), remixOriginal({review: false})],
  ["a remixOf to an original that is not AI generated", remixWall("orig"), remixOriginal({isAiGenerated: false})],
  ["a remixOf to an original without an AI prompt", remixWall("orig"), remixOriginal({aiPrompt: "  "})],
  ["a remixOf to an original with a non-string prompt", remixWall("orig"), remixOriginal({aiPrompt: {text: "neon dunes"}})],
  ["a remixOf with a slash", remixWall("a/b"), remixOriginal()],
  ["a remixOf longer than 64 characters", remixWall("x".repeat(70)), remixOriginal()],
  ["a remixOf with a non-string value", remixWall("unused", {remixOf: 42}), remixOriginal()],
  ["a remixOf on a wall that is not AI generated", wall({remixOf: "orig"}), remixOriginal()],
];

for (const [name, remix, original] of unverifiedRemixes) {
  test(`${name} is removed on submission`, async (t) => {
    const {store} = setup(t, {name: "Maker"}, remix);
    if (original) store.set("walls/orig", original);
    await fire(store);
    assert.equal("remixOf" in (store.get("walls/w1") ?? {}), false);
  });
}

test("removing a stale invalid link does not delete a replacement wall's link", async (t) => {
  const {store} = setup(t, {name: "Maker"}, remixWall("gone"));
  const expected = await db.doc("walls/w1").get();
  store.delete("walls/w1");
  store.set("walls/w1", remixWall("gone", {title: "Replacement wall"}));

  assert.equal(await removeRemixOfIfUnchanged(expected as Parameters<typeof removeRemixOfIfUnchanged>[0], "gone"), false);
  assert.equal(store.get("walls/w1")?.remixOf, "gone");
  assert.equal(store.get("walls/w1")?.title, "Replacement wall");
});

test("submission removes a link that closes a longer remix loop", async (t) => {
  const {store} = setup(t, {name: "Maker"}, remixWall("orig"));
  store.set("walls/orig", remixOriginal({remixOf: "middle"}));
  store.set("walls/middle", remixOriginal({remixOf: "w1"}));

  await fire(store);

  assert.equal("remixOf" in (store.get("walls/w1") ?? {}), false);
});

test("submission keeps a valid remix link through a long acyclic chain", async (t) => {
  const {store} = setup(t, {name: "Maker"}, remixWall("node0"));
  for (let index = 0; index < 65; index++) {
    store.set(`walls/node${index}`, remixOriginal({remixOf: `node${index + 1}`}));
  }
  store.set("walls/node65", remixOriginal());

  await fire(store);

  assert.equal(store.get("walls/w1")?.remixOf, "node0");
});

test("submission keeps a link if its original is approved before sanitization commits", async (t) => {
  const {store} = setup(t, {name: "Maker"}, remixWall("orig"));
  store.set("walls/orig", remixOriginal({review: false}));
  const expected = await db.doc("walls/w1").get();
  store.set("walls/orig", remixOriginal({review: true}));

  assert.equal(await removeRemixOfIfUnchanged(expected as Parameters<typeof removeRemixOfIfUnchanged>[0], "orig"), false);
  assert.equal(store.get("walls/w1")?.remixOf, "orig");
});

test("a failed remixOf check still notifies the admins", async (t) => {
  const {store, pushes} = setup(t, {name: "Maker", premium: true}, wall({isAiGenerated: true, remixOf: "a/b"}));
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("unavailable");
  });
  await fire(store);
  assert.deepEqual(pushes.map((push) => push.token), ["admin-token"]);
});

test("submission removes forged lineage and clears rejected text while preserving the upload", async (t) => {
  withGithubRepo(t);
  const sha = "a".repeat(40);
  const thumbSha = "b".repeat(40);
  const originalUrl = `${RAW}/a.jpg`;
  const thumbUrl = `${RAW}/thumb_a.jpg`;
  const {store} = setup(t, {name: "Maker", premium: false}, wall({
    resubmitOf: "claimed-parent", title: "p0rn", desc: "Hidden\u202e", tags: ["nudes"], category: "Nature",
    wallpaper_url: originalUrl, wallpaper_path: "a.jpg", wallpaper_sha: sha, wallpaper_source_kind: "github",
    wallpaper_thumb: thumbUrl, thumb_path: "thumb_a.jpg", thumb_sha: thumbSha, thumb_source_kind: "github",
  }));
  for (const [key, value] of Object.entries({
    ...stillProof("a.jpg", sha, originalUrl),
    ...stillProof("thumb_a.jpg", thumbSha, thumbUrl),
  })) store.set(key, value);
  await fire(store);
  const current = store.get("walls/w1")!;
  assert.equal(current.resubmitOf, undefined);
  assert.equal(current.title, "");
  assert.equal(current.desc, "");
  assert.deepEqual(current.tags, []);
  assert.equal(current.wallpaper_url, originalUrl);
  assert.equal(current.review, false);
  assert.equal(current.category, "Nature");
});

test("a live wall with a broken live map is marked unverified, and the rest of the trigger still runs", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  // The trigger binds the R2 secrets, so R2 is configured in production. The proof builds its client before it checks the shape.
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "private-assets", R2_PREVIEW_BUCKET: "public-previews",
    R2_PREVIEW_BASE_URL: "https://images.example.com", GH_REPO_WALLS: "walls"});
  const sha = "a".repeat(40);
  const broken = {video: `${RAW}/live_a.mp4`, videoPath: "live_a.mp4", videoSha: sha, frames: [
    {url: `${RAW}/frame_1_a.jpg`, path: "frame_1_a.jpg", sha},
    {url: `${RAW}/frame_2_a.jpg`, path: "frame_2_a.jpg", sha},
  ]};
  const {store} = setup(t, {name: "Real Maker"}, wall({kind: "live", live: broken}));
  await fire(store);
  const live = store.get("walls/w1")?.live as Doc;
  assert.equal(live.verified, false);
  assert.equal(live.error, "bad_fields");
  assert.equal(store.get("walls/w1")?.by, "Real Maker");
});

test("a profile email cannot authorize live files when Auth has not verified its owner", async (t) => {
  const sha = "a".repeat(40);
  const live = {video: "https://images.example/live.mp4", videoPath: "live_a.mp4", videoSha: sha,
    frames: [1, 2, 3].map((n) => ({url: `https://images.example/frame${n}.jpg`, path: `frame_${n}_a.jpg`, sha}))};
  const {store} = setup(t, {name: "Real Maker", premium: false}, wall({kind: "live", live}));
  t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "maker", email: "maker@example.com", emailVerified: false}));
  await fire(store);
  assert.equal((store.get("walls/w1")?.live as Doc).verified, false);
  assert.equal((store.get("walls/w1")?.live as Doc).error, "no_owner");
});

test("a transient Auth failure retries without terminally rejecting the live wall", async (t) => {
  const live = {video: "pending"};
  const {store} = setup(t, {name: "Maker", premium: false}, wall({kind: "live", live}));
  t.mock.method(admin.auth(), "getUserByEmail", async () => {
    throw new Error("temporary Auth failure");
  });
  await assert.rejects(() => fire(store), /temporary Auth failure/);
  assert.deepEqual(store.get("walls/w1")?.live, live);
  t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "maker", email: "maker@example.com", emailVerified: true}));
  await fire(store);
  assert.equal((store.get("walls/w1")?.live as Doc).error, "bad_fields");
});

test("a retried submission keeps one admin inbox entry per wall", async (t) => {
  const {store} = setup(t, {name: "Maker", premium: true}, wall());
  await fire(store);
  await fire(store);
  const inbox = [...store.keys()].filter((key) => key.startsWith("notifications/"));
  assert.deepEqual(inbox, ["notifications/wall_submitted_w1"]);
});
