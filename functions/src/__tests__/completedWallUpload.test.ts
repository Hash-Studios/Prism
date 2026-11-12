import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "../common";
import {proveStillWallUpload, uploadFileKey, uploadPathKey} from "../completedWallUpload";
import {ownedThumbnailUrl, type StoredUpload} from "../ownedAssetDelivery";
import {R2Storage, r2ObjectId} from "../r2Storage";
import {type Doc, installFakeDb} from "./fakeDb";

const RAW = "https://raw.githubusercontent.com/owner/walls/main";
const sha1 = (bytes: Buffer) => createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

function env(t: TestContext, extra: Record<string, string> = {}) {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  Object.assign(process.env, {
    GH_REPO_WALLS: "walls", GH_USERNAME: "owner", GH_TOKEN: "test-token",
    R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "private-assets", R2_PREVIEW_BUCKET: "public-previews",
    R2_PREVIEW_BASE_URL: "https://images.example.com", ...extra,
  });
}

function githubRecord(path: string, sha: string, url: string, uid = "maker"): Record<string, Doc> {
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

function ownedFile(path: string, bytes: Buffer, preview: boolean) {
  const sha = sha1(bytes);
  const digest = sha256(bytes);
  const identity = {uid: "maker", repo: "walls", path, sha, sourceKind: "owned" as const, uploadId: "upload-1"};
  const objectId = r2ObjectId(identity, digest);
  const asset: StoredUpload = {...identity, bucket: "private-assets", object: `private-originals/${objectId}`,
    objectId, sha256: digest, ...(preview ? {previewObjectId: objectId} : {})};
  const url = preview ? ownedThumbnailUrl(asset) : "";
  const file = {path, sha, sourceKind: "owned" as const};
  const record = {
    uid: "maker", repo: "walls", path, sha, sourceKind: "owned", generation: "generation-1",
    weeklyQuotaCharged: true, uploadWeek: "2026-W01", retainedAsset: asset, uploadId: "upload-1",
    createdAt: admin.firestore.Timestamp.fromMillis(1),
  };
  const docs: Record<string, Doc> = {
    [`githubUploads/${uploadFileKey("walls", file)}`]: record,
    [`githubUploadIntents/${uploadPathKey("walls", file)}`]: {
      ...record, status: "complete", blobSha: sha,
      response: {sourceKind: "owned", content: {path, sha, download_url: url}},
      retainedAsset: asset,
    },
    [`r2ObjectRegistry/${objectId}`]: {...asset, status: "active"},
  };
  return {file, asset, bytes, url, docs};
}

function mockGithub(t: TestContext, files: Record<string, string | "missing" | "changed">) {
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL) => {
    const url = String(input);
    const path = decodeURIComponent(url.split("/contents/")[1] ?? "");
    const spec = files[path];
    if (!spec || spec === "missing") return {ok: false, status: 404, json: async () => ({})};
    const sha = spec === "changed" ? "c".repeat(40) : spec;
    return {ok: true, status: 200, json: async () => ({path, sha, type: "file"})};
  });
}

function mockPrivateAndPreview(t: TestContext, files: Array<{asset: StoredUpload; bytes: Buffer}>,
  preview: "ok" | "missing" | "changed" = "ok") {
  const byObject = new Map(files.map((file) => [file.asset.object, file]));
  t.mock.method(R2Storage.prototype, "head", async (kind: string, object: string) => {
    if (kind === "preview") {
      const id = object.replace(/^previews\//, "").replace(/\.img$/, "");
      const match = files.find((file) => file.asset.objectId === id);
      if (preview === "missing" || !match) return null;
      const sha = preview === "changed" ? "e".repeat(64) : match.asset.sha256;
      return {objectId: match.asset.objectId, sha256: sha, uid: match.asset.uid, size: match.bytes.length};
    }
    const match = byObject.get(object);
    if (!match) return null;
    return {objectId: match.asset.objectId, sha256: match.asset.sha256, uid: match.asset.uid,
      repo: match.asset.repo, path: match.asset.path, gitSha: match.asset.sha,
      uploadId: match.asset.uploadId ?? "imported", size: match.bytes.length};
  });
  t.mock.method(R2Storage.prototype, "get", async (kind: string, object: string) => {
    if (kind === "preview") {
      const id = object.replace(/^previews\//, "").replace(/\.img$/, "");
      const match = files.find((file) => file.asset.objectId === id);
      if (!match) throw new Error("R2 GET failed (404)");
      return preview === "changed" ? Buffer.from("changed-preview") : match.bytes;
    }
    const match = byObject.get(object);
    if (!match) throw new Error("R2 GET failed (404)");
    return match.bytes;
  });
}

async function prove(uid: string, file: {path: string; sha: string; sourceKind: "github" | "owned"},
  role: "original" | "thumbnail") {
  return db.runTransaction((tx) => proveStillWallUpload(tx, uid, file, role));
}

test("proveStillWallUpload accepts a GitHub original whose live SHA still matches", async (t) => {
  env(t);
  const sha = "a".repeat(40);
  installFakeDb(t, githubRecord("a.jpg", sha, `${RAW}/a.jpg`));
  mockGithub(t, {"a.jpg": sha});
  const proven = await prove("maker", {path: "a.jpg", sha, sourceKind: "github"}, "original");
  assert.equal(proven.url, `${RAW}/a.jpg`);
});

test("proveStillWallUpload rejects a GitHub file that is missing from the live repo", async (t) => {
  env(t);
  const sha = "a".repeat(40);
  installFakeDb(t, githubRecord("a.jpg", sha, `${RAW}/a.jpg`));
  mockGithub(t, {"a.jpg": "missing"});
  await assert.rejects(() => prove("maker", {path: "a.jpg", sha, sourceKind: "github"}, "original"),
    (error: unknown) => error instanceof HttpsError && error.code === "failed-precondition");
});

test("proveStillWallUpload rejects a GitHub file whose live SHA changed", async (t) => {
  env(t);
  const sha = "a".repeat(40);
  installFakeDb(t, githubRecord("a.jpg", sha, `${RAW}/a.jpg`));
  mockGithub(t, {"a.jpg": "changed"});
  await assert.rejects(() => prove("maker", {path: "a.jpg", sha, sourceKind: "github"}, "original"),
    (error: unknown) => error instanceof HttpsError && error.code === "failed-precondition");
});

test("proveStillWallUpload retries a GitHub outage instead of treating it as a missing file", async (t) => {
  env(t);
  const sha = "a".repeat(40);
  installFakeDb(t, githubRecord("a.jpg", sha, `${RAW}/a.jpg`));
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("GitHub unavailable");
  });
  await assert.rejects(() => prove("maker", {path: "a.jpg", sha, sourceKind: "github"}, "original"),
    (error: unknown) => error instanceof HttpsError && error.code === "internal");
});

test("proveStillWallUpload accepts an owned original without a public preview object", async (t) => {
  env(t);
  const original = ownedFile("maker_1234567890123_a.jpg", Buffer.from("original-bytes"), false);
  installFakeDb(t, original.docs);
  mockPrivateAndPreview(t, [original]);
  const proven = await prove("maker", original.file, "original");
  assert.equal(proven.url, "");
});

test("proveStillWallUpload accepts an owned thumbnail whose public preview hash matches", async (t) => {
  env(t);
  const thumb = ownedFile("thumb_maker_1234567890123_a.jpg", Buffer.from("thumb-bytes"), true);
  installFakeDb(t, thumb.docs);
  mockPrivateAndPreview(t, [thumb]);
  const proven = await prove("maker", thumb.file, "thumbnail");
  assert.equal(proven.url, thumb.url);
});

test("proveStillWallUpload rejects an owned thumbnail whose public preview is missing", async (t) => {
  env(t);
  const thumb = ownedFile("thumb_maker_1234567890123_a.jpg", Buffer.from("thumb-bytes"), true);
  installFakeDb(t, thumb.docs);
  mockPrivateAndPreview(t, [thumb], "missing");
  await assert.rejects(() => prove("maker", thumb.file, "thumbnail"),
    (error: unknown) => error instanceof HttpsError && error.code === "failed-precondition" &&
      error.message === "Preview is unavailable.");
});

test("proveStillWallUpload rejects an owned thumbnail whose public preview hash changed", async (t) => {
  env(t);
  const thumb = ownedFile("thumb_maker_1234567890123_a.jpg", Buffer.from("thumb-bytes"), true);
  installFakeDb(t, thumb.docs);
  mockPrivateAndPreview(t, [thumb], "changed");
  await assert.rejects(() => prove("maker", thumb.file, "thumbnail"),
    (error: unknown) => error instanceof HttpsError && error.code === "failed-precondition" &&
      error.message === "Preview is unavailable.");
});
