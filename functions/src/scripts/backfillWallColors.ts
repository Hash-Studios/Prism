import * as admin from "firebase-admin";

import {ColorFetch, hasPaletteColors, wallColorsFor} from "../wallColors";

export type BackfillOptions = {apply: boolean; batchSize: number; startAfter?: string; force: boolean};
export type BackfillCounts = {scanned: number; skipped: number; colored: number; failed: number; written: number};

const CONCURRENCY = 8;

/**
 * Sets walls.colors on reviewed walls, one batch at a time in document id order.
 * Logs the last id of each batch. Pass it as --start-after=<id> to resume.
 */
export async function backfillWallColors(
  db: admin.firestore.Firestore,
  options: BackfillOptions,
  fetchImpl?: ColorFetch,
  log: (line: string) => void = console.log,
): Promise<BackfillCounts> {
  const counts: BackfillCounts = {scanned: 0, skipped: 0, colored: 0, failed: 0, written: 0};
  const writer = db.bulkWriter();
  let cursor = options.startAfter;

  while (true) {
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
      if (hasPaletteColors(doc.get("colors")) && !options.force) {
        counts.skipped += 1;
        return false;
      }
      return true;
    });

    for (let i = 0; i < pending.length; i += CONCURRENCY) {
      await Promise.all(pending.slice(i, i + CONCURRENCY).map(async (doc) => {
        const colors = await wallColorsFor(doc.id, doc.data(), fetchImpl);
        if (!colors) {
          counts.failed += 1;
          return;
        }
        counts.colored += 1;
        if (options.apply) {
          void writer.update(doc.ref, {colors}).then(() => {
            counts.written += 1;
          }, () => {
            counts.failed += 1;
          });
        }
      }));
    }

    await writer.flush();
    cursor = snapshot.docs[snapshot.docs.length - 1].id;
    log(`batch done last=${cursor} ${JSON.stringify(counts)}`);
    if (snapshot.size < options.batchSize) {
      break;
    }
  }

  await writer.close();
  log(`done ${JSON.stringify(counts)} applied=${options.apply}`);
  return counts;
}

export function parseBackfillArgs(argv: string[]): BackfillOptions {
  const valueOf = (name: string): string | undefined =>
    argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const batchSize = Number(valueOf("batch") ?? 100);
  return {
    apply: argv.includes("--apply"),
    force: argv.includes("--force"),
    batchSize: Number.isInteger(batchSize) && batchSize > 0 && batchSize <= 500 ? batchSize : 100,
    startAfter: valueOf("start-after") || undefined,
  };
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  backfillWallColors(admin.firestore(), parseBackfillArgs(process.argv.slice(2))).catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
