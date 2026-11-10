import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {db} from "../common";
import {drainReleaseNotices, onWallApproved} from "../onWallApproved";
import {submitDesktopVersion} from "../desktopSubmissions";
import {isScheduledWall, releaseDueWalls, validReleaseAt} from "../wallRelease";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = Date.parse("2026-11-14T12:30:00Z");
const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const A = "creatora@example.com";
const B = "creatorb@example.com";
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const scheduled = (email: string, releaseAt: number, extra: Doc = {}): Doc => ({
  review: false,
  releaseApprovedAt: at(NOW - HOUR),
  releaseAt: at(releaseAt),
  email,
  by: "Artist",
  title: "Dunes",
  ...extra,
});

function harness(t: TestContext, seed: Record<string, Doc>) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  for (const key of ["R2_ACCOUNT_ID", "R2_PRIVATE_BUCKET", "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"]) {
    delete process.env[key];
  }
  process.env.GH_REPO_WALLS = "walls";
  const store = installFakeDb(t, seed);
  const sent: Array<{topic: string; title?: string}> = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; notification?: {title?: string}}) => {
    sent.push({topic: message.topic ?? "", title: message.notification?.title});
    return "id";
  });
  const event = async (wallId: string, before: Doc = {review: false}) => ({
    params: {wallId},
    data: {before: {data: () => before}, after: await db.doc(`walls/${wallId}`).get()},
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  return {store, sent, event};
}

test("validReleaseAt accepts a release time 15 minutes to 30 days ahead and refuses the rest", () => {
  assert.equal(validReleaseAt(NOW + 14 * MIN, NOW), null);
  const fifteen = validReleaseAt(NOW + 15 * MIN, NOW);
  assert.ok(fifteen instanceof admin.firestore.Timestamp);
  assert.equal(fifteen.toMillis(), NOW + 15 * MIN);
  const thirty = validReleaseAt(NOW + 30 * DAY, NOW);
  assert.ok(thirty instanceof admin.firestore.Timestamp);
  assert.equal(thirty.toMillis(), NOW + 30 * DAY);
  assert.equal(validReleaseAt(NOW + 30 * DAY + 1, NOW), null);
  assert.equal(validReleaseAt(String(NOW + HOUR), NOW), null);
  assert.equal(validReleaseAt(Number.NaN, NOW), null);
});

test("isScheduledWall matches only an approved, unpublished wall with a release time", () => {
  const wall = {review: false, releaseApprovedAt: at(NOW), releaseAt: at(NOW + HOUR), email: A};
  assert.equal(isScheduledWall(wall), true);
  assert.equal(isScheduledWall({...wall, review: true}), false);
  assert.equal(isScheduledWall({...wall, releaseApprovedAt: undefined}), false);
  assert.equal(isScheduledWall({...wall, publishedAt: at(NOW)}), false);
  assert.equal(isScheduledWall({...wall, releaseAt: undefined}), false);
});

test("a scheduled wall whose release time is still ahead is not published", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW + HOUR)});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
  assert.equal(store.get("walls/w1")?.review, false);
  assert.equal(store.get("walls/w1")?.publishedAt, undefined);
});

test("a scheduled wall past its release time is published with a pending notice", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW - MIN)});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 1, creators: 1});
  const wall = store.get("walls/w1");
  assert.equal(wall?.review, true);
  assert.equal(wall?.releaseNotice, "pending");
  assert.ok(wall?.publishedAt instanceof admin.firestore.Timestamp);
});

test("a wall past its release time that was never approved for release stays hidden", async (t) => {
  const {store} = harness(t, {"walls/w1": {review: false, releaseAt: at(NOW - MIN), email: A, by: "Artist", title: "Dunes"}});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
  assert.equal(store.get("walls/w1")?.review, false);
  assert.equal(store.get("walls/w1")?.publishedAt, undefined);
});

test("a wall approved for release after an undone approval is published at its release time", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW - MIN, {publishedAt: at(NOW - 2 * HOUR)})});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 1, creators: 1});
  assert.equal(store.get("walls/w1")?.review, true);
});

test("a scheduled live wall is released like a still wall and keeps its kind and live map", async (t) => {
  const live = {video: "https://x.example/live_a.mp4", videoPath: "live_a.mp4", videoSha: "a".repeat(40),
    frames: [1, 2, 3].map((n) => ({url: `https://x.example/frame_${n}_a.jpg`, path: `frame_${n}_a.jpg`, sha: "b".repeat(40)})),
    durationMs: 5000, width: 1080, height: 1920, codec: "avc1", bytes: 1000, loop: true, verified: true};
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW - MIN, {kind: "live", live})});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 1, creators: 1});
  const wall = store.get("walls/w1");
  assert.equal(wall?.review, true);
  assert.ok(wall?.publishedAt instanceof admin.firestore.Timestamp);
  assert.equal(wall?.kind, "live");
  assert.deepEqual(wall?.live, live);
});

test("a wall held after release keeps its older approval and stays hidden", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW - 2 * HOUR, {publishedAt: at(NOW - 30 * MIN)})});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
  assert.equal(store.get("walls/w1")?.review, false);
});

test("running the release job twice publishes a wall once", async (t) => {
  harness(t, {"walls/w1": scheduled(A, NOW - MIN)});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 1, creators: 1});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
});

test("a creator's due walls share one release push, and a single wall gets the single-wall copy", async (t) => {
  const {store, sent, event} = harness(t, {
    "walls/a1": scheduled(A, NOW - 3 * MIN, {title: "A one"}),
    "walls/a2": scheduled(A, NOW - 2 * MIN, {title: "A two"}),
    "walls/a3": scheduled(A, NOW - MIN, {title: "A three"}),
    "walls/b1": scheduled(B, NOW - MIN, {title: "Bee solo", by: "Bee"}),
  });
  assert.deepEqual(await releaseDueWalls(NOW), {released: 4, creators: 2});
  for (const id of ["a1", "a2", "a3", "b1"]) await onWallApproved.run(await event(id));

  assert.deepEqual(sent.map((message) => message.topic).sort(),
    ["creatora_posts", "creatora_posts_loc_v1", "creatorb_posts", "creatorb_posts_loc_v1"]);
  assert.equal(sent.find((message) => message.topic === "creatora_posts")?.title, "Artist released 3 walls");
  assert.equal(sent.find((message) => message.topic === "creatorb_posts")?.title, "New wall by Bee");
  for (const id of ["a1", "a2", "a3", "b1"]) {
    assert.equal("releaseNotice" in (store.get(`walls/${id}`) ?? {}), false);
  }
});

test("a repeated approval of a wall in a claimed set sends no second push", async (t) => {
  const {sent, event} = harness(t, {
    "walls/a1": scheduled(A, NOW - 2 * MIN, {title: "A one"}),
    "walls/a2": scheduled(A, NOW - MIN, {title: "A two"}),
  });
  await releaseDueWalls(NOW);
  await onWallApproved.run(await event("a1"));
  await onWallApproved.run(await event("a2"));
  assert.equal(sent.length, 2);
  await onWallApproved.run(await event("a2"));
  assert.equal(sent.length, 2);
});

test("an edited release time takes effect before the job runs", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW + HOUR)});
  store.set("walls/w1", {...store.get("walls/w1"), releaseAt: at(NOW + 2 * HOUR)});
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
  assert.equal(store.get("walls/w1")?.review, false);
  assert.deepEqual(await releaseDueWalls(NOW + 3 * HOUR), {released: 1, creators: 1});
  assert.equal(store.get("walls/w1")?.review, true);
});

test("a wall deleted before the job runs is skipped without error", async (t) => {
  const {store} = harness(t, {"walls/w1": scheduled(A, NOW - MIN)});
  store.delete("walls/w1");
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 0});
  assert.equal(store.has("walls/w1"), false);
});

test("a colourway waits for its parent, then both walls release together", async (t) => {
  const {store} = harness(t, {
    "walls/P": scheduled(A, NOW + HOUR),
    "walls/V": scheduled(A, NOW - MIN, {variantOf: "P"}),
  });
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 1});
  assert.equal(store.get("walls/V")?.review, false);
  assert.deepEqual(await releaseDueWalls(NOW + 2 * HOUR), {released: 2, creators: 1});
  assert.equal(store.get("walls/P")?.review, true);
  assert.equal(store.get("walls/V")?.review, true);
});

test("a colourway of a published parent releases on its own time", async (t) => {
  const {store} = harness(t, {
    "walls/P": {review: true, email: A, by: "Artist", title: "Parent"},
    "walls/V": scheduled(A, NOW - MIN, {variantOf: "P"}),
  });
  assert.deepEqual(await releaseDueWalls(NOW), {released: 1, creators: 1});
  assert.equal(store.get("walls/V")?.review, true);
});

test("a scheduled wall refuses a desktop version with the unapproved-wall error until it is public", async (t) => {
  harness(t, {
    "usersv2/maker": {email: "maker@example.com"},
    "walls/w1": scheduled(A, NOW + HOUR, {id: "WALL1", creatorUid: "maker", email: "maker@example.com"}),
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: "https://images.example.com"});
  const image = (await sharp({create: {width: 2560, height: 1600, channels: 3, background: "navy"}}).png().toBuffer())
    .toString("base64");
  const maker = {uid: "maker", token: {email: "maker@example.com", email_verified: true}};
  await assert.rejects(submitDesktopVersion.run({auth: maker, data: {wallDocId: "w1", contentBase64: image}} as never),
    (error: unknown) => {
      assert.equal((error as {code?: string}).code, "failed-precondition");
      assert.equal((error as Error).message, "desktop-wall-not-approved");
      return true;
    });
});

test("approval of an unscheduled wall stamps publishedAt", async (t) => {
  const {store, event} = harness(t, {"walls/w1": {id: "w1", review: true, email: A, by: "Artist", title: "Dunes",
    wallpaper_thumb: "https://example.com/thumb.jpg"}});
  await onWallApproved.run(await event("w1"));
  assert.ok(store.get("walls/w1")?.publishedAt instanceof admin.firestore.Timestamp);
});

test("a retry after the approval stamp can finish a pending release notice", async (t) => {
  const {store, sent, event} = harness(t, {
    "walls/a1": {...scheduled(A, NOW - MIN), review: true, releaseNotice: "pending", approvedNotifiedAt: at(NOW)},
  });
  await onWallApproved.run(await event("a1"));
  assert.equal(sent.length, 2);
  assert.equal(store.get("walls/a1")?.releaseNotice, undefined);
});

test("more than 100 due walls of one creator release and announce together", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 101; i++) seed[`walls/w${i}`] = scheduled(A, NOW - MIN);
  const {store, sent, event} = harness(t, seed);
  assert.deepEqual(await releaseDueWalls(NOW), {released: 101, creators: 1});
  for (let i = 0; i < 101; i++) await onWallApproved.run(await event(`w${i}`));
  assert.equal(sent.length, 2);
  assert.equal(sent[0].title, "Artist released 101 walls");
  assert.equal([...store.values()].filter((wall) => wall.releaseNotice === "pending").length, 0);
});

for (const removed of ["held", "deleted", "studio"]) {
  test(`the periodic drain recovers ready siblings when the last waiting wall is ${removed}`, async (t) => {
    const {store, sent} = harness(t, {
      "walls/a1": {...scheduled(A, NOW - MIN), review: true, releaseNotice: "pending", approvedNotifiedAt: at(NOW)},
      "walls/a2": {...scheduled(A, NOW - MIN), review: true, releaseNotice: "pending"},
    });
    await drainReleaseNotices();
    assert.equal(sent.length, 0);
    if (removed === "deleted") store.delete("walls/a2");
    else store.set("walls/a2", {...store.get("walls/a2"), ...(removed === "held" ? {review: false} : {byStudio: true})});
    await drainReleaseNotices();
    assert.equal(sent.length, 2);
    assert.equal(store.get("walls/a1")?.releaseNotice, undefined);
    await drainReleaseNotices();
    assert.equal(sent.length, 2);
  });
}

test("a failing creator does not block other pending release notices", async (t) => {
  const {sent} = harness(t, {
    "walls/a1": {...scheduled(A, NOW - MIN), review: true, releaseNotice: "pending", approvedNotifiedAt: at(NOW)},
    "walls/b1": {...scheduled(B, NOW - MIN), review: true, releaseNotice: "pending", approvedNotifiedAt: at(NOW)},
  });
  const runTransaction = db.runTransaction.bind(db);
  let calls = 0;
  t.mock.method(db, "runTransaction", async (...args: Parameters<typeof db.runTransaction>) => {
    if (calls++ === 0) throw new Error("claim unavailable");
    return runTransaction(...args);
  });
  await assert.rejects(drainReleaseNotices());
  assert.equal(sent.length, 2);
  assert.equal(sent[0].topic, "creatorb_posts");
});

test("a due variant waits when its due parent is itself waiting for an unreleased ancestor", async (t) => {
  const {store} = harness(t, {
    "walls/root": scheduled(A, NOW + HOUR),
    "walls/parent": scheduled(A, NOW - MIN, {variantOf: "root"}),
    "walls/child": scheduled(A, NOW - MIN, {variantOf: "parent"}),
  });
  assert.deepEqual(await releaseDueWalls(NOW), {released: 0, creators: 1});
  assert.equal(store.get("walls/child")?.review, false);
  assert.deepEqual(await releaseDueWalls(NOW + 2 * HOUR), {released: 3, creators: 1});
});
