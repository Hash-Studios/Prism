import assert from "node:assert/strict";
import {test} from "node:test";
import {createHash} from "node:crypto";
import {buildGithubInventory, createInventoryReport, gitBlobSha, migrateGithubInventory, type GithubTree,
  type MigrationDeps, type MigrationOptions, type MigrationWall, validateReviewedInventory} from "../scripts/migrateGithubToR2";

const bytes = Buffer.from("image bytes");
const sha = gitBlobSha(bytes);
const options: MigrationOptions = {apply: false, allowReviewedLegacy: false, owner: "hash", repo: "walls", commit: "a".repeat(40)};
const wall = (data: Record<string, unknown> = {}, docPath = "walls/canonical"): MigrationWall => ({docPath,
  incarnation: 100, incarnationNanos: 1_000_000, data: {id: "wall_1", review: true,
    wallpaper_url: `https://raw.githubusercontent.com/hash/walls/${options.commit}/original.jpg`,
    wallpaper_thumb: `https://raw.githubusercontent.com/hash/walls/${options.commit}/thumb_original.jpg`,
    wallpaper_path: "original.jpg", thumb_path: "thumb_original.jpg", wallpaper_sha: sha, thumb_sha: sha, ...data}});
const tree: GithubTree = {truncated: false, entries: [
  {path: "original.jpg", sha, size: bytes.length, type: "blob"},
  {path: "thumb_original.jpg", sha, size: bytes.length, type: "blob"},
]};

function fixture() {
  const calls: string[] = [];
  const retained: {uid: string; sourceKind?: string; uploadId?: string; sha: string}[] = [];
  let bound = false;
  const deps: MigrationDeps = {
    prove: async () => ({uid: "creator", legacyEligible: false}),
    fetchBytes: async () => bytes,
    retain: async (asset) => {
      retained.push({uid: asset.uid, sourceKind: asset.sourceKind, uploadId: asset.uploadId, sha: asset.sha});
      const objectId = asset.path.includes("thumb_") ? "2".repeat(64) : "1".repeat(64);
      return {repo: asset.repo, path: asset.path, sha: asset.sha, uid: asset.uid, bucket: "private",
        object: `retained/${objectId}`, objectId, sha256: createHash("sha256").update(bytes).digest("hex"),
        ...(asset.path.includes("thumb_") ? {previewObjectId: objectId} : {})};
    },
    verify: async () => undefined,
    revalidate: async () => undefined,
    attach: async (asset) => {
      calls.push(`attach:${asset.path}`);
    },
    bind: async (id) => {
      calls.push(`bind:${id}`); bound = true;
    },
    bindLegacy: async (input) => {
      calls.push(`bind-legacy:${JSON.stringify(input.source ?? null)}`); bound = true;
    },
    ready: async () => bound,
  };
  return {calls, retained, deps};
}

const reviewedFor = (walls: MigrationWall[]) => ({mode: "dry-run", policy: {allowReviewedLegacy: false},
  inventory: createInventoryReport(buildGithubInventory(walls, tree, options))});

test("apply skips walls added after the review and walls deleted since the review", async () => {
  const reviewed = reviewedFor([wall(), wall({id: "wall_2"}, "walls/deleted")]);
  const live = buildGithubInventory([wall(), wall({id: "wall_3"}, "walls/added")], tree, options);
  const authorized = await validateReviewedInventory(reviewed, live, options.commit, false);
  assert.deepEqual([...authorized], ["walls/canonical"]);
  const planned = {...live, walls: live.walls.filter((row) => authorized.has(row.wall.docPath))};
  const results = await migrateGithubInventory(planned, {...options, apply: true}, fixture().deps);
  assert.deepEqual(results.map((row) => [row.docPath, row.status]), [["walls/canonical", "migrated"]]);
});

test("apply still aborts when a reviewed wall changed its source", async () => {
  const reviewed = reviewedFor([wall()]);
  const other = {...tree, entries: [...tree.entries, {path: "other.jpg", sha, size: bytes.length, type: "blob"}]};
  const changed = buildGithubInventory([wall({wallpaper_url: `https://raw.githubusercontent.com/hash/walls/${options.commit}/other.jpg`,
    wallpaper_path: "other.jpg"})], other, options);
  await assert.rejects(validateReviewedInventory(reviewed, changed, options.commit, false), /changed since review/);
});

test("a wall converted by the approval trigger counts as done only when its manifest matches the review", async () => {
  const reviewed = reviewedFor([wall()]);
  const converted = wall({originalProtected: true, originalObjectId: "1".repeat(64), wallpaper_url: "",
    wallpaper_thumb: "https://images.example.com/previews/x.img", wallpaper_path: "", thumb_path: "", wallpaper_sha: "", thumb_sha: ""});
  const live = buildGithubInventory([converted], tree, options);
  const verified: string[] = [];
  const authorized = await validateReviewedInventory(reviewed, live, options.commit, false, async (row) => {
    verified.push(row.docPath); return true;
  });
  assert.deepEqual(verified, ["walls/canonical"]);
  assert.ok(authorized.has("walls/canonical"));
  await assert.rejects(validateReviewedInventory(reviewed, live, options.commit, false, async () => false), /changed since review/);
  const {calls, deps} = fixture();
  deps.ready = async () => true;
  const [result] = await migrateGithubInventory(live, {...options, apply: true}, deps);
  assert.equal(result.status, "already-owned");
  assert.deepEqual(calls, []);
});

test("a legacy wall without stored paths takes its paths from the validated URLs", () => {
  const legacy = wall({wallpaper_path: undefined, thumb_path: undefined, wallpaper_sha: undefined, thumb_sha: undefined});
  const [row] = buildGithubInventory([legacy], tree, options).walls;
  assert.equal(row.status, "planned");
  assert.equal(row.original?.path, "original.jpg");
  assert.equal(row.thumb?.path, "thumb_original.jpg");
});

const studioWall = (data: Record<string, unknown> = {}): MigrationWall => ({docPath: "walls/studio", incarnation: 100,
  incarnationNanos: 1_000_000, data: {id: "studio_1", review: true, origin: "studio", email: "studio@prismwalls.com",
    studioRunId: "run-1", studioCandidateId: "cand-1", resolution: "1440x3200",
    wallpaper_url: "https://prismwalls.com/api/ai/assets/ai/studio/cand-1.jpg",
    wallpaper_thumb: "https://prismwalls.com/api/ai/assets/ai/studio/thumb_cand-1.jpg", ...data}});

test("Studio walls are inventoried from their worker URLs, not from the GitHub tree", () => {
  const [row] = buildGithubInventory([studioWall()], tree, options).walls;
  assert.equal(row.status, "planned");
  assert.deepEqual(row.studio, {kind: "studio", runId: "run-1", candidateId: "cand-1"});
  assert.equal(row.original?.url, "https://prismwalls.com/api/ai/assets/ai/studio/cand-1.jpg");
  assert.equal(row.original?.expectedResolution, "1440x3200");
  const [forged] = buildGithubInventory([studioWall({wallpaper_url: "https://evil.example/a.jpg"})], tree, options).walls;
  assert.equal(forged.status, "blocked");
});

test("a Studio row converts with Studio provenance, without receipts or a GitHub attach", async () => {
  const {calls, retained, deps} = fixture();
  deps.prove = async (_original, _thumb, row) => ({uid: "prism-studio", legacyEligible: false, studio: row.studio});
  const inventory = buildGithubInventory([studioWall()], tree, options);
  const [result] = await migrateGithubInventory(inventory, {...options, apply: true}, deps);
  assert.equal(result.status, "migrated", result.detail);
  assert.deepEqual(calls, ["bind-legacy:{\"kind\":\"studio\",\"runId\":\"run-1\",\"candidateId\":\"cand-1\"}"]);
  assert.deepEqual(retained.map((row) => [row.uid, row.sourceKind, row.uploadId]),
    [["prism-studio", "studio", "cand-1"], ["prism-studio", "studio", "cand-1"]]);
  assert.equal(retained[0].sha, gitBlobSha(bytes), "the blob SHA comes from the downloaded bytes");
});
