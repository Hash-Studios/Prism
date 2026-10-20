import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import {db} from "../common";
import * as ownedAssets from "../ownedAssetDelivery";
import {r2ObjectId} from "../r2Storage";
import {AI_LEGACY_UID, AI_STORAGE_REPO, aiUploadId} from "../aiWallSource";

import {
  canDeleteUpload,
  base64DecodedBytes,
  githubDeleteFile,
  githubPutFile,
  isAllowedRepo,
  isValidBase64,
  isValidGithubPath,
  weekStartUtc,
} from "../githubContent";

const env = {GH_REPO_WALLS: "walls", GH_REPO_SETUPS: "setups"};
function retainedFixture(path: string, sha: string, sourceKind?: "owned", uid = "u", uploadId?: string) {
  process.env.R2_PRIVATE_BUCKET = "owned";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
  const identity = {uid, repo: "walls", path, sha, ...(sourceKind ? {sourceKind} : {}), ...(uploadId ? {uploadId} : {})};
  const sha256 = "b".repeat(64);
  const objectId = r2ObjectId(identity, sha256);
  return {...identity, bucket: "owned", object: `${sourceKind ? "private-originals" : "retained"}/${objectId}`,
    objectId, sha256, ...(path.startsWith("thumb_") ? {previewObjectId: objectId} : {})};
}
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (fn: {run: (request: any) => Promise<any>}, request: Record<string, unknown>) => fn.run(request);

function manifestCleanupFixture(t: TestContext, privateOriginal = true) {
  testGithubEnvironment(t);
  const priorR2 = Object.fromEntries(["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"].map((key) => [key, process.env[key]]));
  process.env.R2_ACCOUNT_ID = "a".repeat(32);
  process.env.R2_ACCESS_KEY_ID = "access";
  process.env.R2_SECRET_ACCESS_KEY = "secret";
  process.env.R2_PRIVATE_BUCKET = "owned";
  process.env.R2_PREVIEW_BUCKET = "previews";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
  t.after(() => {
    for (const [key, value] of Object.entries(priorR2)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const asset = (path: string, kind?: "owned") => {
    const identity = {uid: "u", repo: "walls", path, sha: "c".repeat(40), ...(kind ? {sourceKind: kind} : {})};
    const objectId = r2ObjectId(identity, "b".repeat(64));
    return {bucket: "owned", object: `${kind ? "private-originals" : "retained"}/${objectId}`, objectId,
      sha256: "b".repeat(64), ...identity};
  };
  const original = asset("private.jpg", privateOriginal ? "owned" : undefined);
  const thumb = asset("thumb_wall.jpg", privateOriginal ? "owned" : undefined);
  const manifest = {status: "ready", canonicalPath: "walls/doc", incarnation: 123, incarnationNanos: 42,
    original, thumb, provenance: {uid: "u", kind: privateOriginal ? "owned" : "github"}};
  const receiptKey = (item: typeof thumb, kind?: string) => `githubUploads/${kind === "owned" ? "owned_" : ""}file_${
    createHash("sha256").update(`walls\0${item.path}\0${item.sha}`).digest("hex")}`;
  const race: {beforeClaim?: () => void} = {};
  let transactions = 0;
  const docs = uploadStore(t, {
    "ownedAssets/wall": manifest,
    [`r2ObjectRegistry/${original.objectId}`]: {status: "active", ...original, uploadId: "imported"},
    [`r2ObjectRegistry/${thumb.objectId}`]: {status: "active", ...thumb, uploadId: "imported"},
    [receiptKey(original, privateOriginal ? "owned" : undefined)]: {...original, retainedAsset: original, generation: "receipt-original"},
    [receiptKey(thumb, privateOriginal ? "owned" : undefined)]: {...thumb, retainedAsset: thumb,
      generation: "receipt-thumb", weeklyQuotaCharged: true,
      uploadWeek: weekStartUtc(Date.now())},
    "githubUploadStats/u": {week: weekStartUtc(Date.now()), weekCount: 1},
  }, 0, () => {
    if (++transactions === 2) race.beforeClaim?.();
  });
  const remove = (assetRole = "wallpaper", uid = "u", extras: Record<string, unknown> = {}) => run(githubDeleteFile, {
    auth: {uid}, data: {wallId: "wall", originalObjectId: original.objectId, assetRole, ...extras},
  });
  const retained = t.mock.method(ownedAssets, "deleteRetainedUpload", async () => {
    docs.set("ownedAssets/wall", {...docs.get("ownedAssets/wall"), status: "deleted"});
  });
  const github = t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  return {docs, original, thumb, manifest, remove, retained, github, receiptKey, race};
}

test("manifest cleanup resolves redacted assets after wall deletion and retries without charging quota twice", async (t) => {
  const {remove, docs, retained, github} = manifestCleanupFixture(t);
  assert.deepEqual(await remove(), {ok: true});
  assert.deepEqual(await remove("thumb"), {ok: true});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  assert.deepEqual(await remove(), {ok: true});
  assert.deepEqual(await remove("thumb"), {ok: true});
  assert.equal(retained.mock.callCount(), 2);
  assert.equal(github.mock.callCount(), 0);
});

test("manifest cleanup rejects strangers, mixed identifiers and stale original generations", async (t) => {
  const {remove, retained, github} = manifestCleanupFixture(t);
  await assert.rejects(() => remove("wallpaper", "stranger"), {code: "permission-denied"});
  await assert.rejects(() => remove("wallpaper", "u", {repo: "walls"}), {code: "invalid-argument"});
  await assert.rejects(() => remove("wallpaper", "u", {originalObjectId: "d".repeat(64)}), {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 0);
  assert.equal(github.mock.callCount(), 0);
});

test("manifest cleanup rejects same-path same-SHA replacement object identities", async (t) => {
  const {remove, docs, original, receiptKey, retained} = manifestCleanupFixture(t);
  const key = receiptKey(original, "owned");
  docs.set(key, {...docs.get(key), retainedAsset: retainedFixture(original.path, original.sha, "owned", "u", "replacement")});
  await assert.rejects(remove, {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 0);
});

for (const changedId of ["wall", "replacement"]) {
  test(`manifest cleanup rejects a recreated canonical wall with id ${changedId}`, async (t) => {
    const {remove, docs, retained} = manifestCleanupFixture(t);
    docs.set("walls/doc", {id: changedId, review: false, originalObjectId: "a".repeat(64), originalProtected: true,
      __createTime: {toMillis: () => 123, nanoseconds: 43}});
    await assert.rejects(remove, {code: "failed-precondition"});
    assert.equal(retained.mock.callCount(), 0);
  });
}

test("manifest cleanup preserves a failed asset for retry after the other asset was removed", async (t) => {
  const {remove, retained, docs} = manifestCleanupFixture(t);
  await remove();
  retained.mock.mockImplementationOnce(async () => {
    throw new Error("storage unavailable");
  });
  await assert.rejects(() => remove("thumb"), /storage unavailable/);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  await remove("thumb");
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
});

test("manifest cleanup rechecks wall incarnation inside the deletion claim", async (t) => {
  const {remove, docs, original, retained, race} = manifestCleanupFixture(t);
  race.beforeClaim = () => docs.set("walls/doc", {id: "wall", review: false, originalObjectId: original.objectId,
    originalProtected: true, __createTime: {toMillis: () => 124, nanoseconds: 42}});
  await assert.rejects(remove, {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 0);
});

test("manifest cleanup rejects an approved current wall", async (t) => {
  const {remove, docs, original, retained} = manifestCleanupFixture(t);
  docs.set("walls/doc", {id: "wall", review: true, originalObjectId: original.objectId, originalProtected: true,
    __createTime: {toMillis: () => 123, nanoseconds: 42}});
  await assert.rejects(remove, {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 0);
});

test("manifest cleanup supports a legacy GitHub original without private path inputs", async (t) => {
  const {remove, github, retained} = manifestCleanupFixture(t, false);
  assert.deepEqual(await remove(), {ok: true});
  assert.equal(github.mock.callCount(), 1);
  assert.equal(retained.mock.callCount(), 1);
});

test("manifest cleanup fences a replacement receipt between resolution and claim", async (t) => {
  const {remove, docs, original, receiptKey, retained, race} = manifestCleanupFixture(t);
  const key = receiptKey(original, "owned");
  race.beforeClaim = () => docs.set(key, {...docs.get(key), generation: "replacement-receipt",
    retainedAsset: retainedFixture(original.path, original.sha, "owned", "u", "replacement")});
  await assert.rejects(remove, {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 0);
});

test("manifest cleanup passes the exact retained object identity for a tombstoned deletion", async (t) => {
  const {remove, docs, original, retained, receiptKey} = manifestCleanupFixture(t);
  retained.mock.mockImplementation(async (input: {expected?: Record<string, unknown>}) => {
    assert.deepEqual(input.expected, original);
    docs.set("ownedAssets/wall", {...docs.get("ownedAssets/wall"), status: "deleted"});
  });
  await remove();
  assert.equal(retained.mock.callCount(), 1);
  assert.equal(docs.get("ownedAssets/wall")?.status, "deleted");
  assert.equal(docs.has(receiptKey(original, "owned")), false);
  assert.equal(docs.has("walls/doc"), false);
});

test("manifest cleanup lets an admin remove an exact legacy original without a receipt", async (t) => {
  const {docs, original, thumb, receiptKey, retained, github} = manifestCleanupFixture(t, false);
  docs.set("admin_users/boss@x.com", {ok: true});
  const legacyOriginal = retainedFixture(original.path, original.sha, undefined, "legacy-migration");
  const legacyThumb = retainedFixture(thumb.path, thumb.sha, undefined, "legacy-migration");
  docs.set("ownedAssets/wall", {...docs.get("ownedAssets/wall"), original: legacyOriginal,
    thumb: legacyThumb, provenance: {uid: "legacy-migration", kind: "legacy"}});
  docs.delete(receiptKey(original));
  docs.delete(receiptKey(thumb));
  retained.mock.mockImplementation(async (input: {expected?: Record<string, unknown>;
    authorize?: (tx: FirebaseFirestore.Transaction) => Promise<void>}) => {
    assert.ok(input.expected?.objectId === legacyOriginal.objectId || input.expected?.objectId === legacyThumb.objectId);
    assert.ok(input.authorize);
    const authorize = input.authorize;
    assert.ok(authorize);
    await db.runTransaction(authorize);
  });
  const adminRemove = (uid = "boss", token = {admin: true}, assetRole = "wallpaper") => run(githubDeleteFile, {
    auth: {uid, token},
    data: {wallId: "wall", originalObjectId: legacyOriginal.objectId, assetRole},
  });
  assert.deepEqual(await adminRemove(), {ok: true});
  assert.deepEqual(await adminRemove(), {ok: true});
  assert.deepEqual(await adminRemove("boss", {admin: true}, "thumb"), {ok: true});
  assert.equal(retained.mock.callCount(), 3);
  assert.equal(github.mock.callCount(), 0);
  await assert.rejects(() => adminRemove("stranger", {admin: false}),
    {code: "permission-denied"});
});

test("manifest cleanup deletes live AI R2 assets for their owner without GitHub receipts", async (t) => {
  testGithubEnvironment(t);
  const priorR2 = Object.fromEntries(["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"].map((key) => [key, process.env[key]]));
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "owned", R2_PREVIEW_BUCKET: "previews", R2_PREVIEW_BASE_URL: "https://images.example.com"});
  t.after(() => {
    for (const [key, value] of Object.entries(priorR2)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const generationId = "gen_abc123_0123456789abcdef";
  const asset = (role: "original" | "thumb") => {
    const path = role === "original" ? `ai/original/${generationId}.png` : `ai/public/${generationId}.png`;
    const uploadId = aiUploadId(generationId, role);
    const identity = {uid: "u", repo: AI_STORAGE_REPO, path, sha: "c".repeat(40), sourceKind: "ai" as const, uploadId};
    const sha256 = "b".repeat(64);
    const objectId = r2ObjectId(identity, sha256);
    return {bucket: "owned", object: `ai-originals/${objectId}`, objectId, sha256, ...identity,
      ...(role === "thumb" ? {previewObjectId: objectId} : {})};
  };
  const original = asset("original");
  const thumb = asset("thumb");
  const store = uploadStore(t, {"ownedAssets/wall": {status: "ready", canonicalPath: "walls/doc", incarnation: 1,
    incarnationNanos: 1_000_000, original, thumb, provenance: {kind: "ai", uid: "u", generationId}},
  "walls/doc": {id: "wall", review: false, originalProtected: true, originalObjectId: original.objectId,
    __createTime: {toMillis: () => 1, nanoseconds: 1_000_000}},
  });
  const retained = t.mock.method(ownedAssets, "deleteRetainedUpload", async (input: {
    expected?: Record<string, unknown>; authorize?: (tx: FirebaseFirestore.Transaction) => Promise<void>;
  }) => {
    assert.ok([original.objectId, thumb.objectId].includes(input.expected?.objectId as string));
    assert.ok(input.authorize, "R2-only deletion revalidates the manifest during tombstoning");
    const authorize = input.authorize;
    assert.ok(authorize);
    await db.runTransaction(authorize);
  });
  const github = t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  await assert.rejects(() => run(githubDeleteFile, {auth: {uid: "stranger"}, data: {
    wallId: "wall", originalObjectId: original.objectId, assetRole: "wallpaper",
  }}), {code: "permission-denied"});
  assert.equal(retained.mock.callCount(), 0, "a copied wall identity does not authorize R2 deletion");
  assert.deepEqual(await run(githubDeleteFile, {auth: {uid: "u"}, data: {
    wallId: "wall", originalObjectId: original.objectId, assetRole: "wallpaper",
  }}), {ok: true});
  assert.deepEqual(await run(githubDeleteFile, {auth: {uid: "u"}, data: {
    wallId: "wall", originalObjectId: original.objectId, assetRole: "wallpaper",
  }}), {ok: true}, "a repeated R2 deletion remains idempotent");
  assert.deepEqual(await run(githubDeleteFile, {auth: {uid: "u"}, data: {
    wallId: "wall", originalObjectId: original.objectId, assetRole: "thumb",
  }}), {ok: true});
  assert.equal(retained.mock.callCount(), 3, "both R2 roles and a retry use the tombstone cleanup path");
  store.set("walls/doc", {id: "wall", review: true, originalProtected: true, originalObjectId: original.objectId,
    __createTime: {toMillis: () => 1, nanoseconds: 1_000_000}});
  await assert.rejects(() => run(githubDeleteFile, {auth: {uid: "u"}, data: {
    wallId: "wall", originalObjectId: original.objectId, assetRole: "wallpaper",
  }}), {code: "failed-precondition"}, "an approved current wall cannot be deleted by its owner");
  assert.equal(retained.mock.callCount(), 3);
  assert.equal(github.mock.callCount(), 0);
  assert.equal([...store.keys()].some((key) => key.startsWith("githubUploads/")), false);
});

test("manifest cleanup lets admins remove legacy AI and Firebase Storage R2 objects without GitHub calls", async (t) => {
  testGithubEnvironment(t);
  const priorR2 = Object.fromEntries(["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"].map((key) => [key, process.env[key]]));
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "owned", R2_PREVIEW_BUCKET: "previews", R2_PREVIEW_BASE_URL: "https://images.example.com"});
  t.after(() => {
    for (const [key, value] of Object.entries(priorR2)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const legacyAi = "gen_abc123_0123456789abcdef";
  const asset = (uid: string, repo: string, path: string, sourceKind?: "ai", uploadId?: string, preview = false) => {
    const identity = {uid, repo, path, sha: "c".repeat(40), ...(sourceKind ? {sourceKind, uploadId} : {})};
    const sha256 = "b".repeat(64);
    const objectId = r2ObjectId(identity, sha256);
    return {bucket: "owned", object: `${sourceKind === "ai" ? "ai-originals" : "retained"}/${objectId}`,
      objectId, sha256, ...identity, ...(preview ? {previewObjectId: objectId} : {})};
  };
  const aiOriginal = asset(AI_LEGACY_UID, AI_STORAGE_REPO, `ai/original/${legacyAi}.png`, "ai",
    aiUploadId(legacyAi, "original"));
  const aiThumb = asset(AI_LEGACY_UID, AI_STORAGE_REPO, `ai/public/${legacyAi}.png`, "ai",
    aiUploadId(legacyAi, "thumb"), true);
  const firebaseOriginal = asset("legacy-migration", "firebase-storage", "prism-wallpapers.appspot.com/old.jpg");
  const firebaseThumb = asset("legacy-migration", "walls", "thumb_old.jpg", undefined, undefined, true);
  const store = uploadStore(t, {
    "admin_users/admin@example.com": {ok: true},
    "ownedAssets/ai-wall": {status: "ready", canonicalPath: "walls/ai-wall", incarnation: 123, incarnationNanos: 42,
      original: aiOriginal, thumb: aiThumb, provenance: {kind: "ai-legacy", generationId: legacyAi}},
    "ownedAssets/firebase-wall": {status: "ready", canonicalPath: "walls/firebase-wall", incarnation: 123,
      incarnationNanos: 42, original: firebaseOriginal, thumb: firebaseThumb, provenance: {kind: "legacy", uid: "legacy-migration"}},
  });
  const retained = t.mock.method(ownedAssets, "deleteRetainedUpload", async (input: {expected?: Record<string, unknown>;
    authorize?: (tx: FirebaseFirestore.Transaction) => Promise<void>}) => {
    assert.ok(input.authorize);
    const authorize = input.authorize;
    assert.ok(authorize);
    await db.runTransaction(authorize);
  });
  const github = t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  for (const [wallId, original, role] of [["ai-wall", aiOriginal, "wallpaper"], ["firebase-wall", firebaseOriginal, "wallpaper"]] as const) {
    assert.deepEqual(await run(githubDeleteFile, {auth: {uid: "admin", token: {email: "admin@example.com", email_verified: true}},
      data: {wallId, originalObjectId: original.objectId, assetRole: role}}), {ok: true});
  }
  assert.equal(retained.mock.callCount(), 2);
  assert.equal(github.mock.callCount(), 0);
  assert.deepEqual(store.get("ownedAssets/ai-wall")?.provenance,
    {kind: "ai-legacy", generationId: legacyAi}, "legacy AI cleanup stays admin-only and preserves its no-owner claim");
});

test("manifest cleanup rechecks a legacy admin proof inside the tombstone transaction", async (t) => {
  const {docs, original, receiptKey, retained, github} = manifestCleanupFixture(t, false);
  docs.set("admin_users/boss@x.com", {ok: true});
  const legacyOriginal = retainedFixture(original.path, original.sha, undefined, "legacy-migration");
  docs.set("ownedAssets/wall", {...docs.get("ownedAssets/wall"), original: legacyOriginal,
    provenance: {uid: "legacy-migration", kind: "legacy"}});
  docs.delete(receiptKey(original));
  retained.mock.mockImplementation(async (input: {authorize?: (tx: FirebaseFirestore.Transaction) => Promise<void>}) => {
    docs.set("ownedAssets/wall", {...docs.get("ownedAssets/wall"), provenance: {uid: "changed", kind: "changed"}});
    const authorize = input.authorize;
    assert.ok(authorize);
    await db.runTransaction(authorize);
  });
  await assert.rejects(() => run(githubDeleteFile, {
    auth: {uid: "boss", token: {admin: true}},
    data: {wallId: "wall", originalObjectId: legacyOriginal.objectId, assetRole: "wallpaper"},
  }), {code: "failed-precondition"});
  assert.equal(retained.mock.callCount(), 1);
  assert.equal(github.mock.callCount(), 0);
});

test("private originals use a separate identity from legacy GitHub paths", async (t) => {
  testGithubEnvironment(t);
  const path = "a.jpg";
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const pathHash = createHash("sha256").update(`walls\0${path}`).digest("hex");
  const fileHash = createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex");
  const legacy = {uid: "victim", repo: "walls", path, sha, sourceKind: "github"};
  const docs = uploadStore(t, {[`githubUploads/file_${fileHash}`]: legacy});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  t.mock.method(ownedAssets, "retainUpload", async (input: {sourceKind?: string}) => {
    assert.equal(input.sourceKind, "owned");
    return retainedFixture(path, sha, "owned", "u");
  });
  const fetch = t.mock.method(globalThis, "fetch", async () => {
    throw new Error("Path validation must not depend on GitHub");
  });
  const request = {auth: {uid: "u"}, data: {repo: "walls", path, message: "upload", contentBase64: "/9j/",
    purpose: "wallpaper"}};
  await run(githubPutFile, request);
  await run(githubPutFile, request);
  assert.equal(fetch.mock.callCount(), 0);
  assert.deepEqual(docs.get(`githubUploads/file_${fileHash}`), legacy);
  assert.equal(docs.has(`githubUploadIntents/path_${pathHash}`), false);
  assert.equal(docs.get(`githubUploadIntents/owned_path_${pathHash}`)?.uid, "u");
  assert.equal(docs.get(`githubUploads/owned_file_${fileHash}`)?.uid, "u");
  const legacyIntent = {uid: "victim", repo: "walls", path, sha, blobSha: sha, sourceKind: "github", status: "complete"};
  docs.set(`githubUploadIntents/path_${pathHash}`, legacyIntent);
  await run(githubPutFile, request);
  assert.deepEqual(docs.get(`githubUploadIntents/path_${pathHash}`), legacyIntent);
});

test("profile and unspecified uploads stay on GitHub when R2 is configured", async (t) => {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  const path = "avatar.jpg";
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const github = t.mock.method(globalThis, "fetch", async (url: RequestInfo | URL, init?: RequestInit) => {
    const uploadPath = decodeURIComponent(String(url).split("/").pop()!);
    return init?.method === "GET" ? {ok: false, status: 404, json: async () => ({})} : {ok: true, json: async () => ({
      content: {path: uploadPath, sha, download_url: `https://raw.example/${uploadPath}`},
    })};
  });
  const retain = t.mock.method(ownedAssets, "retainUpload", async () => {
    throw new Error("GitHub profile uploads must not be retained privately");
  });

  for (const [index, purpose] of [undefined, "profile"].entries()) {
    const uploadPath = `${index}-${path}`;
    const data = {repo: "walls", path: uploadPath, message: "upload", contentBase64: "/9j/", ...(purpose ? {purpose} : {})};
    const uploadSha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
    assert.deepEqual(await run(githubPutFile, {auth: {uid: "u"}, data}), {
      content: {path: uploadPath, sha: uploadSha, download_url: `https://raw.example/${uploadPath}`}, sourceKind: "github",
    });
  }
  assert.equal(github.mock.callCount(), 4);
  assert.equal(retain.mock.callCount(), 0);
  assert.equal([...docs.entries()].some(([key, value]) => key.startsWith("githubUploads/") && value.retainedAsset), false);
});

test("invalid upload purpose is rejected before writes", async (t) => {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {});
  const github = t.mock.method(globalThis, "fetch", async () => {
    throw new Error("Invalid purposes must fail before GitHub requests");
  });
  await assert.rejects(run(githubPutFile, {auth: {uid: "u"}, data: {
    repo: "walls", path: "avatar.jpg", message: "upload", contentBase64: "/9j/", purpose: "cover",
  }}), {code: "invalid-argument"});
  assert.equal(github.mock.callCount(), 0);
  assert.deepEqual([...docs.keys()], []);
});

test("profile upload deletion does not require an R2 receipt", async (t) => {
  testGithubEnvironment(t);
  const path = "avatar.jpg";
  const sha = "a".repeat(40);
  const hash = createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex");
  const docs = uploadStore(t, {[`githubUploads/file_${hash}`]: {
    uid: "u", repo: "walls", path, sha, sourceKind: "github",
  }});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  const github = t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  assert.deepEqual(await run(githubDeleteFile, {auth: {uid: "u"}, data: {
    repo: "walls", path, message: "delete", sha,
  }}), {ok: true});
  assert.equal(github.mock.callCount(), 1);
  assert.equal(docs.has(`githubUploads/file_${hash}`), false);
});

test("private original upload, completed retry and deletion never contact GitHub", async (t) => {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("GitHub must not be contacted");
  });
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  let retained = 0;
  t.mock.method(ownedAssets, "retainUpload", async (input: {uploadId: string}) => {
    retained++;
    return retainedFixture("private.jpg", sha, "owned", "u", input.uploadId);
  });
  let deleted = 0;
  t.mock.method(ownedAssets, "deleteRetainedUpload", async () => {
    deleted++;
  });
  const request = {auth: {uid: "u"}, data: {repo: "walls", path: "private.jpg", message: "upload", contentBase64: "/9j/",
    purpose: "wallpaper"}};
  const expected = {content: {path: "private.jpg", sha, download_url: ""}, sourceKind: "owned"};
  assert.deepEqual(await run(githubPutFile, request), expected);
  assert.deepEqual(await run(githubPutFile, request), expected);
  assert.equal(retained, 1);
  assert.equal([...docs.entries()].find(([key]) => key.startsWith("githubUploads/"))?.[1].sourceKind, "owned");
  await run(githubDeleteFile, {auth: {uid: "u"}, data: {repo: "walls", path: "private.jpg", message: "delete", sha}});
  assert.equal(deleted, 1);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploads/")), false);
});

for (const legacyUid of ["u", "victim"]) {
  test(`private deletion cannot remove a colliding GitHub upload owned by ${legacyUid}`, async (t) => {
    testGithubEnvironment(t);
    const path = "a.jpg";
    const sha = "a".repeat(40);
    const hash = createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex");
    const pathHash = createHash("sha256").update(`walls\0${path}`).digest("hex");
    const legacy = {uid: legacyUid, repo: "walls", path, sha, sourceKind: "github"};
    const docs = uploadStore(t, {
      [`githubUploads/file_${hash}`]: legacy,
      [`githubUploads/owned_file_${hash}`]: {uid: "u", repo: "walls", path, sha, sourceKind: "owned",
        retainedAsset: retainedFixture(path, sha, "owned")},
    });
    t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
    const fetch = t.mock.method(globalThis, "fetch", async () => {
      throw new Error("No GitHub delete allowed");
    });
    const retained = t.mock.method(ownedAssets, "deleteRetainedUpload", async (input: {sourceKind?: string}) => {
      assert.equal(input.sourceKind, "owned");
    });
    const data = {repo: "walls", path, sha, message: "delete"};
    if (legacyUid === "u") {
      await assert.rejects(run(githubDeleteFile, {auth: {uid: "u"}, data}), {code: "failed-precondition"});
      assert.equal(retained.mock.callCount(), 0);
    }
    await run(githubDeleteFile, {auth: {uid: "u"}, data: {...data, sourceKind: "owned"}});
    if (legacyUid === "u") {
      await assert.rejects(run(githubDeleteFile, {auth: {uid: "u"}, data}), {code: "failed-precondition"});
    } else {
      await run(githubDeleteFile, {auth: {uid: "u"}, data});
    }
    await run(githubDeleteFile, {auth: {uid: "u"}, data: {...data, sourceKind: "owned"}});
    assert.equal(retained.mock.callCount(), 1);
    assert.equal(fetch.mock.callCount(), 0);
    assert.deepEqual(docs.get(`githubUploads/file_${hash}`), legacy);
    assert.equal(docs.has(`githubUploads/owned_file_${hash}`), false);
    assert.equal(docs.has(`githubUploadIntents/owned_path_${pathHash}`), false);
    assert.equal(docs.get(`ownedUploadDeletions/owned_file_${hash}`)?.status, "deleted");
  });
}

for (const privateDeleted of [false, true]) {
  test(`another user's private ${privateDeleted ? "tombstone" : "receipt"} cannot block legacy deletion`, async (t) => {
    testGithubEnvironment(t);
    const path = "a.jpg";
    const sha = "a".repeat(40);
    const hash = createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex");
    const privateRecord = {uid: "attacker", repo: "walls", path, sha, sourceKind: "owned"};
    const privateKey = privateDeleted ? `ownedUploadDeletions/owned_file_${hash}` : `githubUploads/owned_file_${hash}`;
    const privateState = privateDeleted ? {...privateRecord, status: "deleted"} : privateRecord;
    const docs = uploadStore(t, {
      [`githubUploads/file_${hash}`]: {uid: "victim", repo: "walls", path, sha, sourceKind: "github",
        retainedAsset: retainedFixture(path, sha, undefined, "victim")},
      [privateKey]: privateState,
    });
    const fetch = t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
    t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
    t.mock.method(ownedAssets, "deleteRetainedUpload", async (input: {sourceKind?: string}) => {
      assert.equal(input.sourceKind, undefined);
    });
    await run(githubDeleteFile, {auth: {uid: "victim"}, data: {repo: "walls", path, sha, message: "delete"}});
    assert.equal(fetch.mock.callCount(), 1);
    assert.equal(docs.has(`githubUploads/file_${hash}`), false);
    assert.deepEqual(docs.get(privateKey), privateState);
  });
}

test("private rollout blocks legacy pending originals before any public GitHub write", async (t) => {
  testGithubEnvironment(t);
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const key = `path_${createHash("sha256").update("walls\0pending.jpg").digest("hex")}`;
  uploadStore(t, {[`githubUploadIntents/${key}`]: {
    uid: "u", repo: "walls", path: "pending.jpg", blobSha: sha, status: "pending", attemptExpiresAt: 0,
  }});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  let fetches = 0;
  t.mock.method(globalThis, "fetch", async () => {
    fetches++; throw new Error("No origin request allowed");
  });
  await assert.rejects(run(githubPutFile, {auth: {uid: "u"}, data: {
    repo: "walls", path: "pending.jpg", message: "retry", contentBase64: "/9j/", purpose: "wallpaper",
  }}), /reconciliation/);
  assert.equal(fetches, 0);
});

test("private deletion tombstones permit same-path reuploads with same or different bytes", async (t) => {
  testGithubEnvironment(t);
  uploadStore(t, {});
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("No GitHub request allowed");
  });
  t.mock.method(ownedAssets, "retainUpload", async (input: {sha: string; uploadId: string}) =>
    retainedFixture("a.jpg", input.sha, "owned", "u", input.uploadId));
  t.mock.method(ownedAssets, "deleteRetainedUpload", async () => undefined);
  for (const contentBase64 of ["/9j/", "/9j/", "/9j/AA=="]) {
    const result = await run(githubPutFile, {auth: {uid: "u"}, data: {
      repo: "walls", path: "a.jpg", message: "upload", contentBase64, purpose: "wallpaper",
    }});
    assert.equal(result.content.path, "a.jpg");
    await run(githubDeleteFile, {auth: {uid: "u"}, data: {repo: "walls", path: "a.jpg", sha: result.content.sha, message: "delete"}});
  }
});

test("R2 preview retention failure retries without a GitHub write and preserves exact upload bytes", async (t) => {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {});
  const bytes = Buffer.from([0xff, 0xd8, 0xff, 0x00, 0x01, 0xfe]);
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const path = "thumb_retained.jpg";
  const github = t.mock.method(globalThis, "fetch", async () => {
    throw new Error("No GitHub request allowed");
  });
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  let retains = 0;
  let retained: ReturnType<typeof retainedFixture>;
  t.mock.method(ownedAssets, "retainUpload", async (input: {bytes: Buffer; uploadId: string}) => {
    assert.deepEqual(input.bytes, bytes);
    if (++retains === 1) throw new Error("storage unavailable");
    retained = retainedFixture(path, sha, "owned", "u", input.uploadId);
    return retained;
  });
  const upload = () => run(githubPutFile, {auth: {uid: "u"}, data: {
    repo: "walls", path, message: "upload", contentBase64: bytes.toString("base64"), purpose: "wallpaper",
  }});
  await assert.rejects(upload, /storage unavailable/);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploads/")), false);
  const result = await upload();
  assert.deepEqual(result, {content: {path, sha,
    download_url: `https://images.example.com/previews/${retained!.objectId}.img`}, sourceKind: "owned"});
  assert.equal(github.mock.callCount(), 0);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.ok([...docs.entries()].find(([key]) => key.startsWith("githubUploads/"))?.[1].retainedAsset);
  for (const [key, value] of docs) {
    if (key.startsWith("githubUploads/") || key.startsWith("githubUploadIntents/")) delete value.retainedAsset;
  }
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("GitHub origin unavailable");
  });
  assert.deepEqual(await upload(), result);
  assert.equal(retains, 3);
  assert.ok([...docs.entries()].find(([key]) => key.startsWith("githubUploads/"))?.[1].retainedAsset);
});

test("allows configured repositories only", () => {
  assert.equal(isAllowedRepo("walls", env), true);
  assert.equal(isAllowedRepo("other", env), false);
  assert.equal(isAllowedRepo("owner/walls", env), false);
});

test("retained deletion failure preserves evidence and retries after GitHub is gone", async (t) => {
  testGithubEnvironment(t);
  const week = weekStartUtc(Date.now());
  const sha = "a".repeat(40);
  const asset = retainedFixture("thumb_a.jpg", sha);
  const docs = uploadStore(t, {
    [`githubUploads/${sha}`]: {uid: "u", repo: "walls", path: "thumb_a.jpg", sha,
      retainedAsset: asset, weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {week, weekCount: 1},
  });
  let requests = 0;
  t.mock.method(globalThis, "fetch", async () => ({ok: ++requests === 1, status: requests === 1 ? 200 : 404,
    json: async () => ({})}));
  t.mock.method(ownedAssets, "ownedAssetStorageEnabled", () => true);
  let deletes = 0;
  t.mock.method(ownedAssets, "deleteRetainedUpload", async (identity: unknown) => {
    assert.deepEqual(identity, {repo: "walls", path: "thumb_a.jpg", sha, expected: asset});
    if (++deletes === 1) throw new Error("storage delete unavailable");
  });
  const remove = () => run(githubDeleteFile, {auth: {uid: "u"}, data: {
    repo: "walls", path: "thumb_a.jpg", message: "delete", sha,
  }});
  await assert.rejects(remove, /storage delete unavailable/);
  assert.equal(docs.has(`githubUploads/${sha}`), true);
  assert.equal([...docs.entries()].find(([key]) => key.startsWith("githubUploadIntents/"))?.[1].status, "deleting");
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.deepEqual(await remove(), {ok: true});
  assert.equal(docs.has(`githubUploads/${sha}`), false);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
});

test("isValidBase64 accepts canonical data and rejects malformed encodings", () => {
  assert.equal(isValidBase64("AA=="), true);
  assert.equal(isValidBase64("AQID"), true);
  assert.equal(isValidBase64("AA="), false);
  assert.equal(isValidBase64("AQ!D"), false);
  assert.equal(isValidBase64("AB=="), false);
});

test("the 15 MiB base64 boundary is valid", () => {
  const bytes = Buffer.alloc(15 * 1024 * 1024);
  const encoded = bytes.toString("base64");
  assert.equal(base64DecodedBytes(encoded), bytes.length);
  assert.equal(isValidBase64(encoded), true);
});

test("rejects unsafe GitHub content paths", () => {
  assert.equal(isValidGithubPath("images/wall.png"), true);
  assert.equal(isValidGithubPath("../secret"), false);
  assert.equal(isValidGithubPath("images/../secret"), false);
  assert.equal(isValidGithubPath("/secret"), false);
  assert.equal(isValidGithubPath("images/"), false);
});

test("canDeleteUpload: admins can delete without an ownership record", () => {
  assert.equal(canDeleteUpload(undefined, "user-1", "walls", "images/a.png", true), true);
});

test("canDeleteUpload: rejects a missing ownership record", () => {
  assert.equal(canDeleteUpload(undefined, "user-1", "walls", "images/a.png", false), false);
});

test("canDeleteUpload: rejects a record owned by another uid", () => {
  const record = {uid: "user-2", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/a.png", false), false);
});

test("canDeleteUpload: rejects a record for a different repo or path", () => {
  const record = {uid: "user-1", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "setups", "images/a.png", false), false);
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/b.png", false), false);
});

test("canDeleteUpload: allows the owner to delete their own upload", () => {
  const record = {uid: "user-1", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/a.png", false), true);
});

function uploadStore(t: TestContext, seed: Record<string, Record<string, unknown>>, failReceiptWrites = 0,
  beforeTransaction?: () => void) {
  const docs = new Map<string, Record<string, unknown>>(Object.entries(seed));
  let transactionQueue = Promise.resolve();
  const set = (path: string, data: Record<string, unknown>) => {
    if (path.startsWith("githubUploads/") && failReceiptWrites > 0) {
      failReceiptWrites--;
      throw new Error("temporary receipt write failure");
    }
    docs.set(path, data);
  };
  const ref = (path: string) => ({
    path,
    get: async () => ({exists: docs.has(path), data: () => docs.get(path)}),
    set: async (data: Record<string, unknown>) => set(path, data),
    delete: async () => void docs.delete(path),
  });
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ref(`${name}/${id}`),
    where: (field: string, _op: string, value: unknown) => ({
      limit: () => ({query: {name, field, value}}),
      get: async () => ({docs: [...docs.entries()].filter(([path, data]) => {
        const actual = field.split(".").reduce<unknown>((item, part) =>
          item && typeof item === "object" ? (item as Record<string, unknown>)[part] : undefined, data);
        return path.startsWith(`${name}/`) && actual === value;
      }).map(([path, data]) => ({ref: ref(path), data: () => data}))}),
    }),
  }));
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => {
    const run = transactionQueue.then(async () => {
      beforeTransaction?.();
      const writes: (() => void)[] = [];
      let hasWritten = false;
      const tx = {
        get: async (document: {path: string; query?: {name: string; field: string; value: unknown}}) => {
          if (hasWritten) throw new Error("Firestore transactions require reads before writes");
          if (document.query) {
            const {name, field, value} = document.query;
            const rows = [...docs.entries()].filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === value)
              .map(([path, data]) => ({ref: ref(path), data: () => data, createTime: data.__createTime}));
            return {size: rows.length, docs: rows};
          }
          const value = docs.get(document.path);
          return {exists: value !== undefined, data: () => value, ref: document, createTime: value?.__createTime};
        },
        update: (document: {path: string}, data: Record<string, unknown>) => {
          hasWritten = true;
          writes.push(() => docs.set(document.path, {...docs.get(document.path), ...data}));
        },
        set: (document: {path: string}, data: Record<string, unknown>) => {
          hasWritten = true;
          writes.push(() => set(document.path, data));
        },
        delete: (document: {path: string}) => {
          hasWritten = true;
          writes.push(() => void docs.delete(document.path));
        },
      };
      const result = await callback(tx);
      writes.forEach((write) => write());
      return result;
    });
    transactionQueue = run.then(() => undefined, () => undefined);
    return run;
  });
  return docs;
}

function testGithubEnvironment(t: TestContext) {
  const priorR2 = {R2_PRIVATE_BUCKET: process.env.R2_PRIVATE_BUCKET, R2_PREVIEW_BASE_URL: process.env.R2_PREVIEW_BASE_URL};
  const prior = {token: process.env.GH_TOKEN, username: process.env.GH_USERNAME, walls: process.env.GH_REPO_WALLS};
  t.after(() => {
    for (const [key, value] of Object.entries(priorR2)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    for (const [key, value] of Object.entries({GH_TOKEN: prior.token, GH_USERNAME: prior.username, GH_REPO_WALLS: prior.walls})) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  process.env.GH_TOKEN = "test-token";
  process.env.GH_USERNAME = "owner";
  process.env.GH_REPO_WALLS = "walls";
}

async function deleteRequest(t: TestContext, upload: Record<string, unknown>, stats: Record<string, unknown>) {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {"githubUploads/sha": upload, "githubUploadStats/u": stats});
  t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  const result = await run(githubDeleteFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "thumb_a.jpg", message: "delete", sha: "sha"},
  });
  return {docs, result};
}

test("githubDeleteFile releases quota charged by this week's free wall preview", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs, result} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: true, uploadWeek: week,
  }, {day, count: 2, week, weekCount: 1});
  assert.deepEqual(result, {ok: true});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
});

test("githubDeleteFile does not release a premium upload's weekly quota", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: false, uploadWeek: week,
  }, {day, count: 2, week, weekCount: 2});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
});

test("githubDeleteFile does not release this week's quota for an older upload", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const oldWeek = new Date(Date.parse(`${week}T00:00:00Z`) - 7 * 86_400_000).toISOString().slice(0, 10);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: true, uploadWeek: oldWeek,
  }, {day, count: 2, week, weekCount: 2});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
});

test("githubDeleteFile refunds once and fences a duplicate delete from a same-path reupload", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day, count: 2, week, weekCount: 1},
  });
  let deleteCount = 0;
  const remote = new Map<string, Record<string, unknown>>();
  const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const path = decodeURIComponent(new URL(rawUrl.toString()).pathname.split("/contents/")[1]);
    if (init.method === "DELETE") {
      deleteCount++;
      remote.delete(path);
      return {ok: true, status: 200, json: async () => ({})};
    }
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ? {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({})};
    }
    const content = {path, sha: blobSha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });

  await remove();
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  await assert.rejects(remove, {code: "permission-denied"});
  await run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  assert.equal(deleteCount, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubDeleteFile blocks a duplicate delete and reupload while delete is in flight", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day, count: 1, week, weekCount: 1},
    "usersv2/u": {premium: false},
  });
  let deleteCount = 0;
  let started!: () => void;
  const deleteStarted = new Promise<void>((resolve) => {
    started = resolve;
  });
  let finishDelete!: () => void;
  const deleteResponse = new Promise<void>((resolve) => {
    finishDelete = resolve;
  });
  const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
  const remote = new Map<string, Record<string, unknown>>();
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "DELETE") {
      deleteCount++;
      started();
      remote.delete("thumb_wall.jpg");
      await deleteResponse;
      return {ok: true, status: 200, json: async () => ({})};
    }
    if (init.method === "GET") {
      const content = remote.get("thumb_wall.jpg");
      return content ? {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({})};
    }
    const content = {path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg"};
    remote.set("thumb_wall.jpg", content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });
  const firstDelete = remove();
  await deleteStarted;
  await assert.rejects(remove, {code: "resource-exhausted"});
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  }), {code: "failed-precondition"});
  assert.equal(deleteCount, 1);
  finishDelete();
  await firstDelete;
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  await run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  assert.equal(deleteCount, 1);
  assert.equal(remote.get("thumb_wall.jpg")?.sha, blobSha);
});

test("githubDeleteFile recovers a lost response after its lease and refunds only once", async (t) => {
  testGithubEnvironment(t);
  let nowMs = Date.parse("2026-10-01T12:00:00Z");
  t.mock.method(Date, "now", () => nowMs);
  const week = weekStartUtc(nowMs);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day: "2026-10-01", count: 1, week, weekCount: 2},
  });
  let deleteCount = 0;
  t.mock.method(globalThis, "fetch", async () => {
    if (++deleteCount === 1) throw new Error("response lost after GitHub deletion");
    return {ok: false, status: 404, json: async () => ({message: "Not Found"})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });

  await assert.rejects(remove, {code: "internal"});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
  assert.equal(docs.has("githubUploads/sha"), true);
  await assert.rejects(remove, {code: "resource-exhausted"});
  assert.equal(deleteCount, 1);
  nowMs += 120_000;
  assert.deepEqual(await remove(), {ok: true});
  assert.equal(deleteCount, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.equal(docs.has("githubUploads/sha"), false);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
  await assert.rejects(remove, {code: "permission-denied"});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile keeps a main wall upload when a failed preview is retried", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  const remote = new Map<string, Record<string, unknown>>();
  let previewPutCount = 0;
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    const body = JSON.parse(init.body as string) as {content: string};
    const bytes = Buffer.from(body.content, "base64");
    const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
    const content = {path, sha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    if (path === "thumb_wall.jpg" && ++previewPutCount === 1) throw new Error("response lost after GitHub commit");
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const put = (path: string) => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path, message: path, contentBase64: "/9j/"},
  });

  await put("wall.jpg");
  await assert.rejects(() => put("thumb_wall.jpg"), {code: "internal"});
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "v"},
    data: {repo: "walls", path: "thumb_wall.jpg", message: "thumb_wall.jpg", contentBase64: "/9j/"},
  }), {code: "permission-denied"});
  const recovered = await put("thumb_wall.jpg");
  assert.deepEqual(recovered, {content: remote.get("thumb_wall.jpg"), sourceKind: "github"});
  assert.equal(docs.get("githubUploadStats/u")?.count, 3);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.equal(previewPutCount, 1);
});

test("githubPutFile retries receipt persistence without charging the weekly quota twice", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  }, 1);
  const remote = new Map<string, Record<string, unknown>>();
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  let putCount = 0;
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    putCount++;
    const content = {path, sha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const put = () => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "thumb_wall.jpg", message: "thumb_wall.jpg", contentBase64: "/9j/"},
  });

  await assert.rejects(put, /temporary receipt write failure/);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  const recovered = await put();
  assert.deepEqual(recovered, {content: remote.get("thumb_wall.jpg"), sourceKind: "github"});
  assert.equal(putCount, 1);
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile rolls back weekly quota after a definite GitHub rejection", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  let puts = 0;
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
    puts++;
    return {ok: false, status: 422, json: async () => ({message: "validation failed"})};
  });

  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  }), {code: "internal"});
  assert.equal(puts, 1);
  assert.equal(docs.get("githubUploadStats/u")?.count, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
});

for (const premiumInitially of [false, true]) {
  test(`githubPutFile revalidates an unwritten retry after ${premiumInitially ? "a Free downgrade" : "a new week"}`, async (t) => {
    testGithubEnvironment(t);
    let nowMs = Date.parse("2026-10-01T12:00:00Z");
    t.mock.method(Date, "now", () => nowMs);
    const week = weekStartUtc(nowMs);
    const docs = uploadStore(t, {
      "usersv2/u": {premium: premiumInitially},
      "githubUploadStats/u": {day: "2026-10-01", count: 0, week, weekCount: 0},
    });
    const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
    let puts = 0;
    t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
      if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
      if (++puts === 1) throw new Error("GitHub was unreachable before writing");
      return {ok: true, status: 201, json: async () => ({content: {
        path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg",
      }})};
    });
    const upload = () => run(githubPutFile, {
      auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
    });
    await assert.rejects(upload, {code: "internal"});
    assert.equal(docs.get("githubUploadStats/u")?.weekCount, premiumInitially ? 0 : 1);

    if (!premiumInitially) nowMs = Date.parse("2026-10-05T12:00:00Z");
    const currentWeek = weekStartUtc(nowMs);
    docs.set("usersv2/u", {premium: false});
    docs.set("githubUploadStats/u", {
      day: new Date(nowMs).toISOString().slice(0, 10), count: 1, week: currentWeek, weekCount: 3,
    });
    await assert.rejects(upload, {code: "resource-exhausted"});
    assert.equal(puts, 1);
    docs.set("githubUploadStats/u", {...docs.get("githubUploadStats/u"), weekCount: 2});
    assert.deepEqual(await upload(), {content: {
      path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg",
    }, sourceKind: "github"});
    assert.equal(puts, 2);
    assert.equal(docs.get("githubUploadStats/u")?.weekCount, 3);
    const receipt = [...docs.entries()].find(([key]) => key.startsWith("githubUploads/"))?.[1];
    assert.equal(receipt?.weeklyQuotaCharged, true);
    assert.equal(receipt?.uploadWeek, currentWeek);
  });
}

test("githubPutFile permits only one simultaneous upload for a path", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  let puts = 0;
  let started!: () => void;
  const putStarted = new Promise<void>((resolve) => {
    started = resolve;
  });
  let finishPut!: () => void;
  const putResponse = new Promise<void>((resolve) => {
    finishPut = resolve;
  });
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
    puts++;
    started();
    await putResponse;
    return {ok: true, status: 201, json: async () => ({content: {
      path: "thumb_wall.jpg", sha: createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex"),
      download_url: "https://raw.example/thumb_wall.jpg",
    }})};
  });
  const upload = () => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  const firstUpload = upload();
  await putStarted;
  await assert.rejects(upload, {code: "resource-exhausted"});
  assert.equal(puts, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  finishPut();
  await firstUpload;
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile does not claim a pre-existing public file with matching bytes", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/v": {premium: false},
    "githubUploadStats/v": {day, count: 0, week, weekCount: 0},
  });
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  t.mock.method(globalThis, "fetch", async () => ({
    ok: true,
    status: 200,
    json: async () => ({path: "thumb_public.jpg", sha, download_url: "https://raw.example/thumb_public.jpg"}),
  }));

  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "v"},
    data: {repo: "walls", path: "thumb_public.jpg", message: "thumb_public.jpg", contentBase64: "/9j/"},
  }), {code: "already-exists"});
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
  assert.equal(docs.get("githubUploadStats/v")?.weekCount, 0);
});

test("githubPutFile rejects malformed base64 before reserving upload quota", async (t) => {
  testGithubEnvironment(t);
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not reserve quota for malformed content");
  });
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "wall.jpg", message: "wall", contentBase64: "AQ!D"},
  }), {code: "invalid-argument"});
});

test("githubDeleteFile rejects path-like SHAs before Firestore lookup", async (t) => {
  testGithubEnvironment(t);
  t.mock.method(db, "collection", () => {
    throw new Error("must not look up a path-like document ID");
  });
  await assert.rejects(() => run(githubDeleteFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "wall.jpg", message: "wall", sha: "../wall"},
  }), {code: "invalid-argument"});
});

test("githubPutFile keeps separate delete records when files share a blob SHA", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
    "githubUploadStats/v": {day, count: 0, week, weekCount: 0},
  });
  const bytes = Buffer.from("/9j/", "base64");
  const sameSha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  const remote = new Map<string, Record<string, unknown>>();
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    if (init.method === "DELETE") {
      remote.delete(path);
      return {ok: true, status: 200, json: async () => ({})};
    }
    const content = {path, sha: sameSha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });

  for (const [uid, path] of [["u", "a.jpg"], ["v", "b.jpg"]]) {
    await run(githubPutFile, {
      auth: {uid},
      data: {repo: "walls", path, message: path, contentBase64: "/9j/"},
    });
  }
  assert.deepEqual(
    [...docs.entries()].filter(([key]) => key.startsWith("githubUploads/")).map(([, record]) => record.path).sort(),
    ["a.jpg", "b.jpg"],
  );

  for (const [uid, path] of [["u", "a.jpg"], ["v", "b.jpg"]]) {
    await run(githubDeleteFile, {
      auth: {uid},
      data: {repo: "walls", path, message: path, sha: sameSha},
    });
  }
  assert.equal([...docs.keys()].filter((key) => key.startsWith("githubUploads/")).length, 0);
  await run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "a.jpg", message: "a.jpg", contentBase64: "/9j/"},
  });
  assert.equal([...docs.keys()].filter((key) => key.startsWith("githubUploads/")).length, 1);
});

test("githubDeleteFile accepts a verified admin_users admin who owns no upload record", async (t) => {
  testGithubEnvironment(t);
  uploadStore(t, {"admin_users/boss@x.com": {ok: true}});
  t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  const result = await run(githubDeleteFile, {
    auth: {uid: "boss", token: {email: "boss@x.com", email_verified: true}},
    data: {repo: "walls", path: "thumb_a.jpg", message: "delete", sha: "sha"},
  });
  assert.deepEqual(result, {ok: true});
});

test("githubDeleteFile refuses an unverified admin_users email and a plain user", async (t) => {
  testGithubEnvironment(t);
  uploadStore(t, {"admin_users/boss@x.com": {ok: true}});
  t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  for (const token of [{email: "boss@x.com", email_verified: false}, {email: "user@x.com", email_verified: true}]) {
    await assert.rejects(() => run(githubDeleteFile, {
      auth: {uid: "boss", token},
      data: {repo: "walls", path: "thumb_a.jpg", message: "delete", sha: "sha"},
    }), {code: "permission-denied"});
  }
});
