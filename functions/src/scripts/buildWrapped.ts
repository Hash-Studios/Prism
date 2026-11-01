import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto";

import {str} from "../common";
import {notificationCopyPayload} from "../notificationCatalog";
import {sendToUser} from "../notificationHelper";
import {
  buildWrapped,
  loadWallIndex,
  readCreatorProfile,
  readWrappedSignals,
  topCreator,
  WRAPPED_COLLECTION,
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
  beforeGuardTransaction?: (uid: string, operation: "write" | "remove") => Promise<void>;
};

function validateOptions(options: Pick<JobOptions, "pageSize" | "maxPages" | "concurrency" | "now">): void {
  if (options.pageSize !== undefined && (!Number.isInteger(options.pageSize) || options.pageSize < 1)) {
    throw new Error("Invalid --page-size. Use a positive integer.");
  }
  if (options.maxPages !== undefined && (!Number.isInteger(options.maxPages) || options.maxPages < 1)) {
    throw new Error("Invalid --max-pages. Use a positive integer.");
  }
  if (options.concurrency !== undefined &&
    (!Number.isInteger(options.concurrency) || options.concurrency < 1 || options.concurrency > 50)) {
    throw new Error("Invalid --concurrency. Use an integer from 1 to 50.");
  }
  if (options.now && !Number.isFinite(options.now.getTime())) throw new Error("Invalid build time.");
}

export const USAGE = `Usage: node lib/scripts/buildWrapped.js [--apply] [--restart] [--notify] [--page-size=N] [--max-pages=N] [--concurrency=N]

Builds ${wrappedDocPath("<uid>")} for every eligible user, one page of usersv2 at a time in document id order.
A dry run writes nothing and reports how many users are eligible. --apply writes the docs and keeps a checkpoint in
${WRAPPED_RUN}, so a stopped run resumes where it stopped. --restart begins a new build with a new window end.
--notify (after a finished build) sends the launch push and inbox item once per eligible user.
Credentials come from Application Default Credentials.`;

/** Builds or rebuilds every user's doc. Each page commits its checkpoint only after every user in it is written. */
export async function buildWrappedDocs(db: admin.firestore.Firestore, options: JobOptions): Promise<WrappedJobResult> {
  validateOptions(options);
  const pageSize = options.pageSize ?? 200;
  const maxPages = options.maxPages ?? Number.MAX_SAFE_INTEGER;
  const log = options.log ?? console.log;
  const runRef = db.doc(WRAPPED_RUN);
  const now = options.now ?? new Date();
  let cursor: string | null = null;
  let endMs = wrappedWindow(now).endMs;
  let runId: string | null = null;
  let removeStale = Boolean(options.restart);
  if (options.apply) {
    const run = await db.runTransaction(async (tx) => {
      const current = (await tx.get(runRef)).data();
      if (current && !options.restart) return current;
      const fresh = {phase: "building", cursor: null, endMs, removeStale: Boolean(current), startedAt: now.getTime(),
        runId: randomUUID()};
      tx.set(runRef, fresh);
      return fresh;
    });
    if (run.phase === "built") return {phase: "built", cursor: null, scanned: 0, eligible: 0, removed: 0, skipped: 0};
    cursor = run.cursor ?? null;
    endMs = run.endMs;
    runId = run.runId;
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
        if (options.apply) {
          await options.beforeGuardTransaction?.(user.id, "write");
          await db.runTransaction(async (tx) => {
            const [account, deletion, marker, currentRun] = await Promise.all([
              tx.get(db.doc(`usersv2/${user.id}`)), tx.get(db.doc(`creatorDeletionState/${user.id}`)),
              tx.get(db.doc(`${WRAPPED_COLLECTION}/${user.id}`)), tx.get(runRef),
            ]);
            if (!account.exists || account.data()?.deleted === true || deletion.data()?.closed === true ||
              currentRun.data()?.phase !== "building" || currentRun.data()?.runId !== runId ||
              currentRun.data()?.endMs !== endMs) return;
            const notifiedAt = marker.data()?.[`notifiedAt_${WRAPPED_YEAR}`];
            tx.set(ref, notifiedAt ? {...doc, notifiedAt} : doc, {merge: true});
          });
        }
      } else if (options.apply && removeStale) {
        await options.beforeGuardTransaction?.(user.id, "remove");
        const removed = await db.runTransaction(async (tx) => {
          const markerRef = db.doc(`${WRAPPED_COLLECTION}/${user.id}`);
          const [existing, marker, currentRun] = await Promise.all([tx.get(ref), tx.get(markerRef), tx.get(runRef)]);
          if (currentRun.data()?.phase !== "building" || currentRun.data()?.runId !== runId ||
            currentRun.data()?.endMs !== endMs) return false;
          if (!existing.exists) return false;
          const notifiedAt = existing.data()?.notifiedAt;
          if (notifiedAt && !marker.data()?.[`notifiedAt_${WRAPPED_YEAR}`]) {
            tx.set(markerRef, {[`notifiedAt_${WRAPPED_YEAR}`]: notifiedAt}, {merge: true});
          }
          tx.delete(ref);
          return true;
        });
        if (removed) counts.removed += 1;
      }
    });
    const next = users.empty ? null : users.docs[users.size - 1].id;
    if (options.apply) {
      const advanced = await db.runTransaction(async (tx) => {
        const current = (await tx.get(runRef)).data();
        // A second runner must not move the checkpoint backwards or reopen a finished build.
        if (current?.phase !== "building" || current.cursor !== cursor || current.endMs !== endMs ||
          current.runId !== runId) return false;
        tx.update(runRef, users.empty ? {phase: "built", cursor: null} : {cursor: next});
        return true;
      });
      if (!advanced) return {phase: "superseded", cursor, ...counts};
    }
    if (users.empty) return {phase: options.apply ? "built" : "dry-run", cursor: null, ...counts};
    cursor = next;
  }
  return {phase: options.apply ? "building" : "dry-run", cursor, ...counts};
}

export type NotifyResult = {phase: string; scanned: number; notified: number; cursor: string | null};

/** Claims the yearly notification on the private parent doc so eligibility rebuilds cannot erase the claim. */
export async function claimWrappedNotification(
  db: admin.firestore.Firestore,
  uid: string,
  wrappedRef: admin.firestore.DocumentReference,
  runId: string,
  copy: ReturnType<typeof notificationCopyPayload>,
): Promise<string | null> {
  const accountRef = db.doc(`usersv2/${uid}`);
  const deletionRef = db.doc(`creatorDeletionState/${uid}`);
  const markerRef = db.doc(`${WRAPPED_COLLECTION}/${uid}`);
  const runRef = db.doc(WRAPPED_RUN);
  const inboxRef = db.doc(`notifications/wrapped_${WRAPPED_YEAR}_${uid}`);
  const markerField = `notifiedAt_${WRAPPED_YEAR}`;
  return db.runTransaction(async (tx) => {
    const [wrapped, marker, account, deletion, run] = await Promise.all([
      tx.get(wrappedRef), tx.get(markerRef), tx.get(accountRef), tx.get(deletionRef), tx.get(runRef),
    ]);
    if (!wrapped.exists || !account.exists || account.data()?.deleted === true || deletion.data()?.closed === true) {
      return null;
    }
    if (run.data()?.phase !== "built" || run.data()?.runId !== runId) return null;
    const email = str(account.data()?.email);
    if (!email) return null;
    const notifiedAt = wrapped.data()?.notifiedAt;
    if (marker.data()?.[markerField] || notifiedAt) {
      // Migrate claims made before the parent marker existed, without sending the notice again.
      if (!marker.data()?.[markerField]) {
        tx.set(markerRef, {[markerField]: notifiedAt}, {merge: true});
      }
      return null;
    }
    const claimedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.set(markerRef, {[markerField]: claimedAt}, {merge: true});
    tx.update(wrappedRef, {notifiedAt: claimedAt});
    tx.set(inboxRef, {
      notification: {title: copy.title, body: copy.body},
      message: {kind: copy.message.kind, args: copy.message.args},
      data: {route: "wrapped", imageUrl: "", url: "", pageName: "", arguments: []},
      modifier: email,
      pushHandled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return email;
  });
}

/** Marks a doc notified before the send, so a crash can drop one push but never send two. */
export async function notifyWrapped(
  db: admin.firestore.Firestore,
  options: Omit<JobOptions, "restart"> & {send?: typeof sendToUser},
): Promise<NotifyResult> {
  validateOptions(options);
  const pageSize = options.pageSize ?? 200;
  const maxPages = options.maxPages ?? Number.MAX_SAFE_INTEGER;
  const send = options.send ?? sendToUser;
  const log = options.log ?? console.log;
  const runRef = db.doc(WRAPPED_RUN);
  const run = (await runRef.get()).data();
  if (run?.phase !== "built") throw new Error("Finish the build before --notify.");
  const runId = run.runId;
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
      const claimedEmail = await claimWrappedNotification(db, uid, doc.ref, runId, copy);
      if (!claimedEmail) return;
      const session = (await db.doc(`usersv2/${uid}/private/session`).get()).data();
      await send({
        ...copy,
        data: {route: "wrapped"},
        modifier: claimedEmail,
        channelId: "recommendations",
        scoreKind: "wrapped",
        docId: `wrapped_${WRAPPED_YEAR}_${uid}`,
        collapseKey: `wrapped_${WRAPPED_YEAR}`,
        pushOnly: true,
      }, {uid, email: claimedEmail, loggedOut: user.loggedIn === false}, session?.marketingPushes !== false);
      notified += 1;
      log(`${uid} notified`);
    });
    const next = docs.empty ? null : docs.docs[docs.size - 1].ref.path;
    if (options.apply) {
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(runRef)).data();
        if (current?.phase === "built" && current.runId === runId) tx.update(runRef, {notifyCursor: next});
      });
    }
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
      const matches = args.filter((arg) => arg === `--${name}` || arg.startsWith(`--${name}=`));
      if (matches.length === 0) return undefined;
      if (matches.length !== 1 || !matches[0].startsWith(`--${name}=`)) {
        throw new Error(`Invalid --${name}. Use --${name}=N.`);
      }
      return Number(matches[0].slice(name.length + 3));
    };
    const options = {apply: args.includes("--apply"), pageSize: number("page-size"), maxPages: number("max-pages"),
      concurrency: number("concurrency")};
    const job = args.includes("--notify") ?
      notifyWrapped(admin.firestore(), options) :
      buildWrappedDocs(admin.firestore(), {...options, restart: args.includes("--restart")});
    job.then((result) => console.log(JSON.stringify(result))).catch((err: unknown) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
