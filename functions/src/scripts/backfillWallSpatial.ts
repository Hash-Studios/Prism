import * as admin from "firebase-admin";

import {
  SPATIAL_VERSION,
  type SpatialStore,
  storeSpatialMap,
  type WallSpatial,
  type WallSpatialDeps,
  wallSpatialFor,
} from "../wallSpatial";

export type SpatialBackfillOptions = {
  apply: boolean;
  batchSize: number;
  startAfter?: string;
  force: boolean;
  /** Stop after this many walls are checked. */
  limit?: number;
  /** R2 folder for the maps. Dry runs only: a dry run with it stores maps in R2 but writes no Firestore. */
  mapPrefix?: string;
};
export type SpatialBackfillCounts = {
  scanned: number;
  skipped: number;
  checked: number;
  failed: number;
  written: number;
  tiers: Record<string, number>;
};

const CONCURRENCY = 4;

export const USAGE = `Usage: node lib/scripts/backfillWallSpatial.js [--apply] [--force] [--limit=N] [--batch=N] [--start-after=<id>] [--map-prefix=<p>]

Sets walls.spatial (the iOS Spatial Scene tier and depth map) on reviewed walls, in document id order.
A dry run writes nothing to Firestore and saves no maps, but it still calls fal for every wall it checks.
That costs about $0.005 per wall at most. Use --limit=50 for a cheap calibration sample.
--map-prefix=<p> stores the dry-run maps in R2 under <p> (for example spatial-test/v1). It is for dry runs only.
FAL_API_KEY must be set in the environment.
R2 env vars are needed when maps are stored: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY,
R2_PRIVATE_BUCKET, R2_PREVIEW_BUCKET and R2_PREVIEW_BASE_URL.
--force recomputes walls that have spatial.v >= ${SPATIAL_VERSION}.`;

export function needsSpatial(spatial: unknown, force: boolean): boolean {
  if (force) return true;
  const current = typeof spatial === "object" && spatial !== null ? spatial as Partial<WallSpatial> : undefined;
  return !(typeof current?.v === "number" && current.v >= SPATIAL_VERSION);
}

/** A store for dry runs without --map-prefix: it saves nothing, so a plain dry run never writes to R2. */
const dryRunStore: SpatialStore = async (object) => `dry-run:${object}`;

/**
 * Sets walls.spatial on reviewed walls, one batch at a time in document id order.
 * Logs one line per wall and the last id of each batch. Pass it as --start-after=<id> to resume.
 */
export async function backfillWallSpatial(
  db: admin.firestore.Firestore,
  options: SpatialBackfillOptions,
  deps?: WallSpatialDeps,
  log: (line: string) => void = console.log,
): Promise<SpatialBackfillCounts> {
  const counts: SpatialBackfillCounts = {scanned: 0, skipped: 0, checked: 0, failed: 0, written: 0, tiers: {}};
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
      if (!needsSpatial(doc.get("spatial"), options.force)) {
        counts.skipped += 1;
        return false;
      }
      return true;
    }).slice(0, left);
    left -= pending.length;

    for (let i = 0; i < pending.length; i += CONCURRENCY) {
      await Promise.all(pending.slice(i, i + CONCURRENCY).map(async (doc) => {
        const url = String(doc.get("wallpaper_url") || doc.get("wallpaper_thumb") || "").trim();
        const spatial = url ? await wallSpatialFor(doc.id, {url}, deps) : undefined;
        if (!spatial) {
          counts.failed += 1;
          log(`${doc.id} failed`);
          return;
        }
        counts.checked += 1;
        counts.tiers[spatial.tier] = (counts.tiers[spatial.tier] ?? 0) + 1;
        log(`${doc.id} ${spatial.tier} ${spatial.map}`);
        if (options.apply) {
          void writer.update(doc.ref, {spatial}, {lastUpdateTime: doc.updateTime}).then(() => {
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
  log(`done tiers=${JSON.stringify(counts.tiers)} ` +
    `scanned=${counts.scanned} skipped=${counts.skipped} checked=${counts.checked} failed=${counts.failed} ` +
    `written=${counts.written} applied=${options.apply}`);
  return counts;
}

export function parseSpatialBackfillArgs(argv: string[]): SpatialBackfillOptions {
  const valueOf = (name: string): string | undefined =>
    argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const batchSize = Number(valueOf("batch") ?? 100);
  const limit = Number(valueOf("limit"));
  const apply = argv.includes("--apply");
  const mapPrefix = valueOf("map-prefix") || undefined;
  if (apply && mapPrefix) {
    throw new Error("--map-prefix is for dry runs only");
  }
  return {
    apply,
    force: argv.includes("--force"),
    batchSize: Number.isInteger(batchSize) && batchSize > 0 && batchSize <= 500 ? batchSize : 100,
    startAfter: valueOf("start-after") || undefined,
    limit: Number.isInteger(limit) && limit > 0 ? limit : undefined,
    mapPrefix,
  };
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    const options = parseSpatialBackfillArgs(argv);
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    const deps: WallSpatialDeps = {
      fetch: (url, init) => fetch(url, init),
      key: () => process.env.FAL_API_KEY ?? "",
      store: options.apply || options.mapPrefix ? storeSpatialMap : dryRunStore,
      prefix: options.mapPrefix,
    };
    backfillWallSpatial(admin.firestore(), options, deps).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
