import * as admin from "firebase-admin";

import {isStudioWall} from "../studio/isStudioWall";
import {readWallImage} from "../wallModeration";
import {fetchImageBuffer} from "../wallColors";

export type BackfillOptions = {apply: boolean; batchSize: number; startAfter?: string};
export type BackfillCounts = {scanned: number; skipped: number; signed: number; failed: number; written: number};
export type BackfillDeps = {
  fetchImage: (url: string) => Promise<Buffer>;
  isStudio: (wallId: string, data: admin.firestore.DocumentData) => Promise<boolean>;
};

const CONCURRENCY = 8;

/**
 * Writes wallSignatures/{id} for reviewed walls that have none, so new uploads can be compared to them. Studio walls
 * keep their signature in studioSignatures. No Vision calls. One batch at a time in document id order.
 * Logs the last id of each batch. Pass it as --start-after=<id> to resume.
 */
export async function backfillWallSignatures(
  db: admin.firestore.Firestore,
  options: BackfillOptions,
  deps: BackfillDeps = {fetchImage: (url) => fetchImageBuffer(url), isStudio: isStudioWall},
  log: (line: string) => void = console.log,
): Promise<BackfillCounts> {
  const counts: BackfillCounts = {scanned: 0, skipped: 0, signed: 0, failed: 0, written: 0};
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

    for (let i = 0; i < snapshot.docs.length; i += CONCURRENCY) {
      await Promise.all(snapshot.docs.slice(i, i + CONCURRENCY).map(async (doc) => {
        counts.scanned += 1;
        const target = db.collection("wallSignatures").doc(doc.id);
        if ((await target.get()).exists || await deps.isStudio(doc.id, doc.data())) {
          counts.skipped += 1;
          return;
        }
        const image = await readWallImage(doc.id, doc.data(), deps.fetchImage);
        if (!image) {
          counts.failed += 1;
          return;
        }
        counts.signed += 1;
        if (options.apply) {
          void writer.set(target, {
            signature: image.signature,
            wallId: doc.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }).then(() => {
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
    batchSize: Number.isInteger(batchSize) && batchSize > 0 && batchSize <= 500 ? batchSize : 100,
    startAfter: valueOf("start-after") || undefined,
  };
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  backfillWallSignatures(admin.firestore(), parseBackfillArgs(process.argv.slice(2))).catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
