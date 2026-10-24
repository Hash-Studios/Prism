import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {aiCommunityId} from "../aiWallSource";
import {isGithubRawUrl, onWallSubmitted} from "../onWallSubmitted";
import {type Doc, installFakeDb} from "./fakeDb";

const RAW = "https://raw.githubusercontent.com/owner/walls/main";

function setup(t: TestContext, owner: Doc | null, wall: Doc) {
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

const fire = (store: Map<string, Doc>) => onWallSubmitted.run({
  params: {wallId: "w1"},
  data: {
    data: () => store.get("walls/w1"),
    ref: {update: async (update: Doc) => void store.set("walls/w1", {...store.get("walls/w1"), ...update})},
  },
} as unknown as Parameters<typeof onWallSubmitted.run>[0]);

const wall = (extra: Doc = {}): Doc => ({
  email: "maker@example.com", by: "Fake Admin", userPhoto: "https://evil.example/p.png", review: false,
  wallpaper_url: `${RAW}/a.jpg`, wallpaper_thumb: `${RAW}/thumb_a.jpg`, ...extra,
});

test("the submission trigger binds STUDIO_SECRET", () => {
  assert.deepEqual(onWallSubmitted.__endpoint.secretEnvironmentVariables?.map(({key}) => key), ["STUDIO_SECRET"]);
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

test("an image link outside the GitHub raw host is logged and the wall is kept", async (t) => {
  const {store} = setup(t, {name: "Maker", premium: true}, wall({wallpaper_url: "https://evil.example/a.jpg"}));
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, "https://evil.example/a.jpg");
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
