import {createHash, randomUUID} from "node:crypto";
import {mkdir, readFile, rename, unlink, writeFile} from "node:fs/promises";
import {dirname} from "node:path";
import type {StoredUpload} from "../ownedAssetDelivery";

const MAX_BYTES = 15 * 1024 * 1024;
const IMAGE_PATH = /\.(?:jpe?g|png|webp|gif)$/i;
const digest = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");

export type MigrationOptions = {apply: boolean; allowReviewedLegacy: boolean; owner: string; repo: string; commit: string};
export type MigrationWall = {docPath: string; incarnation: number; incarnationNanos: number; data: Record<string, unknown>};
export type GithubTreeEntry = {path: string; sha: string; size: number; type: string};
export type GithubTree = {truncated: boolean; entries: GithubTreeEntry[]};
export type GithubAsset = {repo: string; path: string; url: string; recordedUrl: string; sha: string; gitSha: string;
  size: number; commit: string};
export type StoredMigrationAsset = StoredUpload;
export type WallInventory = {wall: MigrationWall; wallId: string; original?: GithubAsset; thumb?: GithubAsset;
  status: "planned" | "blocked"; detail: string};
export type GithubInventory = {owner: string; repo: string; commit: string; generatedAt: string; wallCount: number;
  imageCount: number; totalImageBytes: number; referencedImageCount: number; orphanImageCount: number; assets: GithubAsset[];
  orphanImages: {path: string; sha: string; size: number}[]; treeHash: string; walls: WallInventory[]};
export type MigrationResult = {docPath: string; wallId: string; status: "would-migrate" | "in-progress" | "migrated" | "already-owned" | "blocked";
  detail: string; publicGithubCopiesRemain: true};
export type LegacyBinding = {wallId: string; canonicalPath: string; incarnation: number; incarnationNanos: number;
  originalUrl: string; thumbUrl: string; original: StoredMigrationAsset; thumb: StoredMigrationAsset};
export type OwnershipProof = {uid: string | null; legacyEligible: boolean};
export type MigrationDeps = {
  prove: (original: GithubAsset, thumb: GithubAsset) => Promise<OwnershipProof>;
  fetchBytes: (asset: GithubAsset) => Promise<Buffer>;
  retain: (asset: GithubAsset & {uid: string; bytes: Buffer}) => Promise<StoredMigrationAsset>;
  verify: (asset: StoredMigrationAsset, size: number) => Promise<void>;
  revalidate: (wall: MigrationWall, original: GithubAsset, thumb: GithubAsset) => Promise<void>;
  attach: (asset: StoredMigrationAsset) => Promise<void>;
  bind: (wallId: string) => Promise<void>;
  bindLegacy: (input: LegacyBinding) => Promise<void>;
  ready: (wall: MigrationWall) => Promise<boolean>;
  progress?: (results: MigrationResult[]) => Promise<void>;
};
export type R2ObjectClient = {get: (kind: "private" | "preview", object: string) => Promise<Buffer>};

export function isLegacyMigrationUid(uid: unknown): boolean {
  return uid === "legacy-migration";
}

export const gitBlobSha = (bytes: Buffer): string => createHash("sha1")
  .update(`blob ${bytes.length}\0`).update(bytes).digest("hex");

/** Only a raw URL at the pinned commit in the configured public repository is accepted. */
export function parseGithubAsset(raw: unknown, path: unknown, options: MigrationOptions): GithubAsset {
  if (!options.owner || !options.repo || !/^[a-f0-9]{40}$/.test(options.commit) || typeof raw !== "string") {
    throw new Error("Missing configured GitHub source or pinned commit");
  }
  const url = new URL(raw);
  const parts = url.pathname.slice(1).split("/").map(decodeURIComponent);
  if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.port || url.username ||
    url.password || url.search || url.hash || parts[0]?.toLowerCase() !== options.owner.toLowerCase() ||
    parts[1] !== options.repo || !parts[2] || parts.length < 4 ||
    parts.some((part) => !part || part === "." || part === ".." || /[\\/]/.test(part) ||
      Array.from(part).some((character) => character.charCodeAt(0) < 32))) {
    throw new Error("Untrusted or unpinned GitHub asset URL");
  }
  const sourcePath = parts.slice(3).join("/");
  if (path !== undefined && path !== "" && path !== sourcePath) throw new Error("GitHub URL path mismatch");
  return {repo: options.repo, path: sourcePath, url: `https://raw.githubusercontent.com/${options.owner}/${options.repo}/${options.commit}/${
    sourcePath.split("/").map(encodeURIComponent).join("/")}`, recordedUrl: url.href, sha: "", commit: options.commit,
  gitSha: "", size: 0};
}

export function buildGithubInventory(walls: MigrationWall[], tree: GithubTree, options: MigrationOptions): GithubInventory {
  if (tree.truncated) throw new Error("GitHub returned a truncated recursive tree; inventory is incomplete");
  const entries = new Map(tree.entries.filter((entry) => entry.type === "blob").map((entry) => [entry.path, entry]));
  const references = new Set<string>();
  const wallRows: WallInventory[] = walls.map((wall) => {
    const row: WallInventory = {wall, wallId: typeof wall.data.id === "string" ? wall.data.id : "", status: "blocked",
      detail: ""};
    try {
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(row.wallId)) throw new Error("Invalid logical wall.id");
      const originalPath = wall.data.wallpaper_path;
      const thumbPath = wall.data.thumb_path;
      if (typeof originalPath !== "string" || originalPath.split("/").pop()?.startsWith("thumb_") ||
        typeof thumbPath !== "string" || !thumbPath.split("/").pop()?.startsWith("thumb_")) {
        throw new Error("Original and thumbnail paths must use explicit original and thumb_ roles");
      }
      row.original = assetForWall(wall, "wallpaper", options, entries);
      references.add(row.original.path);
      row.thumb = assetForWall(wall, "thumb", options, entries);
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

/** Bounded download. GitHub credentials are not sent to raw-content requests. */
export async function downloadGithubAsset(asset: GithubAsset): Promise<Buffer> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(asset.url, {redirect: "error", signal: controller.signal,
      headers: {"accept-encoding": "identity"}});
    if (!response.ok || !response.body) throw new Error(`Raw download failed: ${response.status}`);
    const declared = Number(response.headers.get("content-length"));
    if (declared > MAX_BYTES || declared !== asset.size) throw new Error("GitHub asset size differs from pinned tree");
    const reader = response.body.getReader();
    const chunks: Buffer[] = [];
    let length = 0;
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        length += next.value.byteLength;
        if (length > MAX_BYTES || length > asset.size) throw new Error("Image exceeds pinned size limit");
        chunks.push(Buffer.from(next.value));
      }
    } finally {
      await reader.cancel();
    }
    const bytes = Buffer.concat(chunks);
    if (bytes.length !== asset.size || gitBlobSha(bytes) !== asset.gitSha) throw new Error("Git blob SHA mismatch");
    const sharp = (await import("sharp")).default;
    const metadata = await sharp(bytes, {limitInputPixels: 100000000}).metadata();
    if (!metadata.format || !["jpeg", "png", "webp", "gif"].includes(metadata.format) ||
      !metadata.width || !metadata.height) throw new Error("Unsupported image format");
    return bytes;
  } finally {
    clearTimeout(timer);
  }
}

export async function verifyR2MigrationCopy(asset: StoredMigrationAsset, size: number | undefined,
  getObject: R2ObjectClient["get"], verifyMetadata: (asset: StoredMigrationAsset, size?: number) => Promise<void>): Promise<void> {
  await verifyMetadata(asset, size);
  const privateBytes = await getObject("private", asset.object);
  if ((size !== undefined && privateBytes.length !== size) || digest(privateBytes) !== asset.sha256) {
    throw new Error("R2 private readback mismatch");
  }
  if (asset.previewObjectId) {
    const previewBytes = await getObject("preview", `previews/${asset.previewObjectId}.img`);
    if ((size !== undefined && previewBytes.length !== size) || digest(previewBytes) !== asset.sha256) {
      throw new Error("R2 preview readback mismatch");
    }
  }
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
      if (await deps.ready(row.wall)) {
        result.status = "already-owned";
        result.detail = "R2 manifest is ready; public GitHub copies remain unchanged";
        continue;
      }
      if (row.status !== "planned" || !row.original || !row.thumb) throw new Error(row.detail || "Invalid inventory row");
      const proof = await deps.prove(row.original, row.thumb);
      const owner = proof.uid;
      const legacy = owner === null;
      if (legacy && (!proof.legacyEligible || !options.allowReviewedLegacy || row.wall.data.review !== true)) {
        throw new Error("Unproven or partial provenance: reviewed legacy policy requires explicit opt-in and no receipts");
      }
      result.detail = legacy ? "Reviewed legacy policy; no receipt or creator credit will be fabricated" :
        "Modern upload receipts and completed intents verified";
      if (!options.apply) {
        result.status = "would-migrate";
        continue;
      }
      result.status = "in-progress";
      await deps.progress?.([...results]);
      await deps.revalidate(row.wall, row.original, row.thumb);
      const [originalBytes, thumbBytes] = await Promise.all([deps.fetchBytes(row.original), deps.fetchBytes(row.thumb)]);
      await deps.revalidate(row.wall, row.original, row.thumb);
      const uid = owner ?? "legacy-migration";
      const [original, thumb] = await Promise.all([
        deps.retain({...row.original, sha: row.original.gitSha, uid, bytes: originalBytes}),
        deps.retain({...row.thumb, sha: row.thumb.gitSha, uid, bytes: thumbBytes}),
      ]);
      if (original.objectId === thumb.objectId || original.previewObjectId || !thumb.previewObjectId ||
        thumb.previewObjectId !== thumb.objectId) throw new Error("R2 retained objects are not separated by privacy role");
      await Promise.all([deps.verify(original, originalBytes.length), deps.verify(thumb, thumbBytes.length)]);
      if (legacy) {
        await deps.bindLegacy({wallId: row.wallId, canonicalPath: row.wall.docPath,
          incarnation: row.wall.incarnation, incarnationNanos: row.wall.incarnationNanos,
          originalUrl: row.original.recordedUrl, thumbUrl: row.thumb.recordedUrl, original, thumb});
      } else {
        await deps.attach(original);
        await deps.attach(thumb);
        await deps.bind(row.wallId);
      }
      if (!await deps.ready(row.wall)) throw new Error("R2 binding not ready; wall changed or proof no longer valid; rerun safely");
      result.status = "migrated";
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
  const asset = (value: GithubAsset) => ({path: value.path, gitSha: value.gitSha, size: value.size, commit: value.commit});
  return {owner: inventory.owner, repo: inventory.repo, commit: inventory.commit, generatedAt: inventory.generatedAt,
    wallCount: inventory.wallCount, imageCount: inventory.imageCount, totalImageBytes: inventory.totalImageBytes,
    referencedImageCount: inventory.referencedImageCount, orphanImageCount: inventory.orphanImageCount,
    orphanImages: inventory.orphanImages, treeHash: inventory.treeHash, assets: inventory.assets.map(asset), walls: inventory.walls.map((row) => ({
      docPath: row.wall.docPath, wallId: row.wallId, incarnation: row.wall.incarnation,
      incarnationNanos: row.wall.incarnationNanos,
      original: row.original && asset(row.original), thumb: row.thumb && asset(row.thumb), status: row.status, detail: row.detail,
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

export async function validateReviewedInventory(reviewed: unknown, inventory: GithubInventory, commit: string,
  allowReviewedLegacy: boolean,
  verifyMigrated?: (wall: MigrationWall, original: GithubAsset, thumb: GithubAsset) => Promise<boolean>): Promise<void> {
  if (!reviewed || typeof reviewed !== "object") throw new Error("Apply requires a reviewed dry-run inventory report");
  const report = reviewed as {mode?: unknown; inventory?: unknown; policy?: {allowReviewedLegacy?: unknown}};
  if (!(["dry-run", "apply"].includes(String(report.mode))) || !report.inventory || typeof report.inventory !== "object") {
    throw new Error("Apply requires a reviewed dry-run inventory report");
  }
  const envelope = reviewed as {reviewedInventory?: unknown};
  const snapshot = envelope.reviewedInventory ?? report.inventory;
  const previous = snapshot as {owner?: unknown; repo?: unknown; commit?: unknown};
  if (report.policy?.allowReviewedLegacy !== allowReviewedLegacy || previous.owner !== inventory.owner ||
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
  for (const row of current.walls) {
    if (typeof row.docPath !== "string") throw new Error("Reviewed inventory snapshot is invalid");
    const old = oldByPath.get(row.docPath) as Record<string, unknown> | undefined;
    if (!old) throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
    if (digest(JSON.stringify(canonical(old))) === digest(JSON.stringify(canonical(row)))) continue;
    const source = inventory.walls.find((candidate) => candidate.wall.docPath === row.docPath);
    const oldOriginal = old.original as {path?: string; gitSha?: string; size?: number; commit?: string} | undefined;
    const oldThumb = old.thumb as {path?: string; gitSha?: string; size?: number; commit?: string} | undefined;
    if (!verifyMigrated || !source || !oldOriginal || !oldThumb ||
      old.docPath !== source.wall.docPath || old.wallId !== source.wallId ||
      old.incarnation !== source.wall.incarnation || old.incarnationNanos !== source.wall.incarnationNanos ||
      !source.wall.data.originalProtected || source.wall.data.wallpaper_url !== "" ||
      typeof source.wall.data.originalObjectId !== "string" || source.wall.data.id !== old.wallId ||
      ![undefined, ""].includes(source.wall.data.wallpaper_path as string | undefined) ||
      ![undefined, ""].includes(source.wall.data.thumb_path as string | undefined) ||
      !assetByPath.has(oldOriginal.path) || !assetByPath.has(oldThumb.path) ||
      !await verifyMigrated(source.wall, reviewedAsset(oldOriginal, previous), reviewedAsset(oldThumb, previous))) {
      throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
    }
  }
  if (oldByPath.size !== current.walls.length) {
    throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
  }
  const currentReport = createInventoryReport(inventory) as Record<string, unknown>;
  const invariantKeys = ["owner", "repo", "commit", "imageCount", "totalImageBytes", "treeHash"];
  if (invariantKeys.some((key) => digest(JSON.stringify(canonical((snapshot as Record<string, unknown>)[key]))) !==
    digest(JSON.stringify(canonical(currentReport[key]))))) {
    throw new Error("GitHub or Firestore inventory changed since review; run dry-run again");
  }
}

function reviewedAsset(value: {path?: string; gitSha?: string; size?: number; commit?: string}, source: {
  owner?: unknown; repo?: unknown;
}): GithubAsset {
  if (typeof source.owner !== "string" || typeof source.repo !== "string" || typeof value.path !== "string" ||
    typeof value.gitSha !== "string" || typeof value.size !== "number" || typeof value.commit !== "string") {
    throw new Error("Reviewed inventory asset is invalid");
  }
  const encodedPath = value.path.split("/").map(encodeURIComponent).join("/");
  const url = `https://raw.githubusercontent.com/${source.owner}/${source.repo}/${value.commit}/${encodedPath}`;
  return {repo: source.repo, path: value.path, url, recordedUrl: url, sha: value.gitSha, gitSha: value.gitSha,
    size: value.size, commit: value.commit};
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
    if (["--apply", "--allow-reviewed-legacy", "--confirm-approved-migration"].includes(arg)) args.set(arg, true);
    else if (["--ref", "--report"].includes(arg) && values[index + 1]) args.set(arg, values[++index]);
    else throw new Error(`Unknown or incomplete option: ${arg}`);
  }
  const apply = args.has("--apply");
  if (apply && !args.has("--confirm-approved-migration")) {
    throw new Error("--apply requires explicit operator approval and --confirm-approved-migration");
  }
  const ref = args.get("--ref");
  const reportPath = args.get("--report");
  if (typeof ref !== "string" || typeof reportPath !== "string") throw new Error("Usage: --ref <branch-or-commit> --report <json-path> [--apply --confirm-approved-migration]");
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
    commit: resolved.commit};
  const inventory = buildGithubInventory(walls, resolved.tree, options);
  let reviewed: unknown;
  if (apply) {
    try {
      reviewed = JSON.parse(await readFile(reportPath, "utf8")) as unknown;
    } catch {
      throw new Error("Apply requires the existing private dry-run report at --report");
    }
    const verifier = async (wall: MigrationWall, original: GithubAsset, thumb: GithubAsset) => {
      const manifest = (await db.collection("ownedAssets").doc(String(wall.data.id)).get()).data();
      if (!manifest || manifest.status !== "ready" || !manifest.original || !manifest.thumb ||
        manifest.original.path !== original.path || manifest.original.sha !== original.gitSha ||
        manifest.thumb.path !== thumb.path || manifest.thumb.sha !== thumb.gitSha ||
        manifest.original.uid !== manifest.thumb.uid) return false;
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
      const current = await db.doc(wall.docPath).get();
      const data = current.data();
      if (!current.exists || !data || current.createTime?.toMillis() !== wall.incarnation ||
        current.createTime.nanoseconds !== wall.incarnationNanos || data.id !== wall.data.id ||
        data.originalProtected !== true || data.wallpaper_url !== "" || typeof data.originalObjectId !== "string") return false;
      const delivery = await import("../ownedAssetDelivery.js");
      const ready = manifest?.status === "ready" && manifest.canonicalPath === wall.docPath &&
        manifest.incarnation === wall.incarnation && manifest.incarnationNanos === wall.incarnationNanos &&
        manifest.original?.path === original.path && manifest.original?.sha === original.gitSha &&
        manifest.thumb?.path === thumb.path && manifest.thumb?.sha === thumb.gitSha &&
        data.originalObjectId === manifest.original?.objectId &&
        data.wallpaper_thumb === delivery.ownedThumbnailUrl(manifest.thumb);
      if (!ready) return false;
      const r2 = new (await import("../r2Storage.js")).R2Storage();
      const owned = await delivery.getOwnedWallDelivery(String(wall.data.id));
      await Promise.all([delivery.verifyStoredUpload(owned.original), delivery.verifyStoredUpload(owned.thumb)]);
      await Promise.all([
        verifyR2MigrationCopy(owned.original, undefined, (kind, object) => r2.get(kind, object), async () => undefined),
        verifyR2MigrationCopy(owned.thumb, undefined, (kind, object) => r2.get(kind, object), async () => undefined),
      ]);
      return true;
    };
    await validateReviewedInventory(reviewed, inventory, resolved.commit, options.allowReviewedLegacy, verifier);
  }
  const reviewedSnapshot = apply && reviewed && typeof reviewed === "object" &&
    "reviewedInventory" in reviewed ? (reviewed as {reviewedInventory: unknown}).reviewedInventory :
    apply && reviewed && typeof reviewed === "object" && "inventory" in reviewed ?
      (reviewed as {inventory: unknown}).inventory : createInventoryReport(inventory);
  const report = {mode: apply ? "apply" : "dry-run", policy: {allowReviewedLegacy: options.allowReviewedLegacy},
    reviewedInventory: reviewedSnapshot, inventory: createInventoryReport(inventory), results: [] as MigrationResult[],
    warning: "GitHub assets remain public and unchanged. Removal requires a separate approved operation."};
  await writeInventoryReport(reportPath, report);
  const [delivery, dbModule] = await Promise.all([import("../ownedAssetDelivery.js"), import("../common.js")]);
  const r2 = apply ? new (await import("../r2Storage.js")).R2Storage() : null;
  const results = await migrateGithubInventory(inventory, options, {
    prove: async (original, thumb) => {
      const first = await proveMigrationAsset(original, dbModule.db);
      const second = await proveMigrationAsset(thumb, dbModule.db);
      if (first.uid && first.uid === second.uid) return {uid: first.uid, legacyEligible: false};
      return {uid: null, legacyEligible: first.legacyEligible && second.legacyEligible};
    },
    fetchBytes: downloadGithubAsset,
    retain: delivery.retainUpload,
    verify: async (asset, size) => {
      if (!r2) throw new Error("R2 storage is not configured");
      return verifyR2MigrationCopy(asset, size, (kind, object) => r2.get(kind, object), delivery.verifyStoredUpload);
    },
    revalidate: async (wall, original, thumb) => {
      const current = await dbModule.db.doc(wall.docPath).get();
      const data = current.data();
      if (!current.exists || !data || current.createTime?.toMillis() !== wall.incarnation ||
        current.createTime.nanoseconds !== wall.incarnationNanos || data?.id !== wall.data.id ||
        data.wallpaper_url !== wall.data.wallpaper_url || data.wallpaper_thumb !== wall.data.wallpaper_thumb ||
        data.wallpaper_path !== wall.data.wallpaper_path || data.thumb_path !== wall.data.thumb_path ||
        (data.wallpaper_sha !== undefined && data.wallpaper_sha !== "" && data.wallpaper_sha !== original.gitSha) ||
        (data.thumb_sha !== undefined && data.thumb_sha !== "" && data.thumb_sha !== thumb.gitSha)) {
        throw new Error("Wall changed since inventory; rerun the pinned inventory");
      }
    },
    attach: async (asset) => {
      const ref = dbModule.db.collection("githubUploads").doc(`file_${digest(`${asset.repo}\0${asset.path}\0${asset.sha}`)}`);
      await dbModule.db.runTransaction(async (tx) => {
        const receipt = (await tx.get(ref)).data();
        if (!receipt || receipt.uid !== asset.uid || receipt.repo !== asset.repo || receipt.path !== asset.path ||
          receipt.sha !== asset.sha) throw new Error("Receipt changed during migration");
        tx.update(ref, {retainedAsset: asset});
      });
    },
    bind: delivery.bindOwnedWall,
    bindLegacy: delivery.bindLegacyOwnedWall,
    ready: async (wall) => {
      const manifest = (await dbModule.db.collection("ownedAssets").doc(String(wall.data.id)).get()).data();
      const current = await dbModule.db.doc(wall.docPath).get();
      const data = current.data();
      const ready = manifest?.status === "ready" && manifest.canonicalPath === wall.docPath &&
        manifest.incarnation === wall.incarnation && manifest.incarnationNanos === wall.incarnationNanos &&
        current.createTime?.toMillis() === wall.incarnation && current.createTime.nanoseconds === wall.incarnationNanos &&
        data?.originalProtected === true && data.wallpaper_url === "" &&
        data.originalObjectId === manifest.original?.objectId && data.wallpaper_thumb === delivery.ownedThumbnailUrl(manifest.thumb);
      if (!ready || !apply) return ready;
      const owned = await delivery.getOwnedWallDelivery(String(wall.data.id));
      if (!r2) throw new Error("R2 storage is not configured");
      await Promise.all([delivery.verifyStoredUpload(owned.original), delivery.verifyStoredUpload(owned.thumb)]);
      await Promise.all([
        verifyR2MigrationCopy(owned.original, undefined, (kind, object) => r2.get(kind, object), async () => undefined),
        verifyR2MigrationCopy(owned.thumb, undefined, (kind, object) => r2.get(kind, object), async () => undefined),
      ]);
      return true;
    },
    progress: async (partial) => {
      report.results = partial; await writeInventoryReport(reportPath, report);
    },
  });
  report.results = results;
  await writeInventoryReport(reportPath, report);
  process.stdout.write(`${JSON.stringify({mode: report.mode, commit: inventory.commit, wallCount: inventory.wallCount,
    imageCount: inventory.imageCount, totalImageBytes: inventory.totalImageBytes,
    referencedImageCount: inventory.referencedImageCount, orphanImageCount: inventory.orphanImageCount, results,
    report: reportPath, warning: report.warning}, null, 2)}\n`);
  if (results.some((row) => row.status === "blocked")) process.exitCode = 2;
}

export async function proveMigrationAsset(asset: GithubAsset, db?: FirebaseFirestore.Firestore): Promise<OwnershipProof> {
  if (!asset.gitSha) return {uid: null, legacyEligible: false};
  const firestore = db ?? (await import("../common.js")).db;
  const query = firestore.collection("githubUploads").where("path", "==", asset.path).orderBy("__name__").limit(8);
  const matching: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  let rows = await query.get();
  while (true) {
    matching.push(...rows.docs.filter((row) => row.data().repo === asset.repo && row.data().sourceKind !== "owned"));
    if (matching.length >= 8) return {uid: null, legacyEligible: false};
    if (rows.size < 8) break;
    rows = await query.startAfter(rows.docs[rows.docs.length - 1]).get();
  }
  const receipt = matching.find((row) => row.id === `file_${digest(`${asset.repo}\0${asset.path}\0${asset.gitSha}`)}`)?.data();
  const intent = (await firestore.collection("githubUploadIntents")
    .doc(`path_${digest(`${asset.repo}\0${asset.path}`)}`).get()).data();
  if (!receipt && matching.length === 0 && !intent) return {uid: null, legacyEligible: true};
  if (!receipt || typeof receipt.uid !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(receipt.uid) ||
    receipt.repo !== asset.repo || receipt.path !== asset.path || receipt.sha !== asset.gitSha ||
    matching.some((row) => row.data().uid !== receipt.uid) || intent?.sourceKind === "owned" ||
    intent?.status !== "complete" || intent.uid !== receipt.uid || intent.repo !== asset.repo ||
    intent.path !== asset.path || intent.blobSha !== asset.gitSha || intent.response?.content?.sha !== asset.gitSha ||
    intent.response?.content?.path !== asset.path || intent.response?.content?.download_url !== asset.recordedUrl) {
    return {uid: null, legacyEligible: false};
  }
  return {uid: receipt.uid, legacyEligible: false};
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : "Migration failed"}\n`);
    process.exitCode = 1;
  });
}
