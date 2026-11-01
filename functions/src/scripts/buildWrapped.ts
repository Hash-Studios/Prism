import * as admin from "firebase-admin";

import {str} from "../common";
import {notificationCopyPayload} from "../notificationCatalog";
import {sendToUser} from "../notificationHelper";
import {
  buildWrapped,
  loadWallIndex,
  readCreatorProfile,
  readWrappedSignals,
  topCreator,
  WRAPPED_YEAR,
  wrappedDocPath,
  wrappedWindow,
} from "../wrapped";
import {runPool} from "./runChunked";

export const WRAPPED_RUN = `wrappedRuns/${WRAPPED_YEAR}`;

export type WrappedJobCounts = {scanned: number; eligible: number; removed: number; skipped: number};
export type WrappedJobResult = WrappedJobCounts & {phase: string; cursor: string | null};

type JobOptions = {
  apply: boolean;
  /** Starts a new build: resets the cursor and the window end, and removes docs of users no longer eligible. */
  restart?: boolean;
  maxPages?: number;
  pageSize?: number;
  concurrency?: number;
  now?: Date;
  log?: (line: string) => void;
};

export const USAGE = `Usage: node lib/scripts/buildWrapped.js [--apply] [--restart] [--notify] [--max-pages=N] [--concurrency=N]

Builds ${wrappedDocPath("<uid>")} for every eligible user, one page of usersv2 at a time in document id order.
A dry run writes nothing and reports how many users are eligible. --apply writes the docs and keeps a checkpoint in
${WRAPPED_RUN}, so a stopped run resumes where it stopped. --restart begins a new build with a new window end.
--notify (after a finished build) sends the launch push and inbox item once per eligible user.
Credentials come from Application Default Credentials.`;

/** Builds or rebuilds every user's doc. Each page commits its checkpoint only after every user in it is written. */
export async function buildWrappedDocs(db: admin.firestore.Firestore, options: JobOptions): Promise<WrappedJobResult> {
  const pageSize = options.pageSize ?? 200;
  const maxPages = options.maxPages ?? Number.MAX_SAFE_INTEGER;
  const log = options.log ?? console.log;
  const runRef = db.doc(WRAPPED_RUN);
  const now = options.now ?? new Date();
  let cursor: string | null = null;
  let endMs = wrappedWindow(now).endMs;
  let removeStale = Boolean(options.restart);
  if (options.apply) {
    const run = await db.runTransaction(async (tx) => {
      const current = (await tx.get(runRef)).data();
      if (current && !options.restart) return current;
      const fresh = {phase: "building", cursor: null, endMs, removeStale: Boolean(current), startedAt: now.getTime()};
      tx.set(runRef, fresh);
      return fresh;
    });
    if (run.phase === "built") return {phase: "built", cursor: null, scanned: 0, eligible: 0, removed: 0, skipped: 0};
    cursor = run.cursor ?? null;
    endMs = run.endMs;
    removeStale = run.removeStale === true;
  }
  const window = {startMs: wrappedWindow(now).startMs, endMs};
  const walls = await loadWallIndex(db);
  const counts: WrappedJobCounts = {scanned: 0, eligible: 0, removed: 0, skipped: 0};

  for (let page = 0; page < maxPages; page++) {
    let query = db.collection("usersv2").select("coinState", "deleted")
      .orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const users = await query.get();
    await runPool(users.docs, options.concurrency ?? 8, async (user) => {
      counts.scanned += 1;
      const ref = db.doc(wrappedDocPath(user.id));
      let doc = null;
      if (user.data().deleted !== true) {
        const signals = await readWrappedSignals(db, user.id, user.data(), walls, window);
        const top = topCreator(signals);
        doc = buildWrapped(signals, top ? await readCreatorProfile(db, top.uid) : null, window, now);
      } else {
        counts.skipped += 1;
      }
      if (doc) {
        counts.eligible += 1;
        log(`${user.id} eligible ${doc.cards.map((card) => card.id).join(",")}`);
        // Merge keeps notifiedAt, so a rebuild never sends the launch push again. Every built field is replaced.
        if (options.apply) await ref.set(doc, {merge: true});
      } else if (options.apply && removeStale && (await ref.get()).exists) {
        counts.removed += 1;
        await ref.delete();
      }
    });
    const next = users.empty ? null : users.docs[users.size - 1].id;
    if (options.apply) {
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(runRef)).data();
        // A second runner must not move the checkpoint backwards or reopen a finished build.
        if (current?.phase !== "building" || current.cursor !== cursor || current.endMs !== endMs) return;
        tx.update(runRef, users.empty ? {phase: "built", cursor: null} : {cursor: next});
      });
    }
    if (users.empty) return {phase: options.apply ? "built" : "dry-run", cursor: null, ...counts};
    cursor = next;
  }
  return {phase: options.apply ? "building" : "dry-run", cursor, ...counts};
}

export type NotifyResult = {phase: string; scanned: number; notified: number; cursor: string | null};

/** Marks a doc notified before the send, so a crash can drop one push but never send two. */
export async function notifyWrapped(
  db: admin.firestore.Firestore,
  options: Omit<JobOptions, "restart"> & {send?: typeof sendToUser},
): Promise<NotifyResult> {
  const pageSize = options.pageSize ?? 200;
  const maxPages = options.maxPages ?? Number.MAX_SAFE_INTEGER;
  const send = options.send ?? sendToUser;
  const log = options.log ?? console.log;
  const runRef = db.doc(WRAPPED_RUN);
  const run = (await runRef.get()).data();
  if (run?.phase !== "built") throw new Error("Finish the build before --notify.");
  let cursor: string | null = options.apply ? run.notifyCursor ?? null : null;
  const copy = notificationCopyPayload({kind: "wrappedReady", year: WRAPPED_YEAR});
  let scanned = 0;
  let notified = 0;

  for (let page = 0; page < maxPages; page++) {
    let query = db.collectionGroup("years").orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(db.doc(cursor));
    const docs = await query.get();
    await runPool(docs.docs, options.concurrency ?? 8, async (doc) => {
      const uid = doc.ref.parent.parent?.id ?? "";
      if (doc.ref.path !== wrappedDocPath(uid)) return;
      scanned += 1;
      if (doc.data().notifiedAt) return;
      const user = (await db.doc(`usersv2/${uid}`).get()).data();
      const email = str(user?.email);
      if (!user || user.deleted === true || !email) return;
      if (!options.apply) {
        notified += 1;
        return;
      }
      const claimed = await db.runTransaction(async (tx) => {
        if ((await tx.get(doc.ref)).data()?.notifiedAt) return false;
        tx.update(doc.ref, {notifiedAt: admin.firestore.FieldValue.serverTimestamp()});
        return true;
      });
      if (!claimed) return;
      const session = (await db.doc(`usersv2/${uid}/private/session`).get()).data();
      await send({
        ...copy,
        data: {route: "wrapped"},
        modifier: email,
        channelId: "recommendations",
        scoreKind: "wrapped",
        docId: `wrapped_${WRAPPED_YEAR}_${uid}`,
        collapseKey: `wrapped_${WRAPPED_YEAR}`,
      }, {uid, email, loggedOut: user.loggedIn === false}, session?.marketingPushes !== false);
      notified += 1;
      log(`${uid} notified`);
    });
    const next = docs.empty ? null : docs.docs[docs.size - 1].ref.path;
    if (options.apply) await runRef.update({notifyCursor: next});
    if (docs.empty) return {phase: options.apply ? "notified" : "dry-run", scanned, notified, cursor: null};
    cursor = next;
  }
  return {phase: options.apply ? "notifying" : "dry-run", scanned, notified, cursor};
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.includes("--help")) {
    console.log(USAGE);
  } else {
    const number = (name: string) => {
      const raw = args.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
      return raw === undefined ? undefined : Number(raw);
    };
    const options = {apply: args.includes("--apply"), maxPages: number("max-pages"), concurrency: number("concurrency")};
    const job = args.includes("--notify") ?
      notifyWrapped(admin.firestore(), options) :
      buildWrappedDocs(admin.firestore(), {...options, restart: args.includes("--restart")});
    job.then((result) => console.log(JSON.stringify(result))).catch((err: unknown) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
