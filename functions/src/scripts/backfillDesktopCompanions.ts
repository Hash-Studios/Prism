import * as admin from "firebase-admin";
import {str} from "../common";
import {annotateWithVision} from "../studio/gates";
import {
  DESKTOP_COMPANIONS, desktopCostUsd, desktopEligibility, type DesktopOutcome, makeDesktopCompanion,
} from "../studio/desktop";
import {isStudioWall} from "../studio/isStudioWall";
import {workerBaseUrl} from "../studio/process";

export type DesktopBackfillOptions = {apply: boolean; limit: number; startAfter?: string};
export type DesktopBackfillReport = {
  scanned: number;
  skipped: Record<string, number>;
  planned: Array<{id: string; model: string; costUsd: number}>;
  costUsd: number;
  outcomes: Record<string, number>;
  /** Pass as --start-after to resume after the last wall this run looked at. */
  last?: string;
};
export type DesktopBackfillDeps = {
  make: (wallPath: string) => Promise<DesktopOutcome>;
  isStudio: (wallId: string, data: admin.firestore.DocumentData) => Promise<boolean>;
};

const BATCH = 200;
export const DEFAULT_LIMIT = 25;

export const USAGE = `Usage: node lib/scripts/backfillDesktopCompanions.js [--apply] [--limit=N] [--start-after=<wall doc id>]

Makes desktop companions (2560x1600 plus a 16:9 crop) for approved Prism Studio walls that have none.
A dry run (the default) writes nothing and calls no paid service. It lists each wall it would make, with its cost.
--apply calls the Studio model through the Worker. It spends the Studio budget and stops when the budget is used up.
--limit=N stops after N walls are planned (default ${DEFAULT_LIMIT}).
Walls with a companion, or with a rejected or failed one, are skipped. A second run does not pay twice.
STUDIO_SECRET and the R2 env vars must be set for --apply.`;

/** Walks the Studio walls in doc id order. Each planned wall is made one at a time with --apply. */
export async function backfillDesktopCompanions(db: admin.firestore.Firestore, options: DesktopBackfillOptions,
  deps: DesktopBackfillDeps, log: (line: string) => void = console.log): Promise<DesktopBackfillReport> {
  const report: DesktopBackfillReport = {scanned: 0, skipped: {}, planned: [], costUsd: 0, outcomes: {}};
  const skip = (reason: string) => {
    report.skipped[reason] = (report.skipped[reason] ?? 0) + 1;
  };
  let cursor = options.startAfter;
  scan: for (;;) {
    let query = db.collection("walls").where("origin", "==", "studio")
      .orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    for (const doc of snapshot.docs) {
      if (report.planned.length >= options.limit) break scan;
      report.scanned++;
      const previousLast = report.last ?? options.startAfter;
      report.last = doc.id;
      const data = doc.data();
      const shareId = str(data.id);
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(shareId)) {
        skip("not_studio");
        continue;
      }
      const manifest = (await db.collection(DESKTOP_COMPANIONS).doc(shareId).get()).data();
      if (options.apply && ["ready", "rejected", "failed"].includes(str(manifest?.status)) &&
          (manifest?.workerKey || manifest?.pendingObjects)) {
        // make() only performs terminal cleanup here; it does not claim or spend for terminal manifests.
        await deps.make(doc.ref.path);
      }
      const eligible = desktopEligibility(data);
      if ("skip" in eligible) {
        skip(eligible.skip);
        continue;
      }
      if (manifest?.status === "ready" || manifest?.status === "rejected" || manifest?.status === "failed") {
        skip(`manifest_${manifest.status}`);
        continue;
      }
      if (!(await deps.isStudio(doc.id, data))) {
        skip("not_studio");
        continue;
      }
      const costUsd = desktopCostUsd(eligible.model);
      report.planned.push({id: doc.id, model: eligible.model, costUsd});
      report.costUsd = Math.round((report.costUsd + costUsd) * 10000) / 10000;
      if (!options.apply) {
        log(`would make ${doc.id} model=${eligible.model} cost=$${costUsd.toFixed(4)}`);
        continue;
      }
      const outcome = await deps.make(doc.ref.path);
      report.outcomes[outcome] = (report.outcomes[outcome] ?? 0) + 1;
      log(`${outcome} ${doc.id}`);
      if (outcome === "deferred") {
        report.last = previousLast;
        log("The Studio budget is used up. Run again tomorrow: walls with a companion are skipped.");
        break scan;
      }
    }
    if (snapshot.size < BATCH) break;
    cursor = snapshot.docs[snapshot.docs.length - 1].id;
  }
  log(`done applied=${options.apply} scanned=${report.scanned} planned=${report.planned.length} ` +
    `cost=$${report.costUsd.toFixed(4)} skipped=${JSON.stringify(report.skipped)} outcomes=${JSON.stringify(report.outcomes)} ` +
    `last=${report.last ?? ""}`);
  return report;
}

export function parseDesktopBackfillArgs(argv: string[]): DesktopBackfillOptions {
  const valueOf = (name: string): string | undefined =>
    argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const limit = Number(valueOf("limit") ?? DEFAULT_LIMIT);
  if (!Number.isInteger(limit) || limit < 1 || limit > 1000) throw new Error("--limit must be 1 to 1000");
  return {apply: argv.includes("--apply"), limit, startAfter: valueOf("start-after") || undefined};
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    const options = parseDesktopBackfillArgs(argv);
    const secret = process.env.STUDIO_SECRET ?? "";
    if (options.apply && !secret) throw new Error("STUDIO_SECRET must be set for --apply");
    backfillDesktopCompanions(admin.firestore(), options, {
      isStudio: isStudioWall,
      make: (wallPath) => makeDesktopCompanion(wallPath,
        {worker: {base: workerBaseUrl(), secret}, annotate: annotateWithVision, nowMs: Date.now}),
    }).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
