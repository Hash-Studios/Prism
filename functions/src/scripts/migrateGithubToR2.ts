import {createHash, randomUUID} from "node:crypto";
import {mkdir, readFile, rename, unlink, writeFile} from "node:fs/promises";
import {dirname} from "node:path";
import {AI_LEGACY_UID, AI_STORAGE_REPO} from "../aiWallSource";
import {FIREBASE_STORAGE_REPO, firebaseStoragePath} from "../ownedAssetDelivery";
import {buildAiRow, buildFirebaseRow, buildStudioRow, convertWall, conversionDeps, isLegacyMigrationUid, parseGithubAsset,
  proveMigrationAsset, readFirebaseObjectMeta, verifyR2MigrationCopy, type FirebaseObjectMeta, type GithubAsset,
  type MigrationDeps, type MigrationOptions, type MigrationResult, type MigrationWall, type StoredMigrationAsset,
  type WallInventory} from "../ownedWallConversion";
import {STUDIO_ACCOUNT} from "../studio/account";

export {buildAiRow, buildFirebaseRow, buildStudioRow, convertWall, downloadFirebaseAsset, downloadGithubAsset,
  downloadStudioAsset, gitBlobSha, isLegacyMigrationUid, parseGithubAsset, proveAiWall, proveMigrationAsset,
  verifyR2MigrationCopy} from "../ownedWallConversion";
export type {FirebaseObjectMeta, GithubAsset, LegacyBinding, MigrationDeps, MigrationOptions, MigrationResult, MigrationWall, OwnershipProof,
  R2ObjectClient, StoredMigrationAsset, WallInventory} from "../ownedWallConversion";

const IMAGE_PATH = /\.(?:jpe?g|png|webp|gif)$/i;
const digest = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");

export type GithubTreeEntry = {path: string; sha: string; size: number; type: string};
export type GithubTree = {truncated: boolean; entries: GithubTreeEntry[]};
export type GithubInventory = {owner: string; repo: string; commit: string; generatedAt: string; wallCount: number;
  imageCount: number; totalImageBytes: number; referencedImageCount: number; orphanImageCount: number; assets: GithubAsset[];
  orphanImages: {path: string; sha: string; size: number}[]; treeHash: string; walls: WallInventory[]};
type ReviewedAsset = GithubAsset & {recordedUrlHash: string};
type ReportAsset = {path?: string; gitSha?: string; size?: number; commit?: string; recordedUrlHash?: string;
  expectedResolution?: string; storagePin?: {generation?: string; md5?: string}};

/** `firebaseMeta` holds the pinned metadata of each legacy Firebase Storage original, by wall doc path. */
export function buildGithubInventory(walls: MigrationWall[], tree: GithubTree, options: MigrationOptions,
  firebaseMeta: Map<string, FirebaseObjectMeta> = new Map()): GithubInventory {
  if (tree.truncated) throw new Error("GitHub returned a truncated recursive tree; inventory is incomplete");
  const entries = new Map(tree.entries.filter((entry) => entry.type === "blob").map((entry) => [entry.path, entry]));
  const references = new Set<string>();
  const wallRows: WallInventory[] = walls.map((wall) => {
    // Studio and user AI walls are read from the Worker, not from the GitHub tree.
    const worker = buildStudioRow(wall) ?? buildAiRow(wall);
    if (worker) return worker;
    const firebase = buildFirebaseRow(wall, firebaseMeta.get(wall.docPath), () => assetForWall(wall, "thumb", options, entries));
    if (firebase) {
      if (firebase.thumb) references.add(firebase.thumb.path);
      return firebase;
    }
    const row: WallInventory = {wall, wallId: typeof wall.data.id === "string" ? wall.data.id : "", status: "blocked",
      detail: ""};
    try {
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(row.wallId)) throw new Error("Invalid logical wall.id");
      // A legacy wall has no stored paths; the path comes from the validated URL, and any stored path must match it.
      const stored = [wall.data.wallpaper_path, wall.data.thumb_path];
      if ((typeof stored[0] === "string" && stored[0] !== "" && stored[0].split("/").pop()?.startsWith("thumb_")) ||
        (typeof stored[1] === "string" && stored[1] !== "" && !stored[1].split("/").pop()?.startsWith("thumb_"))) {
        throw new Error("Original and thumbnail paths must use explicit original and thumb_ roles");
      }
      row.original = assetForWall(wall, "wallpaper", options, entries);
      row.thumb = assetForWall(wall, "thumb", options, entries);
      if (row.original.path.split("/").pop()?.startsWith("thumb_") || !row.thumb.path.split("/").pop()?.startsWith("thumb_")) {
        throw new Error("Original and thumbnail paths must use explicit original and thumb_ roles");
      }
      references.add(row.original.path);
      references.add(row.thumb.path);
      if (row.original.path === row.thumb.path) throw new Error("Original and thumbnail must be separate assets");
      row.status = "planned";
      row.detail = "Both assets exist in the pinned GitHub tree; GitHub remains unchanged";
    } catch (error) {
      row.detail = error instanceof Error ? error.message : "Inventory validation failed";
    }
    return row;
  });
  const images = [...entries.values()].filter((entry) => IMAGE_PATH.test(entry.path));
  const unique = new Map<string, GithubAsset>();
  for (const row of wallRows) {
    if (row.original) unique.set(row.original.path, row.original);
    if (row.thumb) unique.set(row.thumb.path, row.thumb);
  }
  const orphanImages = images.filter((entry) => !references.has(entry.path)
  ).map(({path, sha, size}) => ({path, sha, size}));
  return {owner: options.owner, repo: options.repo, commit: options.commit, generatedAt: new Date().toISOString(),
    wallCount: walls.length, imageCount: images.length,
    totalImageBytes: images.reduce((total, item) => total + item.size, 0), referencedImageCount: references.size,
    orphanImageCount: orphanImages.length, orphanImages, assets: [...unique.values()],
    treeHash: digest(JSON.stringify(tree.entries.map(({path, sha, size, type}) => ({path, sha, size, type}))
      .sort((left, right) => left.path.localeCompare(right.path)))), walls: wallRows};
}

function assetForWall(wall: MigrationWall, prefix: "wallpaper" | "thumb", options: MigrationOptions,
  entries: Map<string, GithubTreeEntry>): GithubAsset {
  const raw = wall.data[prefix === "thumb" ? "wallpaper_thumb" : "wallpaper_url"];
  const path = wall.data[prefix === "thumb" ? "thumb_path" : "wallpaper_path"];
  const asset = parseGithubAsset(raw, path, options);
  if (!IMAGE_PATH.test(asset.path)) throw new Error(`Unsupported wallpaper image path: ${asset.path}`);
  const entry = entries.get(asset.path);
  if (!entry || !/^[a-f0-9]{40}$/.test(entry.sha) || !Number.isSafeInteger(entry.size) || entry.size <= 0) {
    throw new Error(`Asset ${asset.path} is missing from pinned GitHub tree`);
  }
  const docSha = wall.data[prefix === "thumb" ? "thumb_sha" : "wallpaper_sha"];
  if (docSha !== undefined && docSha !== "" && docSha !== entry.sha) throw new Error(`Wall Git SHA differs from pinned tree: ${asset.path}`);
  return {...asset, sha: entry.sha, gitSha: entry.sha, size: entry.size};
}

export async function migrateGithubInventory(inventory: GithubInventory, options: MigrationOptions,
  deps: MigrationDeps): Promise<MigrationResult[]> {
  const idCounts = new Map<string, number>();
  for (const row of inventory.walls) idCounts.set(row.wallId, (idCounts.get(row.wallId) ?? 0) + 1);
  const results: MigrationResult[] = [];
  for (const row of inventory.walls) {
    const result: MigrationResult = {docPath: row.wall.docPath, wallId: row.wallId, status: "blocked", detail: row.detail,
      publicGithubCopiesRemain: true};
    results.push(result);
    try {
      if (idCounts.get(row.wallId) !== 1) throw new Error("Duplicate logical wall.id");
      await convertWall(row, options, deps, result, async () => deps.progress?.([...results]));
    } catch (error) {
      result.detail = error instanceof Error ? error.message : "Migration failed";
      if (result.status === "in-progress") result.status = "blocked";
    }
    await deps.progress?.([...results]);
  }
  return results;
}

export async function writeInventoryReport(path: string, report: unknown): Promise<void> {
  await mkdir(dirname(path), {recursive: true, mode: 0o700});
  const temporary = `${path}.tmp-${randomUUID()}`;
  try {
    await writeFile(temporary, `${JSON.stringify(report, null, 2)}\n`, {encoding: "utf8", flag: "wx", mode: 0o600});
    await rename(temporary, path);
  } catch (error) {
    await unlink(temporary).catch(() => undefined);
    throw error;
  }
}

export function createInventoryReport(inventory: GithubInventory) {
  const asset = (value: GithubAsset) => ({path: value.path, gitSha: value.gitSha, size: value.size, commit: value.commit,
    recordedUrlHash: digest(value.recordedUrl), ...(value.expectedResolution ? {expectedResolution: value.expectedResolution} : {}),
    ...(value.storagePin ? {storagePin: value.storagePin} : {})});
  const aiFingerprint = (row: WallInventory) => row.ai && ({generationId: row.ai.generationId,
    authorEmailHash: typeof row.wall.data.email === "string" ? digest(row.wall.data.email) : null,
    resolution: typeof row.wall.data.resolution === "string" ? row.wall.data.resolution : null,
    origin: typeof row.wall.data.origin === "string" ? row.wall.data.origin : null});
  return {sourceFingerprintVersion: 1, owner: inventory.owner, repo: inventory.repo, commit: inventory.commit, generatedAt: inventory.generatedAt,
    wallCount: inventory.wallCount, imageCount: inventory.imageCount, totalImageBytes: inventory.totalImageBytes,
    referencedImageCount: inventory.referencedImageCount, orphanImageCount: inventory.orphanImageCount,
    orphanImages: inventory.orphanImages, treeHash: inventory.treeHash, assets: inventory.assets.map(asset), walls: inventory.walls.map((row) => ({
      docPath: row.wall.docPath, wallId: row.wallId, incarnation: row.wall.incarnation,
      incarnationNanos: row.wall.incarnationNanos, review: row.wall.data.review === true,
      original: row.original && asset(row.original), thumb: row.thumb && asset(row.thumb), status: row.status, detail: row.detail,
      ...(row.studio ? {studio: row.studio} : {}), ...(row.ai ? {ai: aiFingerprint(row)} : {}),
    }))};
}

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value)
      .filter(([key]) => key !== "generatedAt").sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => [key, canonical(child)]));
  }
  return value;
}

type ReviewedAiSource = {generationId?: unknown; authorEmailHash?: unknown; resolution?: unknown; origin?: unknown};
function matchesReviewedAiSource(data: Record<string, unknown>, ai: ReviewedAiSource): boolean {
  return data.isAiGenerated === true && data.aiGenerationId === ai.generationId &&
    (typeof data.email === "string" ? digest(data.email) : null) === ai.authorEmailHash &&
    (typeof data.resolution === "string" ? data.resolution : null) === ai.resolution &&
    (typeof data.origin === "string" ? data.origin : null) === ai.origin;
}

/**
 * Checks the reviewed dry-run against the live inventory and returns the doc paths the apply may touch.
 * Walls added since the review are not in that set (the approval trigger converts them) and deleted walls are skipped.
 * A reviewed wall that changed throws, unless it is now converted and its manifest still matches the review.
 */
export async function validateReviewedInventory(reviewed: unknown, inventory: GithubInventory, commit: string,
  allowReviewedLegacy: boolean,
  verifyMigrated?: (wall: MigrationWall, original: ReviewedAsset, thumb: ReviewedAsset,
    ai?: ReviewedAiSource) => Promise<boolean>,
  allowReviewedAiLegacy = false): Promise<Set<string>> {
  if (!reviewed || typeof reviewed !== "object") throw new Error("Apply requires a reviewed dry-run inventory report");
  const report = reviewed as {mode?: unknown; inventory?: unknown;
    policy?: {allowReviewedLegacy?: unknown; allowReviewedAiLegacy?: unknown}};
  if (!(["dry-run", "apply"].includes(String(report.mode))) || !report.inventory || typeof report.inventory !== "object") {
    throw new Error("Apply requires a reviewed dry-run inventory report");
  }
  const envelope = reviewed as {reviewedInventory?: unknown};
  const snapshot = envelope.reviewedInventory ?? report.inventory;
  const previous = snapshot as {owner?: unknown; repo?: unknown; commit?: unknown; sourceFingerprintVersion?: unknown};
  if (previous.sourceFingerprintVersion !== 1) throw new Error("Reviewed source fingerprints are missing; run dry-run again");
  if (report.policy?.allowReviewedLegacy !== allowReviewedLegacy ||
    (report.policy?.allowReviewedAiLegacy === true) !== allowReviewedAiLegacy || previous.owner !== inventory.owner ||
    previous.repo !== inventory.repo || previous.commit !== commit) {
    throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
  }
  const oldRows = (snapshot as {walls?: unknown}).walls;
  if (!Array.isArray(oldRows)) throw new Error("Reviewed inventory snapshot is invalid");
  const oldByPath = new Map<string, unknown>();
  for (const row of oldRows) {
    const path = (row as {docPath?: unknown}).docPath;
    if (typeof path !== "string" || oldByPath.has(path)) throw new Error("Reviewed inventory snapshot is invalid");
    oldByPath.set(path, row);
  }
  const current = createInventoryReport(inventory) as {walls: Record<string, unknown>[]};
  const snapshotAssets = (snapshot as {assets?: unknown}).assets;
  if (!Array.isArray(snapshotAssets)) throw new Error("Reviewed inventory snapshot is invalid");
  const assetByPath = new Map<string | undefined, unknown>(
    snapshotAssets.map((asset) => [(asset as {path?: string}).path, asset]));
  const authorized = new Set<string>();
  for (const row of current.walls) {
    if (typeof row.docPath !== "string") throw new Error("Reviewed inventory snapshot is invalid");
    const old = oldByPath.get(row.docPath) as Record<string, unknown> | undefined;
    if (!old) continue;
    authorized.add(row.docPath);
    if (digest(JSON.stringify(canonical(old))) === digest(JSON.stringify(canonical(row)))) continue;
    const source = inventory.walls.find((candidate) => candidate.wall.docPath === row.docPath);
    const oldOriginal = old.original as ReportAsset | undefined;
    const oldThumb = old.thumb as ReportAsset | undefined;
    const studio = old.studio as {runId?: unknown; candidateId?: unknown} | undefined;
    const ai = old.ai as ReviewedAiSource | undefined;
    if (!verifyMigrated || !source || !oldOriginal || !oldThumb ||
      old.docPath !== source.wall.docPath || old.wallId !== source.wallId ||
      old.review !== row.review ||
      old.incarnation !== source.wall.incarnation || old.incarnationNanos !== source.wall.incarnationNanos ||
      (studio && (source.wall.data.origin !== "studio" || source.wall.data.email !== STUDIO_ACCOUNT.email ||
        source.wall.data.studioRunId !== studio.runId ||
        source.wall.data.studioCandidateId !== studio.candidateId ||
        source.wall.data.resolution !== oldOriginal.expectedResolution)) ||
      (ai && !matchesReviewedAiSource(source.wall.data, ai)) ||
      !source.wall.data.originalProtected || source.wall.data.wallpaper_url !== "" ||
      typeof source.wall.data.originalObjectId !== "string" || source.wall.data.id !== old.wallId ||
      ![undefined, ""].includes(source.wall.data.wallpaper_path as string | undefined) ||
      ![undefined, ""].includes(source.wall.data.thumb_path as string | undefined) ||
      !assetByPath.has(oldOriginal.path) || !assetByPath.has(oldThumb.path) ||
      !await verifyMigrated(source.wall, reviewedAsset(oldOriginal, previous, ai), reviewedAsset(oldThumb, previous, ai), ai)) {
      throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
    }
  }
  const currentReport = createInventoryReport(inventory) as Record<string, unknown>;
  const invariantKeys = ["owner", "repo", "commit", "imageCount", "totalImageBytes", "treeHash"];
  if (invariantKeys.some((key) => digest(JSON.stringify(canonical((snapshot as Record<string, unknown>)[key]))) !==
    digest(JSON.stringify(canonical(currentReport[key]))))) {
    throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
  }
  return authorized;
}

function reviewedAsset(value: ReportAsset, source: {
  owner?: unknown; repo?: unknown;
}, ai?: ReviewedAiSource): ReviewedAsset {
  if (typeof source.owner !== "string" || typeof source.repo !== "string" || typeof value.path !== "string" ||
    typeof value.gitSha !== "string" || typeof value.size !== "number" || typeof value.commit !== "string" ||
    typeof value.recordedUrlHash !== "string" || !/^[a-f0-9]{64}$/.test(value.recordedUrlHash)) {
    throw new Error("Reviewed inventory asset is invalid; run dry-run again");
  }
  const encodedPath = value.path.split("/").map(encodeURIComponent).join("/");
  const url = `https://raw.githubusercontent.com/${source.owner}/${source.repo}/${value.commit}/${encodedPath}`;
  const pin = value.storagePin;
  if (pin && (typeof pin.generation !== "string" || typeof pin.md5 !== "string" ||
    !Number.isSafeInteger(value.size) || (value.size as number) <= 0)) {
    throw new Error("Reviewed inventory asset is invalid; run dry-run again");
  }
  return {repo: pin ? FIREBASE_STORAGE_REPO : ai ? AI_STORAGE_REPO : source.repo, path: value.path, url, recordedUrl: url, sha: value.gitSha,
    gitSha: value.gitSha, size: value.size, commit: value.commit, recordedUrlHash: value.recordedUrlHash,
    ...(value.expectedResolution ? {expectedResolution: value.expectedResolution} : {}),
    ...(pin ? {storagePin: {generation: pin.generation as string, md5: pin.md5 as string}} : {})};
}

/** Verifies already-retained assets against their manifest and the source pins from the reviewed dry run. */
export async function verifyReviewedR2Copies(original: StoredMigrationAsset, thumb: StoredMigrationAsset,
  reviewedOriginal: ReviewedAsset, verifyStored: (asset: StoredMigrationAsset) => Promise<void>,
  getObject: (kind: "private" | "preview", object: string) => Promise<Buffer>): Promise<void> {
  await Promise.all([verifyStored(original), verifyStored(thumb)]);
  let firebasePin: {size: number; md5: string} | undefined;
  if (reviewedOriginal.storagePin) {
    firebasePin = {size: reviewedOriginal.size, md5: reviewedOriginal.storagePin.md5};
  }
  await Promise.all([
    verifyR2MigrationCopy(original, firebasePin?.size, getObject, async () => undefined, firebasePin),
    verifyR2MigrationCopy(thumb, undefined, getObject, async () => undefined),
  ]);
}

export function validateMigrationCommit(ref: string, apply: boolean): void {
  if (apply && !/^[a-f0-9]{40}$/.test(ref)) {
    throw new Error("Apply requires the exact 40-character commit SHA from the reviewed dry-run report");
  }
}

async function githubJson(path: string): Promise<unknown> {
  const headers: Record<string, string> = {"accept": "application/vnd.github+json", "user-agent": "Prism-R2-migration"};
  if (process.env.GH_TOKEN) headers.authorization = `Bearer ${process.env.GH_TOKEN}`;
  const response = await fetch(`https://api.github.com${path}`, {headers});
  if (!response.ok) throw new Error(`GitHub API failed (${response.status}); check repo access and rate limits`);
  return response.json();
}

async function resolvePinnedTree(owner: string, repo: string, ref: string): Promise<{commit: string; tree: GithubTree}> {
  const commitResult = await githubJson(`/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/commits/${encodeURIComponent(ref)}`);
  const commit = commitResult as {sha?: unknown};
  if (typeof commit.sha !== "string" || !/^[a-f0-9]{40}$/.test(commit.sha)) throw new Error("GitHub did not return a pinned commit");
  const treeResult = await githubJson(`/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/git/trees/${commit.sha}?recursive=1`);
  const tree = treeResult as {tree?: unknown; truncated?: unknown};
  if (!Array.isArray(tree.tree)) throw new Error("GitHub tree response is invalid");
  const entries: GithubTreeEntry[] = tree.tree.map((value: unknown) => {
    if (!value || typeof value !== "object") throw new Error("GitHub tree entry is invalid");
    const entry = value as {path?: unknown; sha?: unknown; size?: unknown; type?: unknown};
    if (typeof entry.path !== "string" || !entry.path || entry.path.startsWith("/") || entry.path.includes("\\") ||
      entry.path.split("/").some((part) => !part || part === "." || part === "..") ||
      Array.from(entry.path).some((character) => character.charCodeAt(0) < 32) ||
      typeof entry.type !== "string" || (entry.type === "blob" && (typeof entry.sha !== "string" ||
      !/^[a-f0-9]{40}$/.test(entry.sha) || typeof entry.size !== "number" || !Number.isSafeInteger(entry.size) || entry.size < 0))) {
      throw new Error("GitHub tree entry is invalid");
    }
    return {path: entry.path, sha: typeof entry.sha === "string" ? entry.sha : "",
      size: typeof entry.size === "number" ? entry.size : 0, type: entry.type};
  });
  return {commit: commit.sha, tree: {truncated: tree.truncated === true, entries}};
}

async function main(): Promise<void> {
  const values = process.argv.slice(2);
  const args = new Map<string, string | true>();
  for (let index = 0; index < values.length; index++) {
    const arg = values[index];
    if (["--apply", "--allow-reviewed-legacy", "--allow-reviewed-ai-legacy", "--confirm-approved-migration"].includes(arg)) {
      args.set(arg, true);
    } else if (["--ref", "--report"].includes(arg) && values[index + 1]) args.set(arg, values[++index]);
    else throw new Error(`Unknown or incomplete option: ${arg}`);
  }
  const apply = args.has("--apply");
  if (apply && !args.has("--confirm-approved-migration")) {
    throw new Error("--apply requires explicit operator approval and --confirm-approved-migration");
  }
  const ref = args.get("--ref");
  const reportPath = args.get("--report");
  if (typeof ref !== "string" || typeof reportPath !== "string") throw new Error("Usage: --ref <branch-or-commit> --report <json-path> [--allow-reviewed-legacy] [--allow-reviewed-ai-legacy] [--apply --confirm-approved-migration]");
  validateMigrationCommit(ref, apply);
  const owner = process.env.GH_USERNAME ?? "";
  const repo = process.env.GH_REPO_WALLS ?? "";
  if (!/^[A-Za-z0-9-]{1,39}$/.test(owner) || !/^[A-Za-z0-9_.-]{1,100}$/.test(repo)) {
    throw new Error("GH_USERNAME and GH_REPO_WALLS must name the configured public repository");
  }
  const {db} = await import("../common.js");
  const resolved = await resolvePinnedTree(owner, repo, ref);
  const rows = await db.collection("walls").get();
  const walls = rows.docs.map((doc) => ({docPath: doc.ref.path, incarnation: doc.createTime?.toMillis() ?? 0,
    incarnationNanos: doc.createTime?.nanoseconds ?? 0, data: doc.data()}));
  const options: MigrationOptions = {apply, allowReviewedLegacy: args.has("--allow-reviewed-legacy"), owner, repo,
    commit: resolved.commit, allowReviewedAiLegacy: args.has("--allow-reviewed-ai-legacy")};
  const firebaseMeta = new Map<string, FirebaseObjectMeta>();
  for (const wall of walls) {
    const path = firebaseStoragePath(wall.data.wallpaper_url);
    // A failed read leaves the row blocked with "metadata is missing".
    if (path) await readFirebaseObjectMeta(path).then((meta) => firebaseMeta.set(wall.docPath, meta)).catch(() => undefined);
  }
  const inventory = buildGithubInventory(walls, resolved.tree, options, firebaseMeta);
  let reviewed: unknown;
  let authorized: Set<string> | undefined;
  if (apply) {
    try {
      reviewed = JSON.parse(await readFile(reportPath, "utf8")) as unknown;
    } catch {
      throw new Error("Apply requires the existing private dry-run report at --report");
    }
    const verifier = async (wall: MigrationWall, original: ReviewedAsset, thumb: ReviewedAsset, reviewedAi?: ReviewedAiSource) => {
      const manifest = (await db.collection("ownedAssets").doc(String(wall.data.id)).get()).data();
      if (!manifest || manifest.status !== "ready" || !manifest.original || !manifest.thumb ||
        manifest.original.path !== original.path || manifest.thumb.path !== thumb.path ||
        manifest.original.uid !== manifest.thumb.uid || typeof manifest.originalUrl !== "string" ||
        typeof manifest.thumbUrl !== "string" || digest(manifest.originalUrl) !== original.recordedUrlHash ||
        digest(manifest.thumbUrl) !== thumb.recordedUrlHash) return false;
      // Studio and AI assets are not pinned to a Git blob; the candidate backlink or generation is their proof.
      // A Firebase Storage original is pinned to its object generation instead of a Git blob.
      const studio = manifest.provenance?.kind === "studio";
      const ai = ["ai", "ai-legacy"].includes(manifest.provenance?.kind);
      if (!studio && !ai && ((original.gitSha && manifest.original.sha !== original.gitSha) ||
        manifest.thumb.sha !== thumb.gitSha)) return false;
      if (ai) {
        const {kind, generationId, uid} = manifest.provenance as {kind: string; generationId?: unknown; uid?: unknown};
        if (typeof generationId !== "string" || !reviewedAi || !matchesReviewedAiSource(wall.data, reviewedAi) ||
          ![`ai/original/${generationId}.png`, `ai/public/${generationId}.png`].includes(original.path) ||
          thumb.path !== `ai/public/${generationId}.png` ||
          manifest.original.uid !== (kind === "ai" ? uid : AI_LEGACY_UID) || manifest.thumb.uid !== manifest.original.uid ||
          (kind === "ai-legacy" && !options.allowReviewedAiLegacy)) return false;
      } else if (studio) {
        const {runId, candidateId} = manifest.provenance as {runId?: unknown; candidateId?: unknown};
        if (typeof runId !== "string" || typeof candidateId !== "string" || manifest.original.uid !== STUDIO_ACCOUNT.id ||
          wall.data.origin !== "studio" || wall.data.studioRunId !== runId || wall.data.studioCandidateId !== candidateId ||
          original.path !== `ai/studio/${candidateId}.jpg` || thumb.path !== `ai/studio/thumb_${candidateId}.jpg` ||
          (await db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId).get())
            .data()?.wallId !== wall.data.id) return false;
      } else {
        const historicalOriginal = {...original, recordedUrl: manifest.originalUrl};
        const historicalThumb = {...thumb, recordedUrl: manifest.thumbUrl};
        const [originalProof, thumbProof] = await Promise.all([
          proveMigrationAsset(historicalOriginal), proveMigrationAsset(historicalThumb),
        ]);
        const modern = Boolean(originalProof.uid && originalProof.uid === thumbProof.uid &&
          manifest.provenance?.kind === "github" && manifest.provenance.uid === originalProof.uid &&
          manifest.original.uid === originalProof.uid && manifest.thumb.uid === originalProof.uid);
        const legacy = Boolean(originalProof.legacyEligible && thumbProof.legacyEligible &&
          options.allowReviewedLegacy && wall.data.review === true && manifest.provenance?.kind === "legacy" &&
          isLegacyMigrationUid(manifest.original.uid));
        if (!modern && !legacy) return false;
      }
      const current = await db.doc(wall.docPath).get();
      const data = current.data();
      if (!current.exists || !data || current.createTime?.toMillis() !== wall.incarnation ||
        current.createTime.nanoseconds !== wall.incarnationNanos || data.id !== wall.data.id ||
        data.originalProtected !== true || data.wallpaper_url !== "" || typeof data.originalObjectId !== "string") return false;
      const delivery = await import("../ownedAssetDelivery.js");
      const ready = manifest?.status === "ready" && manifest.canonicalPath === wall.docPath &&
        manifest.incarnation === wall.incarnation && manifest.incarnationNanos === wall.incarnationNanos &&
        data.originalObjectId === manifest.original?.objectId &&
        data.wallpaper_thumb === delivery.ownedThumbnailUrl(manifest.thumb);
      if (!ready) return false;
      const r2 = new (await import("../r2Storage.js")).R2Storage();
      const owned = await delivery.getOwnedWallDelivery(String(wall.data.id));
      await verifyReviewedR2Copies(owned.original, owned.thumb, original, delivery.verifyStoredUpload,
        (kind, object) => r2.get(kind, object));
      return true;
    };
    authorized = await validateReviewedInventory(reviewed, inventory, resolved.commit, options.allowReviewedLegacy, verifier,
      options.allowReviewedAiLegacy);
  }
  const reviewedSnapshot = apply && reviewed && typeof reviewed === "object" &&
    "reviewedInventory" in reviewed ? (reviewed as {reviewedInventory: unknown}).reviewedInventory :
    apply && reviewed && typeof reviewed === "object" && "inventory" in reviewed ?
      (reviewed as {inventory: unknown}).inventory : createInventoryReport(inventory);
  const policy = {allowReviewedLegacy: options.allowReviewedLegacy, allowReviewedAiLegacy: options.allowReviewedAiLegacy};
  const report = {mode: apply ? "apply" : "dry-run", policy,
    reviewedInventory: reviewedSnapshot, inventory: createInventoryReport(inventory), results: [] as MigrationResult[],
    warning: "GitHub assets remain public and unchanged. Removal requires a separate approved operation."};
  await writeInventoryReport(reportPath, report);
  const r2 = apply ? new (await import("../r2Storage.js")).R2Storage() : null;
  // Only reviewed walls are touched; walls added since the review are converted by the approval trigger.
  const planned = authorized ? {...inventory, walls: inventory.walls.filter((row) => authorized!.has(row.wall.docPath))} : inventory;
  const results = await migrateGithubInventory(planned, options, {
    ...conversionDeps(apply, r2, db, options.allowReviewedAiLegacy),
    progress: async (partial) => {
      report.results = partial; await writeInventoryReport(reportPath, report);
    },
  });
  report.results = results;
  await writeInventoryReport(reportPath, report);
  process.stdout.write(`${JSON.stringify({mode: report.mode, commit: inventory.commit, wallCount: inventory.wallCount,
    imageCount: inventory.imageCount, totalImageBytes: inventory.totalImageBytes,
    referencedImageCount: inventory.referencedImageCount, orphanImageCount: inventory.orphanImageCount, results,
    skippedUnreviewed: inventory.walls.length - planned.walls.length,
    report: reportPath, warning: report.warning}, null, 2)}\n`);
  if (results.some((row) => row.status === "blocked")) process.exitCode = 2;
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : "Migration failed"}\n`);
    process.exitCode = 1;
  });
}
