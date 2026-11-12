import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import * as admin from "firebase-admin";
import test, {type TestContext} from "node:test";
import {logger} from "firebase-functions/v2";
import {uploadFileKey, uploadPathKey} from "../completedWallUpload";
import {db} from "../common";
import {bindOwnedWall, cleanupDeletedOwnedWall, ownedThumbnailUrl, type StoredUpload} from "../ownedAssetDelivery";
import {R2Storage, r2ObjectId} from "../r2Storage";
import {getWallResubmissionContext, rejectWallForReview, undoWallRejection} from "../wallResubmissions";
import {
  liveModerationFrameUrls,
  liveAssetReferenced,
  type LiveProofDeps,
  parseClientLive,
  proveLiveSubmission,
  tombstoneLiveAssets,
  tombstoneUnreferencedLiveUploads,
  onRejectedLiveWallDeleted,
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
function owned(path: string, bytes: Buffer, preview = true): Owned {
  const sha = sha1(bytes);
  const digest = sha256(bytes);
  const identity = {uid: "owner", repo: "walls", path, sha, sourceKind: "owned" as const, uploadId: "upload-1"};
  const objectId = r2ObjectId(identity, digest);
  const asset: StoredUpload = {...identity, bucket: "private-assets", object: `private-originals/${objectId}`,
    objectId, sha256: digest, ...(preview ? {previewObjectId: objectId} : {})};
  return {path, sha, bytes, asset, url: preview ? ownedThumbnailUrl(asset) : ""};
}

function fixture(t: TestContext, video: Buffer = mp4()) {
  env(t);
  const all = [owned("live_a.mp4", video), owned("frame_1_a.jpg", Buffer.from("frame 1")),
    owned("frame_2_a.jpg", Buffer.from("frame 2")), owned("frame_3_a.jpg", Buffer.from("frame 3"))];
  const [videoFile, ...frames] = all;
  const live = {video: videoFile.url, videoPath: videoFile.path, videoSha: videoFile.sha,
    frames: frames.map((frame) => ({url: frame.url, path: frame.path, sha: frame.sha}))};
  const png = readFileSync(resolve(__dirname, "../../../assets/icon/ic_background.png"));
  const posters = [owned("owner_1234567890123_a.jpg", png, false), owned("thumb_owner_1234567890123_a.jpg", png)];
  const wall = {id: "w1", email: "owner@example.com", kind: "live", review: false, live,
    wallpaper_url: "", wallpaper_thumb: posters[1].url, wallpaper_path: posters[0].path, wallpaper_sha: posters[0].sha,
    thumb_path: posters[1].path, thumb_sha: posters[1].sha, wallpaper_source_kind: "owned", thumb_source_kind: "owned"};
  return {all, live, posters, wall};
}

/** Git upload receipts with their stored assets, as githubPutFile writes them. */
function receipts(files: Owned[]): Record<string, Doc> {
  return Object.fromEntries(files.flatMap((file) => {
    const reference = {path: file.path, sha: file.sha, sourceKind: "owned" as const};
    const record = {uid: "owner", repo: "walls", ...reference, generation: "generation-1", retainedAsset: file.asset};
    return [
      [`githubUploads/${uploadFileKey("walls", reference)}`, record],
      [`githubUploadIntents/${uploadPathKey("walls", reference)}`, {...record, status: "complete", blobSha: file.sha,
        uploadId: file.asset.uploadId, response: {sourceKind: "owned", content: {path: file.path, sha: file.sha, download_url: file.url}}}],
      [`r2ObjectRegistry/${file.asset.objectId}`, {...file.asset, status: "active"}],
    ];
  }));
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
    {url: "https://evil.example/x.jpg"}]}}), []);
  const valid = ["a", "b", "c"].map((c) => `https://img.example.com/previews/${c.repeat(64)}.img`);
  assert.deepEqual(liveModerationFrameUrls({kind: "live", live: {frames: valid.map((url) => ({url}))}}), valid);
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
  const {all, posters, wall} = fixture(t);
  const store = installFakeDb(t, {...receipts([...all, ...posters]), "usersv2/owner": {}, "walls/w1": wall});
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps([...all, ...posters]));
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
  const store = installFakeDb(t, receipts(all));
  const before = {kind: "live", review: true, live: {...live, verified: true}};
  assert.equal(await tombstoneLiveAssets(before), 4);
  for (const file of all) {
    assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
  }
});

test("deletion of an unverified foreign submission cannot tombstone someone else's objects", async (t) => {
  const {all, live} = fixture(t);
  const store = installFakeDb(t, receipts(all));
  assert.equal(await tombstoneLiveAssets({kind: "live", review: false, creatorUid: "attacker", live}), 0);
  for (const file of all) {
    assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  }
});

test("terminal deletion of an owner-proven pending live wall schedules all four files", async (t) => {
  const {all, wall} = fixture(t);
  const store = installFakeDb(t, receipts(all));
  assert.equal(await tombstoneLiveAssets({...wall, creatorUid: "owner"}), 4);
  for (const file of all) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("tombstoned assets and incomplete upload intents cannot prove a live submission", async (t) => {
  const {all, live} = fixture(t);
  const store = installFakeDb(t, receipts(all));
  const registry = `r2ObjectRegistry/${all[0].asset.objectId}`;
  store.set(registry, {...store.get(registry), status: "tombstoned"});
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all)), {ok: false, error: "unproven_file"});
  store.set(registry, {...store.get(registry), status: "active"});
  const intent = `githubUploadIntents/${uploadPathKey("walls", {...all[0], sourceKind: "owned"})}`;
  store.set(intent, {...store.get(intent), status: "uploading"});
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all)), {ok: false, error: "unproven_file"});
});

test("a receipt cannot substitute a retained asset from another path", async (t) => {
  const {all, live} = fixture(t);
  const store = installFakeDb(t, receipts(all));
  const key = `githubUploads/${uploadFileKey("walls", {...all[0], sourceKind: "owned"})}`;
  store.set(key, {...store.get(key), retainedAsset: all[1].asset});
  assert.deepEqual(await proveLiveSubmission("owner", live, deps(all)), {ok: false, error: "unproven_file"});
});

test("verification fences a tombstone made while the file bytes are being checked", async (t) => {
  const {all, posters, wall} = fixture(t);
  const files = [...all, ...posters];
  const store = installFakeDb(t, {...receipts(files), "usersv2/owner": {}, "walls/w1": wall});
  const dependencies = deps(files);
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", {...dependencies, readPrivate: async (asset) => {
    const key = `r2ObjectRegistry/${all[0].asset.objectId}`;
    store.set(key, {...store.get(key), status: "tombstoned"});
    return dependencies.readPrivate(asset);
  }});
  assert.equal((store.get("walls/w1")?.live as Doc).verified, false);
  assert.equal((store.get("walls/w1")?.live as Doc).error, "unproven_file");
});

for (const change of ["recreated", "email", "kind"] as const) {
  test(`an old submission proof cannot write into a wall whose ${change} changed`, async (t) => {
    const {all, posters, wall} = fixture(t);
    const files = [...all, ...posters];
    const store = installFakeDb(t, {...receipts(files), "usersv2/owner": {}, "walls/w1": wall});
    const snapshot = await db.doc("walls/w1").get();
    if (change === "recreated") {
      await db.doc("walls/w1").delete();
      await db.doc("walls/w1").set(wall);
    } else await db.doc("walls/w1").update({[change]: change === "email" ? "other@example.com" : "still"});
    await verifyLiveWall(snapshot, "owner", deps(files));
    assert.equal((store.get("walls/w1")?.live as Doc).verified, undefined);
  });
}

test("a transient storage failure stays pending and the next delivery can verify it", async (t) => {
  const {all, posters, wall, live} = fixture(t);
  const files = [...all, ...posters];
  const store = installFakeDb(t, {...receipts(files), "usersv2/owner": {}, "walls/w1": wall});
  const snapshot = await db.doc("walls/w1").get();
  await assert.rejects(() => verifyLiveWall(snapshot, "owner", deps(files, {readPrivate: async () => {
    throw new Error("temporary R2 failure");
  }})), /temporary R2 failure/);
  assert.deepEqual(store.get("walls/w1")?.live, live);
  await verifyLiveWall(snapshot, "owner", deps(files));
  assert.equal((store.get("walls/w1")?.live as Doc).verified, true);
});

for (const invalid of ["video", "foreign", "truncated"] as const) {
  test(`a live wall with a ${invalid} poster is not verified`, async (t) => {
    const {all, posters, wall} = fixture(t);
    if (invalid === "video") wall.wallpaper_thumb = all[0].url;
    if (invalid === "truncated") {
      posters[0] = owned(posters[0].path, posters[0].bytes.subarray(0, 40), false);
      wall.wallpaper_sha = posters[0].sha;
    }
    const files = [...all, ...posters];
    const seed = receipts(files);
    if (invalid === "foreign") {
      const key = `githubUploads/${uploadFileKey("walls", {...posters[0], sourceKind: "owned"})}`;
      seed[key].uid = "other-owner";
    }
    const store = installFakeDb(t, {...seed, "usersv2/owner": {}, "walls/w1": wall});
    await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps(files));
    assert.equal((store.get("walls/w1")?.live as Doc).verified, false);
    assert.equal((store.get("walls/w1")?.live as Doc).error, "unproven_poster");
  });
}

test("server-enriched live references are re-proved on a protected wall", async (t) => {
  const {all, posters, wall, live} = fixture(t);
  const protectedWall = {...wall, live: {...live, verified: true, durationMs: 999}, originalProtected: true,
    originalObjectId: posters[0].asset.objectId, wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""};
  const files = [...all, ...posters];
  const store = installFakeDb(t, {...receipts(files), "usersv2/owner": {}, "walls/w1": protectedWall,
    "ownedAssets/w1": {status: "ready", canonicalPath: "walls/w1", incarnation: 1, incarnationNanos: 1_000_000,
      original: posters[0].asset, thumb: posters[1].asset}});
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps(files));
  assert.equal((store.get("walls/w1")?.live as Doc).verified, true);
  assert.equal((store.get("walls/w1")?.live as Doc).durationMs, 5000);
  const manifest = store.get("ownedAssets/w1")!;
  store.set("ownedAssets/w1", {...manifest, incarnation: 0});
  await verifyLiveWall(await db.doc("walls/w1").get(), "owner", deps(files));
  assert.equal((store.get("walls/w1")?.live as Doc).verified, false);
  assert.equal((store.get("walls/w1")?.live as Doc).error, "unproven_poster");
});

for (const collection of ["walls", "rejectedWalls"]) {
  test(`cleanup preserves shared video and frame assets referenced by ${collection}`, async (t) => {
    const {all, live} = fixture(t);
    const before = {kind: "live", review: true, live: {...live, verified: true}};
    const store = installFakeDb(t, {...receipts(all), [`${collection}/replacement`]: before});
    assert.equal(await tombstoneLiveAssets(before), 0);
    for (const file of all) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
    await db.doc(`${collection}/replacement`).delete();
    assert.equal(await tombstoneLiveAssets(before), 4);
  });
}

test("an unverified foreign wall cannot pin another owner's assets", async (t) => {
  const {all, wall, live} = fixture(t);
  installFakeDb(t, {...receipts(all), "walls/foreign": {...wall, creatorUid: "attacker"}});
  assert.equal(await tombstoneLiveAssets({kind: "live", review: true, live: {...live, verified: true}}), 4);
});

test("a pending canonical owner reference protects an upload before verification", async (t) => {
  const {all, wall} = fixture(t);
  installFakeDb(t, {...receipts(all), "walls/pending": {...wall, creatorUid: "owner"}});
  assert.equal(await db.runTransaction((tx) => liveAssetReferenced(tx, all[0].asset)), true);
  assert.equal(await db.runTransaction((tx) => liveAssetReferenced(tx, all[1].asset)), true);
});

test("registry identity still permits deleted-account cleanup after upload receipts are removed", async (t) => {
  const {all, live} = fixture(t);
  const seed = receipts(all);
  for (const path of Object.keys(seed)) if (path.startsWith("githubUploads/")) delete seed[path];
  const store = installFakeDb(t, seed);
  assert.equal(await tombstoneLiveAssets({kind: "live", review: true, live: {...live, verified: true}}), 4);
  for (const file of all) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("a protected live rejection keeps its files and undo binds the new wall incarnation before re-proof", async (t) => {
  const {all, posters, wall, live} = fixture(t);
  Object.assign(process.env, {GH_USERNAME: "github-owner", R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PREVIEW_BUCKET: "public-previews"});
  const files = [...all, ...posters];
  const protectedWall = {...wall, creatorUid: "owner", review: true, live: {...live, verified: true}, originalProtected: true,
    originalObjectId: posters[0].asset.objectId, wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""};
  const store = installFakeDb(t, {...receipts(files), "usersv2/owner": {}, "usersv2/moderator": {}, "walls/w1": protectedWall,
    "ownedAssets/w1": {status: "ready", canonicalPath: "walls/w1", incarnation: 1, incarnationNanos: 1_000_000,
      original: posters[0].asset, thumb: posters[1].asset, originalUrl: "", thumbUrl: posters[1].url}});
  t.mock.method(admin.auth(), "getUser", async () => ({uid: "owner", email: wall.email, emailVerified: true}));
  t.mock.method(R2Storage.prototype, "head", async (_bucket: "private" | "preview", object: string) => {
    const file = files.find((file) => file.asset.object === object);
    assert.ok(file);
    return {size: file.bytes.length, contentType: "image/png", sha256: file.asset.sha256, uid: "owner",
      objectId: file.asset.objectId, repo: "walls", path: file.path, gitSha: file.sha, uploadId: "upload-1"};
  });
  const auth = {uid: "moderator", token: {admin: true}};
  const context = () => getWallResubmissionContext.run({auth, data: {wallDocIds: ["w1"]}} as never);
  const before = await db.doc("walls/w1").get();
  await rejectWallForReview.run({auth, data: {wallDocId: "w1", expectedWallRevision: (await context()).contexts.w1.wallRevision,
    expectedReview: true, rejectionOperationId: "reject-live", reason: "Review again"}} as never);
  assert.equal(await tombstoneLiveAssets(before.data()), 0);
  await cleanupDeletedOwnedWall({wallId: "w1", canonicalPath: "walls/w1", incarnation: before.createTime?.toMillis(),
    incarnationNanos: before.createTime?.nanoseconds});
  assert.equal(store.get("ownedAssets/w1")?.status, "ready");
  const archive = await db.doc("rejectedWalls/w1").get();
  await undoWallRejection.run({auth, data: {wallDocId: "w1", expectedRejectionRevision: (await context()).contexts.w1.rejectionRevision,
    operationId: "undo-live"}} as never);
  assert.equal(store.has("ownedAssets/w1"), false);
  assert.equal(store.get("walls/w1")?.originalProtected, undefined);
  assert.equal(store.get("walls/w1")?.wallpaper_path, posters[0].path);
  await onRejectedLiveWallDeleted.run({data: archive, params: {wallId: "w1"}} as never);
  for (const file of files) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  await bindOwnedWall("w1");
  const recreated = await db.doc("walls/w1").get();
  assert.notEqual(recreated.createTime?.toMillis(), before.createTime?.toMillis());
  assert.equal(store.get("ownedAssets/w1")?.incarnation, recreated.createTime?.toMillis());
  assert.equal(store.get("walls/w1")?.originalProtected, true);
  await verifyLiveWall(recreated, "owner", deps(files));
  assert.equal((store.get("walls/w1")?.live as Doc).verified, true);
  assert.equal((store.get("walls/w1")?.live as Doc).durationMs, 5000);
  assert.equal(store.get("walls/w1")?.review, true);
});

test("terminal deletion of rejected live history cleans all six owned files", async (t) => {
  const {all, posters, wall, live} = fixture(t);
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PREVIEW_BUCKET: "public-previews"});
  const files = [...all, ...posters];
  const archive = {...wall, creatorUid: "owner", live: {...live, verified: true}, originalProtected: true,
    originalObjectId: posters[0].asset.objectId, wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: "",
    sourceWallCreateTime: admin.firestore.Timestamp.fromMillis(1)};
  const store = installFakeDb(t, {...receipts(files), "rejectedWalls/w1": archive,
    "ownedAssets/w1": {status: "ready", canonicalPath: "walls/w1", incarnation: 1, incarnationNanos: 1_000_000,
      original: posters[0].asset, thumb: posters[1].asset}});
  const removed = await db.doc("rejectedWalls/w1").get();
  await db.doc("rejectedWalls/w1").delete();
  t.mock.method(R2Storage.prototype, "delete", async () => undefined);
  await onRejectedLiveWallDeleted.run({data: removed, params: {wallId: "w1"}} as never);
  for (const file of files) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
  assert.equal(store.get("ownedAssets/w1")?.status, "deleted");
  assert.equal(onRejectedLiveWallDeleted.__endpoint.eventTrigger?.retry, true);
});

test("account closure tombstones unpublished still originals that no wall references", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, receipts(posters));
  assert.equal(await tombstoneUnreferencedLiveUploads("owner"), 2);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

function stillOwnedWall(posters: Owned[], extra: Doc = {}): Doc {
  return {
    id: "w1", email: "owner@example.com", creatorUid: "owner", review: false,
    wallpaper_url: "", wallpaper_thumb: posters[1].url, wallpaper_path: posters[0].path, wallpaper_sha: posters[0].sha,
    thumb_path: posters[1].path, thumb_sha: posters[1].sha, wallpaper_source_kind: "owned", thumb_source_kind: "owned",
    ...extra,
  };
}

test("unpublished still wall rows keep owned originals until accountClosing ignores them", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, {...receipts(posters), "walls/w1": stillOwnedWall(posters)});
  assert.equal(await tombstoneUnreferencedLiveUploads("owner"), 0);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 2);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("rejected still wall rows keep owned originals until accountClosing ignores them", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, {...receipts(posters), "rejectedWalls/w1": stillOwnedWall(posters)});
  assert.equal(await tombstoneUnreferencedLiveUploads("owner"), 0);
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 2);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("accountClosing preserves approved still originals and other principals' assets", async (t) => {
  const {posters} = fixture(t);
  const other = owned("other_1234567890123_z.jpg", Buffer.from("other-bytes"), false);
  const store = installFakeDb(t, {
    ...receipts(posters),
    ...receipts([other]),
    "walls/approved": stillOwnedWall(posters, {id: "approved", review: true}),
    [`r2ObjectRegistry/${other.asset.objectId}`]: {...other.asset, uid: "other", status: "active"},
  });
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 0);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  assert.equal(store.get(`r2ObjectRegistry/${other.asset.objectId}`)?.status, "active");
  assert.equal(store.get(`r2ObjectRegistry/${other.asset.objectId}`)?.uid, "other");
});

test("accountClosing tombstones a scrubbed unpublished still and ignores a foreign approved path", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, {
    ...receipts(posters),
    "walls/pending": stillOwnedWall(posters, {email: "", creatorUid: undefined}),
    "walls/foreign": {
      id: "foreign", review: true, email: "attacker@example.com", creatorUid: "attacker",
      wallpaper_url: "", wallpaper_thumb: posters[1].url, wallpaper_path: posters[0].path, wallpaper_sha: "c".repeat(40),
      thumb_path: posters[1].path, thumb_sha: "d".repeat(40), wallpaper_source_kind: "owned", thumb_source_kind: "owned",
    },
  });
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 2);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("accountClosing ignores a foreign approved still with matching path and sha", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, {
    ...receipts(posters),
    "walls/foreign": {
      id: "foreign", review: true, email: "attacker@example.com", creatorUid: "attacker",
      wallpaper_url: "", wallpaper_thumb: posters[1].url, wallpaper_path: posters[0].path, wallpaper_sha: posters[0].sha,
      thumb_path: posters[1].path, thumb_sha: posters[1].sha, wallpaper_source_kind: "owned", thumb_source_kind: "owned",
    },
  });
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 2);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("a failing still-registry check during accountClosing leaves receipts in place", async (t) => {
  const {posters} = fixture(t);
  const store = installFakeDb(t, receipts([posters[0]]));
  store.set(`r2ObjectRegistry/${posters[0].asset.objectId}`, {...posters[0].asset, status: "active", sha256: "e".repeat(64)});
  assert.equal(await tombstoneUnreferencedLiveUploads("owner", Date.now(), {accountClosing: true}), 0);
  assert.equal(store.get(`r2ObjectRegistry/${posters[0].asset.objectId}`)?.status, "active");
  assert.ok(store.has(`githubUploads/${uploadFileKey("walls",
    {path: posters[0].path, sha: posters[0].sha, sourceKind: "owned"})}`));
});

test("account closure tombstones orphan live uploads and preserves retained canonical and archive references", async (t) => {
  const {all, live} = fixture(t);
  const orphanVideo = owned("live_orphan.mp4", mp4());
  const orphanFrame = owned("frame_1_orphan.jpg", Buffer.from("orphan frame"));
  const files = [...all, orphanVideo, orphanFrame];
  const store = installFakeDb(t, {...receipts(files), "walls/retained": {kind: "live", live: {...live, verified: true}}});
  assert.equal(await tombstoneUnreferencedLiveUploads("owner"), 2);
  for (const file of all) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
  assert.equal(store.get(`r2ObjectRegistry/${orphanVideo.asset.objectId}`)?.status, "tombstoned");
  assert.equal(store.get(`r2ObjectRegistry/${orphanFrame.asset.objectId}`)?.status, "tombstoned");
  await db.doc("walls/retained").delete();
  await db.doc("rejectedWalls/retained").set({kind: "live", creatorUid: "owner", live});
  assert.equal(await tombstoneUnreferencedLiveUploads("owner"), 0);
});

test("rejection before binding followed by history deletion schedules all six raw live assets", async (t) => {
  const {all, posters, wall} = fixture(t);
  const files = [...all, ...posters];
  const archive = {...wall, creatorUid: "owner", sourceWallCreateTime: admin.firestore.Timestamp.fromMillis(1)};
  const store = installFakeDb(t, {...receipts(files), "rejectedWalls/w1": archive});
  const removed = await db.doc("rejectedWalls/w1").get();
  await db.doc("rejectedWalls/w1").delete();
  await onRejectedLiveWallDeleted.run({data: removed, params: {wallId: "w1"}} as never);
  for (const file of files) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});

test("raw live cleanup preserves all six files of a recreated canonical wall", async (t) => {
  const {all, posters, wall} = fixture(t);
  const files = [...all, ...posters];
  const store = installFakeDb(t, {...receipts(files), "walls/recreated": {...wall, creatorUid: "owner"}});
  assert.equal(await tombstoneLiveAssets({...wall, creatorUid: "owner"}), 0);
  for (const file of files) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
});

test("a shared owned manifest preserves raw live posters without retaining unrelated video files", async (t) => {
  const {all, posters, wall} = fixture(t);
  const files = [...all, ...posters];
  const store = installFakeDb(t, {...receipts(files), "ownedAssets/shared": {status: "ready",
    original: posters[0].asset, thumb: posters[1].asset}});
  assert.equal(await tombstoneLiveAssets({...wall, creatorUid: "owner"}), 4);
  for (const file of posters) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "active");
});

test("foreign raw poster claims cannot pin someone else's live assets", async (t) => {
  const {all, posters, wall} = fixture(t);
  const store = installFakeDb(t, {...receipts([...all, ...posters]), "walls/foreign": {...wall, creatorUid: "attacker"}});
  assert.equal(await tombstoneLiveAssets({...wall, creatorUid: "owner"}), 6);
  for (const file of [...all, ...posters]) assert.equal(store.get(`r2ObjectRegistry/${file.asset.objectId}`)?.status, "tombstoned");
});
