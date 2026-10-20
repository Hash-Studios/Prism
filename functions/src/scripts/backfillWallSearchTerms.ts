import * as admin from "firebase-admin";

import {str} from "../common";
import {detectLabels} from "../wallCategory";
import {sameTerms, wallSearchTermsFor} from "../wallSearchTerms";

export type SearchTermsOptions = {apply: boolean; labels: boolean; batchSize: number; startAfter?: string};
export type SearchTermsCounts = {scanned: number; changed: number; labelled: number; failed: number; written: number};
export type LabelDetector = (imageUrl: string) => Promise<string[]>;

const CONCURRENCY = 8;

export async function backfillWallSearchTerms(
  db: admin.firestore.Firestore,
  options: SearchTermsOptions,
  detect: LabelDetector = detectLabels,
  log: (line: string) => void = console.log,
): Promise<SearchTermsCounts> {
  const counts: SearchTermsCounts = {scanned: 0, changed: 0, labelled: 0, failed: 0, written: 0};
  const writer = db.bulkWriter();
  let cursor = options.startAfter;

  const backfillWall = async (doc: admin.firestore.QueryDocumentSnapshot): Promise<void> => {
    counts.scanned += 1;
    const data = doc.data();
    const needsLabels = options.labels && !Array.isArray(data.visionLabels);
    const fetched = needsLabels && options.apply ? await labelsOf(data, detect) : undefined;
    if (needsLabels) counts[fetched || !options.apply ? "labelled" : "failed"] += 1;
    const searchTerms = wallSearchTermsFor(fetched ? {...data, visionLabels: fetched} : data);
    const changes = {
      ...(fetched ? {visionLabels: fetched} : {}),
      ...(sameTerms(data.searchTerms, searchTerms) ? {} : {searchTerms}),
    };
    if (Object.keys(changes).length === 0) return;
    counts.changed += 1;
    if (options.apply) {
      void writer.update(doc.ref, changes).then(() => {
        counts.written += 1;
      }, () => {
        counts.failed += 1;
      });
    }
  };

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
      await Promise.all(snapshot.docs.slice(i, i + CONCURRENCY).map(backfillWall));
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

async function labelsOf(data: admin.firestore.DocumentData, detect: LabelDetector): Promise<string[] | undefined> {
  const imageUrl = str(data.wallpaper_url) || str(data.wallpaper_thumb);
  if (!imageUrl) return undefined;
  try {
    return await detect(imageUrl);
  } catch {
    return undefined;
  }
}

export function parseSearchTermsArgs(argv: string[]): SearchTermsOptions {
  const valueOf = (name: string): string | undefined =>
    argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const batchSize = Number(valueOf("batch") ?? 100);
  return {
    apply: argv.includes("--apply"),
    labels: argv.includes("--labels"),
    batchSize: Number.isInteger(batchSize) && batchSize > 0 && batchSize <= 500 ? batchSize : 100,
    startAfter: valueOf("start-after") || undefined,
  };
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  backfillWallSearchTerms(admin.firestore(), parseSearchTermsArgs(process.argv.slice(2))).catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
