import * as admin from "firebase-admin";
import {db} from "./common";
import {FAVOURITE_AGGREGATION_GATE, isPrismFavourite} from "./wallStats";
import {normalizeId, WALLPAPER_STATS} from "./viewStats";

type Options = {apply: false; cursor?: string; maxPages?: number; pageSize?: number} |
  {apply: true; epoch: string; favouritesFrozen: boolean; maxPages?: number; pageSize?: number; concurrency?: number};

function member(doc: admin.firestore.QueryDocumentSnapshot): {uid: string; wallId: string} | null {
  const parts = doc.ref.path.split("/");
  if (parts.length !== 4 || parts[0] !== "usersv2" || !isPrismFavourite(doc.id, doc.data())) return null;
  try {
    return {uid: parts[1], wallId: normalizeId(doc.id)};
  } catch {
    return null;
  }
}

/** Dry-run first. Apply requires an externally enforced write freeze until phase=ready. No historical quest/daily awards. */
export async function backfillFavouriteContributions(options: Options) {
  const pageSize = options.pageSize ?? 100;
  const maxPages = options.maxPages ?? 10;
  // Each document is still its own transaction, so aliases and hot walls serialize inside Firestore.
  const concurrency = options.apply ? options.concurrency ?? 1 : 1;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 200 ||
      !Number.isInteger(maxPages) || maxPages < 1 ||
      !Number.isInteger(concurrency) || concurrency < 1 || concurrency > 50) throw new Error("Invalid page bounds.");
  if (options.apply && (!options.favouritesFrozen || !/^[A-Za-z0-9_-]{1,64}$/.test(options.epoch))) {
    throw new Error("Apply requires a stable epoch and confirmation that favourite writes are frozen.");
  }
  let scanned = 0;
  let cursor: string | null = !options.apply ? options.cursor ?? null : null;
  const gateRef = db.doc(FAVOURITE_AGGREGATION_GATE);
  const pairs = new Set<string>();
  if (options.apply) {
    await db.runTransaction(async (tx) => {
      const gate = await tx.get(gateRef);
      if (gate.exists) {
        if (gate.data()?.epoch !== options.epoch) throw new Error("Another rollout epoch already owns the gate.");
        if (!["scanning", "publishing", "ready"].includes(gate.data()?.phase)) throw new Error("Invalid rollout phase.");
      } else {
        tx.create(gateRef, {epoch: options.epoch, phase: "scanning", cursor: null});
      }
    });
  }
  for (let page = 0; page < maxPages; page++) {
    const gate = options.apply ? (await gateRef.get()).data() : null;
    if (options.apply && gate?.epoch !== options.epoch) throw new Error("Rollout epoch changed.");
    const phase = gate?.phase ?? "dry-run";
    if (phase === "ready") return {phase, scanned, cursor: null};
    if (options.apply) cursor = gate?.cursor ?? null;
    const base = phase === "publishing" ? db.collection(WALLPAPER_STATS) : db.collectionGroup("images");
    let query = base.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(db.doc(cursor));
    const docs = await query.get();
    scanned += docs.size;
    const applyDoc = async (doc: admin.firestore.QueryDocumentSnapshot, epoch: string) => {
      const identity = phase === "publishing" ? null : member(doc);
      if (phase !== "publishing" && !identity) return;
      await db.runTransaction(async (tx) => {
        const currentGate = (await tx.get(gateRef)).data();
        if (currentGate?.epoch !== epoch || currentGate.phase !== phase) return;
        if (phase === "publishing") {
          const total = await tx.get(doc.ref.collection("favouriteBootstrap").doc(epoch));
          tx.set(doc.ref, {favs: total.data()?.count ?? 0, favouriteEpoch: epoch}, {merge: true});
        } else if (identity) {
          const stats = db.collection(WALLPAPER_STATS).doc(identity.wallId);
          const contribution = stats.collection("favouriteContributions").doc(identity.uid);
          const previous = (await tx.get(contribution)).data();
          if (previous?.epoch === epoch) return;
          const previousSequence = previous?.sequence;
          const sequence = Number.isSafeInteger(previousSequence) ? previousSequence : 0;
          tx.set(contribution, {active: true, epoch, sequence, questSequence: sequence});
          tx.set(stats.collection("favouriteBootstrap").doc(epoch), {
            count: admin.firestore.FieldValue.increment(1),
          }, {merge: true});
          // A parent doc is needed so publishing also sees walls that had no legacy aggregate.
          tx.set(stats, {favouriteEpoch: epoch}, {merge: true});
        }
      });
    };
    if (!options.apply) {
      for (const doc of docs.docs) {
        const identity = member(doc);
        if (identity) pairs.add(`${identity.uid}/${identity.wallId}`);
      }
    } else {
      // The page checkpoint moves only after every document in the page has committed.
      for (let i = 0; i < docs.size; i += concurrency) {
        await Promise.all(docs.docs.slice(i, i + concurrency).map((doc) => applyDoc(doc, options.epoch)));
      }
    }
    const nextCursor = docs.empty ? null : docs.docs[docs.size - 1].ref.path;
    if (!options.apply) {
      cursor = nextCursor;
      if (docs.empty) break;
    } else {
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(gateRef)).data();
        // Another resumable runner must not move the checkpoint backwards or reopen a completed phase.
        if (current?.epoch !== options.epoch || current.phase !== phase || current.cursor !== cursor) return;
        tx.update(gateRef, {cursor: nextCursor,
          phase: docs.empty ? (phase === "scanning" ? "publishing" : "ready") : phase});
      });
    }
  }
  if (options.apply) {
    const gate = (await gateRef.get()).data();
    return {phase: gate?.phase, scanned, cursor: gate?.cursor ?? null};
  }
  return {phase: "dry-run", scanned, uniquePairsInScan: pairs.size, cursor};
}

// Kept in this module so the CLI cannot accidentally run when a test imports the worker.
if (require.main === module) {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const epoch = args.find((arg) => arg.startsWith("--epoch="))?.slice("--epoch=".length) ?? "";
  const maxPages = Number(args.find((arg) => arg.startsWith("--max-pages="))?.slice("--max-pages=".length) ?? 10);
  const cursor = args.find((arg) => arg.startsWith("--cursor="))?.slice("--cursor=".length);
  backfillFavouriteContributions(apply ? {
    apply: true, epoch, maxPages, favouritesFrozen: args.includes("--confirm-favourites-frozen"),
    concurrency: Number(args.find((arg) => arg.startsWith("--concurrency="))?.slice("--concurrency=".length) ?? 1),
  } : {apply: false, maxPages, cursor}).then((result) => console.log(JSON.stringify(result))).catch((err: unknown) => {
    console.error(err);
    process.exitCode = 1;
  });
}
