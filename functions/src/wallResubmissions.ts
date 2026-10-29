import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isDeepStrictEqual} from "node:util";
import {isAdminCaller} from "./adminConfig";
import {CALLABLE_REGIONS, db} from "./common";
import {activeWallOwner, digest, expectedRevision, openAccount, revisionOf, sameTimestamp, signedIn, stableJson} from "./wallEditingCommon";
import {boundedDisplayText, boundedText, exactKeys, operationId, parseWallText, wallDocumentId} from "./wallMetadataValidation";
import {parseFileReference, proveCompletedWallUpload} from "./completedWallUpload";
import {wallSearchTermsFor} from "./wallSearchTerms";
import {r2Secrets} from "./r2Storage";
import {authorOf} from "./wallAuthor";
import {ownedThumbnailUrl, stored} from "./ownedAssetDelivery";

export const RESUBMISSION_ROOTS = "wallResubmissionRoots";
export const RESUBMISSIONS = "wallResubmissions";
export const RESUBMISSION_OPERATIONS = "wallResubmissionOperations";
export const RESUBMISSION_CONSUMPTIONS = "wallResubmissionConsumptions";
const options = {region: CALLABLE_REGIONS, cors: true};
const githubToken = defineSecret("GH_TOKEN");
const identityFields = ["id", "creatorUid", "email", "wallpaper_url", "wallpaper_thumb", "wallpaper_path", "wallpaper_sha",
  "thumb_path", "thumb_sha", "wallpaper_source_kind", "thumb_source_kind", "resubmitOf", "originalProtected", "originalObjectId"];
const identityOf = (data: admin.firestore.DocumentData): admin.firestore.DocumentData =>
  Object.fromEntries(identityFields.filter((key) => key in data).map((key) => [key, data[key]]));
const rootRefFor = (docId: string) => db.collection(RESUBMISSION_ROOTS).doc(digest(docId));

async function matchesIdentity(tx: admin.firestore.Transaction, data: admin.firestore.DocumentData,
  identity: admin.firestore.DocumentData, canonicalPath: string, incarnation: admin.firestore.Timestamp): Promise<boolean> {
  if (isDeepStrictEqual(identityOf(data), identity)) return true;
  // Approval can legitimately redact the public source fields. Only the private, incarnation-bound manifest
  // may reconstruct that original identity; a logical ID or mutable originalProtected flag is not proof.
  if (data.originalProtected !== true || data.id !== identity.id || typeof data.id !== "string" ||
    !/^[A-Za-z0-9_-]{1,200}$/.test(data.id)) return false;
  const manifest = (await tx.get(db.collection("ownedAssets").doc(data.id))).data();
  if (!manifest || !["ready", "deleted"].includes(manifest.status) || manifest.canonicalPath !== canonicalPath ||
    manifest.incarnation !== incarnation.toMillis() || manifest.incarnationNanos !== incarnation.nanoseconds ||
    !stored(manifest.original) || !stored(manifest.thumb) || manifest.original.uid !== identity.creatorUid ||
    manifest.thumb.uid !== identity.creatorUid || data.originalObjectId !== manifest.original.objectId ||
    data.wallpaper_url !== "" || data.wallpaper_path !== "" || data.wallpaper_sha !== "" ||
    data.thumb_path !== "" || data.thumb_sha !== "" || data.wallpaper_thumb !== ownedThumbnailUrl(manifest.thumb)) return false;
  const restored: admin.firestore.DocumentData = {...data, wallpaper_url: manifest.originalUrl, wallpaper_thumb: manifest.thumbUrl,
    wallpaper_path: manifest.original.path, wallpaper_sha: manifest.original.sha,
    thumb_path: manifest.thumb.path, thumb_sha: manifest.thumb.sha};
  delete restored.originalProtected;
  delete restored.originalObjectId;
  return isDeepStrictEqual(identityOf(restored), identity);
}
async function validAdmission(tx: admin.firestore.Transaction, wall: admin.firestore.DocumentSnapshot,
  ledger: admin.firestore.DocumentSnapshot): Promise<boolean> {
  // A new admission creates both docs together; a guarded undo updates this private doc while re-creating the wall.
  // No mutable public marker and no millisecond-rounded timestamp transform can stand in for the commit timestamp.
  return ledger.exists && wall.exists && sameTimestamp(wall.createTime, ledger.updateTime) &&
    matchesIdentity(tx, wall.data()!, ledger.data()!.identity, wall.ref.path, wall.createTime!);
}
async function validArchive(tx: admin.firestore.Transaction, archive: admin.firestore.DocumentSnapshot,
  ledger: admin.firestore.DocumentSnapshot): Promise<boolean> {
  return sameTimestamp(archive.data()?.sourceWallCreateTime, ledger.updateTime) &&
    matchesIdentity(tx, archive.data()!, ledger.data()!.identity, `walls/${archive.id}`, ledger.updateTime!);
}

export const submitWallResubmission = onCall({...options, secrets: [githubToken, ...r2Secrets], timeoutSeconds: 120},
  async (request: CallableRequest<unknown>) => {
    const uid = signedIn(request);
    const input = exactKeys(request.data, ["operationId", "sourceRejectedDocId", "original", "thumbnail", "metadata", "presentation"]);
    const op = operationId(input.operationId);
    const parentDocId = wallDocumentId(input.sourceRejectedDocId);
    const original = parseFileReference(input.original);
    const thumbnail = parseFileReference(input.thumbnail);
    const rawMetadata = exactKeys(input.metadata, ["title", "desc", "tags", "category"]);
    const metadata = parseWallText({title: rawMetadata.title, desc: rawMetadata.desc, tags: rawMetadata.tags});
    const category = boundedText(rawMetadata.category, 60);
    if (!category) throw new HttpsError("invalid-argument", "category is required.");
    const rawPresentation = exactKeys(input.presentation, ["resolution", "size"]);
    const presentation = {resolution: boundedText(rawPresentation.resolution, 80), size: boundedText(rawPresentation.size, 80)};
    const remainder = original.path.startsWith(`${uid}_`) ? original.path.slice(uid.length + 1) : "";
    if (!/^\d{10,17}_.+$/u.test(remainder) || thumbnail.path !== `thumb_${original.path}` ||
      original.sourceKind !== thumbnail.sourceKind) throw new HttpsError("invalid-argument", "Invalid original/thumbnail pairing.");
    const opKey = digest(`${uid}\0${op}`);
    const opRef = db.collection(RESUBMISSION_OPERATIONS).doc(opKey);
    const wallDocId = `wall_resub_${opKey}`;
    const logicalId = `RS${opKey.slice(0, 40)}`;
    const hash = digest(stableJson(input));
    return db.runTransaction(async (tx) => {
      const owner = await openAccount(tx, uid);
      const prior = (await tx.get(opRef)).data();
      if (prior) {
        if (prior.digest !== hash || prior.kind !== "submit") throw new HttpsError("already-exists", "operationId-conflict");
        return prior.result;
      }
      const [source, live, parentLedgerSnap] = await Promise.all([
        tx.get(db.collection("rejectedWalls").doc(parentDocId)), tx.get(db.collection("walls").doc(parentDocId)),
        tx.get(db.collection(RESUBMISSIONS).doc(parentDocId)),
      ]);
      if (!source.exists || live.exists) throw new HttpsError("failed-precondition", "rejection-unavailable-or-undone");
      const archived = source.data()!;
      if (await activeWallOwner(tx, archived) !== uid) throw new HttpsError("permission-denied", "Not your rejected wall.");
      const parentLedger = parentLedgerSnap.data();
      if (parentLedger && (parentLedger.ownerUid !== uid || !await validArchive(tx, source, parentLedgerSnap))) {
        throw new HttpsError("failed-precondition", "rejected-descendant-identity-mismatch");
      }
      if (!parentLedger && archived.resubmitOf !== undefined) throw new HttpsError("failed-precondition", "unverified-lineage");
      const rootRef = parentLedger ? db.collection(RESUBMISSION_ROOTS).doc(parentLedger.rootKey) : rootRefFor(parentDocId);
      const root = (await tx.get(rootRef)).data();
      if (root && (root.ownerUid !== uid || !parentLedger &&
        (!isDeepStrictEqual(root.sourceIdentity, identityOf(archived)) || root.sourceIncarnation &&
          !sameTimestamp(root.sourceIncarnation, archived.sourceWallCreateTime)))) {
        throw new HttpsError("failed-precondition", "root-identity-mismatch");
      }
      if (parentLedger && !root) throw new HttpsError("failed-precondition", "lineage-root-missing");
      const count = root?.count ?? 0;
      if (!Number.isInteger(count) || count < 0 || count >= 3) throw new HttpsError("resource-exhausted", "resubmission-limit");
      const wallRef = db.collection("walls").doc(wallDocId);
      const [target, targetArchive, attemptLedger, originalProof, thumbProof] = await Promise.all([
        tx.get(wallRef), tx.get(db.collection("rejectedWalls").doc(wallDocId)),
        tx.get(db.collection(RESUBMISSIONS).doc(wallDocId)),
        proveCompletedWallUpload(tx, uid, original, "original", source.createTime!),
        proveCompletedWallUpload(tx, uid, thumbnail, "thumbnail", source.createTime!),
      ]);
      if (target.exists || targetArchive.exists || attemptLedger.exists) throw new HttpsError("already-exists", "wall-identity-used");
      for (const [file, oldPath, oldSha, oldUrl, proof] of [
        [original, archived.wallpaper_path, archived.wallpaper_sha, archived.wallpaper_url, originalProof],
        [thumbnail, archived.thumb_path, archived.thumb_sha, archived.wallpaper_thumb, thumbProof],
      ] as const) {
        if (file.path === oldPath || proof.url && proof.url === oldUrl ||
          file.path === oldPath && file.sha === oldSha) throw new HttpsError("failed-precondition", "fresh-files-required");
      }
      const proofs = [originalProof, thumbProof];
      const consumptionRefs = proofs.map((proof) => db.collection(RESUBMISSION_CONSUMPTIONS)
        .doc(digest(`${proof.fileKey}\0${proof.generation}`)));
      const consumed = await Promise.all(consumptionRefs.map((ref) => tx.get(ref)));
      if (consumed.some((snapshot) => snapshot.exists)) throw new HttpsError("failed-precondition", "upload-already-consumed");
      const attempt = count + 1;
      const at = admin.firestore.FieldValue.serverTimestamp();
      const result = {wallDocId, logicalId, attempt, operationId: op};
      const wall = {id: logicalId, creatorUid: uid, email: archived.email, ...authorOf(owner),
        wallpaper_provider: "Prism", wallpaper_url: originalProof.url, wallpaper_thumb: thumbProof.url,
        wallpaper_path: original.path, wallpaper_sha: original.sha, wallpaper_source_kind: original.sourceKind,
        thumb_path: thumbnail.path, thumb_sha: thumbnail.sha, thumb_source_kind: thumbnail.sourceKind,
        ...metadata, category, ...presentation, review: false, isAiGenerated: false, createdAt: at,
        collections: ["community"], resubmitOf: parentDocId};
      tx.create(wallRef, {...wall, searchTerms: wallSearchTermsFor(wall)});
      tx.create(db.collection(RESUBMISSIONS).doc(wallDocId), {ownerUid: uid, parentDocId, rootKey: rootRef.id,
        rootDocId: root?.rootDocId ?? parentDocId, attempt, operationId: op, digest: hash, result,
        previousReason: typeof archived.rejectionReason === "string" ? archived.rejectionReason.slice(0, 2000) : "",
        sourceArchiveCreateTime: source.createTime, sourceArchiveRevision: revisionOf(source),
        admittedAt: at, identity: identityOf(wall)});
      tx.set(rootRef, root ? {...root, count: attempt} : {ownerUid: uid, rootDocId: parentDocId,
        sourceIdentity: identityOf(archived), sourceIncarnation: archived.sourceWallCreateTime ?? null, count: attempt});
      tx.create(opRef, {ownerUid: uid, actorUid: uid, kind: "submit", digest: hash, operationId: op, result, createdAt: at});
      consumptionRefs.forEach((ref, i) => tx.create(ref, {ownerUid: uid, operationId: op, wallDocId,
        fileKey: proofs[i].fileKey, generation: proofs[i].generation, createdAt: at}));
      return result;
    });
  });

async function adminUid(request: CallableRequest<unknown>): Promise<string> {
  const uid = signedIn(request);
  if (!await isAdminCaller(request.auth)) throw new HttpsError("permission-denied", "Only admins can inspect resubmissions.");
  return uid;
}
export const getWallResubmissionContext = onCall(options, async (request: CallableRequest<unknown>) => {
  await adminUid(request);
  const input = exactKeys(request.data, ["wallDocIds"]);
  if (!Array.isArray(input.wallDocIds) || input.wallDocIds.length < 1 || input.wallDocIds.length > 50) {
    throw new HttpsError("invalid-argument", "Supply 1 to 50 wallDocIds.");
  }
  const ids = [...new Set(input.wallDocIds.map(wallDocumentId))];
  const entries = await Promise.all(ids.map((id) => db.runTransaction(async (tx) => {
    const [wall, ledger, archive, children] = await Promise.all([
      tx.get(db.collection("walls").doc(id)), tx.get(db.collection(RESUBMISSIONS).doc(id)),
      tx.get(db.collection("rejectedWalls").doc(id)),
      tx.get(db.collection(RESUBMISSIONS).where("parentDocId", "==", id).limit(1)),
    ]);
    const row = ledger.data();
    const common = {rejectionRevision: archive.exists ? revisionOf(archive) : null,
      rejectionOperationId: archive.data()?.rejectionOperationId ?? null,
      wallRevision: wall.exists ? revisionOf(wall) : null, hasAdmittedChild: !children.empty};
    return [id, await validAdmission(tx, wall, ledger) ? {verified: true as const, attempt: row!.attempt, rootDocId: row!.rootDocId,
      parentDocId: row!.parentDocId, previousReason: row!.previousReason, ...common} : {verified: false as const, ...common}] as const;
  })));
  return {contexts: Object.fromEntries(entries)};
});

/** Admin undo is a continuation, not another admission. It cannot race or hide an already admitted child. */
export const undoWallRejection = onCall(options, async (request: CallableRequest<unknown>) => {
  const uid = await adminUid(request);
  const input = exactKeys(request.data, ["wallDocId", "expectedRejectionRevision", "operationId"]);
  const id = wallDocumentId(input.wallDocId);
  const expected = expectedRevision(input.expectedRejectionRevision);
  const op = operationId(input.operationId);
  const hash = digest(stableJson(input));
  const opRef = db.collection(RESUBMISSION_OPERATIONS).doc(digest(`${uid}\0${op}`));
  return db.runTransaction(async (tx) => {
    await openAccount(tx, uid);
    const prior = (await tx.get(opRef)).data();
    if (prior) {
      if (prior.digest !== hash || prior.kind !== "undo") throw new HttpsError("already-exists", "operationId-conflict");
      return prior.result;
    }
    const archiveRef = db.collection("rejectedWalls").doc(id);
    const wallRef = db.collection("walls").doc(id);
    const [archive, live, ledgerSnap, rootSnap, children] = await Promise.all([
      tx.get(archiveRef), tx.get(wallRef), tx.get(db.collection(RESUBMISSIONS).doc(id)), tx.get(rootRefFor(id)),
      tx.get(db.collection(RESUBMISSIONS).where("parentDocId", "==", id).limit(1)),
    ]);
    if (!archive.exists || live.exists || revisionOf(archive) !== expected || !children.empty) {
      throw new HttpsError("aborted", "rejection-changed-or-already-resubmitted");
    }
    const ownerUid = await activeWallOwner(tx, archive.data()!);
    const ledger = ledgerSnap.data();
    if (ledger && (ledger.ownerUid !== ownerUid || !await validArchive(tx, archive, ledgerSnap))) throw new HttpsError("aborted", "lineage-identity-mismatch");
    const root = rootSnap.data();
    if (root && (root.ownerUid !== ownerUid || !isDeepStrictEqual(root.sourceIdentity, identityOf(archive.data()!)))) {
      throw new HttpsError("aborted", "root-identity-mismatch");
    }
    const restored = {...archive.data()!};
    for (const key of ["rejectedAt", "rejectionReason", "rejectionOperationId", "sourceWallCreateTime"]) delete restored[key];
    const at = admin.firestore.FieldValue.serverTimestamp();
    tx.create(wallRef, restored);
    tx.delete(archiveRef);
    if (ledger) tx.update(ledgerSnap.ref, {continuedAt: at, identity: identityOf(restored)});
    const result = {wallDocId: id, operationId: op};
    tx.create(opRef, {ownerUid, actorUid: uid, kind: "undo", digest: hash, operationId: op, result, createdAt: at});
    return result;
  });
});

/** SDK client snapshots do not expose createTime. Capture rejection identity on the server instead. */
export const rejectWallForReview = onCall(options, async (request: CallableRequest<unknown>) => {
  const uid = await adminUid(request);
  const input = exactKeys(request.data, ["wallDocId", "expectedWallRevision", "expectedReview", "rejectionOperationId", "reason"]);
  if (typeof input.expectedReview !== "boolean") throw new HttpsError("invalid-argument", "expectedReview must be boolean.");
  const id = wallDocumentId(input.wallDocId);
  const expected = expectedRevision(input.expectedWallRevision);
  const op = operationId(input.rejectionOperationId);
  const reason = boundedDisplayText(input.reason, 2000);
  const hash = digest(stableJson(input));
  const opRef = db.collection(RESUBMISSION_OPERATIONS).doc(digest(`${uid}\0${op}`));
  return db.runTransaction(async (tx) => {
    await openAccount(tx, uid);
    const prior = (await tx.get(opRef)).data();
    if (prior) {
      if (prior.kind !== "reject" || prior.digest !== hash) throw new HttpsError("already-exists", "operationId-conflict");
      return prior.result;
    }
    const wallRef = db.collection("walls").doc(id);
    const archiveRef = db.collection("rejectedWalls").doc(id);
    const [wall, archive] = await Promise.all([tx.get(wallRef), tx.get(archiveRef)]);
    if (!wall.exists || wall.data()?.review !== input.expectedReview || archive.exists || revisionOf(wall) !== expected) {
      throw new HttpsError("aborted", "wall-changed");
    }
    const ownerUid = await activeWallOwner(tx, wall.data()!);
    const at = admin.firestore.FieldValue.serverTimestamp();
    const result = {wallDocId: id, rejectionOperationId: op};
    tx.create(archiveRef, {...wall.data(), rejectionReason: reason, rejectionOperationId: op,
      sourceWallCreateTime: wall.createTime, rejectedAt: at});
    tx.delete(wallRef);
    tx.create(opRef, {ownerUid, actorUid: uid, kind: "reject", digest: hash, operationId: op, result, createdAt: at});
    return result;
  });
});

/** Only remove the exact unverified pointer from the exact created incarnation. */
export async function sanitizeResubmitOf(expected: admin.firestore.DocumentSnapshot): Promise<boolean> {
  const value = expected.data()?.resubmitOf;
  if (value === undefined) return false;
  return db.runTransaction(async (tx) => {
    const [current, ledger] = await Promise.all([
      tx.get(expected.ref), tx.get(db.collection(RESUBMISSIONS).doc(expected.id)),
    ]);
    if (!current.exists || !sameTimestamp(current.createTime, expected.createTime) ||
      !isDeepStrictEqual(current.data()?.resubmitOf, value) || await validAdmission(tx, current, ledger)) return false;
    tx.update(expected.ref, {resubmitOf: admin.firestore.FieldValue.delete()});
    return true;
  });
}
