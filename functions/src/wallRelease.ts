import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db, str} from "./common";

/**
 * Scheduled release. A creator may set `releaseAt`. An admin approval of such a wall writes `releaseApprovedAt` and
 * leaves `review` false, so old clients, the rules and every public query keep it hidden. This job flips `review` and
 * stamps `publishedAt` when `releaseAt` passes. onWallApproved then runs the normal approval fan-out, and sends one
 * grouped push per creator for the walls that carry `releaseNotice: "pending"`.
 */
export const RELEASE_MIN_MS = 15 * 60 * 1000;
export const RELEASE_MAX_MS = 30 * 24 * 60 * 60 * 1000;
const PAGE = 200;

type Wall = admin.firestore.DocumentData;
const {FieldValue, Timestamp} = admin.firestore;

function millis(value: unknown): number | null {
  return value instanceof Timestamp ? value.toMillis() : null;
}

/** Approved for a later release and not public yet. */
export function isScheduledWall(wall: Wall | undefined): boolean {
  return !!wall && wall.review !== true && wall.releaseApprovedAt != null && wall.publishedAt == null &&
    millis(wall.releaseAt) !== null;
}

/** The release time a client may ask for at `nowMs` (epoch ms), or null when it is not 15 minutes to 30 days ahead. */
export function validReleaseAt(value: unknown, nowMs: number): admin.firestore.Timestamp | null {
  const ms = typeof value === "number" ? value : millis(value);
  if (ms === null || !Number.isSafeInteger(ms) || ms < nowMs + RELEASE_MIN_MS || ms > nowMs + RELEASE_MAX_MS) return null;
  return Timestamp.fromMillis(ms);
}

/** Publishes every scheduled wall whose release time has passed. Safe to run twice: a published wall is skipped. */
export async function releaseDueWalls(nowMs: number): Promise<{released: number; creators: number}> {
  const byCreator = new Map<string, admin.firestore.DocumentReference[]>();
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collection("walls").where("review", "==", false)
      .where("releaseAt", "<=", Timestamp.fromMillis(nowMs)).orderBy("releaseAt").limit(PAGE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const email = str(doc.data().email);
      if (!email || !isScheduledWall(doc.data())) continue;
      const refs = byCreator.get(email) ?? [];
      refs.push(doc.ref);
      byCreator.set(email, refs);
    }
    if (page.size < PAGE) break;
    cursor = page.docs[page.size - 1];
  }

  let released = 0;
  let failed = 0;
  for (const [email, refs] of byCreator) {
    try {
      released += await publishCreatorWalls(email, refs, nowMs);
    } catch (err) {
      failed += 1;
      logger.error("wallRelease: could not publish a creator's walls.", {wallCount: refs.length, err});
    }
  }
  if (released > 0) logger.info("wallRelease: released", {released, creators: byCreator.size});
  if (failed > 0) throw new Error(`wallRelease: ${failed} creators failed`);
  return {released, creators: byCreator.size};
}

/**
 * One transaction per creator, so every due wall of the creator turns public together and the walls share one push.
 * A colourway waits while its parent wall exists and is not public, unless the parent is released in this batch.
 */
export async function publishCreatorWalls(email: string, refs: admin.firestore.DocumentReference[],
  nowMs: number): Promise<number> {
  return db.runTransaction(async (tx) => {
    const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
    const due = snaps.filter((snap) => {
      const wall = snap.data();
      return wall && str(wall.email) === email && isScheduledWall(wall) && (millis(wall.releaseAt) ?? Infinity) <= nowMs;
    });
    const releasing = new Set(due.map((snap) => snap.id));
    const parentIds = [...new Set(due.map((snap) => str(snap.data()?.variantOf)))]
      .filter((id) => id && !id.includes("/") && !releasing.has(id));
    const parents = await Promise.all(parentIds.map((id) => tx.get(db.collection("walls").doc(id))));
    const waiting = new Set(parents.filter((p) => p.exists && p.data()?.review !== true).map((p) => p.id));
    let previousSize: number;
    do {
      previousSize = waiting.size;
      for (const snap of due) {
        if (waiting.has(str(snap.data()?.variantOf))) waiting.add(snap.id);
      }
    } while (waiting.size !== previousSize);
    const go = due.filter((snap) => !waiting.has(snap.id));
    for (const snap of go) {
      tx.update(snap.ref, {
        review: true,
        publishedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        releaseNotice: "pending",
      });
    }
    return go.length;
  });
}

/**
 * Claims the release push of a creator once every wall waiting for it is ready (onWallApproved stamps
 * `approvedNotifiedAt` when the wall's delivery is ready). Each ready wall calls this after its own stamp, so the last
 * one claims the whole set. A claimed set is never sent twice: the claim clears the marker before the push.
 */
export async function claimReleaseNotices(email: string): Promise<Array<{id: string; data: Wall}>> {
  if (!email) return [];
  return db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("email", "==", email)
      .where("releaseNotice", "==", "pending"));
    const live = rows.docs.filter((doc) => doc.data().review === true && doc.data().byStudio !== true);
    if (live.length === 0 || live.some((doc) => doc.data().approvedNotifiedAt == null)) {
      for (const doc of rows.docs) {
        if (doc.data().review !== true || doc.data().byStudio === true) {
          tx.update(doc.ref, {releaseNotice: FieldValue.delete()});
        }
      }
      return [];
    }
    for (const doc of rows.docs) tx.update(doc.ref, {releaseNotice: FieldValue.delete()});
    return live
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .sort((a, b) => (millis(b.data.releaseAt) ?? 0) - (millis(a.data.releaseAt) ?? 0));
  });
}
