import assert from "node:assert/strict";
import {test} from "node:test";
import {createHash} from "node:crypto";
import sharp from "sharp";
import {downloadRawAsset, gitBlobSha, migrateOwnedAssets, MigrationDeps, MigrationOptions,
  MigrationWall, parseRawAsset, proveMigrationAsset} from "../scripts/migrateOwnedAssets";
import {installFakeDb} from "./fakeDb";

const options: MigrationOptions = {apply: false, allowReviewedLegacy: false, owner: "hash", repo: "walls"};
const bytes = Buffer.from("test bytes");
const sha = gitBlobSha(bytes);
const wall = (docPath = "walls/old-auto-id"): MigrationWall => ({docPath, incarnation: 10, incarnationNanos: 10000000, data: {
  id: "logical-id", review: true, wallpaper_url: "https://raw.githubusercontent.com/hash/walls/main/a.jpg",
  wallpaper_thumb: "https://raw.githubusercontent.com/hash/walls/main/thumb_a.jpg",
  wallpaper_path: "a.jpg", thumb_path: "thumb_a.jpg", wallpaper_sha: sha, thumb_sha: sha,
}});
function fixture(owner: string | null = "u1") {
  const calls: string[] = [];
  let ready = false;
  const deps: MigrationDeps = {
    prove: async () => owner,
    ready: async () => ready,
    fetchBytes: async () => {
      calls.push("fetch"); return bytes;
    },
    retain: async ({bytes: _bytes, url: _url, ...input}) => {
      calls.push("retain");
      return {...input, bucket: "private", object: "retained/test", generation: "1", sha256: "digest"};
    },
    attach: async () => {
      calls.push("attach");
    },
    bind: async () => {
      calls.push("bind"); ready = true;
    },
    bindLegacy: async (input) => {
      calls.push("legacy");
      assert.equal(input.canonicalPath, "walls/old-auto-id");
      assert.equal(input.original.uid, "legacy-migration");
      ready = true;
    },
  };
  return {calls, deps};
}

test("modern migration ignores foreign private twins without changing private provenance", async (t) => {
  const store = installFakeDb(t);
  const digest = (value: string) => createHash("sha256").update(value).digest("hex");
  const assets = [parseRawAsset(wall().data.wallpaper_url, "a.jpg", sha, options),
    parseRawAsset(wall().data.wallpaper_thumb, "thumb_a.jpg", sha, options)];
  for (const asset of assets) {
    store.set(`githubUploads/file_${digest(`walls\0${asset.path}\0${sha}`)}`,
      {repo: "walls", path: asset.path, sha, uid: "u1"});
    store.set(`githubUploadIntents/path_${digest(`walls\0${asset.path}`)}`, {
      repo: "walls", path: asset.path, uid: "u1", status: "complete", blobSha: sha,
      response: {content: {sha, path: asset.path, download_url: asset.url}},
    });
    // Seven public rows are below the ambiguity cap. Private twins must not consume it.
    for (let index = 0; index < 6; index++) {
      store.set(`githubUploads/public_${asset.path}_${index}`, {repo: "walls", path: asset.path, uid: "u1"});
    }
    for (let index = 0; index < 10; index++) {
      store.set(`githubUploads/owned_file_${asset.path}_${index}`,
        {repo: "walls", path: asset.path, sha, uid: "attacker", sourceKind: "owned"});
    }
    store.set(`githubUploadIntents/owned_path_${digest(`walls\0${asset.path}`)}`,
      {repo: "walls", path: asset.path, uid: "attacker", sourceKind: "owned", status: "complete"});
  }
  const privateBefore = [...store].filter(([key]) => key.includes("/owned_"));
  const {deps, calls} = fixture();
  deps.prove = async (original, thumb) => {
    const uid = await proveMigrationAsset(original);
    return uid && uid === await proveMigrationAsset(thumb) ? uid : null;
  };
  const retain = deps.retain;
  deps.retain = async (input) => {
    assert.equal(input.uid, "u1");
    return retain(input);
  };
  const [result] = await migrateOwnedAssets([wall()], {...options, apply: true}, deps);
  assert.equal(result.status, "migrated");
  assert.deepEqual(calls, ["fetch", "fetch", "retain", "retain", "attach", "attach", "bind"]);
  assert.deepEqual([...store].filter(([key]) => key.includes("/owned_")), privateBefore);
  const asset = assets[0];
  store.set("githubUploads/public_conflict", {repo: "walls", path: asset.path, uid: "other"});
  assert.equal(await proveMigrationAsset(asset), null);
  store.set("githubUploads/public_conflict", {repo: "walls", path: asset.path, uid: "u1"});
  assert.equal(await proveMigrationAsset(asset), null, "eight public rows still fail the ambiguity cap");
  store.delete("githubUploads/public_conflict");
  store.set("githubUploads/public_ownership_conflict", {repo: "walls", path: asset.path, uid: "other"});
  store.delete(`githubUploads/public_${asset.path}_0`);
  assert.equal(await proveMigrationAsset(asset), null, "conflicting public owners still fail below the cap");
});

test("dry run uses logical id and reads proof only, no network or writes", async () => {
  const {calls, deps} = fixture();
  const [result] = await migrateOwnedAssets([wall()], options, deps);
  assert.equal(result.status, "would-migrate");
  assert.equal(result.wallId, "logical-id");
  assert.equal(result.publicOriginalRemains, true);
  assert.deepEqual(calls, []);
});

test("duplicate logical ids block both legacy and id-keyed documents before fetching", async () => {
  const {calls, deps} = fixture();
  const results = await migrateOwnedAssets([wall(), wall("walls/logical-id")], {...options, apply: true}, deps);
  assert.ok(results.every((row) => row.status === "blocked" && row.detail.includes("Duplicate")));
  assert.deepEqual(calls, []);
});

test("unproven legacy is blocked unless reviewed policy explicitly enabled", async () => {
  const {calls, deps} = fixture(null);
  const [blocked] = await migrateOwnedAssets([wall()], options, deps);
  assert.match(blocked.detail, /Unproven provenance/);
  const [planned] = await migrateOwnedAssets([wall()], {...options, allowReviewedLegacy: true}, deps);
  assert.equal(planned.status, "would-migrate");
  assert.deepEqual(calls, []);
  const unreviewed = wall();
  unreviewed.data.review = false;
  const [rejected] = await migrateOwnedAssets([unreviewed], {...options, allowReviewedLegacy: true}, deps);
  assert.equal(rejected.status, "blocked");
});

test("reviewed legacy binds private provenance without fabricating upload receipts", async () => {
  const {calls, deps} = fixture(null);
  const [result] = await migrateOwnedAssets([wall()], {...options, apply: true, allowReviewedLegacy: true}, deps);
  assert.equal(result.status, "migrated");
  assert.deepEqual(calls, ["fetch", "fetch", "retain", "retain", "legacy"]);
  assert.equal(result.publicOriginalRemains, true);
});

test("partial retention failure stays blocked and can be resumed", async () => {
  const {calls, deps} = fixture();
  const retain = deps.retain;
  let failed = false;
  deps.retain = async (input) => {
    if (!failed) {
      failed = true; throw new Error("transient storage failure");
    }
    return retain(input);
  };
  const [failure] = await migrateOwnedAssets([wall()], {...options, apply: true}, deps);
  assert.equal(failure.status, "blocked");
  assert.ok(!calls.includes("bind"));
  const [retry] = await migrateOwnedAssets([wall()], {...options, apply: true}, deps);
  assert.equal(retry.status, "migrated");
});

test("thumbnail fetch failure performs no storage writes", async () => {
  const {calls, deps} = fixture();
  deps.fetchBytes = async (asset) => {
    if (asset.path.startsWith("thumb")) throw new Error("download failed");
    return bytes;
  };
  const [result] = await migrateOwnedAssets([wall()], {...options, apply: true}, deps);
  assert.equal(result.status, "blocked");
  assert.deepEqual(calls, []);
});

test("source allowlist rejects redirects to arbitrary hosts and mismatched identities at planning", () => {
  for (const raw of ["http://raw.githubusercontent.com/hash/walls/main/a.jpg",
    "https://evil.example/hash/walls/main/a.jpg", "https://raw.githubusercontent.com/attacker/walls/main/a.jpg",
    "https://raw.githubusercontent.com/hash/walls/main/a.jpg?token=secret",
    "https://raw.githubusercontent.com/hash/walls/main/%2fetc",
    "https://raw.githubusercontent.com/hash/walls/main/a%00.jpg",
    "https://raw.githubusercontent.com/hash/walls/main/a%1f.jpg"]) {
    assert.throws(() => parseRawAsset(raw, undefined, undefined, options));
  }
  assert.throws(() => parseRawAsset(wall().data.wallpaper_url, "different.jpg", sha, options));
  assert.throws(() => parseRawAsset(wall().data.wallpaper_url, "a.jpg", "invalid", options));
});

test("downloader forbids redirect following and rejects failed responses", async (t) => {
  const asset = parseRawAsset(wall().data.wallpaper_url, "a.jpg", sha, options);
  t.mock.method(globalThis, "fetch", async (_url: unknown, init?: RequestInit) => {
    assert.equal(init?.redirect, "error");
    assert.ok(init?.signal);
    return new Response(null, {status: 503});
  });
  await assert.rejects(downloadRawAsset(asset), /503/);
});

test("downloader verifies real image metadata and supplied git blob SHA", async (t) => {
  const image = await sharp({create: {width: 2, height: 2, channels: 3, background: "red"}}).png().toBuffer();
  const asset = parseRawAsset(wall().data.wallpaper_url, "a.jpg", gitBlobSha(image), options);
  t.mock.method(globalThis, "fetch", async () => new Response(new Uint8Array(image), {
    headers: {"content-type": "image/png"},
  }));
  assert.deepEqual(await downloadRawAsset(asset), image);
  await assert.rejects(downloadRawAsset({...asset, sha: "0".repeat(40)}), /SHA mismatch/);
});

test("downloader rejects oversized declared bodies before image processing", async (t) => {
  const asset = parseRawAsset(wall().data.wallpaper_url, "a.jpg", sha, options);
  t.mock.method(globalThis, "fetch", async () => new Response("body", {
    headers: {"content-length": String(33 * 1024 * 1024)},
  }));
  await assert.rejects(downloadRawAsset(asset), /size limit/);
});
