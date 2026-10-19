import {createHash} from "node:crypto";
import type {StoredUpload} from "../ownedAssetDelivery";

type Asset = {repo: string; path: string; url: string; sha?: string};
export type MigrationWall = {docPath: string; incarnation: number; incarnationNanos: number; data: Record<string, unknown>};
export type MigrationOptions = {apply: boolean; allowReviewedLegacy: boolean; owner: string; repo: string};
export type MigrationResult = {docPath: string; wallId: string; status: string; detail: string;
  publicOriginalRemains: boolean};
export type LegacyBinding = {wallId: string; canonicalPath: string; incarnation: number; incarnationNanos: number;
  originalUrl: string; thumbUrl: string; original: StoredUpload; thumb: StoredUpload};
export type MigrationDeps = {
  prove: (original: Asset, thumb: Asset) => Promise<string | null>;
  fetchBytes: (asset: Asset) => Promise<Buffer>;
  retain: (asset: Asset & {sha: string; uid: string; bytes: Buffer}) => Promise<StoredUpload>;
  attach: (asset: StoredUpload) => Promise<void>;
  bind: (wallId: string) => Promise<void>;
  bindLegacy: (input: LegacyBinding) => Promise<void>;
  ready: (wall: MigrationWall) => Promise<boolean>;
};
const digest = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");
export const gitBlobSha = (bytes: Buffer): string => createHash("sha1")
  .update(`blob ${bytes.length}\0`).update(bytes).digest("hex");

/** Only the configured GitHub raw repository, with one explicit ref and safe path segments. */
export function parseRawAsset(raw: unknown, path: unknown, sha: unknown, options: MigrationOptions): Asset {
  if (!options.owner || !options.repo || typeof raw !== "string") throw new Error("Missing configured raw source");
  const url = new URL(raw);
  const parts = url.pathname.slice(1).split("/").map(decodeURIComponent);
  if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.port || url.username ||
    url.password || url.search || url.hash || parts[0]?.toLowerCase() !== options.owner.toLowerCase() ||
    parts[1] !== options.repo || parts.length < 4 || parts.some((part) => !part || part === "." || part === ".." ||
      /[\\/\x00-\x1f]/.test(part))) throw new Error("Untrusted raw asset URL");
  const sourcePath = parts.slice(3).join("/");
  if (path !== undefined && path !== "" && path !== sourcePath) throw new Error("Raw URL path mismatch");
  if (sha !== undefined && sha !== "" && (typeof sha !== "string" || !/^[a-f0-9]{40}$/.test(sha))) {
    throw new Error("Invalid source Git blob SHA");
  }
  return {repo: options.repo, path: sourcePath, url: url.href,
    ...(typeof sha === "string" && sha ? {sha} : {})};
}

const MAX_BYTES = 32 * 1024 * 1024;
/** No redirects, bounded body and deadline. Never attach GitHub credentials to raw downloads. */
export async function downloadRawAsset(asset: Asset): Promise<Buffer> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(asset.url, {redirect: "error", signal: controller.signal});
    if (!response.ok || !response.body) throw new Error(`Raw download failed: ${response.status}`);
    if (Number(response.headers.get("content-length")) > MAX_BYTES) throw new Error("Image exceeds size limit");
    const reader = response.body.getReader();
    const chunks: Buffer[] = [];
    let length = 0;
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        length += next.value.byteLength;
        if (length > MAX_BYTES) throw new Error("Image exceeds size limit");
        chunks.push(Buffer.from(next.value));
      }
    } finally {
      await reader.cancel();
    }
    const bytes = Buffer.concat(chunks);
    // Decode headers, not the full untrusted bitmap. Preserve existing supported image formats.
    const sharp = (await import("sharp")).default;
    const metadata = await sharp(bytes, {limitInputPixels: 100000000}).metadata();
    if (!metadata.format || !["jpeg", "png", "webp", "gif"].includes(metadata.format) ||
      !metadata.width || !metadata.height) throw new Error("Unsupported image format");
    if (asset.sha && gitBlobSha(bytes) !== asset.sha) throw new Error("Git blob SHA mismatch");
    return bytes;
  } finally {
    clearTimeout(timer);
  }
}

/** Default dry run reads metadata only: no fetch, retention, receipt changes or binding. */
export async function migrateOwnedAssets(walls: MigrationWall[], options: MigrationOptions,
  deps: MigrationDeps): Promise<MigrationResult[]> {
  const counts = new Map<unknown, number>();
  for (const wall of walls) counts.set(wall.data.id, (counts.get(wall.data.id) ?? 0) + 1);
  const results: MigrationResult[] = [];
  for (const wall of walls) {
    const id = typeof wall.data.id === "string" ? wall.data.id : "";
    const result: MigrationResult = {docPath: wall.docPath, wallId: id, status: "blocked", detail: "",
      publicOriginalRemains: true};
    results.push(result);
    try {
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(id)) throw new Error("Invalid logical wall.id");
      if (counts.get(id) !== 1) throw new Error("Duplicate logical wall.id, including legacy canonical documents");
      if (await deps.ready(wall)) {
        result.status = "already-owned";
        result.detail = "Private manifest present; prior public GitHub copies still require removal review";
        continue;
      }
      const original = parseRawAsset(wall.data.wallpaper_url, wall.data.wallpaper_path, wall.data.wallpaper_sha, options);
      const thumb = parseRawAsset(wall.data.wallpaper_thumb, wall.data.thumb_path, wall.data.thumb_sha, options);
      if (original.path === thumb.path) throw new Error("Original and thumbnail must be separate assets");
      const owner = await deps.prove(original, thumb);
      const legacy = owner === null;
      if (legacy && (!options.allowReviewedLegacy || wall.data.review !== true)) {
        throw new Error("Unproven provenance: modern receipts absent; reviewed legacy policy requires explicit opt-in");
      }
      result.detail = legacy ? "Reviewed legacy policy; no ownership receipt or creator credit will be fabricated" :
        "Modern upload receipts and completed intents verified";
      if (!options.apply) {
        result.status = "would-migrate";
        continue;
      }
      // Fetch both before writes. Retention is content-addressed and safe to resume after partial failure.
      const originalBytes = await deps.fetchBytes(original);
      const thumbBytes = await deps.fetchBytes(thumb);
      const uid = owner ?? "legacy-migration";
      const retainedOriginal = await deps.retain({...original, sha: original.sha ?? gitBlobSha(originalBytes), uid,
        bytes: originalBytes});
      const retainedThumb = await deps.retain({...thumb, sha: thumb.sha ?? gitBlobSha(thumbBytes), uid, bytes: thumbBytes});
      if (legacy) {
        await deps.bindLegacy({wallId: id, canonicalPath: wall.docPath, incarnation: wall.incarnation,
          incarnationNanos: wall.incarnationNanos,
          originalUrl: original.url, thumbUrl: thumb.url, original: retainedOriginal, thumb: retainedThumb});
      } else {
        await deps.attach(retainedOriginal);
        await deps.attach(retainedThumb);
        await deps.bind(id);
      }
      if (!await deps.ready(wall)) throw new Error("Binding not ready; wall changed or proof no longer valid, rerun safely");
      result.status = "migrated";
    } catch (error) {
      result.detail = error instanceof Error ? error.message : "Migration failed";
    }
  }
  return results;
}

async function main(): Promise<void> {
  const args = new Set(process.argv.slice(2));
  for (const arg of args) if (!["--apply", "--allow-reviewed-legacy", "--confirm-approved-migration"].includes(arg)) {
    throw new Error(`Unknown option: ${arg}`);
  }
  const apply = args.has("--apply");
  if (apply && !args.has("--confirm-approved-migration")) {
    throw new Error("--apply requires explicit operator approval and --confirm-approved-migration");
  }
  const {db} = await import("../common.js");
  const delivery = await import("../ownedAssetDelivery.js");
  const options: MigrationOptions = {apply, allowReviewedLegacy: args.has("--allow-reviewed-legacy"),
    owner: process.env.GH_USERNAME ?? "", repo: process.env.GH_REPO_WALLS ?? ""};
  const rows = await db.collection("walls").get();
  const walls = rows.docs.map((doc) => ({docPath: doc.ref.path, incarnation: doc.createTime.toMillis(),
    incarnationNanos: doc.createTime.nanoseconds, data: doc.data()}));
  const proof = async (asset: Asset): Promise<string | null> => {
    if (!asset.sha) return null;
    const rows = await db.collection("githubUploads").where("path", "==", asset.path).limit(8).get();
    if (rows.size >= 8) return null;
    const matching = rows.docs.filter((row) => row.data().repo === asset.repo);
    const receipt = matching.find((row) => row.id === `file_${digest(`${asset.repo}\0${asset.path}\0${asset.sha}`)}`)?.data();
    const intent = (await db.collection("githubUploadIntents")
      .doc(`path_${digest(`${asset.repo}\0${asset.path}`)}`).get()).data();
    if (!receipt || typeof receipt.uid !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(receipt.uid) ||
      receipt.sha !== asset.sha || matching.some((row) => row.data().uid !== receipt.uid) ||
      intent?.status !== "complete" || intent.uid !== receipt.uid || intent.repo !== asset.repo ||
      intent.path !== asset.path || intent.blobSha !== asset.sha || intent.response?.content?.sha !== asset.sha ||
      intent.response?.content?.path !== asset.path || intent.response?.content?.download_url !== asset.url) return null;
    return receipt.uid;
  };
  const results = await migrateOwnedAssets(walls, options, {
    prove: async (original, thumb) => {
      const uid = await proof(original);
      return uid && uid === await proof(thumb) ? uid : null;
    },
    fetchBytes: downloadRawAsset,
    retain: delivery.retainUpload,
    attach: async (asset) => {
      const ref = db.collection("githubUploads").doc(`file_${digest(`${asset.repo}\0${asset.path}\0${asset.sha}`)}`);
      await db.runTransaction(async (tx) => {
        const receipt = (await tx.get(ref)).data();
        if (!receipt || receipt.uid !== asset.uid || receipt.repo !== asset.repo || receipt.path !== asset.path ||
          receipt.sha !== asset.sha) throw new Error("Receipt changed during migration");
        tx.update(ref, {retainedAsset: asset});
      });
    },
    bind: delivery.bindOwnedWall,
    bindLegacy: delivery.bindLegacyOwnedWall,
    ready: async (wall) => {
      const manifest = (await db.collection("ownedAssets").doc(String(wall.data.id)).get()).data();
      const current = await db.doc(wall.docPath).get();
      const data = current.data();
      return manifest?.status === "ready" && manifest.canonicalPath === wall.docPath &&
        manifest.incarnation === wall.incarnation && manifest.incarnationNanos === wall.incarnationNanos &&
        current.createTime?.toMillis() === wall.incarnation && current.createTime.nanoseconds === wall.incarnationNanos &&
        data?.originalProtected === true && data.wallpaper_url === "" &&
        data.originalGeneration === manifest.original?.generation &&
        data.wallpaper_thumb === delivery.ownedThumbnailUrl(String(wall.data.id));
    },
  });
  process.stdout.write(`${JSON.stringify({mode: apply ? "apply" : "dry-run", results,
    warning: "GitHub public originals are NOT deleted or made private. Separate approved removal inventory required."}, null, 2)}\n`);
  if (results.some((row) => row.status === "blocked")) process.exitCode = 2;
}

if (require.main === module) main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : "Migration failed"}\n`);
  process.exitCode = 1;
});
