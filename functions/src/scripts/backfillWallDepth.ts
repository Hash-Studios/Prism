import * as admin from "firebase-admin";

import {annotateForDepth, DEPTH_VERSION, type WallDepth, type WallDepthDeps, wallDepthFor} from "../wallDepth";

export type DepthBackfillOptions = {
  apply: boolean;
  batchSize: number;
  startAfter?: string;
  force: boolean;
  /** Stop after this many walls are checked. */
  limit?: number;
};
export type DepthBackfillCounts = {
  scanned: number;
  skipped: number;
  checked: number;
  failed: number;
  written: number;
  tiers: Record<string, number>;
  kinds: Record<string, number>;
};

const CONCURRENCY = 4;

export const USAGE = `Usage: node lib/scripts/backfillWallDepth.js [--apply] [--force] [--limit=N] [--batch=N] [--start-after=<id>]

Sets walls.depth (the iOS Depth Effect tier) on reviewed walls, in document id order.
A dry run writes nothing, but it still calls Vision and fal for every wall it checks, so it costs money.
Use --limit=50 for a cheap calibration sample. FAL_KEY must be set in the environment.
--force recomputes walls that have depth.v >= ${DEPTH_VERSION}. Walls with depth.by "admin" are never changed.`;

/** True when the backfill should check this wall. An admin value is never replaced, even with --force. */
export function needsDepth(depth: unknown, force: boolean): boolean {
  const current = typeof depth === "object" && depth !== null ? depth as Partial<WallDepth> : undefined;
  if (current?.by === "admin") return false;
  if (force) return true;
  return !(typeof current?.v === "number" && current.v >= DEPTH_VERSION);
}

/**
 * Sets walls.depth on reviewed walls, one batch at a time in document id order.
 * Logs one line per wall and the last id of each batch. Pass it as --start-after=<id> to resume.
 */
export async function backfillWallDepth(
  db: admin.firestore.Firestore,
  options: DepthBackfillOptions,
  deps?: WallDepthDeps,
  log: (line: string) => void = console.log,
): Promise<DepthBackfillCounts> {
  const counts: DepthBackfillCounts = {scanned: 0, skipped: 0, checked: 0, failed: 0, written: 0, tiers: {}, kinds: {}};
  const writer = db.bulkWriter();
  let cursor = options.startAfter;
  let left = options.limit ?? Infinity;

  while (left > 0) {
    let query = db.collection("walls")
      .where("review", "==", true)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(options.batchSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const pending = snapshot.docs.filter((doc) => {
      counts.scanned += 1;
      if (!needsDepth(doc.get("depth"), options.force)) {
        counts.skipped += 1;
        return false;
      }
      return true;
    }).slice(0, left);
    left -= pending.length;

    for (let i = 0; i < pending.length; i += CONCURRENCY) {
      await Promise.all(pending.slice(i, i + CONCURRENCY).map(async (doc) => {
        const url = String(doc.get("wallpaper_url") || doc.get("wallpaper_thumb") || "").trim();
        const depth = url ? await wallDepthFor(doc.id, {url}, deps) : undefined;
        if (!depth) {
          counts.failed += 1;
          log(`${doc.id} failed`);
          return;
        }
        counts.checked += 1;
        counts.tiers[depth.tier] = (counts.tiers[depth.tier] ?? 0) + 1;
        counts.kinds[depth.kind ?? "none"] = (counts.kinds[depth.kind ?? "none"] ?? 0) + 1;
        log(`${doc.id} ${depth.tier} ${depth.kind ?? "-"} ${depth.top ?? "-"}`);
        if (options.apply) {
          void writer.update(doc.ref, {depth}, {lastUpdateTime: doc.updateTime}).then(() => {
            counts.written += 1;
          }, () => {
            counts.failed += 1;
          });
        }
      }));
    }

    await writer.flush();
    cursor = (left === 0 && pending.length > 0 ? pending[pending.length - 1] : snapshot.docs[snapshot.docs.length - 1]).id;
    log(`batch done last=${cursor} ${JSON.stringify(counts)}`);
    if (snapshot.size < options.batchSize) {
      break;
    }
  }

  await writer.close();
  log(`done tiers=${JSON.stringify(counts.tiers)} kinds=${JSON.stringify(counts.kinds)} ` +
    `scanned=${counts.scanned} skipped=${counts.skipped} checked=${counts.checked} failed=${counts.failed} ` +
    `written=${counts.written} applied=${options.apply}`);
  return counts;
}

export function parseDepthBackfillArgs(argv: string[]): DepthBackfillOptions {
  const valueOf = (name: string): string | undefined =>
    argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const batchSize = Number(valueOf("batch") ?? 100);
  const limit = Number(valueOf("limit"));
  return {
    apply: argv.includes("--apply"),
    force: argv.includes("--force"),
    batchSize: Number.isInteger(batchSize) && batchSize > 0 && batchSize <= 500 ? batchSize : 100,
    startAfter: valueOf("start-after") || undefined,
    limit: Number.isInteger(limit) && limit > 0 ? limit : undefined,
  };
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    const deps: WallDepthDeps = {annotate: annotateForDepth, fetch, key: () => process.env.FAL_KEY ?? ""};
    backfillWallDepth(admin.firestore(), parseDepthBackfillArgs(argv), deps).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
