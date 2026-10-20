import assert from "node:assert/strict";
import {test} from "node:test";
import {createHash} from "node:crypto";
import {mkdtemp, readFile, rm, stat} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import sharp from "sharp";
import {buildGithubInventory, createInventoryReport, gitBlobSha, migrateGithubInventory, parseGithubAsset, type GithubTree,
  proveMigrationAsset, type MigrationDeps, type MigrationOptions, type MigrationWall,
  isLegacyMigrationUid,
  validateMigrationCommit, validateReviewedInventory,
  verifyR2MigrationCopy, writeInventoryReport} from "../scripts/migrateGithubToR2";
import {installFakeDb} from "./fakeDb";

const bytes = Buffer.from("image bytes");
const sha = gitBlobSha(bytes);
const options: MigrationOptions = {apply: false, allowReviewedLegacy: false, owner: "hash", repo: "walls",
  commit: "a".repeat(40)};
const wall = (data: Record<string, unknown> = {}): MigrationWall => ({docPath: "walls/canonical",
  incarnation: 100, incarnationNanos: 1_000_000, data: {id: "wall_1", review: true,
    wallpaper_url: "https://raw.githubusercontent.com/hash/walls/" + options.commit + "/original.jpg",
    wallpaper_thumb: "https://raw.githubusercontent.com/hash/walls/" + options.commit + "/thumb_original.jpg",
    wallpaper_path: "original.jpg", thumb_path: "thumb_original.jpg", wallpaper_sha: sha, thumb_sha: sha,
    ...data}});
const tree: GithubTree = {truncated: false, entries: [
  {path: "original.jpg", sha, size: bytes.length, type: "blob"},
  {path: "thumb_original.jpg", sha, size: bytes.length, type: "blob"},
  {path: "orphan.webp", sha, size: bytes.length, type: "blob"},
]};
function fixture(owner: string | null = "creator") {
  const calls: string[] = [];
  let ready = false;
  const deps: MigrationDeps = {
    prove: async () => ({uid: owner, legacyEligible: owner === null}),
    fetchBytes: async (asset) => {
      calls.push(`fetch:${asset.path}`); return bytes;
    },
    retain: async (asset) => {
      calls.push(`retain:${asset.path}`);
      const objectId = asset.path.startsWith("thumb_") ? "2".repeat(64) : "1".repeat(64);
      return {repo: asset.repo, path: asset.path, sha: asset.sha, uid: asset.uid, bucket: "private",
        object: `retained/${objectId}`, objectId, sha256: createHash("sha256").update(bytes).digest("hex"),
        ...(asset.path.startsWith("thumb_") ? {previewObjectId: objectId} : {})};
    },
    verify: async (asset) => {
      calls.push(`verify:${asset.path}`);
    },
    revalidate: async () => {
      calls.push("revalidate");
    },
    attach: async (asset) => {
      calls.push(`attach:${asset.path}`);
    },
    bind: async (id) => {
      calls.push(`bind:${id}`); ready = true;
    },
    bindLegacy: async (input) => {
      calls.push("bind-legacy"); assert.equal(input.wallId, "wall_1"); ready = true;
    },
    ready: async () => ready,
  };
  return {calls, deps};
}

test("inventory pins exact GitHub tree blobs and reports unreferenced image objects", () => {
  const inventory = buildGithubInventory([wall()], tree, options);
  assert.equal(inventory.commit, options.commit);
  assert.equal(inventory.assets.length, 2);
  assert.equal(inventory.orphanImageCount, 1);
  assert.equal(inventory.wallCount, 1);
  assert.equal(inventory.assets[0].gitSha, sha);
  assert.equal(inventory.walls[0].status, "planned");
});

test("durable report is private and excludes full Firestore wall data and URLs", async () => {
  const inventory = buildGithubInventory([wall({email: "creator@example.com"})], tree, options);
  const report = createInventoryReport(inventory);
  const directory = await mkdtemp(join(tmpdir(), "prism-r2-report-"));
  try {
    const path = join(directory, "inventory.json");
    await writeInventoryReport(path, report);
    const parsed = JSON.parse(await readFile(path, "utf8")) as Record<string, unknown>;
    assert.equal((await stat(path)).mode & 0o777, 0o600);
    assert.doesNotMatch(JSON.stringify(parsed), /creator@example\.com|raw\.githubusercontent\.com/);
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
});

test("apply accepts only the exact reviewed commit and unchanged inventory", async () => {
  validateMigrationCommit(options.commit, true);
  assert.throws(() => validateMigrationCommit("master", true), /exact 40-character commit SHA/);
  assert.doesNotThrow(() => validateMigrationCommit("master", false));
  const inventory = buildGithubInventory([wall()], tree, options);
  const reviewed = {mode: "dry-run", policy: {allowReviewedLegacy: false}, inventory: createInventoryReport(inventory)};
  await assert.doesNotReject(validateReviewedInventory(reviewed, inventory, options.commit, false));
  const changed = {...inventory, treeHash: "0".repeat(64)};
  await assert.rejects(validateReviewedInventory(reviewed, changed, options.commit, false), /changed since review/);
  await assert.rejects(validateReviewedInventory(reviewed, inventory, options.commit, true), /changed since review/);
});

test("review snapshot includes nanosecond incarnation and explicit image roles", () => {
  const inventory = buildGithubInventory([wall()], tree, options);
  assert.equal((createInventoryReport(inventory).walls[0] as {incarnationNanos: number}).incarnationNanos, 1_000_000);
  const swapped = buildGithubInventory([wall({wallpaper_path: "thumb_original.jpg", thumb_path: "original.jpg"})], tree, options);
  assert.equal(swapped.walls[0].status, "blocked");
  assert.match(swapped.walls[0].detail, /explicit original and thumb_/);
});

test("apply report resumes after a successful redacted row without changing its reviewed snapshot", async () => {
  const reviewedInventory = createInventoryReport(buildGithubInventory([wall()], tree, options));
  const reviewed = {mode: "apply", policy: {allowReviewedLegacy: false}, inventory: reviewedInventory, reviewedInventory};
  const redactedWall = wall({originalProtected: true, originalObjectId: "1".repeat(64), wallpaper_url: "",
    wallpaper_thumb: "https://cdn.example/thumb", wallpaper_path: "", thumb_path: "",
    wallpaper_sha: "", thumb_sha: ""});
  const live = buildGithubInventory([redactedWall], tree, options);
  const partialReport = {...reviewed, inventory: createInventoryReport(live), results: [{status: "migrated"}]};
  (partialReport.inventory as {referencedImageCount: number; assets: unknown[]}).referencedImageCount = 0;
  (partialReport.inventory as {assets: unknown[]}).assets = [];
  const verify = async (_wall: MigrationWall, original: {path: string}, thumb: {path: string}) =>
    original.path === "original.jpg" && thumb.path === "thumb_original.jpg";
  await assert.doesNotReject(validateReviewedInventory(partialReport, live, options.commit, false, verify));
  await assert.rejects(validateReviewedInventory(partialReport, live, options.commit, false, async () => false),
    /changed since review/);
  const malicious = {...redactedWall, incarnationNanos: 1_000_001};
  const changed = buildGithubInventory([malicious], tree, options);
  await assert.rejects(validateReviewedInventory(partialReport, changed, options.commit, false, verify),
    /changed since review/);
});

test("dry-run proves ownership and inventories without downloading bytes or writing storage", async () => {
  const {calls, deps} = fixture();
  const inventory = buildGithubInventory([wall()], tree, options);
  const results = await migrateGithubInventory(inventory, {...options, apply: false}, deps);
  assert.deepEqual(results.map((item) => item.status), ["would-migrate"]);
  assert.deepEqual(calls, []);
});

test("legacy eligibility requires complete absence of receipts and intents", async (t) => {
  const store = installFakeDb(t);
  const asset = buildGithubInventory([wall()], tree, options).assets[0];
  assert.deepEqual(await proveMigrationAsset(asset), {uid: null, legacyEligible: true});
  store.set("githubUploads/partial", {repo: "walls", path: asset.path, uid: "creator"});
  assert.deepEqual(await proveMigrationAsset(asset), {uid: null, legacyEligible: false});
});

test("legacy migrated manifests require the legacy-migration original UID", () => {
  assert.equal(isLegacyMigrationUid("legacy-migration"), true);
  assert.equal(isLegacyMigrationUid("creator"), false);
  assert.equal(isLegacyMigrationUid(undefined), false);
});

test("modern provenance binds matching public receipt and completed intent", async (t) => {
  const store = installFakeDb(t);
  const asset = buildGithubInventory([wall()], tree, options).assets.find((entry) => entry.path === "original.jpg")!;
  const hash = (value: string) => createHash("sha256").update(value).digest("hex");
  const receiptId = `file_${hash(`${asset.repo}\0${asset.path}\0${asset.gitSha}`)}`;
  const intentId = `path_${hash(`${asset.repo}\0${asset.path}`)}`;
  store.set(`githubUploads/${receiptId}`, {repo: asset.repo, path: asset.path, sha: asset.gitSha, uid: "creator"});
  store.set(`githubUploadIntents/${intentId}`, {repo: asset.repo, path: asset.path, uid: "creator", status: "complete",
    blobSha: asset.gitSha, response: {content: {sha: asset.gitSha, path: asset.path, download_url: asset.recordedUrl}}});
  assert.deepEqual(await proveMigrationAsset(asset), {uid: "creator", legacyEligible: false});
});

test("modern source provenance may retain the original main-branch URL", async (t) => {
  const store = installFakeDb(t);
  const branchWall = wall({wallpaper_url: "https://raw.githubusercontent.com/hash/walls/main/original.jpg"});
  const asset = buildGithubInventory([branchWall], tree, options).assets.find((entry) => entry.path === "original.jpg")!;
  const hash = (value: string) => createHash("sha256").update(value).digest("hex");
  const receiptId = `file_${hash(`${asset.repo}\0${asset.path}\0${asset.gitSha}`)}`;
  const intentId = `path_${hash(`${asset.repo}\0${asset.path}`)}`;
  store.set(`githubUploads/${receiptId}`, {repo: asset.repo, path: asset.path, sha: asset.gitSha, uid: "creator"});
  store.set(`githubUploadIntents/${intentId}`, {repo: asset.repo, path: asset.path, uid: "creator", status: "complete",
    blobSha: asset.gitSha, response: {content: {sha: asset.gitSha, path: asset.path, download_url: asset.recordedUrl}}});
  assert.deepEqual(await proveMigrationAsset(asset), {uid: "creator", legacyEligible: false});
});

test("truncated GitHub tree cannot produce a complete inventory", () => {
  assert.throws(() => buildGithubInventory([wall()], {...tree, truncated: true}, options), /truncated/);
});

test("wall URLs and source paths must match assets at the pinned commit", () => {
  const branchUrl = wall({wallpaper_url: "https://raw.githubusercontent.com/hash/walls/main/original.jpg"});
  const inventory = buildGithubInventory([branchUrl], tree, options);
  assert.equal(inventory.walls[0].original?.url,
    `https://raw.githubusercontent.com/hash/walls/${options.commit}/original.jpg`);
  const missing = {...tree, entries: tree.entries.filter((entry) => entry.path !== "thumb_original.jpg")};
  const blocked = buildGithubInventory([wall()], missing, options);
  assert.equal(blocked.walls[0].status, "blocked");
  assert.match(blocked.walls[0].detail, /missing from pinned GitHub tree/);
  assert.throws(() => parseGithubAsset("https://raw.githubusercontent.com/evil/walls/" + options.commit + "/x.jpg",
    "x.jpg", options), /Untrusted/);
});

test("asset preserves the exact recorded URL while downloads use the canonical pinned URL", () => {
  const recordedUrl = `https://RAW.GITHUBUSERCONTENT.COM/hash/walls/${options.commit}/original.jpg`;
  const asset = parseGithubAsset(recordedUrl, "original.jpg", options);
  assert.equal(asset.recordedUrl, recordedUrl);
  assert.equal(asset.url, `https://raw.githubusercontent.com/hash/walls/${options.commit}/original.jpg`);
});

test("R2 readback checks private and public-preview bytes against their SHA-256 digest", async () => {
  const asset = {repo: "walls", path: "thumb_original.jpg", sha, uid: "creator", bucket: "private",
    object: "retained/one", objectId: "1".repeat(64), sha256: createHash("sha256").update(bytes).digest("hex"),
    previewObjectId: "1".repeat(64)};
  const calls: string[] = [];
  const get = async (kind: "private" | "preview", object: string) => {
    calls.push(`${kind}:${object}`); return bytes;
  };
  await verifyR2MigrationCopy(asset, bytes.length, get, async () => undefined);
  assert.deepEqual(calls, ["private:retained/one", `preview:previews/${"1".repeat(64)}.img`]);
  await assert.rejects(verifyR2MigrationCopy(asset, bytes.length, async () => Buffer.from("wrong"),
    async () => undefined), /readback mismatch/);
});

test("apply verifies source bytes and durable R2 readback before binding", async () => {
  const {calls, deps} = fixture();
  const inventory = buildGithubInventory([wall()], tree, options);
  const results = await migrateGithubInventory(inventory, {...options, apply: true}, deps);
  assert.equal(results[0].status, "migrated");
  assert.deepEqual(calls, ["revalidate", "fetch:original.jpg", "fetch:thumb_original.jpg", "revalidate",
    "retain:original.jpg", "retain:thumb_original.jpg", "verify:original.jpg", "verify:thumb_original.jpg", "attach:original.jpg",
    "attach:thumb_original.jpg", "bind:wall_1"]);
});

test("legacy rows require reviewed opt-in and do not fabricate creator receipts", async () => {
  const {calls, deps} = fixture(null);
  const inventory = buildGithubInventory([wall({wallpaper_sha: undefined, thumb_sha: undefined})], tree, options);
  const blocked = await migrateGithubInventory(inventory, {...options, apply: false}, deps);
  assert.match(blocked[0].detail, /Unproven or partial provenance/);
  const permitted = await migrateGithubInventory(inventory, {...options, apply: true, allowReviewedLegacy: true}, deps);
  assert.equal(permitted[0].status, "migrated");
  assert.ok(calls.includes("bind-legacy"));
  assert.ok(!calls.some((call) => call.startsWith("attach:")));
});

test("retried apply is safe after partial storage writes", async () => {
  const {calls, deps} = fixture();
  let fail = true;
  const retain = deps.retain;
  deps.retain = async (asset) => {
    if (asset.path.startsWith("thumb_") && fail) {
      fail = false; throw new Error("temporary R2 failure");
    }
    return retain(asset);
  };
  const inventory = buildGithubInventory([wall()], tree, options);
  assert.equal((await migrateGithubInventory(inventory, {...options, apply: true}, deps))[0].status, "blocked");
  assert.equal((await migrateGithubInventory(inventory, {...options, apply: true}, deps))[0].status, "migrated");
  assert.equal(calls.filter((call) => call.startsWith("bind:")).length, 1);
});

test("apply rejects missing public preview copy before changing receipts or binding", async () => {
  const {calls, deps} = fixture();
  const retain = deps.retain;
  deps.retain = async (asset) => {
    const stored = await retain(asset);
    if (asset.path.startsWith("thumb_")) delete stored.previewObjectId;
    return stored;
  };
  const inventory = buildGithubInventory([wall()], tree, options);
  const [result] = await migrateGithubInventory(inventory, {...options, apply: true}, deps);
  assert.equal(result.status, "blocked");
  assert.match(result.detail, /privacy role/);
  assert.ok(!calls.some((call) => call.startsWith("attach:") || call.startsWith("bind:")));
});

test("downloader rejects invalid image bytes and mismatched source SHA", async (t) => {
  const image = await sharp({create: {width: 2, height: 2, channels: 3, background: "red"}}).png().toBuffer();
  const source = parseGithubAsset(`https://raw.githubusercontent.com/hash/walls/${options.commit}/original.jpg`,
    "original.jpg", options);
  t.mock.method(globalThis, "fetch", async (_url: unknown, init?: RequestInit) => {
    assert.equal(init?.redirect, "manual");
    assert.equal(new Headers(init?.headers).get("accept-encoding"), "identity");
    return new Response(new Uint8Array(image), {headers: {"content-length": String(image.length)}});
  });
  assert.deepEqual(await (await import("../scripts/migrateGithubToR2.js")).downloadGithubAsset({...source,
    gitSha: gitBlobSha(image), sha: gitBlobSha(image), size: image.length}), image);
  await assert.rejects((await import("../scripts/migrateGithubToR2.js")).downloadGithubAsset({...source,
    gitSha: "0".repeat(40), size: image.length}), /Git blob SHA mismatch/);
});
