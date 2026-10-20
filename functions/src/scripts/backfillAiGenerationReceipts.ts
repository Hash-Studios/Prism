import * as admin from "firebase-admin";

import {AI_RECEIPTS, parseAiSource, readAiGenerationRecord, saveAiGenerationReceipt} from "../aiWallSource";

export type AiReceiptBackfillCounts = {
  scanned: number;
  /** Walls that `parseAiSource` does not accept as user AI walls. */
  skipped: number;
  hadReceipt: number;
  /** Receipts written, or with a dry run, receipts that apply would write. */
  receiptWritten: number;
  recordGone: number;
  failed: number;
};

const BATCH_SIZE = 300;

export const USAGE = `Usage: node lib/scripts/backfillAiGenerationReceipts.js [--apply]

Finds pending user AI walls (isAiGenerated true, review false) that have no aiGenerationReceipts/{generationId}
document and copies their live Worker record ai:gen:{generationId} to that receipt.
A dry run writes nothing, but it reads the Worker records to report which are still live.
--apply writes the receipts. A receipt that already exists is kept.
STUDIO_SECRET must be in the environment. Credentials come from Application Default Credentials.`;

/**
 * Writes the receipts that `onWallSubmitted` makes for user AI walls submitted before it made them, one batch at a
 * time in document id order. Logs one line per user AI wall.
 */
export async function backfillAiGenerationReceipts(
  db: admin.firestore.Firestore,
  options: {apply: boolean},
  readRecord = readAiGenerationRecord,
  log: (line: string) => void = console.log,
): Promise<AiReceiptBackfillCounts> {
  const counts: AiReceiptBackfillCounts =
    {scanned: 0, skipped: 0, hadReceipt: 0, receiptWritten: 0, recordGone: 0, failed: 0};
  let last: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collection("walls")
      .where("isAiGenerated", "==", true)
      .where("review", "==", false)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (last) query = query.startAfter(last);
    const snapshot = await query.get();
    for (const doc of snapshot.docs) {
      counts.scanned += 1;
      last = doc;
      const source = parseAiSource(doc.data());
      if (!source) {
        counts.skipped += 1;
        continue;
      }
      const id = source.generationId;
      try {
        if ((await db.collection(AI_RECEIPTS).doc(id).get()).exists) {
          counts.hadReceipt += 1;
          log(`${doc.id} ${id} had-receipt`);
          continue;
        }
        const live = options.apply ? await saveAiGenerationReceipt(db, id, readRecord) : !!(await readRecord(id));
        counts[live ? "receiptWritten" : "recordGone"] += 1;
        log(`${doc.id} ${id} ${live ? "receipt-written" : "record-gone"}`);
      } catch (error) {
        counts.failed += 1;
        log(`${doc.id} ${id} failed ${error instanceof Error ? error.message : String(error)}`);
      }
    }
    if (snapshot.size < BATCH_SIZE) break;
  }
  log(`done ${JSON.stringify(counts)} applied=${options.apply}`);
  return counts;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!process.env.STUDIO_SECRET) {
      console.error("STUDIO_SECRET is required");
      process.exitCode = 1;
    } else {
      if (!admin.apps.length) admin.initializeApp();
      backfillAiGenerationReceipts(admin.firestore(), {apply: argv.includes("--apply")}).then((counts) => {
        if (counts.failed > 0) process.exitCode = 1;
      }, (err) => {
        console.error(err);
        process.exitCode = 1;
      });
    }
  }
}
