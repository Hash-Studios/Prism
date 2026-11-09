import * as admin from "firebase-admin";

export type PublishedAtBackfillCounts = {scanned: number; already: number; planned: number; noTime: number; written: number};

const BATCH_SIZE = 300;
const WRITE_BATCH_SIZE = 400;

/** The publishedAt value for a wall, "already" when it is set, or null when neither time is a Timestamp. */
export function planPublishedAt(data: Record<string, unknown>): admin.firestore.Timestamp | null | "already" {
  if (data.publishedAt !== undefined && data.publishedAt !== null) return "already";
  if (data.reviewedAt instanceof admin.firestore.Timestamp) return data.reviewedAt;
  if (data.createdAt instanceof admin.firestore.Timestamp) return data.createdAt;
  return null;
}

/**
 * Gives every approved wall without publishedAt a value from reviewedAt, or else createdAt. A dry run plans the
 * writes and writes nothing. With apply, each batch uses lastUpdateTime, so a wall changed since it was read is
 * refused and the script stops. A rerun is safe because walls already set are skipped.
 */
export async function backfillPublishedAt(
  db: admin.firestore.Firestore,
  options: {apply: boolean},
  log: (line: string) => void = console.log,
): Promise<PublishedAtBackfillCounts> {
  const counts: PublishedAtBackfillCounts = {scanned: 0, already: 0, planned: 0, noTime: 0, written: 0};
  const pending: Array<{ref: admin.firestore.DocumentReference; updateTime: admin.firestore.Timestamp;
    value: admin.firestore.Timestamp}> = [];
  let last: admin.firestore.QueryDocumentSnapshot | undefined;

  const flush = async (): Promise<void> => {
    if (pending.length === 0) return;
    const batch = db.batch();
    for (const write of pending) {
      batch.update(write.ref, {publishedAt: write.value}, {lastUpdateTime: write.updateTime});
    }
    await batch.commit();
    counts.written += pending.length;
    pending.length = 0;
  };

  while (true) {
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

    for (const doc of snapshot.docs) {
      counts.scanned += 1;
      last = doc;
      const plan = planPublishedAt(doc.data());
      if (plan === "already") {
        counts.already += 1;
        continue;
      }
      if (plan === null) {
        counts.noTime += 1;
        continue;
      }
      counts.planned += 1;
      if (options.apply) {
        pending.push({ref: doc.ref, updateTime: doc.updateTime, value: plan});
        if (pending.length >= WRITE_BATCH_SIZE) {
          await flush();
        }
      }
    }

    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  await flush();
  if (!options.apply) {
    log(`dry run planned=${counts.planned}`);
  }
  log(`done ${JSON.stringify(counts)} applied=${options.apply}`);
  return counts;
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  backfillPublishedAt(admin.firestore(), {apply: process.argv.slice(2).includes("--apply")}).catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
