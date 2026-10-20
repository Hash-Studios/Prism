import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {AI_LEGACY_UID, aiCommunityId, aiRecordExpired} from "../aiWallSource";
import {db} from "../common";
import {verifiedUploadOwner} from "../creatorProgress";
import {cleanupDeletedOwnedWall, onOwnedWallWritten, STUDIO_STORAGE_REPO, stored} from "../ownedAssetDelivery";
import {buildAiRow, buildFirebaseRow, convertApprovedWall, convertWall, conversionDeps, buildStudioRow, gitBlobSha,
  readFirebaseObjectMeta,
  type GithubAsset, type MigrationDeps, type MigrationResult, type MigrationWall,
  type WallInventory} from "../ownedWallConversion";
import {R2Storage} from "../r2Storage";
import {installFakeDb} from "./fakeDb";

type Doc = Record<string, unknown>;
const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");
const STUDIO_EMAIL = "studio@prismwalls.com";
const RAW = "https://raw.githubusercontent.com/hash/walls/main";
const WORKER = "https://prismwalls.com/api/ai/assets";

function configure(t: TestContext) {
  t.mock.method(logger, "error", () => undefined);
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "private-assets", R2_PREVIEW_BUCKET: "public-previews", R2_PREVIEW_BASE_URL: "https://images.example.com",
    GH_REPO_WALLS: "walls", GH_USERNAME: "hash"});
}

/** An in-memory R2 plus the public GitHub and worker origins, behind one fetch mock. */
function installNetwork(t: TestContext, sources: Record<string, Buffer>, sourceHeaders: Record<string, Record<string, string>> = {}) {
  const objects = new Map<string, {bytes: Buffer; meta: Record<string, string>}>();
  const fetched: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    if (url.hostname.endsWith(".r2.cloudflarestorage.com")) {
      const key = decodeURIComponent(url.pathname.slice(1));
      const headers = new Headers(init?.headers);
      if (method === "PUT") {
        if (objects.has(key)) return new Response(null, {status: 412});
        const meta = Object.fromEntries([...headers.entries()].filter(([name]) => name.startsWith("x-amz-meta-")));
        objects.set(key, {bytes: Buffer.from(init?.body as Uint8Array), meta});
        return new Response(null, {status: 200});
      }
      const object = objects.get(key);
      if (method === "DELETE") {
        objects.delete(key);
        return new Response(null, {status: 204});
      }
      if (!object) return new Response(null, {status: 404});
      const lengthHeaders = {"content-length": String(object.bytes.length)};
      if (method === "HEAD") return new Response(null, {status: 200, headers: {...lengthHeaders, ...object.meta}});
      return new Response(new Uint8Array(object.bytes), {status: 200, headers: lengthHeaders});
    }
    fetched.push(url.href);
    const bytes = sources[url.href];
    if (!bytes) return new Response(null, {status: 404});
    return new Response(new Uint8Array(bytes), {status: 200,
      headers: {"content-length": String(bytes.length), ...sourceHeaders[url.href]}});
  });
  return {objects, fetched};
}

const image = (width: number, height: number, color: string) =>
  sharp({create: {width, height, channels: 3, background: color}}).jpeg().toBuffer();

const studioWall = (extra: Doc = {}): Doc => ({id: "w1", email: STUDIO_EMAIL, review: true, origin: "studio",
  studioRunId: "run-1", studioCandidateId: "cand-1", resolution: "40x60",
  wallpaper_url: `${WORKER}/ai/studio/cand-1.jpg`, wallpaper_thumb: `${WORKER}/ai/studio/thumb_cand-1.jpg`, ...extra});
const studioSeed = (wall: Doc = studioWall(), candidate: Doc = {wallId: "w1"}): Record<string, Doc> =>
  ({"walls/w1": wall, "studioRuns/run-1/candidates/cand-1": candidate});

async function studioSources() {
  return {[`${WORKER}/ai/studio/cand-1.jpg`]: await image(40, 60, "red"),
    [`${WORKER}/ai/studio/thumb_cand-1.jpg`]: await image(20, 30, "blue")};
}

test("a Studio wall converts from its worker URLs with Studio provenance and no receipts", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed());
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "converted");
  const wall = store.get("walls/w1")!;
  assert.equal(wall.originalProtected, true);
  assert.equal(wall.wallpaper_url, "");
  assert.match(String(wall.wallpaper_thumb), /^https:\/\/images\.example\.com\/previews\/[a-f0-9]{64}\.img$/);
  const manifest = store.get("ownedAssets/w1") as {original: Doc; thumb: Doc; provenance: Doc; status: string};
  assert.equal(manifest.status, "ready");
  assert.deepEqual(manifest.provenance, {kind: "studio", runId: "run-1", candidateId: "cand-1"});
  assert.equal(manifest.original.sourceKind, "studio");
  assert.equal(manifest.original.uid, "prism-studio");
  assert.equal(manifest.original.repo, STUDIO_STORAGE_REPO);
  assert.ok(stored(manifest.original) && stored(manifest.thumb));
  assert.equal(wall.originalObjectId, manifest.original.objectId);
  assert.ok(![...store.keys()].some((key) => key.startsWith("githubUploads/") || key.startsWith("creatorWallCredits/")),
    "Studio gets no GitHub receipt and no creator credit");
  assert.ok(network.objects.has(`private-assets/${manifest.original.object}`));
  assert.ok(network.objects.has(`public-previews/previews/${manifest.thumb.objectId}.img`));
});

test("a converted wall is a no-op when it is delivered again", async (t) => {
  configure(t);
  installFakeDb(t, studioSeed());
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "converted");
  const calls = network.fetched.length;
  assert.equal(await convertApprovedWall("w1"), "skipped");
  assert.equal(network.fetched.length, calls);
});

for (const [name, wall, candidate] of [
  ["a foreign host", studioWall({wallpaper_url: "https://evil.example/api/ai/assets/ai/studio/cand-1.jpg"}), {wallId: "w1"}],
  ["a URL for another candidate", studioWall({wallpaper_url: `${WORKER}/ai/studio/cand-2.jpg`}), {wallId: "w1"}],
  ["a thumb for another candidate", studioWall({wallpaper_thumb: `${WORKER}/ai/studio/thumb_cand-2.jpg`}), {wallId: "w1"}],
  ["a spoofed origin on a user wall", studioWall({email: "user@example.com"}), {wallId: "w1"}],
  ["a candidate that belongs to another wall", studioWall(), {wallId: "other"}],
  ["a candidate that does not exist", studioWall(), {}],
] as const) {
  test(`forged Studio markers are refused: ${name}`, async (t) => {
    configure(t);
    const store = installFakeDb(t, studioSeed(wall, candidate));
    const network = installNetwork(t, await studioSources());
    assert.equal(await convertApprovedWall("w1"), "blocked");
    assert.equal(network.objects.size, 0);
    assert.equal(store.get("walls/w1")?.originalProtected, undefined);
    assert.equal(store.has("ownedAssets/w1"), false);
  });
}

test("a Studio image whose size differs from the wall record is refused", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed(studioWall({resolution: "41x60"})));
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "blocked");
  assert.equal(network.objects.size, 0);
  assert.equal(store.has("ownedAssets/w1"), false);
});

test("a corrupt Studio image is blocked without asking the trigger to retry", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed());
  installNetwork(t, {[`${WORKER}/ai/studio/cand-1.jpg`]: Buffer.from("corrupt image"),
    [`${WORKER}/ai/studio/thumb_cand-1.jpg`]: Buffer.from("corrupt thumbnail")});
  assert.equal(await convertApprovedWall("w1"), "blocked");
  assert.equal(store.has("ownedAssets/w1"), false);
});

for (const url of ["not a URL", `${RAW}/%zz.jpg`]) {
  test(`a malformed source is blocked without asking the trigger to retry: ${url}`, async (t) => {
    configure(t);
    installFakeDb(t, {"walls/w2": legacyWall({wallpaper_url: url})});
    const network = installNetwork(t, {});
    assert.equal(await convertApprovedWall("w2"), "blocked");
    assert.equal(network.fetched.length, 0);
  });
}

test("a pending Studio wall is not converted", async (t) => {
  configure(t);
  installFakeDb(t, studioSeed(studioWall({review: false})));
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "skipped");
  assert.equal(network.fetched.length, 0);
});

test("a transient source failure throws so the trigger retries, then converts", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed());
  const sources = await studioSources();
  const network = installNetwork(t, sources);
  const real = globalThis.fetch;
  let down = true;
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    if (down && String(input).startsWith(WORKER)) return new Response(null, {status: 503});
    return real(input, init);
  });
  await assert.rejects(convertApprovedWall("w1"), /Raw download failed: 503/);
  assert.equal(store.has("ownedAssets/w1"), false);
  down = false;
  assert.equal(await convertApprovedWall("w1"), "converted");
  assert.ok(network.objects.size > 0);
});

for (const status of [302, 307]) {
  test(`a source redirect (${status}) is permanently blocked without following its target`, async (t) => {
    configure(t);
    const store = installFakeDb(t, studioSeed());
    const requested: string[] = [];
    const redirects: Array<RequestRedirect | undefined> = [];
    t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
      requested.push(String(input));
      redirects.push(init?.redirect);
      return new Response(null, {status, headers: {location: "http://169.254.169.254/metadata"}});
    });
    assert.equal(await convertApprovedWall("w1"), "blocked");
    assert.ok(requested.length > 0);
    assert.ok(requested.every((url) => url.startsWith(`${WORKER}/ai/studio/`)));
    assert.ok(redirects.every((mode) => mode === "manual"));
    assert.equal(store.has("ownedAssets/w1"), false);
  });
}

async function legacySources(path = "wall.jpg") {
  return {[`${RAW}/${path}`]: await image(40, 60, "green"), [`${RAW}/thumb_${path}`]: await image(20, 30, "yellow")};
}
const legacyWall = (extra: Doc = {}): Doc => ({id: "w2", email: "creator@example.com", review: true,
  wallpaper_url: `${RAW}/wall.jpg`, wallpaper_thumb: `${RAW}/thumb_wall.jpg`, ...extra});

test("a legacy GitHub wall with no receipts and no stored paths converts with reviewed-legacy provenance", async (t) => {
  configure(t);
  const store = installFakeDb(t, {"walls/w2": legacyWall()});
  installNetwork(t, await legacySources());
  assert.equal(await convertApprovedWall("w2"), "converted");
  const manifest = store.get("ownedAssets/w2") as {original: Doc; provenance: Doc};
  assert.deepEqual(manifest.provenance, {kind: "legacy"});
  assert.equal(manifest.original.uid, "legacy-migration");
  assert.equal(store.get("walls/w2")?.wallpaper_url, "");
  assert.ok(![...store.keys()].some((key) => key.startsWith("githubUploads/") || key.startsWith("creatorWallCredits/")));
});

test("a wall whose current file differs from its recorded Git SHA is refused", async (t) => {
  configure(t);
  const store = installFakeDb(t, {"walls/w2": legacyWall({wallpaper_path: "wall.jpg", thumb_path: "thumb_wall.jpg",
    wallpaper_sha: "a".repeat(40), thumb_sha: "b".repeat(40)})});
  const network = installNetwork(t, await legacySources());
  assert.equal(await convertApprovedWall("w2"), "blocked");
  assert.equal(network.objects.size, 0);
  assert.equal(store.has("ownedAssets/w2"), false);
});

function receipts(path: string, sha: string, url: string, uid: string): Record<string, Doc> {
  const file = sha256(`walls\0${path}\0${sha}`);
  const intent = sha256(`walls\0${path}`);
  return {[`githubUploads/file_${file}`]: {uid, repo: "walls", path, sha},
    [`githubUploadIntents/path_${intent}`]: {uid, repo: "walls", path, blobSha: sha, status: "complete",
      response: {content: {path, sha, download_url: url}}}};
}

for (const missingMetadata of [false, true]) {
  test(`a 3.7.0 upload with receipts binds with GitHub provenance (missing metadata: ${missingMetadata})`, async (t) => {
    configure(t);
    const sources = await legacySources("up.jpg");
    const original = sources[`${RAW}/up.jpg`];
    const thumb = sources[`${RAW}/thumb_up.jpg`];
    const wall = legacyWall({id: "w3", wallpaper_url: `${RAW}/up.jpg`, wallpaper_thumb: `${RAW}/thumb_up.jpg`,
      wallpaper_path: "up.jpg", thumb_path: "thumb_up.jpg", wallpaper_sha: gitBlobSha(original), thumb_sha: gitBlobSha(thumb)});
    if (missingMetadata) {
      for (const key of ["wallpaper_path", "thumb_path", "wallpaper_sha", "thumb_sha"]) delete wall[key];
    }
    const store = installFakeDb(t, {"walls/w3": wall,
      ...receipts("up.jpg", gitBlobSha(original), `${RAW}/up.jpg`, "creator-1"),
      ...receipts("thumb_up.jpg", gitBlobSha(thumb), `${RAW}/thumb_up.jpg`, "creator-1")});
    installNetwork(t, sources);
    t.mock.method(admin.auth(), "getUser", async () => ({email: "creator@example.com", disabled: false}) as never);
    assert.equal(await convertApprovedWall("w3"), "converted");
    const manifest = store.get("ownedAssets/w3") as {provenance: Doc; original: Doc};
    assert.deepEqual(manifest.provenance, {kind: "github", uid: "creator-1"});
    assert.equal(manifest.original.uid, "creator-1");
    const receipt = store.get(`githubUploads/file_${sha256(`walls\0up.jpg\0${gitBlobSha(original)}`)}`);
    assert.deepEqual(receipt?.retainedAsset, manifest.original);
    assert.equal(store.get("walls/w3")?.originalProtected, true);
  });
}

test("partial provenance never falls back to the legacy identity", async (t) => {
  configure(t);
  const sources = await legacySources("up.jpg");
  const original = sources[`${RAW}/up.jpg`];
  const wall = legacyWall({id: "w3", wallpaper_url: `${RAW}/up.jpg`, wallpaper_thumb: `${RAW}/thumb_up.jpg`});
  // Only the original has a receipt; the thumbnail has none.
  const store = installFakeDb(t, {"walls/w3": wall,
    ...receipts("up.jpg", gitBlobSha(original), `${RAW}/up.jpg`, "creator-1")});
  const network = installNetwork(t, sources);
  assert.equal(await convertApprovedWall("w3"), "blocked");
  assert.equal(network.objects.size, 0);
  assert.equal(store.has("ownedAssets/w3"), false);
});

test("a duplicate logical wall id is never converted", async (t) => {
  configure(t);
  installFakeDb(t, {"walls/a": legacyWall(), "walls/b": legacyWall()});
  const network = installNetwork(t, await legacySources());
  assert.equal(await convertApprovedWall("w2"), "skipped");
  assert.equal(network.fetched.length, 0);
});

test("without R2 configuration nothing converts", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  for (const key of ["R2_ACCOUNT_ID", "R2_PRIVATE_BUCKET", "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"]) delete process.env[key];
  installFakeDb(t, {"walls/w2": legacyWall()});
  assert.equal(await convertApprovedWall("w2"), "skipped");
});

const snapshot = (path: string, data: Doc | undefined) =>
  ({exists: data !== undefined, data: () => data, ref: {path}, createTime: admin.firestore.Timestamp.fromMillis(1)});
const writeEvent = (before: Doc | undefined, after: Doc | undefined, wallId = "w1") =>
  ({data: {before: snapshot(`walls/${wallId}`, before), after: snapshot(`walls/${wallId}`, after)}, params: {wallId}}) as never;

test("onOwnedWallWritten converts a wall at approval and is a no-op for the redacting write", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed(studioWall({review: false})));
  const network = installNetwork(t, await studioSources());
  const pending = studioWall({review: false});
  // Approval (admin tap, Studio publish review, Drop release) flips review.
  const approved = studioWall();
  store.set("walls/w1", approved);
  await onOwnedWallWritten.run(writeEvent(pending, approved));
  const protectedWall = store.get("walls/w1")!;
  assert.equal(protectedWall.originalProtected, true);
  const calls = network.fetched.length;
  // The binder's own redacting write re-enters the trigger.
  await onOwnedWallWritten.run(writeEvent(approved, protectedWall));
  assert.equal(network.fetched.length, calls);
  assert.deepEqual(store.get("walls/w1"), protectedWall);
});

test("onOwnedWallWritten ignores pending walls, including pending Drop walls", async (t) => {
  configure(t);
  const pending = studioWall({review: false, dropWeek: "2026-W42", dropReserved: false});
  const store = installFakeDb(t, studioSeed(pending));
  const network = installNetwork(t, await studioSources());
  await onOwnedWallWritten.run(writeEvent(undefined, pending));
  assert.equal(network.fetched.length, 0);
  assert.equal(store.get("walls/w1")?.originalProtected, undefined);
});

test("an approved wall of an unreleased Drop is skipped until the Drop is released", async (t) => {
  configure(t);
  const wall = studioWall({dropWeek: "2026-W42"});
  const store = installFakeDb(t, {...studioSeed(wall), "drops/2026-W42": {released: false}});
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "skipped");
  assert.equal(network.fetched.length, 0);
  store.set("drops/2026-W42", {released: true});
  assert.equal(await convertApprovedWall("w1"), "converted");
  assert.equal(store.get("walls/w1")?.dropWeek, undefined, "a released Drop wall loses the marker that blocks original access");
  assert.equal(store.get("walls/w1")?.originalProtected, true);
});

test("an approved reserved Drop without a week remains unavailable", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed(studioWall({dropReserved: true})));
  const network = installNetwork(t, await studioSources());
  assert.equal(await convertApprovedWall("w1"), "skipped");
  assert.equal(store.get("walls/w1")?.dropReserved, true);
  assert.equal(store.has("ownedAssets/w1"), false);
  assert.equal(network.fetched.length, 0);
});

test("bulk conversion refuses a pending modern wall before fetching or retaining bytes", async () => {
  const wall: MigrationWall = {docPath: "walls/w1", incarnation: 1, incarnationNanos: 1000000,
    data: studioWall({review: false})};
  const row = buildStudioRow(wall) as WallInventory;
  delete row.studio;
  let fetched = 0;
  const deps: MigrationDeps = {ready: async () => false, prove: async () => ({uid: "creator", legacyEligible: false}),
    revalidate: async () => undefined, fetchBytes: async () => {
      fetched++;
      return Buffer.from("bytes");
    }, retain: async () => {
      throw new Error("Unexpected retention of pending wall");
    }, verify: async () => undefined, attach: async () => undefined, bind: async () => undefined,
    bindLegacy: async () => undefined};
  const result: MigrationResult = {docPath: wall.docPath, wallId: "w1", status: "blocked", detail: "", publicGithubCopiesRemain: true};
  await assert.rejects(convertWall(row, {apply: true, allowReviewedLegacy: false, owner: "hash", repo: "walls",
    commit: "0".repeat(40)}, deps, result), /not approved/);
  assert.equal(fetched, 0);
});

test("bulk conversion refuses an unreleased Drop before fetching or retaining bytes", async (t) => {
  configure(t);
  const data = studioWall({dropWeek: "2026-W42"});
  const store = installFakeDb(t, {...studioSeed(data), "drops/2026-W42": {released: false}});
  const network = installNetwork(t, await studioSources());
  const wall: MigrationWall = {docPath: "walls/w1", incarnation: 1, incarnationNanos: 1000000, data};
  const result: MigrationResult = {docPath: wall.docPath, wallId: "w1", status: "blocked", detail: "", publicGithubCopiesRemain: true};
  await assert.rejects(convertWall(buildStudioRow(wall) as WallInventory, {apply: true, allowReviewedLegacy: false,
    owner: "hash", repo: "walls", commit: "0".repeat(40)}, conversionDeps(true, new R2Storage()), result), /Drop/);
  assert.equal(network.fetched.length, 0);
  assert.equal(network.objects.size, 0);
  assert.equal(store.has("ownedAssets/w1"), false);
});

test("a Drop that becomes unreleased during conversion cannot lose its access markers", async (t) => {
  configure(t);
  const wall = studioWall({dropWeek: "2026-W42"});
  const store = installFakeDb(t, {...studioSeed(wall), "drops/2026-W42": {released: true}});
  installNetwork(t, await studioSources());
  const request = globalThis.fetch;
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    const response = await request(input, init);
    if (String(input).startsWith(WORKER)) store.set("drops/2026-W42", {released: false});
    return response;
  });
  await convertApprovedWall("w1").catch(() => undefined);
  assert.equal(store.get("walls/w1")?.dropWeek, "2026-W42");
  assert.equal(store.has("ownedAssets/w1"), false);
});

for (const change of ["tombstone", "deleted wall", "Studio resolution", "Studio candidate"] as const) {
  test(`a permanent change during retention blocks without trigger retries: ${change}`, async (t) => {
    configure(t);
    const store = installFakeDb(t, studioSeed());
    installNetwork(t, await studioSources());
    const request = globalThis.fetch;
    let changed = false;
    t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
      const response = await request(input, init);
      if (!changed && init?.method === "PUT") {
        changed = true;
        if (change === "tombstone") {
          const id = new Headers(init.headers).get("x-amz-meta-objectid");
          const key = `r2ObjectRegistry/${id}`;
          store.set(key, {...store.get(key), status: "tombstoned"});
        } else if (change === "deleted wall") {
          store.delete("walls/w1");
        } else {
          store.set("walls/w1", {...store.get("walls/w1"),
            ...(change === "Studio resolution" ? {resolution: "41x60"} : {studioCandidateId: "cand-2"})});
        }
      }
      return response;
    });
    assert.equal(await convertApprovedWall("w1"), "blocked");
    assert.equal(store.has("ownedAssets/w1"), false);
    assert.notEqual(store.get("walls/w1")?.originalProtected, true);
  });
}

test("two deliveries of the same approval converge on one manifest", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed());
  installNetwork(t, await studioSources());
  const results = await Promise.all([convertApprovedWall("w1"), convertApprovedWall("w1")]);
  assert.ok(results.includes("converted"));
  assert.ok(results.every((result) => result === "converted" || result === "skipped"));
  const manifest = store.get("ownedAssets/w1") as {original: {objectId: string}};
  assert.equal(store.get("walls/w1")?.originalObjectId, manifest.original.objectId);
  assert.equal([...store.keys()].filter((key) => key.startsWith("ownedAssets/")).length, 1);
});

test("ready conversion requires the reviewed URL pair, paths, byte hashes and Studio identity", async (t) => {
  configure(t);
  const data = studioWall();
  installFakeDb(t, studioSeed(data));
  const sources: Record<string, Buffer> = await studioSources();
  installNetwork(t, sources);
  const wall: MigrationWall = {docPath: "walls/w1", incarnation: 1, incarnationNanos: 1000000, data};
  const row = buildStudioRow(wall) as WallInventory;
  if (!row.original || !row.thumb) throw new Error("Missing source assets");
  const original = {...row.original, gitSha: gitBlobSha(sources[row.original.url])};
  const thumb = {...row.thumb, gitSha: gitBlobSha(sources[row.thumb.url])};
  assert.equal(await convertApprovedWall("w1"), "converted");
  const deps = conversionDeps(false, null);
  assert.equal(await deps.ready(wall, original, thumb), true);
  for (const change of [{recordedUrl: `${WORKER}/ai/studio/other.jpg`}, {path: "ai/studio/other.jpg"},
    {gitSha: "a".repeat(40)}]) {
    assert.equal(await deps.ready(wall, {...original, ...change}, thumb), false);
    assert.equal(await deps.ready(wall, original, {...thumb, ...change}), false);
  }
  for (const change of [{resolution: "41x60"}, {studioRunId: "run-2"}, {studioCandidateId: "cand-2"}]) {
    assert.equal(await deps.ready({...wall, data: {...data, ...change}}, original, thumb), false);
  }
});

for (const stage of ["before download", "after download"] as const) {
  test(`a matching conversion that wins ${stage} counts as done without retention`, async (t) => {
    configure(t);
    const data = studioWall();
    installFakeDb(t, studioSeed(data));
    installNetwork(t, await studioSources());
    const wall: MigrationWall = {docPath: "walls/w1", incarnation: 1, incarnationNanos: 1000000, data};
    const deps = conversionDeps(true, new R2Storage());
    const revalidate = deps.revalidate;
    let checked = 0;
    deps.revalidate = async (...args) => {
      if (++checked === (stage === "before download" ? 1 : 2)) {
        assert.equal(await convertApprovedWall("w1"), "converted");
      }
      return revalidate(...args);
    };
    deps.retain = async () => {
      throw new Error("A matching winner must prevent losing retention");
    };
    const result: MigrationResult = {docPath: wall.docPath, wallId: "w1", status: "blocked", detail: "", publicGithubCopiesRemain: true};
    await convertWall(buildStudioRow(wall) as WallInventory, {apply: true, allowReviewedLegacy: false, owner: "hash",
      repo: "walls", commit: "0".repeat(40)}, deps, result);
    assert.equal(result.status, "already-owned");
  });
}

test("a loser of the bind race counts as converted when the manifest is ready", async () => {
  const wall: MigrationWall = {docPath: "walls/w1", incarnation: 1, incarnationNanos: 1, data: studioWall()};
  const row = buildStudioRow(wall) as WallInventory;
  assert.equal(row.status, "planned");
  let bound = false;
  const bytes = Buffer.from("bytes");
  const asset = (path: string, preview: boolean) => ({repo: STUDIO_STORAGE_REPO, path, sha: gitBlobSha(bytes), uid: "prism-studio",
    bucket: "b", object: `studio-originals/${path}`, objectId: preview ? "2".repeat(64) : "1".repeat(64), sha256: "c".repeat(64),
    ...(preview ? {previewObjectId: "2".repeat(64)} : {})});
  const deps: MigrationDeps = {
    prove: async (_o, _t, r) => ({uid: "prism-studio", legacyEligible: false, studio: r.studio}),
    fetchBytes: async () => bytes,
    retain: async (a) => asset(a.path, a.path.includes("thumb_")),
    verify: async () => undefined, revalidate: async () => undefined, attach: async () => undefined, bind: async () => undefined,
    bindLegacy: async () => {
      bound = true;
      throw new Error("Legacy wall changed or already bound");
    },
    ready: async () => bound,
  };
  const result: MigrationResult = {docPath: "walls/w1", wallId: "w1", status: "blocked", detail: "", publicGithubCopiesRemain: true};
  await convertWall(row, {apply: true, allowReviewedLegacy: false, owner: "hash", repo: "walls", commit: "0".repeat(40)}, deps, result);
  assert.equal(result.status, "migrated");
  // A bind that fails while the wall is not ready is a real failure.
  bound = false;
  deps.bindLegacy = async () => {
    throw new Error("Legacy wall changed or already bound");
  };
  await assert.rejects(convertWall(row, {apply: true, allowReviewedLegacy: false, owner: "hash", repo: "walls",
    commit: "0".repeat(40)}, deps, result), /already bound/);
});

// User AI community walls. The generation id embeds its creation time, like the Worker's createId.
const genId = (madeAt: number, hex = "7a9688a037a47de6") => `gen_${madeAt.toString(36)}_${hex}`;
const OLD_GEN = genId(Date.parse("2026-02-19T08:40:39Z"));
const NEW_GEN = genId(Date.now() - 24 * 60 * 60 * 1000, "0bddcee964dce970");
const RECORDS = "https://prismwalls.com/api/ai/studio/generation-records";
const aiWall = (gen: string, extra: Doc = {}): Doc => ({id: aiCommunityId(gen), email: "creator@example.com", review: true,
  isAiGenerated: true, aiGenerationId: gen, resolution: "1179x2048", wallpaper_url: `${WORKER}/ai/original/${gen}.png`,
  wallpaper_thumb: `${WORKER}/ai/public/${gen}.png`, ...extra});
const aiRecord = (gen: string, userId = "creator-1") => Buffer.from(JSON.stringify({generationId: gen, userId, width: 1179,
  height: 2048, imageUrl: `${WORKER}/ai/original/${gen}.png`, watermarkedImageUrl: `${WORKER}/ai/public/${gen}.png`}));
async function aiSources(gen: string, record?: Buffer) {
  // The provider returned 1024x1024 although the wall records the requested 1179x2048.
  return {[`${WORKER}/ai/original/${gen}.png`]: await image(1024, 1024, "red"),
    [`${WORKER}/ai/public/${gen}.png`]: await image(1024, 1024, "blue"), ...(record ? {[`${RECORDS}/${gen}`]: record} : {})};
}
function mockAuth(t: TestContext, users: Record<string, {email: string; disabled?: boolean}> = {
  "creator-1": {email: "creator@example.com"}}) {
  const missing = () => Object.assign(new Error("no user"), {code: "auth/user-not-found"});
  t.mock.method(admin.auth(), "getUser", async (uid: string) => {
    if (!users[uid]) throw missing();
    return {uid, disabled: false, ...users[uid]} as never;
  });
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    const entry = Object.entries(users).find(([, user]) => user.email === email);
    if (!entry) throw missing();
    return {uid: entry[0], disabled: false, ...entry[1]} as never;
  });
}

test("the app's AI community id is derived from the generation id", () => {
  assert.equal(aiCommunityId("gen_mlt7o22q_7a9688a037a47de6"), "AIGENMLT7O22");
  assert.equal(aiCommunityId("gen_mqc4rojc_ebbaa0bef876eff2"), "AIGENMQC4ROJ");
  assert.equal(aiRecordExpired(OLD_GEN), true);
  assert.equal(aiRecordExpired(NEW_GEN), false);
  assert.equal(aiRecordExpired("gen_nottime_xyz"), false);
});

for (const shape of ["unwatermarked original", "public image for both roles"]) {
  test(`a live AI wall converts with its Worker record owner and no XP (${shape})`, async (t) => {
    configure(t);
    process.env.STUDIO_SECRET = "studio-secret";
    const same = shape !== "unwatermarked original";
    const wall = aiWall(NEW_GEN, same ? {wallpaper_url: `${WORKER}/ai/public/${NEW_GEN}.png`} : {});
    const id = String(wall.id);
    const store = installFakeDb(t, {[`walls/${id}`]: wall});
    const network = installNetwork(t, await aiSources(NEW_GEN, aiRecord(NEW_GEN)));
    mockAuth(t);
    assert.equal(await convertApprovedWall(id), "converted");
    const manifest = store.get(`ownedAssets/${id}`) as {original: Doc; thumb: Doc; provenance: Doc; originalUrl: string};
    assert.deepEqual(manifest.provenance, {kind: "ai", generationId: NEW_GEN, uid: "creator-1"});
    assert.equal(manifest.originalUrl, wall.wallpaper_url);
    assert.deepEqual([manifest.original.sourceKind, manifest.original.uid, manifest.original.repo, manifest.original.uploadId],
      ["ai", "creator-1", "prism-ai", NEW_GEN]);
    assert.equal(manifest.thumb.uploadId, `thumb_${NEW_GEN}`);
    assert.ok(stored(manifest.original) && stored(manifest.thumb));
    assert.notEqual(manifest.original.objectId, manifest.thumb.objectId);
    assert.equal(manifest.original.previewObjectId, undefined);
    assert.ok(network.objects.has(`public-previews/previews/${manifest.thumb.objectId}.img`));
    assert.ok(![...network.objects.keys()].some((key) => key.startsWith("public-previews/") &&
      key.includes(String(manifest.original.objectId))), "the original is never in the preview bucket");
    assert.equal(store.get(`walls/${id}`)?.originalProtected, true);
    assert.ok(![...store.keys()].some((key) => key.startsWith("githubUploads/") || key.startsWith("creatorWallCredits/")));
    assert.equal(await verifiedUploadOwner(await db.doc(`walls/${id}`).get()), null, "AI provenance earns no creator XP");
    await cleanupDeletedOwnedWall({wallId: id, canonicalPath: `walls/${id}`, incarnation: 1, incarnationNanos: 1_000_000});
    assert.equal((store.get(`ownedAssets/${id}`) as Doc).status, "deleted");
    assert.equal(network.objects.has(`public-previews/previews/${manifest.thumb.objectId}.img`), false);
    assert.equal(store.get(`r2ObjectRegistry/${manifest.original.objectId}`)?.status, "tombstoned");
  });
}

const NOT_AI = /Untrusted or unpinned GitHub asset URL/;
const NOT_OWNER = /does not belong to the wall author/;
for (const [name, wall, record, users, reason] of [
  ["a record of another user", aiWall(NEW_GEN), aiRecord(NEW_GEN, "someone-else"), undefined, NOT_OWNER],
  ["an author whose email changed", aiWall(NEW_GEN), aiRecord(NEW_GEN), {"creator-1": {email: "other@example.com"}}, NOT_OWNER],
  ["a disabled author", aiWall(NEW_GEN), aiRecord(NEW_GEN), {"creator-1": {email: "creator@example.com", disabled: true}},
    NOT_OWNER],
  ["a record for other image keys", aiWall(NEW_GEN), Buffer.from(JSON.stringify({...JSON.parse(String(aiRecord(NEW_GEN))),
    watermarkedImageUrl: `${WORKER}/ai/public/other.png`})), undefined, NOT_OWNER],
  ["a record for another generation", aiWall(NEW_GEN), aiRecord(OLD_GEN), undefined, /record is invalid/],
  ["a wall id not derived from the generation", aiWall(NEW_GEN, {id: "AIGENOTHER1"}), aiRecord(NEW_GEN), undefined, NOT_AI],
  ["a thumb on another generation", aiWall(NEW_GEN, {wallpaper_thumb: `${WORKER}/ai/public/${OLD_GEN}.png`}),
    aiRecord(NEW_GEN), undefined, NOT_AI],
  ["a Studio key", aiWall(NEW_GEN, {wallpaper_url: `${WORKER}/ai/studio/${NEW_GEN}.png`}), aiRecord(NEW_GEN), undefined,
    NOT_AI],
  ["a foreign host", aiWall(NEW_GEN, {wallpaper_url: `https://evil.example/api/ai/assets/ai/original/${NEW_GEN}.png`}),
    aiRecord(NEW_GEN), undefined, NOT_AI],
  ["a Studio author", aiWall(NEW_GEN, {email: STUDIO_EMAIL}), aiRecord(NEW_GEN), undefined, NOT_AI],
  ["no record in the trigger, even when expired", aiWall(OLD_GEN), undefined, undefined, /requires explicit opt-in/],
] as const) {
  test(`AI provenance is refused: ${name}`, async (t) => {
    configure(t);
    process.env.STUDIO_SECRET = "studio-secret";
    const gen = String(wall.aiGenerationId);
    const id = String(wall.id);
    const store = installFakeDb(t, {[`walls/${id}`]: wall});
    const network = installNetwork(t, await aiSources(gen, record));
    mockAuth(t, users);
    assert.equal(await convertApprovedWall(id), "blocked");
    const reasons = (logger.error as unknown as {mock: {calls: {arguments: unknown[]}[]}}).mock.calls
      .map((call) => String((call.arguments[1] as {reason?: unknown})?.reason));
    assert.ok(reasons.some((value) => reason.test(value)), reasons.join("; "));
    assert.equal(network.objects.size, 0);
    assert.equal(store.has(`ownedAssets/${id}`), false);
    assert.equal(store.get(`walls/${id}`)?.originalProtected, undefined);
  });
}

test("an AI wall is blocked without the Worker secret instead of retrying", async (t) => {
  configure(t);
  delete process.env.STUDIO_SECRET;
  const wall = aiWall(NEW_GEN);
  installFakeDb(t, {[`walls/${wall.id}`]: wall});
  const network = installNetwork(t, await aiSources(NEW_GEN, aiRecord(NEW_GEN)));
  mockAuth(t);
  assert.equal(await convertApprovedWall(String(wall.id)), "blocked");
  assert.equal(network.objects.size, 0);
  assert.ok(!network.fetched.some((url) => url.startsWith(RECORDS)), "no record request without the secret");
});

/** The bulk path: one inventory row through the real Firestore and R2 dependencies. */
async function bulkConvert(walls: Record<string, Doc>, options: {allowReviewedLegacy?: boolean; allowReviewedAiLegacy?: boolean},
  inventory: (wall: MigrationWall) => WallInventory | null) {
  const [docPath, data] = Object.entries(walls)[0];
  const wall: MigrationWall = {docPath, incarnation: 1, incarnationNanos: 1_000_000, data};
  const row = inventory(wall);
  assert.ok(row);
  const result: MigrationResult = {docPath, wallId: row.wallId, status: "blocked", detail: "", publicGithubCopiesRemain: true};
  const run = {apply: true, allowReviewedLegacy: options.allowReviewedLegacy ?? false, owner: "hash", repo: "walls",
    commit: "a".repeat(40), allowReviewedAiLegacy: options.allowReviewedAiLegacy ?? false};
  try {
    await convertWall(row, run, conversionDeps(true, new R2Storage(), db, run.allowReviewedAiLegacy), result);
  } catch (error) {
    result.detail = (error as Error).message;
    if (result.status === "in-progress") result.status = "blocked";
  }
  return result;
}

test("an expired AI record converts only under the reviewed AI legacy policy, with no uid claim", async (t) => {
  configure(t);
  process.env.STUDIO_SECRET = "studio-secret";
  const wall = aiWall(OLD_GEN);
  const id = String(wall.id);
  const store = installFakeDb(t, {[`walls/${id}`]: wall, [`aiGenerations/${OLD_GEN}`]: {userId: "creator-1"}});
  const network = installNetwork(t, await aiSources(OLD_GEN));
  mockAuth(t);
  const refused = await bulkConvert({[`walls/${id}`]: wall}, {allowReviewedLegacy: true}, buildAiRow);
  assert.equal(refused.status, "blocked");
  assert.match(refused.detail, /reviewed AI legacy policy requires explicit opt-in/);
  assert.equal(network.objects.size, 0);
  const done = await bulkConvert({[`walls/${id}`]: wall}, {allowReviewedAiLegacy: true}, buildAiRow);
  assert.equal(done.status, "migrated", done.detail);
  assert.match(done.detail, /no receipt, creator credit or XP/);
  const manifest = store.get(`ownedAssets/${id}`) as {original: Doc; thumb: Doc; provenance: Doc};
  assert.deepEqual(manifest.provenance, {kind: "ai-legacy", generationId: OLD_GEN});
  assert.equal(manifest.original.uid, AI_LEGACY_UID);
  assert.equal(manifest.thumb.uid, AI_LEGACY_UID);
  assert.equal(await verifiedUploadOwner(await db.doc(`walls/${id}`).get()), null);
});

for (const [name, gen, seed, reason] of [
  ["a young generation whose record is missing", NEW_GEN, {}, /missing before its expiry/],
  ["client history that names another user", OLD_GEN, {[`aiGenerations/${OLD_GEN}`]: {userId: "someone-else"}},
    /names another user/],
] as const) {
  test(`the reviewed AI legacy policy refuses ${name}`, async (t) => {
    configure(t);
    process.env.STUDIO_SECRET = "studio-secret";
    const wall = aiWall(gen);
    const store = installFakeDb(t, {[`walls/${wall.id}`]: wall, ...seed});
    const network = installNetwork(t, await aiSources(gen));
    mockAuth(t);
    const result = await bulkConvert({[`walls/${wall.id}`]: wall}, {allowReviewedAiLegacy: true}, buildAiRow);
    assert.equal(result.status, "blocked");
    assert.match(result.detail, reason);
    assert.equal(network.objects.size, 0);
    assert.equal(store.has(`ownedAssets/${wall.id}`), false);
  });
}

const FIREBASE_URL = "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/" +
  "Replacement%20Thumbnails%2Fimage_picker42%20(1).jpg?alt=media&token=abc";
const firebaseWall = (extra: Doc = {}): Doc => ({id: "P4EM", email: "creator@example.com", review: true,
  wallpaper_url: FIREBASE_URL, wallpaper_thumb: `${RAW}/thumb_image_picker42.jpg`, ...extra});
async function firebaseFixture(t: TestContext, generationHeader = "1603700046807890") {
  configure(t);
  const original = await image(40, 60, "purple");
  const thumb = await image(20, 30, "orange");
  const store = installFakeDb(t, {"walls/fb": firebaseWall()});
  const network = installNetwork(t, {[FIREBASE_URL]: original, [`${RAW}/thumb_image_picker42.jpg`]: thumb},
    {[FIREBASE_URL]: {"x-goog-generation": generationHeader}});
  const meta = {generation: "1603700046807890", md5Hash: createHash("md5").update(original).digest("base64"),
    size: original.length};
  const thumbAsset = (): GithubAsset => ({repo: "walls", path: "thumb_image_picker42.jpg", url: `${RAW}/thumb_image_picker42.jpg`,
    recordedUrl: `${RAW}/thumb_image_picker42.jpg`, sha: gitBlobSha(thumb), gitSha: gitBlobSha(thumb), size: thumb.length,
    commit: "a".repeat(40)});
  return {store, network, row: (wall: MigrationWall) => buildFirebaseRow(wall, meta, thumbAsset)};
}

test("a legacy Firebase Storage original converts under the reviewed legacy policy, pinned to its generation", async (t) => {
  const {store, network, row} = await firebaseFixture(t);
  const refused = await bulkConvert({"walls/fb": firebaseWall()}, {}, row);
  assert.match(refused.detail, /reviewed legacy policy requires explicit opt-in/);
  assert.equal(network.objects.size, 0);
  const done = await bulkConvert({"walls/fb": firebaseWall()}, {allowReviewedLegacy: true}, row);
  assert.equal(done.status, "migrated", done.detail);
  const manifest = store.get("ownedAssets/P4EM") as {original: Doc; thumb: Doc; provenance: Doc; originalUrl: string};
  assert.deepEqual(manifest.provenance, {kind: "legacy"});
  assert.deepEqual([manifest.original.repo, manifest.original.path, manifest.original.uid],
    ["firebase-storage", "prism-wallpapers.appspot.com/Replacement Thumbnails/image_picker42 (1).jpg", "legacy-migration"]);
  assert.equal(manifest.original.previewObjectId, undefined);
  assert.equal(manifest.thumb.repo, "walls");
  assert.ok(stored(manifest.original) && stored(manifest.thumb));
  assert.equal(manifest.originalUrl, FIREBASE_URL);
  assert.equal(store.get("walls/fb")?.wallpaper_url, "");
});

test("a Firebase Storage original whose generation changed after review is refused", async (t) => {
  const {store, network, row} = await firebaseFixture(t, "1700000000000000");
  const result = await bulkConvert({"walls/fb": firebaseWall()}, {allowReviewedLegacy: true}, row);
  assert.equal(result.status, "blocked");
  assert.match(result.detail, /generation differs/);
  assert.equal(network.objects.size, 0);
  assert.equal(store.has("ownedAssets/P4EM"), false);
});

test("Firebase Storage URLs outside the legacy bucket or with extra parameters are not a source", () => {
  const wall = (url: string): MigrationWall => ({docPath: "walls/fb", incarnation: 1, incarnationNanos: 1, data: firebaseWall({
    wallpaper_url: url})});
  const thumb = (): GithubAsset => {
    throw new Error("unused");
  };
  for (const url of [FIREBASE_URL.replace("prism-wallpapers.appspot.com", "evil.appspot.com"),
    `${FIREBASE_URL}&x=1`, FIREBASE_URL.replace("alt=media", "alt=json"), FIREBASE_URL.replace("https:", "http:"),
    FIREBASE_URL.replace("Replacement%20Thumbnails%2F", "..%2F")]) {
    assert.equal(buildFirebaseRow(wall(url), {generation: "1", md5Hash: "x", size: 1}, thumb), null, url);
  }
});

test("Worker record reads block on configuration errors and retry on server errors", async (t) => {
  configure(t);
  process.env.STUDIO_SECRET = "studio-secret";
  const wall = aiWall(NEW_GEN);
  installFakeDb(t, {[`walls/${wall.id}`]: wall});
  const sources = await aiSources(NEW_GEN);
  let status = 401;
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL) => {
    const url = String(input);
    if (url.startsWith(RECORDS)) return new Response(null, {status});
    const bytes = sources[url];
    return bytes ? new Response(new Uint8Array(bytes), {status: 200}) : new Response(null, {status: 404});
  });
  mockAuth(t);
  assert.equal(await convertApprovedWall(String(wall.id)), "blocked");
  status = 503;
  await assert.rejects(convertApprovedWall(String(wall.id)), /record read failed: 503/);
});

test("legacy Firebase Storage metadata is read without bytes and validated", async (t) => {
  const path = "prism-wallpapers.appspot.com/Replacement Thumbnails/picker (1).jpg";
  const requested: string[] = [];
  let body: Record<string, unknown> = {generation: "1603700046807890", md5Hash: "9cISxVqFwAg9FiaxrnwUJg==", size: "3253176"};
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL) => {
    requested.push(String(input));
    return new Response(JSON.stringify(body), {status: 200});
  });
  assert.deepEqual(await readFirebaseObjectMeta(path),
    {generation: "1603700046807890", md5Hash: "9cISxVqFwAg9FiaxrnwUJg==", size: 3253176});
  assert.deepEqual(requested, ["https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/" +
    "Replacement%20Thumbnails%2Fpicker%20(1).jpg"]);
  body = {...body, size: "99999999999"};
  await assert.rejects(readFirebaseObjectMeta(path), /metadata is invalid/);
  await assert.rejects(readFirebaseObjectMeta("other-bucket/x.jpg"), /outside the legacy bucket/);
});
