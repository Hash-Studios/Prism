import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {onOwnedWallWritten, STUDIO_STORAGE_REPO, stored} from "../ownedAssetDelivery";
import {convertApprovedWall, convertWall, buildStudioRow, gitBlobSha, type MigrationDeps, type MigrationResult,
  type MigrationWall, type WallInventory} from "../ownedWallConversion";
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
function installNetwork(t: TestContext, sources: Record<string, Buffer>) {
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
    return new Response(new Uint8Array(bytes), {status: 200, headers: {"content-length": String(bytes.length)}});
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

test("a 3.7.0 upload with receipts keeps them and binds with GitHub provenance", async (t) => {
  configure(t);
  const sources = await legacySources("up.jpg");
  const original = sources[`${RAW}/up.jpg`];
  const thumb = sources[`${RAW}/thumb_up.jpg`];
  const wall = legacyWall({id: "w3", wallpaper_url: `${RAW}/up.jpg`, wallpaper_thumb: `${RAW}/thumb_up.jpg`,
    wallpaper_path: "up.jpg", thumb_path: "thumb_up.jpg", wallpaper_sha: gitBlobSha(original), thumb_sha: gitBlobSha(thumb)});
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

test("two deliveries of the same approval converge on one manifest", async (t) => {
  configure(t);
  const store = installFakeDb(t, studioSeed());
  installNetwork(t, await studioSources());
  const results = await Promise.all([convertApprovedWall("w1"), convertApprovedWall("w1")]);
  assert.ok(results.includes("converted"));
  const manifest = store.get("ownedAssets/w1") as {original: {objectId: string}};
  assert.equal(store.get("walls/w1")?.originalObjectId, manifest.original.objectId);
  assert.equal([...store.keys()].filter((key) => key.startsWith("ownedAssets/")).length, 1);
});

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
