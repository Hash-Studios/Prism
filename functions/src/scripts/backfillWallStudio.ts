import * as admin from "firebase-admin";

import {isStudioWall} from "../studio/isStudioWall";

export type StudioBackfillOptions = {apply: boolean};
export type StudioBackfillCounts = {scanned: number; matched: number; updated: number; dryRun: boolean};

const BATCH_SIZE = 300;

/**
 * Stamps byStudio on reviewed Studio walls that point back at their candidate doc. A dry run counts the matches and
 * writes nothing. Logs one summary line.
 */
export async function backfillWallStudio(
  db: admin.firestore.Firestore,
  options: StudioBackfillOptions,
  log: (line: string) => void = console.log,
): Promise<StudioBackfillCounts> {
  const counts: StudioBackfillCounts = {scanned: 0, matched: 0, updated: 0, dryRun: !options.apply};
  let last: string | undefined;

  while (true) {
    let query = db.collection("walls")
      .where("review", "==", true)
      .where("origin", "==", "studio")
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
      last = doc.id;
      if (doc.data().byStudio === true) continue;
      if (!(await isStudioWall(doc.id, doc.data()))) continue;
      counts.matched += 1;
      if (options.apply) {
        await doc.ref.update({byStudio: true});
        counts.updated += 1;
      }
    }

    log(`batch done last=${last} ${JSON.stringify(counts)}`);
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  log(`done ${JSON.stringify(counts)}`);
  return counts;
}

export function parseStudioBackfillArgs(argv: string[]): StudioBackfillOptions {
  return {apply: argv.includes("--apply")};
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  backfillWallStudio(admin.firestore(), parseStudioBackfillArgs(process.argv.slice(2))).catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
