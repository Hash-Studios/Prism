import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isDeepStrictEqual} from "node:util";
import {isAdminCaller} from "./adminConfig";
import {CALLABLE_REGIONS, db, utcDateString} from "./common";
import {activeWallOwner, digest, expectedRevision, openAccount, revisionOf, sameTimestamp, signedIn,
  stableJson, timestampKey} from "./wallEditingCommon";
import {exactKeys, operationId, parseWallText, wallDocumentId, wallTextForEdit, type WallText} from "./wallMetadataValidation";
import {wallSearchTermsFor} from "./wallSearchTerms";

export const METADATA_EDITS = "wallMetadataEdits";
export const METADATA_OPERATIONS = "wallMetadataOperations";
export const METADATA_RATES = "wallMetadataEditRates";
const options = {region: CALLABLE_REGIONS, cors: true};
const textKeys = ["title", "desc", "tags"];
const presentText = (data: admin.firestore.DocumentData): admin.firestore.DocumentData =>
  Object.fromEntries(textKeys.filter((k) => Object.prototype.hasOwnProperty.call(data, k)).map((k) => [k, data[k]]));

async function requireAdmin(request: CallableRequest<unknown>): Promise<string> {
  const uid = signedIn(request);
  if (!await isAdminCaller(request.auth)) throw new HttpsError("permission-denied", "Only admins can read or revert edits.");
  return uid;
}
export const getWallMetadataForEdit = onCall(options, async (request: CallableRequest<unknown>) => {
  const uid = signedIn(request);
  const data = exactKeys(request.data, ["wallDocId"]);
  const wallDocId = wallDocumentId(data.wallDocId);
  const adminCaller = await isAdminCaller(request.auth);
  return db.runTransaction(async (tx) => {
    await openAccount(tx, uid);
    const wall = await tx.get(db.collection("walls").doc(wallDocId));
    if (!wall.exists) throw new HttpsError("not-found", "wall-missing");
    const ownerUid = await activeWallOwner(tx, wall.data()!);
    if (ownerUid !== uid && !adminCaller) throw new HttpsError("permission-denied", "Not your wall.");
    return {metadata: wallTextForEdit(wall.data()!), status: wall.data()!.review === true ? "approved" : "pending",
      revision: revisionOf(wall)};
  });
});

type EditResult = {metadata: WallText; status: "approved"; revision: string; auditId: string | null; changed: boolean};
async function operationResult(ref: admin.firestore.DocumentReference): Promise<EditResult> {
  const snapshot = await ref.get();
  const data = snapshot.data()!;
  return {metadata: data.metadata, status: "approved", auditId: data.auditId, changed: data.changed,
    revision: data.changed ? digest(`${timestampKey(data.incarnation)}|${timestampKey(snapshot.createTime)}`) : data.revision};
}

async function save(request: CallableRequest<unknown>, revert: boolean): Promise<EditResult> {
  const uid = signedIn(request);
  if (revert) await requireAdmin(request);
  const input = exactKeys(request.data, revert ? ["wallDocId", "auditId", "operationId", "expectedRevision"] :
    ["wallDocId", "operationId", "expectedRevision", "metadata"]);
  const wallDocId = wallDocumentId(input.wallDocId);
  const op = operationId(input.operationId);
  const expected = expectedRevision(input.expectedRevision);
  const auditId = revert ? operationId(input.auditId) : null;
  const parsed = revert ? null : parseWallText(input.metadata);
  const hash = digest(stableJson({kind: revert ? "revert" : "edit", ...input}));
  const opRef = db.collection(METADATA_OPERATIONS).doc(digest(`${uid}\0${op}`));
  const editRef = db.collection(METADATA_EDITS).doc(opRef.id);
  const day = utcDateString();
  const rateRef = db.collection(METADATA_RATES).doc(`${uid}_${day}`);
  await db.runTransaction(async (tx) => {
    await openAccount(tx, uid);
    const prior = (await tx.get(opRef)).data();
    if (prior) {
      if (prior.digest !== hash) throw new HttpsError("already-exists", "operationId was used for another request.");
      return;
    }
    const wall = await tx.get(db.collection("walls").doc(wallDocId));
    if (!wall.exists) throw new HttpsError("not-found", "wall-missing");
    const current = wall.data()!;
    const ownerUid = await activeWallOwner(tx, current);
    if (!revert && ownerUid !== uid) throw new HttpsError("permission-denied", "Not your wall.");
    if (current.review !== true) throw new HttpsError("failed-precondition", "wall-not-approved");
    if (revisionOf(wall) !== expected) throw new HttpsError("aborted", "metadata-conflict");
    const before = presentText(current);
    let after: admin.firestore.DocumentData = parsed!;
    if (revert) {
      const selected = (await tx.get(db.collection(METADATA_EDITS).doc(auditId!))).data();
      const latest = await tx.get(db.collection(METADATA_EDITS).where("wallDocId", "==", wallDocId).orderBy("createdAt", "desc").limit(1));
      if (!selected || selected.wallDocId !== wallDocId || !sameTimestamp(selected.incarnation, wall.createTime) ||
        latest.docs[0]?.id !== auditId || !isDeepStrictEqual(selected.after, before)) {
        throw new HttpsError("aborted", "edit-is-not-latest");
      }
      // Validate legacy data, but restore exact values and field presence, never a normalized full-wall snapshot.
      const original = selected.before;
      parseWallText({...{title: "", desc: "", tags: []}, ...original});
      after = original;
    }
    const changed = !isDeepStrictEqual(before, after);
    const rate = (await tx.get(rateRef)).data();
    const count = rate?.day === day && Number.isSafeInteger(rate.count) ? rate.count : 0;
    if (changed && !revert && count >= 10) throw new HttpsError("resource-exhausted", "daily-metadata-limit");
    const committedAt = admin.firestore.FieldValue.serverTimestamp();
    const resultMetadata = wallTextForEdit(after);
    tx.create(opRef, {uid, actorUid: uid, ownerUid, wallDocId, digest: hash, operationId: op, incarnation: wall.createTime,
      committedAt, metadata: resultMetadata, changed, auditId: changed ? editRef.id : null, revision: expected});
    if (!changed) return;
    const next = {...current};
    const patch: admin.firestore.DocumentData = {};
    for (const key of textKeys) {
      if (key in after) {
        next[key] = after[key]; patch[key] = after[key];
      } else {
        delete next[key]; patch[key] = admin.firestore.FieldValue.delete();
      }
    }
    patch.searchTerms = wallSearchTermsFor(next);
    tx.update(wall.ref, patch);
    tx.create(editRef, {wallDocId, ownerUid, actorUid: uid, operationId: op, digest: hash, incarnation: wall.createTime,
      createdAt: committedAt, before, after, ...(revert ? {revertsAuditId: auditId} : {})});
    if (!revert) tx.set(rateRef, {uid, day, count: count + 1});
  });
  return operationResult(opRef);
}
export const editWallMetadata = onCall(options, (request: CallableRequest<unknown>) => save(request, false));
export const revertWallMetadata = onCall(options, (request: CallableRequest<unknown>) => save(request, true));

export const listWallMetadataEdits = onCall(options, async (request: CallableRequest<unknown>) => {
  await requireAdmin(request);
  const input = exactKeys(request.data, ["wallDocId", "cursor", "limit"], ["wallDocId"]);
  const wallDocId = wallDocumentId(input.wallDocId);
  const limit = input.limit ?? 20;
  if (!Number.isInteger(limit) || (limit as number) < 1 || (limit as number) > 50) throw new HttpsError("invalid-argument", "Invalid limit.");
  let query = db.collection(METADATA_EDITS).where("wallDocId", "==", wallDocId).orderBy("createdAt", "desc").limit(limit as number);
  if (input.cursor !== undefined && input.cursor !== null) {
    const cursor = await db.collection(METADATA_EDITS).doc(operationId(input.cursor)).get();
    if (!cursor.exists || cursor.data()?.wallDocId !== wallDocId) throw new HttpsError("invalid-argument", "Invalid cursor.");
    query = query.startAfter(cursor);
  }
  const [rows, latest, wall] = await Promise.all([query.get(),
    db.collection(METADATA_EDITS).where("wallDocId", "==", wallDocId).orderBy("createdAt", "desc").limit(1).get(),
    db.collection("walls").doc(wallDocId).get()]);
  return {edits: rows.docs.map((doc) => {
    const d = doc.data();
    return {auditId: doc.id, before: d.before, after: d.after, actorUid: d.actorUid,
      createdAt: d.createdAt.toDate().toISOString(), canRevert: latest.docs[0]?.id === doc.id && wall.data()?.review === true &&
        sameTimestamp(d.incarnation, wall.createTime) && isDeepStrictEqual(d.after, presentText(wall.data()!))};
  }), cursor: rows.size === limit ? rows.docs[rows.size - 1].id : null};
});
