import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {db} from "./common";
import * as delivery from "./ownedAssetDelivery";
import type {StoredUpload, StudioBinding, WallBindingExpectation} from "./ownedAssetDelivery";
import {R2Storage} from "./r2Storage";
import {STUDIO_ACCOUNT} from "./studio/account";
import {parseStudioSource, verifiedStudioSource} from "./studio/assetSource";

/**
 * The per-wall converter shared by the bulk migration script and the `onOwnedWallWritten` trigger.
 * It moves one approved wall from public GitHub or worker URLs to the private R2 original and a public R2 preview.
 */
const MAX_BYTES = 15 * 1024 * 1024;
const IMAGE_PATH = /\.(?:jpe?g|png|webp|gif)$/i;
const NO_COMMIT = "0".repeat(40);
const digest = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");

/** A failure a retry cannot fix (bad URL, unproven owner, changed bytes). Every other error is treated as transient. */
export class PermanentConversionError extends Error {}

export type MigrationOptions = {apply: boolean; allowReviewedLegacy: boolean; owner: string; repo: string; commit: string};
export type MigrationWall = {docPath: string; incarnation: number; incarnationNanos: number; data: Record<string, unknown>};
export type GithubAsset = {repo: string; path: string; url: string; recordedUrl: string; sha: string; gitSha: string;
  size: number; commit: string; expectedResolution?: string};
export type StoredMigrationAsset = StoredUpload;
export type WallInventory = {wall: MigrationWall; wallId: string; original?: GithubAsset; thumb?: GithubAsset;
  status: "planned" | "blocked"; detail: string; studio?: StudioBinding};
export type MigrationResult = {docPath: string; wallId: string; status: "would-migrate" | "in-progress" | "migrated" | "already-owned" | "blocked";
  detail: string; publicGithubCopiesRemain: true};
export type LegacyBinding = {wallId: string; canonicalPath: string; incarnation: number; incarnationNanos: number;
  originalUrl: string; thumbUrl: string; original: StoredMigrationAsset; thumb: StoredMigrationAsset; source?: StudioBinding;
  expected?: WallBindingExpectation};
export type OwnershipProof = {uid: string | null; legacyEligible: boolean; studio?: StudioBinding};
export type MigrationDeps = {
  prove: (original: GithubAsset, thumb: GithubAsset, row: WallInventory) => Promise<OwnershipProof>;
  fetchBytes: (asset: GithubAsset) => Promise<Buffer>;
  retain: (asset: GithubAsset & {uid: string; bytes: Buffer; sourceKind?: "studio"; uploadId?: string}) => Promise<StoredMigrationAsset>;
  verify: (asset: StoredMigrationAsset, size: number) => Promise<void>;
  revalidate: (wall: MigrationWall, original: GithubAsset, thumb: GithubAsset) => Promise<void>;
  attach: (asset: StoredMigrationAsset) => Promise<void>;
  bind: (wallId: string, expected?: WallBindingExpectation) => Promise<void>;
  bindLegacy: (input: LegacyBinding) => Promise<void>;
  ready: (wall: MigrationWall, original?: GithubAsset, thumb?: GithubAsset) => Promise<boolean>;
  progress?: (results: MigrationResult[]) => Promise<void>;
};
export type R2ObjectClient = {get: (kind: "private" | "preview", object: string) => Promise<Buffer>};

export function isLegacyMigrationUid(uid: unknown): boolean {
  return uid === "legacy-migration";
}

export const gitBlobSha = (bytes: Buffer): string => createHash("sha1")
  .update(`blob ${bytes.length}\0`).update(bytes).digest("hex");

/** Only a raw URL in the configured public repository is accepted; the URL is re-pinned to `options.commit`. */
export function parseGithubAsset(raw: unknown, path: unknown, options: MigrationOptions): GithubAsset {
  if (!options.owner || !options.repo || !/^[a-f0-9]{40}$/.test(options.commit) || typeof raw !== "string") {
    throw new PermanentConversionError("Missing configured GitHub source or pinned commit");
  }
  let url: URL;
  let parts: string[];
  try {
    url = new URL(raw);
    parts = url.pathname.slice(1).split("/").map(decodeURIComponent);
  } catch {
    throw new PermanentConversionError("Malformed GitHub asset URL");
  }
  if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.port || url.username ||
    url.password || url.search || url.hash || parts[0]?.toLowerCase() !== options.owner.toLowerCase() ||
    parts[1] !== options.repo || !parts[2] || parts.length < 4 ||
    parts.some((part) => !part || part === "." || part === ".." || /[\\/]/.test(part) ||
      Array.from(part).some((character) => character.charCodeAt(0) < 32))) {
    throw new PermanentConversionError("Untrusted or unpinned GitHub asset URL");
  }
  const sourcePath = parts.slice(3).join("/");
  if (path !== undefined && path !== "" && path !== sourcePath) throw new PermanentConversionError("GitHub URL path mismatch");
  return {repo: options.repo, path: sourcePath, url: `https://raw.githubusercontent.com/${options.owner}/${options.repo}/${options.commit}/${
    sourcePath.split("/").map(encodeURIComponent).join("/")}`, recordedUrl: raw, sha: "", commit: options.commit,
  gitSha: "", size: 0};
}

/**
 * Bounded download. GitHub credentials are not sent to raw-content requests. With `pin`, the declared and actual size and
 * the Git blob SHA must match the pinned tree entry. With `resolution`, the decoded image must have that size.
 */
async function downloadImage(url: string, pin?: {size: number; gitSha: string}, resolution?: string): Promise<Buffer> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, {redirect: "manual", signal: controller.signal,
      headers: {"accept-encoding": "identity"}});
    if (!response.ok || !response.body) {
      const error = `Raw download failed: ${response.status}`;
      // Request timeouts, rate limits and server failures can recover on retry.
      throw response.status >= 300 && response.status < 500 && ![408, 429].includes(response.status) ?
        new PermanentConversionError(error) : new Error(error);
    }
    const declared = Number(response.headers.get("content-length"));
    if (declared > MAX_BYTES || (pin && declared !== pin.size)) {
      throw new PermanentConversionError(pin ? "GitHub asset size differs from pinned tree" : "Image is too large");
    }
    const reader = response.body.getReader();
    const chunks: Buffer[] = [];
    let length = 0;
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        length += next.value.byteLength;
        if (length > MAX_BYTES || (pin && length > pin.size)) {
          throw new PermanentConversionError(pin ? "Image exceeds pinned size limit" : "Image is too large");
        }
        chunks.push(Buffer.from(next.value));
      }
    } finally {
      await reader.cancel();
    }
    const bytes = Buffer.concat(chunks);
    if (pin && (bytes.length !== pin.size || gitBlobSha(bytes) !== pin.gitSha)) throw new PermanentConversionError("Git blob SHA mismatch");
    const sharp = (await import("sharp")).default;
    let metadata: import("sharp").Metadata;
    try {
      metadata = await sharp(bytes, {limitInputPixels: 100000000}).metadata();
    } catch {
      throw new PermanentConversionError("Image cannot be decoded");
    }
    if (!metadata.format || !["jpeg", "png", "webp", "gif"].includes(metadata.format) ||
      !metadata.width || !metadata.height) throw new PermanentConversionError("Unsupported image format");
    if (resolution && `${metadata.width}x${metadata.height}` !== resolution) {
      throw new PermanentConversionError("Image resolution differs from the wall record");
    }
    return bytes;
  } finally {
    clearTimeout(timer);
  }
}

export const downloadGithubAsset = (asset: GithubAsset): Promise<Buffer> =>
  downloadImage(asset.url, {size: asset.size, gitSha: asset.gitSha});

/** Studio assets are keyed by their candidate id and have no Git blob to pin; the bytes are hashed after the download. */
export const downloadStudioAsset = (asset: GithubAsset): Promise<Buffer> =>
  downloadImage(asset.url, undefined, asset.expectedResolution);

export async function verifyR2MigrationCopy(asset: StoredMigrationAsset, size: number | undefined,
  getObject: R2ObjectClient["get"], verifyMetadata: (asset: StoredMigrationAsset, size?: number) => Promise<void>): Promise<void> {
  await verifyMetadata(asset, size);
  const privateBytes = await getObject("private", asset.object);
  if ((size !== undefined && privateBytes.length !== size) || digest(privateBytes) !== asset.sha256) {
    throw new PermanentConversionError("R2 private readback mismatch");
  }
  if (asset.previewObjectId) {
    const previewBytes = await getObject("preview", `previews/${asset.previewObjectId}.img`);
    if ((size !== undefined && previewBytes.length !== size) || digest(previewBytes) !== asset.sha256) {
      throw new PermanentConversionError("R2 preview readback mismatch");
    }
  }
}

export async function proveMigrationAsset(asset: GithubAsset, firestore: FirebaseFirestore.Firestore = db): Promise<OwnershipProof> {
  if (!asset.gitSha) return {uid: null, legacyEligible: false};
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

/** A Studio wall row from its exact URL pair. The candidate backlink is proven later, in `deps.prove`. */
export function buildStudioRow(wall: MigrationWall): WallInventory | null {
  const source = parseStudioSource(wall.data);
  if (!source) return null;
  const wallId = typeof wall.data.id === "string" ? wall.data.id : "";
  const row: WallInventory = {wall, wallId, status: "blocked", detail: "",
    studio: {kind: "studio", runId: source.runId, candidateId: source.candidateId}};
  const resolution = wall.data.resolution;
  if (!/^[A-Za-z0-9_-]{1,200}$/.test(wallId)) row.detail = "Invalid logical wall.id";
  else if (typeof resolution !== "string" || !/^[1-9]\d{1,4}x[1-9]\d{1,4}$/.test(resolution)) row.detail = "Studio wall has no valid resolution";
  else {
    const asset = (path: string, url: string, expectedResolution?: string): GithubAsset => ({repo: delivery.STUDIO_STORAGE_REPO, path, url,
      recordedUrl: url, sha: "", gitSha: "", size: 0, commit: "", ...(expectedResolution ? {expectedResolution} : {})});
    row.original = asset(source.wallKey, source.wallUrl, resolution);
    row.thumb = asset(source.thumbKey, source.thumbUrl);
    row.status = "planned";
    row.detail = "Prism Studio worker assets; the worker copies remain unchanged";
  }
  return row;
}

/** Converts one planned row. Throws on failure; a `PermanentConversionError` means a retry cannot succeed. */
export async function convertWall(row: WallInventory, options: MigrationOptions, deps: MigrationDeps,
  result: MigrationResult, progress: () => Promise<void> = async () => undefined): Promise<void> {
  let expectedOriginal = row.original;
  let expectedThumb = row.thumb;
  const ready = () => deps.ready(row.wall, expectedOriginal, expectedThumb);
  if (await ready()) {
    result.status = "already-owned";
    result.detail = "R2 manifest is ready; public GitHub copies remain unchanged";
    return;
  }
  if (row.status !== "planned" || !row.original || !row.thumb) throw new PermanentConversionError(row.detail || "Invalid inventory row");
  if (row.wall.data.review !== true) throw new PermanentConversionError("Wall is not approved yet; approval converts it");
  if (row.wall.data.dropReserved === true) throw new PermanentConversionError("Wall is reserved for an unreleased Drop");
  const revalidate = async (original: GithubAsset, thumb: GithubAsset): Promise<boolean> => {
    try {
      await deps.revalidate(row.wall, original, thumb);
      return true;
    } catch (error) {
      if (!await ready()) throw error;
      result.status = "already-owned";
      return false;
    }
  };
  const proof = await deps.prove(row.original, row.thumb, row);
  const owner = proof.uid;
  const studio = proof.studio;
  const legacy = owner === null;
  if (legacy && (!proof.legacyEligible || !options.allowReviewedLegacy || row.wall.data.review !== true)) {
    throw new PermanentConversionError("Unproven or partial provenance: reviewed legacy policy requires explicit opt-in and no receipts");
  }
  result.detail = studio ? "Prism Studio provenance; no receipt or creator credit will be fabricated" : legacy ?
    "Reviewed legacy policy; no receipt or creator credit will be fabricated" :
    "Modern upload receipts and completed intents verified";
  if (!options.apply) {
    result.status = "would-migrate";
    return;
  }
  result.status = "in-progress";
  await progress();
  if (!await revalidate(row.original, row.thumb)) return;
  const [originalBytes, thumbBytes] = await Promise.all([deps.fetchBytes(row.original), deps.fetchBytes(row.thumb)]);
  expectedOriginal = {...row.original, gitSha: row.original.gitSha || gitBlobSha(originalBytes)};
  expectedThumb = {...row.thumb, gitSha: row.thumb.gitSha || gitBlobSha(thumbBytes)};
  if (!await revalidate(row.original, row.thumb)) return;
  const uid = studio ? STUDIO_ACCOUNT.id : owner ?? "legacy-migration";
  const extra = studio ? {sourceKind: "studio" as const, uploadId: studio.candidateId} : {};
  const [original, thumb] = await Promise.all([
    deps.retain({...row.original, ...extra, sha: row.original.gitSha || gitBlobSha(originalBytes), uid, bytes: originalBytes}),
    deps.retain({...row.thumb, ...extra, sha: row.thumb.gitSha || gitBlobSha(thumbBytes), uid, bytes: thumbBytes}),
  ]);
  if (original.objectId === thumb.objectId || original.previewObjectId || !thumb.previewObjectId ||
    thumb.previewObjectId !== thumb.objectId) throw new PermanentConversionError("R2 retained objects are not separated by privacy role");
  await Promise.all([deps.verify(original, originalBytes.length), deps.verify(thumb, thumbBytes.length)]);
  const expected: WallBindingExpectation = {canonicalPath: row.wall.docPath, incarnation: row.wall.incarnation,
    incarnationNanos: row.wall.incarnationNanos, originalUrl: row.original.recordedUrl, thumbUrl: row.thumb.recordedUrl,
    originalPath: row.original.path, thumbPath: row.thumb.path, originalSha: row.original.gitSha, thumbSha: row.thumb.gitSha,
    recordedSource: {originalPath: row.wall.data.wallpaper_path, thumbPath: row.wall.data.thumb_path,
      originalSha: row.wall.data.wallpaper_sha, thumbSha: row.wall.data.thumb_sha},
    ...(studio ? {studio: {runId: studio.runId, candidateId: studio.candidateId,
      resolution: String(row.wall.data.resolution)}} : {})};
  try {
    if (studio || legacy) {
      await deps.bindLegacy({wallId: row.wallId, canonicalPath: row.wall.docPath,
        incarnation: row.wall.incarnation, incarnationNanos: row.wall.incarnationNanos,
        originalUrl: row.original.recordedUrl, thumbUrl: row.thumb.recordedUrl, original, thumb,
        ...(studio ? {source: studio} : {}), expected});
    } else {
      await deps.attach(original);
      await deps.attach(thumb);
      await deps.bind(row.wallId, expected);
    }
  } catch (error) {
    // Another delivery of the same trigger, or the bulk script, may have bound the wall first. That is success.
    if (!await ready()) throw error;
  }
  if (!await ready()) {
    throw new PermanentConversionError("R2 binding not ready; wall changed or proof no longer valid; rerun safely");
  }
  result.status = "migrated";
}

/** The Firestore and R2 backed dependencies of `convertWall`. `apply` also checks the R2 copies when it reads a wall as ready. */
export function conversionDeps(apply: boolean, r2: R2Storage | null, firestore: FirebaseFirestore.Firestore = db): MigrationDeps {
  const readback = (asset: StoredMigrationAsset, size: number | undefined, verifyMetadata: Parameters<typeof verifyR2MigrationCopy>[3]) => {
    if (!r2) throw new Error("R2 storage is not configured");
    return verifyR2MigrationCopy(asset, size, (kind, object) => r2.get(kind, object), verifyMetadata);
  };
  return {
    prove: async (original, thumb, row) => {
      if (row.studio) {
        const source = await verifiedStudioSource(row.wallId, row.wall.data);
        if (!source || source.runId !== row.studio.runId || source.candidateId !== row.studio.candidateId) {
          throw new PermanentConversionError("Studio wall is not backed by its candidate");
        }
        return {uid: STUDIO_ACCOUNT.id, legacyEligible: false, studio: row.studio};
      }
      const first = await proveMigrationAsset(original, firestore);
      const second = await proveMigrationAsset(thumb, firestore);
      if (first.uid && first.uid === second.uid) return {uid: first.uid, legacyEligible: false};
      return {uid: null, legacyEligible: first.legacyEligible && second.legacyEligible};
    },
    fetchBytes: (asset) => asset.repo === delivery.STUDIO_STORAGE_REPO ? downloadStudioAsset(asset) : downloadGithubAsset(asset),
    retain: delivery.retainUpload,
    verify: (asset, size) => readback(asset, size, delivery.verifyStoredUpload),
    revalidate: async (wall, original, thumb) => {
      const current = await firestore.doc(wall.docPath).get();
      const data = current.data();
      if (!current.exists || !data || current.createTime?.toMillis() !== wall.incarnation ||
        current.createTime.nanoseconds !== wall.incarnationNanos || data?.id !== wall.data.id ||
        data.wallpaper_url !== wall.data.wallpaper_url || data.wallpaper_thumb !== wall.data.wallpaper_thumb ||
        data.wallpaper_path !== wall.data.wallpaper_path || data.thumb_path !== wall.data.thumb_path ||
        ["review", "origin", "email", "resolution", "studioRunId", "studioCandidateId", "dropWeek", "dropReserved"]
          .some((field) => data[field] !== wall.data[field]) ||
        (data.wallpaper_sha !== undefined && data.wallpaper_sha !== "" && data.wallpaper_sha !== original.gitSha) ||
        (data.thumb_sha !== undefined && data.thumb_sha !== "" && data.thumb_sha !== thumb.gitSha)) {
        throw new PermanentConversionError("Wall changed since inventory; rerun the pinned inventory");
      }
      if (data.review !== true || !await delivery.dropAllowsBinding(data, undefined, firestore)) {
        throw new PermanentConversionError("Wall is not approved or belongs to an unreleased Drop");
      }
    },
    attach: async (asset) => {
      const ref = firestore.collection("githubUploads").doc(`file_${digest(`${asset.repo}\0${asset.path}\0${asset.sha}`)}`);
      await firestore.runTransaction(async (tx) => {
        const receipt = (await tx.get(ref)).data();
        if (!receipt || receipt.uid !== asset.uid || receipt.repo !== asset.repo || receipt.path !== asset.path ||
          receipt.sha !== asset.sha) throw new PermanentConversionError("Receipt changed during migration");
        tx.update(ref, {retainedAsset: asset});
      });
    },
    bind: delivery.bindOwnedWall,
    bindLegacy: delivery.bindLegacyOwnedWall,
    ready: async (wall, original, thumb) => {
      const manifest = (await firestore.collection("ownedAssets").doc(String(wall.data.id)).get()).data();
      const current = await firestore.doc(wall.docPath).get();
      const data = current.data();
      const ready = manifest?.status === "ready" && manifest.canonicalPath === wall.docPath &&
        manifest.incarnation === wall.incarnation && manifest.incarnationNanos === wall.incarnationNanos &&
        current.createTime?.toMillis() === wall.incarnation && current.createTime.nanoseconds === wall.incarnationNanos &&
        data?.originalProtected === true && data.wallpaper_url === "" &&
        data.originalObjectId === manifest.original?.objectId && data.wallpaper_thumb === delivery.ownedThumbnailUrl(manifest.thumb);
      if (!ready) return false;
      if ((original || thumb) && (!original || !thumb)) return false;
      if (original && thumb) {
        const matches = (actual: StoredUpload, source: GithubAsset, url: unknown) =>
          actual?.repo === source.repo && actual.path === source.path && url === source.recordedUrl &&
          (!source.gitSha || actual.sha === source.gitSha);
        if (wall.data.review !== true || data.review !== true || !matches(manifest.original, original, manifest.originalUrl) ||
          !matches(manifest.thumb, thumb, manifest.thumbUrl)) return false;
        if (original.repo === delivery.STUDIO_STORAGE_REPO) {
          const studio = parseStudioSource(wall.data);
          if (!studio || manifest.provenance?.kind !== "studio" || manifest.provenance.runId !== studio.runId ||
            manifest.provenance.candidateId !== studio.candidateId ||
            ["origin", "email", "studioRunId", "studioCandidateId", "resolution"]
              .some((field) => data[field] !== wall.data[field])) return false;
        }
      }
      if (!apply) return true;
      const owned = await delivery.getOwnedWallDelivery(String(wall.data.id));
      await Promise.all([delivery.verifyStoredUpload(owned.original), delivery.verifyStoredUpload(owned.thumb)]);
      await Promise.all([readback(owned.original, undefined, async () => undefined),
        readback(owned.thumb, undefined, async () => undefined)]);
      return true;
    },
  };
}

/** A GitHub row for a wall that is not in a pinned tree: the current files are downloaded and hashed. */
async function githubTriggerRow(wall: MigrationWall, owner: string, repo: string): Promise<{row: WallInventory; bytes: Map<string, Buffer>}> {
  const options: MigrationOptions = {apply: true, allowReviewedLegacy: true, owner, repo, commit: NO_COMMIT};
  const wallId = String(wall.data.id);
  const source = (raw: unknown, path: unknown): GithubAsset => {
    const parsed = parseGithubAsset(raw, path, options);
    if (!IMAGE_PATH.test(parsed.path)) throw new PermanentConversionError(`Unsupported wallpaper image path: ${parsed.path}`);
    // The pinned-commit URL is for the bulk script; a live wall is read at the URL it recorded.
    return {...parsed, url: parsed.recordedUrl, commit: ""};
  };
  const original = source(wall.data.wallpaper_url, wall.data.wallpaper_path);
  const thumb = source(wall.data.wallpaper_thumb, wall.data.thumb_path);
  if (original.path.split("/").pop()?.startsWith("thumb_") || !thumb.path.split("/").pop()?.startsWith("thumb_") ||
    original.path === thumb.path) throw new PermanentConversionError("Original and thumbnail paths must use explicit original and thumb_ roles");
  const bytes = new Map<string, Buffer>();
  for (const [asset, docSha] of [[original, wall.data.wallpaper_sha], [thumb, wall.data.thumb_sha]] as const) {
    const data = await downloadImage(asset.url);
    asset.gitSha = asset.sha = gitBlobSha(data);
    asset.size = data.length;
    if (docSha !== undefined && docSha !== "" && docSha !== asset.gitSha) {
      throw new PermanentConversionError(`Wall Git SHA differs from the current file: ${asset.path}`);
    }
    bytes.set(asset.path, data);
  }
  return {row: {wall, wallId, original, thumb, status: "planned", detail: "Current GitHub files read at approval"}, bytes};
}

/**
 * Converts an approved wall that is still public. Called from `onOwnedWallWritten`, so it covers admin approvals, 3.7.0
 * uploads, Studio walls and released Drop walls. A protected or unapproved wall returns at once, so the redacting
 * write does not loop. A transient failure throws and the trigger retries; a permanent failure is logged and the wall
 * stays hidden from 3.8.0 clients until a later write retries it.
 */
export async function convertApprovedWall(wallId: string): Promise<"converted" | "skipped" | "blocked"> {
  if (!delivery.ownedAssetStorageEnabled()) return "skipped";
  const rows = await db.collection("walls").where("id", "==", wallId).limit(2).get();
  const snap = rows.docs[0];
  const data = snap?.data();
  if (rows.size !== 1 || !snap.createTime || !data || data.review !== true || data.originalProtected === true ||
    data.wallpaper_url === "" || data.wallpaper_url === undefined) {
    if (rows.size > 1) logger.error("owned wall conversion: duplicate logical wall id", {wallId});
    return "skipped";
  }
  if (!await delivery.dropAllowsBinding(data)) return "skipped";
  const wall: MigrationWall = {docPath: snap.ref.path, incarnation: snap.createTime.toMillis(),
    incarnationNanos: snap.createTime.nanoseconds, data};
  const result: MigrationResult = {docPath: wall.docPath, wallId, status: "blocked", detail: "", publicGithubCopiesRemain: true};
  const deps = conversionDeps(true, new R2Storage());
  try {
    const studio = buildStudioRow(wall);
    let row: WallInventory;
    if (studio) {
      row = studio;
    } else {
      const owner = process.env.GH_USERNAME ?? "";
      const repo = process.env.GH_REPO_WALLS ?? "";
      if (!owner || !repo) throw new PermanentConversionError("GH_USERNAME and GH_REPO_WALLS must name the configured public repository");
      const prefetched = await githubTriggerRow(wall, owner, repo);
      row = prefetched.row;
      deps.fetchBytes = async (asset) => {
        const bytes = prefetched.bytes.get(asset.path);
        if (!bytes) throw new PermanentConversionError("Unexpected asset");
        return bytes;
      };
    }
    await convertWall(row, {apply: true, allowReviewedLegacy: true, owner: process.env.GH_USERNAME ?? "",
      repo: process.env.GH_REPO_WALLS ?? "", commit: NO_COMMIT}, deps, result);
    logger.info("owned wall conversion", {wallId, status: result.status});
    return "converted";
  } catch (error) {
    if (!(error instanceof PermanentConversionError) && !(error instanceof delivery.PermanentOwnedAssetError)) throw error;
    logger.error("owned wall conversion blocked", {wallId, reason: error.message});
    return "blocked";
  }
}
