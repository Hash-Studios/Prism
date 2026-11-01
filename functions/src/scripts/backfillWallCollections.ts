import * as admin from "firebase-admin";

import {DEFAULT_CATEGORY, DEFAULT_COLLECTION, detectLabels, mapLabelsToCategory} from "../wallCategory";
import {categoryCollection, isCommunityOnly, refreshCollectionCovers} from "../wallCollections";
import {premiumCollections} from "../wallEligibility";

export type CollectionBackfillOptions = {
  apply: boolean;
  /** Stop after this many walls get a Vision call. */
  limit?: number;
};
export type CollectionBackfillCounts = {
  scanned: number;
  communityOnly: number;
  detected: number;
  kept: number;
  failed: number;
  premiumSkipped: number;
  filed: number;
  written: number;
  categories: Record<string, number>;
  collections: Record<string, number>;
};
export interface CollectionBackfillDeps {
  detect: (imageUrl: string) => Promise<string[]>;
  premium: () => Promise<string[]>;
  refreshCovers: () => Promise<string[]>;
}

const BATCH_SIZE = 300;
const CONCURRENCY = 4;
const DEFAULT_DEPS: CollectionBackfillDeps = {
  detect: detectLabels,
  premium: premiumCollections,
  refreshCovers: refreshCollectionCovers,
};

export const USAGE = `Usage: node lib/scripts/backfillWallCollections.js [--apply] [--limit=N]

Files reviewed walls that are only in community into the collection of their category.
A wall keeps a category that its creator picked or that Vision already set.
A wall with no category gets one from Vision.
A dry run writes nothing, but it still calls Vision for these walls, so it costs a little money.
--limit=N stops after N Vision calls.
Collections in the Remote Config premium list are skipped.
--apply writes the walls and then refreshes the collection covers.
Credentials come from Application Default Credentials, as in the other backfills.`;

/** The category to keep, or null when Vision must find one. */
export function keptCategory(wall: admin.firestore.DocumentData): string | null {
  const category = typeof wall.category === "string" ? wall.category.trim() : "";
  if (wall.aiCategorized === true) return category || DEFAULT_CATEGORY;
  return category && category !== DEFAULT_CATEGORY ? category : null;
}

const bump = (histogram: Record<string, number>, key: string) => {
  histogram[key] = (histogram[key] ?? 0) + 1;
};

/**
 * Files reviewed walls that are only in community into the collection of their category, one batch at a time in
 * document id order. Logs one line per wall. With apply, it then refreshes the collection covers.
 */
export async function backfillWallCollections(
  db: admin.firestore.Firestore,
  options: CollectionBackfillOptions,
  deps: CollectionBackfillDeps = DEFAULT_DEPS,
  log: (line: string) => void = console.log,
): Promise<CollectionBackfillCounts> {
  const counts: CollectionBackfillCounts = {scanned: 0, communityOnly: 0, detected: 0, kept: 0, failed: 0,
    premiumSkipped: 0, filed: 0, written: 0, categories: {}, collections: {}};
  const premium = await deps.premium();
  const writer = options.apply ? db.bulkWriter() : undefined;
  let left = options.limit ?? Infinity;
  let last: admin.firestore.QueryDocumentSnapshot | undefined;

  const fileWall = async (doc: admin.firestore.QueryDocumentSnapshot, kept: string | null) => {
    const wall = doc.data();
    const update: Record<string, unknown> = {};
    let category = kept;
    if (category === null) {
      const url = String(wall.wallpaper_url || wall.wallpaper_thumb || "").trim();
      const labels = url ? await deps.detect(url).catch(() => undefined) : undefined;
      if (!labels) {
        counts.failed += 1;
        log(`${doc.id} failed`);
        return;
      }
      category = mapLabelsToCategory(labels);
      counts.detected += 1;
      Object.assign(update, {category, aiCategorized: true, categorizedAt: admin.firestore.FieldValue.serverTimestamp()});
    } else {
      counts.kept += 1;
    }
    bump(counts.categories, category);

    let target = categoryCollection(category);
    if (target && premium.includes(target)) {
      counts.premiumSkipped += 1;
      target = null;
    }
    if (target) {
      update.collections = [DEFAULT_COLLECTION, target];
      counts.filed += 1;
      bump(counts.collections, target);
    }
    log(`${doc.id} ${category} ${target ?? "-"}`);
    if (writer && Object.keys(update).length > 0) {
      void writer.update(doc.ref, update, {lastUpdateTime: doc.updateTime}).then(() => {
        counts.written += 1;
      }, () => {
        counts.failed += 1;
      });
    }
  };

  while (left > 0) {
    let query = db.collection("walls")
      .where("review", "==", true)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (last) {
      query = query.startAfter(last);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const work: Array<{doc: admin.firestore.QueryDocumentSnapshot; kept: string | null}> = [];
    for (const doc of snapshot.docs) {
      const kept = isCommunityOnly(doc.data().collections) ? keptCategory(doc.data()) : undefined;
      if (kept === null && left === 0) break;
      counts.scanned += 1;
      last = doc;
      if (kept === undefined) continue;
      counts.communityOnly += 1;
      if (kept === null) left -= 1;
      work.push({doc, kept});
    }
    for (let i = 0; i < work.length; i += CONCURRENCY) {
      await Promise.all(work.slice(i, i + CONCURRENCY).map(({doc, kept}) => fileWall(doc, kept)));
    }

    await writer?.flush();
    log(`batch done last=${last?.id} ${JSON.stringify(counts)}`);
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  if (writer) {
    await writer.close();
    const changed = await deps.refreshCovers();
    log(`covers refreshed: ${changed.length > 0 ? changed.join(", ") : "none"}`);
  }
  log(`done scanned=${counts.scanned} communityOnly=${counts.communityOnly} detected=${counts.detected} ` +
    `kept=${counts.kept} failed=${counts.failed} premiumSkipped=${counts.premiumSkipped} filed=${counts.filed} ` +
    `written=${counts.written} categories=${JSON.stringify(counts.categories)} ` +
    `collections=${JSON.stringify(counts.collections)} applied=${options.apply}`);
  return counts;
}

export function parseCollectionBackfillArgs(argv: string[]): CollectionBackfillOptions {
  const limit = Number(argv.find((arg) => arg.startsWith("--limit="))?.slice("--limit=".length));
  return {
    apply: argv.includes("--apply"),
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
    backfillWallCollections(admin.firestore(), parseCollectionBackfillArgs(argv)).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
