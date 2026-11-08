import * as admin from "firebase-admin";

import {DEFAULT_CATEGORY, mapLabelsToCategory} from "../wallCategory";

/** Categories added in #806. A rerun never moves a wall out of them. */
export const NEW_CATEGORIES: readonly string[] = ["Gaming", "Pastel"];

const BATCH_SIZE = 300;

export type WallCategoryBackfillCounts = {
  scanned: number;
  noLabels: number;
  creatorPicked: number;
  changed: number;
  /** Changes to General walls the classifier never set. --classified-only skips them. */
  unclassified: number;
  written: number;
  failed: number;
  moves: Record<string, number>;
  samples: string[];
};

export const USAGE = `Usage: node lib/scripts/backfillWallCategories.js [--apply]

Recategorizes approved walls from their stored Vision labels with the current classifier rules.
A wall keeps its category when a creator picked it, and a wall in Gaming or Pastel stays there.
The classifier owns a wall that it categorized or that has General.
A dry run is the default. It reads approved walls and writes nothing. It calls no paid service.
--classified-only leaves General walls that the classifier never set (labels saved, category never chosen).
--apply writes the new category. Get the owner's OK first.
Credentials come from Application Default Credentials, as in the other backfills.`;

/** The category change for a wall, or why there is none. */
export function planCategoryChange(
  wall: admin.firestore.DocumentData,
): {from: string; to: string} | "noLabels" | "creatorPicked" | null {
  const labels = wall.visionLabels;
  if (!Array.isArray(labels) || labels.length === 0 || !labels.every((label) => typeof label === "string")) {
    return "noLabels";
  }
  const current = typeof wall.category === "string" ? wall.category.trim() : "";
  const from = current || DEFAULT_CATEGORY;
  if (wall.aiCategorized !== true && from !== DEFAULT_CATEGORY) {
    return "creatorPicked";
  }
  const to = mapLabelsToCategory(labels);
  if (to === from || NEW_CATEGORIES.includes(from)) {
    return null;
  }
  return {from, to};
}

const bump = (histogram: Record<string, number>, key: string) => {
  histogram[key] = (histogram[key] ?? 0) + 1;
};

/**
 * Walks approved walls in document id order and plans a category change for each one. Logs one line per change.
 * With apply, it writes the new category through a bulkWriter, one batch at a time.
 */
export async function backfillWallCategories(
  db: admin.firestore.Firestore,
  options: {apply: boolean; classifiedOnly?: boolean},
  log: (line: string) => void = console.log,
): Promise<WallCategoryBackfillCounts> {
  const counts: WallCategoryBackfillCounts = {scanned: 0, noLabels: 0, creatorPicked: 0, changed: 0, unclassified: 0, written: 0,
    failed: 0, moves: {}, samples: []};
  const writer = options.apply ? db.bulkWriter() : undefined;
  let last: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
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
      const data = doc.data();
      const plan = planCategoryChange(data);
      if (plan === "noLabels") {
        counts.noLabels += 1;
        continue;
      }
      if (plan === "creatorPicked") {
        counts.creatorPicked += 1;
        continue;
      }
      if (plan === null) {
        continue;
      }
      const unclassified = data.aiCategorized !== true;
      if (unclassified) counts.unclassified += 1;
      if (unclassified && options.classifiedOnly) {
        continue;
      }
      counts.changed += 1;
      bump(counts.moves, `${plan.from} -> ${plan.to}`);
      if (counts.samples.length < 10) {
        counts.samples.push(doc.id);
      }
      log(`${doc.id} ${plan.from} -> ${plan.to}`);
      if (writer) {
        void writer.update(doc.ref, {
          category: plan.to,
          aiCategorized: true,
          categorizedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {lastUpdateTime: doc.updateTime}).then(() => {
          counts.written += 1;
        }, () => {
          counts.failed += 1;
        });
      }
    }

    await writer?.flush();
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  await writer?.close();
  for (const [move, n] of Object.entries(counts.moves)) {
    log(`move ${move}: ${n}`);
  }
  log(`samples: ${counts.samples.join(" ")}`);
  log(`done scanned=${counts.scanned} noLabels=${counts.noLabels} creatorPicked=${counts.creatorPicked} ` +
    `changed=${counts.changed} unclassified=${counts.unclassified} written=${counts.written} failed=${counts.failed} applied=${options.apply}`);
  if (options.apply && counts.failed > 0) {
    throw new Error(`${counts.failed} category writes failed`);
  }
  return counts;
}

export function parseWallCategoryArgs(argv: string[]): {apply: boolean; classifiedOnly: boolean} {
  return {apply: argv.includes("--apply"), classifiedOnly: argv.includes("--classified-only")};
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    backfillWallCategories(admin.firestore(), parseWallCategoryArgs(argv)).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
