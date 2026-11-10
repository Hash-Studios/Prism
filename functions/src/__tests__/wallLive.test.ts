import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import {logger} from "firebase-functions/v2";
import {uploadFileKey} from "../completedWallUpload";
import {db} from "../common";
import {ownedThumbnailUrl, type StoredUpload} from "../ownedAssetDelivery";
import {r2ObjectId} from "../r2Storage";
import {
  liveModerationFrameUrls,
  type LiveProofDeps,
  parseClientLive,
  proveLiveSubmission,
  tombstoneLiveAssets,
  verifyLiveWall,
} from "../wallLive";
import {type Doc, installFakeDb} from "./fakeDb";
import {mp4} from "./mp4Fixture";

const SHA = "0123456789abcdef0123456789abcdef01234567";
const sha1 = (bytes: Buffer) => createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

function env(t: TestContext) {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  process.env.GH_REPO_WALLS = "walls";
  process.env.R2_PRIVATE_BUCKET = "private-assets";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
}

type Owned = {path: string; sha: string; bytes: Buffer; asset: StoredUpload; url: string};

/** A file the owner uploaded through githubPutFile, stored privately with its preview. Needs env(t) first. */
function owned(path: string, bytes: Buffer): Owned {
  const sha = sha1(bytes);
  const digest = sha256(bytes);
  const identity = {uid: "owner", repo: "walls", path, sha, sourceKind: "owned" as const};
  const objectId = r2ObjectId(identity, digest);
  const asset: StoredUpload = {...identity, bucket: "private-assets", object: `private-originals/${objectId}`,
    objectId, sha256: digest, previewObjectId: objectId};
  return {path, sha, bytes, asset, url: ownedThumbnailUrl(asset)};
}

function fixture(t: TestContext, video: Buffer = mp4()) {
  env(t);
  const all = [owned("live_a.mp4", video), owned("frame_1_a.jpg", Buffer.from("frame 1")),
    owned("frame_2_a.jpg", Buffer.from("frame 2")), owned("frame_3_a.jpg", Buffer.from("frame 3"))];
  const [videoFile, ...frames] = all;
  const live = {video: videoFile.url, videoPath: videoFile.path, videoSha: videoFile.sha,
    frames: frames.map((frame) => ({url: frame.url, path: frame.path, sha: frame.sha}))};
  return {all, live};
}

/** Git upload receipts with their stored assets, as githubPutFile writes them. */
function receipts(files: Owned[]): Record<string, Doc> {
  return Object.fromEntries(files.map((file) => [
    `githubUploads/${uploadFileKey("walls", {path: file.path, sha: file.sha, sourceKind: "owned"})}`,
    {uid: "owner", repo: "walls", path: file.path, sha: file.sha, sourceKind: "owned", retainedAsset: file.asset},
  ]));
}

function deps(files: Owned[], patch: Partial<LiveProofDeps> = {}): LiveProofDeps {
  const bytes = new Map<string, Buffer>(files.map((file): [string, Buffer] => [file.asset.objectId, file.bytes]));
  return {
    readPrivate: async (asset) => bytes.get(asset.objectId) ?? Buffer.alloc(0),
    previewMatches: async () => true,
    ...patch,
  };
}

const withFrame = (frames: Array<{url: string; path: string; sha: string}>, index: number, patch: Doc) =>
  frames.map((frame, i) => (i === index ? {...frame, ...patch} : frame));

test("parseClientLive accepts the exact client shape and returns it", () => {
  const frames = [1, 2, 3].map((n) => ({url: `https://u.example/frame_${n}_a.jpg`, path: `frame_${n}_a.jpg`, sha: SHA}));
  const good = {video: "https://u.example/live_a.mp4", videoPath: "live_a.mp4", videoSha: SHA, frames};
  assert.deepEqual(parseClientLive(good), good);
});

test("parseClientLive refuses extra, short, misnamed and duplicate fields", () => {
  const frames = [1, 2, 3].map((n) => ({url: `https://u.example/frame_${n}_a.jpg`, path: `frame_${n}_a.jpg`, sha: SHA}));
  const good = {video: "https://u.example/live_a.mp4", videoPath: "live_a.mp4", videoSha: SHA, frames};
  assert.equal(parseClientLive({...good, durationMs: 5000}), null);
  assert.equal(parseClientLive({...good, frames: frames.slice(0, 2)}), null);
  assert.equal(parseClientLive({...good, frames: withFrame(frames, 0, {path: "thumb_1_a.jpg"})}), null);
  assert.equal(parseClientLive({...good, videoPath: "live_a.jpg"}), null);
  assert.equal(parseClientLive({...good, frames: withFrame(frames, 1, {path: "frame_1_a.jpg"})}), null);
  assert.equal(parseClientLive({...good, videoSha: "x".repeat(40)}), null);
});

test("liveModerationFrameUrls keeps only exact previews on the R2 preview host of a live wall", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  process.env.R2_PREVIEW_BASE_URL = "https://img.example.com";
  const good = `https://img.example.com/previews/${"a".repeat(64)}.img`;
  assert.deepEqual(liveModerationFrameUrls({kind: "live", live: {frames: [{url: good},
    {url: "https://evil.example/x.jpg"}]}}), [good]);
  assert.deepEqual(liveModerationFrameUrls({kind: "still", live: {frames: [{url: good}]}}), []);
});

test("a proven live submission returns the server facts next to the client keys", async (t) => {
  const {all, live} = fixture(t);
  installFakeDb(t, receipts(all));
  const result = await proveLiveSubmission("owner", live, deps(all));
  assert.deepEqual(result, {ok: true, live: {...live, durationMs: 5000, width: 1080, height: 1920, codec: "avc1",
    bytes: all[0].bytes.length, loop: true, verified: true}});
});

test("a receipt of another uid does not prove the files", async (t) => {
  const {all, live} = fixture(t);
  installFakeDb(t, receipts(all));
  assert.deepEqual(await proveLiveSubmission("someone-else", live, deps(all)), {ok: false, error: "unproven_file"});
});

test("a live submission with no owner is refused", async (t) => {
  const {all, live} = fixture(t);
  installFakeDb(t, receipts(all));
  assert.deepEqual(await proveLiveSubmission(null, live, deps(all)), {ok: false, error: "no_owner"});
});

test("a stored 16 second clip is too long, whatever the client claims", async (t) => {
  const {all, live} = fixture(t, mp4({duration: 16000}));
  installFakeDb(t, receipts(all));
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all)), {ok: false, error: "too_long"});
});

test("stored JPEG bytes named live_a.mp4 are refused as a spoofed type", async (t) => {
  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(60)]);
  const {all, live} = fixture(t, jpeg);
  installFakeDb(t, receipts(all));
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all)), {ok: false, error: "not_mp4"});
});

test("a file whose preview is not in the R2 preview bucket is unproven", async (t) => {
  const {all, live} = fixture(t);
  installFakeDb(t, receipts(all));
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all, {previewMatches: async () => false})),
    {ok: false, error: "unproven_file"});
});

test("verifyLiveWall writes the header facts onto a proven wall", async (t) => {
  const {all, live} = fixture(t);
  const store = installFakeDb(t, {...receipts(all), "walls/w1": {kind: "live", review: false, live}});
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps(all));
  const saved = store.get("walls/w1")?.live as Doc;
  assert.equal(saved.verified, true);
  assert.equal(saved.durationMs, 5000);
});

test("verifyLiveWall marks a failed proof as unverified with its error", async (t) => {
  const {all, live} = fixture(t);
  const log = t.mock.method(logger, "warn", () => undefined);
  const store = installFakeDb(t, {...receipts(all), "walls/w1": {kind: "live", review: false, live}});
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps(all, {previewMatches: async () => false}));
  const saved = store.get("walls/w1")?.live as Doc;
  assert.equal(saved.verified, false);
  assert.equal(saved.error, "unproven_file");
  assert.equal(log.mock.callCount(), 1);
});

test("tombstoneLiveAssets marks the four R2 objects of an approved live wall", async (t) => {
  const {all, live} = fixture(t);
  const registry: Record<string, Doc> = Object.fromEntries(all.map((file) => [`r2ObjectRegistry/${file.asset.objectId}`,
    {status: "active", object: file.asset.object, sha256: file.asset.sha256, path: file.path}]));
  const store = installFakeDb(t, {...receipts(all), ...registry});
  const before = {kind: "live", review: true, live: {...live, verified: true}};
  assert.equal(await tombstoneLiveAssets(before), 4);
  for (const file of all) {
    assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
  }
});

test("tombstoneLiveAssets leaves the objects of a wall that is not approved", async (t) => {
  const {all, live} = fixture(t);
  const registry: Record<string, Doc> = Object.fromEntries(all.map((file) => [`r2ObjectRegistry/${file.asset.objectId}`,
    {status: "active", object: file.asset.object, sha256: file.asset.sha256, path: file.path}]));
  const store = installFakeDb(t, {...receipts(all), ...registry});
  assert.equal(await tombstoneLiveAssets({kind: "live", review: false, live: {...live, verified: true}}), 0);
  for (const file of all) {
    assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  }
});
