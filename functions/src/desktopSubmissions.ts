import * as admin from "firebase-admin";
import {createHash, randomUUID} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {CALLABLE_REGIONS, db, REGION, str} from "./common";
import {base64DecodedBytes, isAllowedImageContent, isValidBase64, reserveUploadSlot} from "./githubContent";
import {notificationCopyPayload} from "./notificationCatalog";
import {isLoggedOut, sendToUser} from "./notificationHelper";
import {R2Storage, r2Secrets} from "./r2Storage";
import {
  DESKTOP_COMPANIONS, DESKTOP_JPEG_QUALITY, DESKTOP_SIZE, DESKTOP_THUMB_QUALITY, DESKTOP_THUMB_SIZE, DESKTOP_WIDE_SIZE,
  creatorDesktopVersion, type DesktopObject, type DesktopVariant, desktopObjectName, desktopThumbObject, desktopThumbUrl,
  parseDesktopVariant, SHARE_ID,
} from "./studio/desktop";
import {activeWallOwner, signedIn} from "./wallEditingCommon";
import {boundedDisplayText, exactKeys, wallDocumentId} from "./wallMetadataValidation";

/**
 * A creator's desktop version of their own approved wall. The upload waits in `desktopSubmissions` until an admin
 * decides. Only approval links it: the companion manifest and the wall's `desktopVariant` change in one transaction,
 * in the same shape as a Studio companion, so every reader of `desktopVariant` serves it unchanged.
 */
export const DESKTOP_SUBMISSIONS = "desktopSubmissions";
export const DESKTOP_STORAGE_LEASES = "desktopStorageLeases";
export const DESKTOP_MIN_WIDTH = 1920;
export const DESKTOP_ASPECT_TOLERANCE = 0.02;
export const DESKTOP_ASPECTS = {"16:10": 16 / 10, "16:9": 16 / 9} as const;
export const MAX_DESKTOP_UPLOAD_BYTES = 15 * 1024 * 1024;
/** Longer than a submit can run, so an older `uploading` submission is a crashed one. */
export const DESKTOP_UPLOAD_LEASE_MS = 10 * 60 * 1000;
export const DESKTOP_REJECT_CODES = ["lowResolution", "watermark", "blurry", "copyright", "duplicate", "notWallpaper",
  "other"] as const;

export type DesktopAspect = keyof typeof DESKTOP_ASPECTS;
/** `uploading` holds the files while they are stored. `withdrawn` is a submission whose wall or owner went away. */
export type DesktopSubmissionState = "uploading" | "pending" | "approved" | "rejected" | "withdrawn";
export type DesktopImageProblem = "desktop-not-landscape" | "desktop-aspect-ratio" | "desktop-too-small";
type StoredObject = {kind: "private" | "preview"; object: string};
interface DesktopThumb {object: string; sha256: string; url: string; width: number; height: number}
interface DesktopFiles {original: DesktopObject; wide: DesktopObject; thumb: DesktopThumb}

const ACTIVE: DesktopSubmissionState[] = ["uploading", "pending"];
const now = () => admin.firestore.FieldValue.serverTimestamp();
/** Longer than a callable can run, so a lease older than this belongs to a crashed run. */
const STORAGE_LEASE_MS = 10 * 60_000;

/**
 * Runs one creator storage step per wall at a time. Identical uploads share object names, so a store must not
 * overlap a delete of the same names. Studio companions do not take this lease: a Studio wall has no creator owner.
 */
async function withStorageLease<T>(shareId: string, callback: () => Promise<T>): Promise<T> {
  const ref = db.collection(DESKTOP_STORAGE_LEASES).doc(shareId);
  const token = randomUUID();
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data();
    if (current?.leaseUntil instanceof admin.firestore.Timestamp && current.leaseUntil.toMillis() > Date.now()) {
      throw new HttpsError("unavailable", "desktop-storage-busy");
    }
    tx.set(ref, {token, leaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + STORAGE_LEASE_MS)});
  });
  try {
    return await callback();
  } finally {
    await db.runTransaction(async (tx) => {
      if ((await tx.get(ref)).data()?.token === token) tx.delete(ref);
    }).catch((err) => logger.warn("desktop: could not release the storage lease.", {shareId, err}));
  }
}

/** The aspect of an upright image, or why it cannot be a desktop version. The order matches the app's checks. */
export function checkDesktopImage(width: number, height: number): {aspect: DesktopAspect} | {problem: DesktopImageProblem} {
  if (!(width > 0 && height > 0) || width <= height) return {problem: "desktop-not-landscape"};
  const ratio = width / height;
  const aspect = (Object.keys(DESKTOP_ASPECTS) as DesktopAspect[]).find((key) =>
    Math.abs(ratio - DESKTOP_ASPECTS[key]) / DESKTOP_ASPECTS[key] <= DESKTOP_ASPECT_TOLERANCE);
  if (!aspect) return {problem: "desktop-aspect-ratio"};
  return width < DESKTOP_MIN_WIDTH ? {problem: "desktop-too-small"} : {aspect};
}

/**
 * The upload as the Studio companion files: a 16:10 original, a 16:9 wide and the thumbnail. Each is a cover fit of
 * the upright upload, so a 16:9 upload keeps its full width in the wide file. A 1920 px upload is enlarged to 2560.
 */
export async function renderCreatorDesktop(bytes: Buffer):
  Promise<{original: Buffer; wide: Buffer; thumb: Buffer; width: number; height: number; aspect: DesktopAspect}> {
  const {default: sharp} = await import("sharp");
  const invalid = () => new HttpsError("invalid-argument", "desktop-image-invalid");
  const meta = await sharp(bytes).metadata().catch(() => {
    throw invalid();
  });
  const turned = (meta.orientation ?? 1) >= 5;
  const width = (turned ? meta.height : meta.width) ?? 0;
  const height = (turned ? meta.width : meta.height) ?? 0;
  const checked = checkDesktopImage(width, height);
  if ("problem" in checked) throw new HttpsError("invalid-argument", checked.problem);
  const jpeg = {quality: DESKTOP_JPEG_QUALITY, mozjpeg: true};
  try {
    const original = await sharp(bytes).rotate().resize(DESKTOP_SIZE.width, DESKTOP_SIZE.height, {fit: "cover"})
      .jpeg(jpeg).toBuffer();
    const wide = await sharp(bytes).rotate().resize(DESKTOP_WIDE_SIZE.width, DESKTOP_WIDE_SIZE.height, {fit: "cover"})
      .jpeg(jpeg).toBuffer();
    const thumb = await sharp(original).resize(DESKTOP_THUMB_SIZE.width, DESKTOP_THUMB_SIZE.height)
      .jpeg({quality: DESKTOP_THUMB_QUALITY, mozjpeg: true}).toBuffer();
    return {original, wide, thumb, width, height, aspect: checked.aspect};
  } catch {
    throw invalid();
  }
}

const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

function filesFor(shareId: string, rendered: {original: Buffer; wide: Buffer; thumb: Buffer}): DesktopFiles {
  const originalSha = sha256(rendered.original);
  const wideSha = sha256(rendered.wide);
  const thumbSha = sha256(rendered.thumb);
  return {
    original: {object: desktopObjectName(shareId, originalSha), sha256: originalSha, ...DESKTOP_SIZE,
      bytes: rendered.original.length},
    wide: {object: desktopObjectName(shareId, wideSha), sha256: wideSha, ...DESKTOP_WIDE_SIZE, bytes: rendered.wide.length},
    thumb: {object: desktopThumbObject(shareId, thumbSha), sha256: thumbSha, url: desktopThumbUrl(shareId, thumbSha),
      ...DESKTOP_THUMB_SIZE},
  };
}

const PRIVATE_OBJECT = /^desktop-originals\/[A-Za-z0-9_-]{1,200}\/[a-f0-9]{64}\.jpg$/;
const PREVIEW_OBJECT = /^previews\/desktop-[a-f0-9]{64}\.jpg$/;

/** The stored objects a submission or a companion manifest names, limited to this wall's desktop layout. */
function objectsOf(shareId: string, data: admin.firestore.DocumentData | undefined): StoredObject[] {
  const objects: StoredObject[] = [];
  for (const key of ["original", "wide"]) {
    const object = str(data?.[key]?.object);
    if (PRIVATE_OBJECT.test(object) && object.startsWith(`desktop-originals/${shareId}/`)) objects.push({kind: "private", object});
  }
  const thumb = str(data?.thumb?.object);
  if (PREVIEW_OBJECT.test(thumb)) objects.push({kind: "preview", object: thumb});
  for (const item of Array.isArray(data?.pendingObjects) ? data.pendingObjects : []) {
    const object = str(item?.object);
    if (item?.kind === "private" && PRIVATE_OBJECT.test(object) && object.startsWith(`desktop-originals/${shareId}/`)) {
      objects.push({kind: "private", object});
    } else if (item?.kind === "preview" && PREVIEW_OBJECT.test(object)) {
      objects.push({kind: "preview", object});
    }
  }
  return objects;
}

/** Deletes objects that the wall's live companion does not serve. Identical uploads share object names. */
async function deleteUnlinked(shareId: string, objects: StoredObject[], keep: StoredObject[] = []): Promise<void> {
  if (objects.length === 0) return;
  const live = (await db.collection(DESKTOP_COMPANIONS).doc(shareId).get()).data();
  const linked = live?.status === "ready" ? objectsOf(shareId, {original: live.original, wide: live.wide, thumb: live.thumb}) : [];
  const reserved = ["generating", "queued", "deferred"].includes(str(live?.status)) ? objectsOf(shareId, live) : [];
  const active = await db.collection(DESKTOP_SUBMISSIONS).where("shareId", "==", shareId).where("state", "in", ACTIVE).get();
  const kept = new Set([...linked, ...reserved, ...keep, ...active.docs.flatMap((doc) => objectsOf(shareId, doc.data()))]
    .map((item) => item.object));
  const storage = new R2Storage();
  for (const item of objects) {
    if (!kept.has(item.object)) await storage.delete(item.kind, item.object);
  }
}

async function store(objects: Array<[StoredObject, Buffer]>): Promise<void> {
  const storage = new R2Storage();
  for (const [{kind, object}, body] of objects) {
    const digest = sha256(body);
    if (!await storage.put(kind, object, body, {sha256: digest}, "image/jpeg")) {
      const head = await storage.head(kind, object);
      if (head?.sha256 !== digest || head.size !== body.length) {
        throw new HttpsError("unavailable", "desktop-store-failed");
      }
    }
  }
}

/** The caller's approved wall, read in `tx`. The owner comes from the wall, never from the request. */
async function ownApprovedWall(tx: admin.firestore.Transaction, uid: string, wallDocId: string) {
  const wallRef = db.collection("walls").doc(wallDocId);
  const wall = (await tx.get(wallRef)).data();
  if (!wall) throw new HttpsError("not-found", "desktop-wall-not-found");
  let owner: string;
  try {
    owner = await activeWallOwner(tx, wall);
  } catch (error) {
    if (error instanceof HttpsError && error.code === "permission-denied") {
      throw new HttpsError("permission-denied", "desktop-not-owner");
    }
    throw error;
  }
  if (owner !== uid) throw new HttpsError("permission-denied", "desktop-not-owner");
  const shareId = str(wall.id);
  if (wall.review !== true || !SHARE_ID.test(shareId)) throw new HttpsError("failed-precondition", "desktop-wall-not-approved");
  return {wallRef, wall, shareId};
}

function parseSubmitInput(raw: unknown): {wallDocId: string; bytes: Buffer} {
  const input = exactKeys(raw, ["wallDocId", "contentBase64"]);
  const wallDocId = wallDocumentId(input.wallDocId);
  const content = input.contentBase64;
  if (typeof content !== "string" || content === "" || !isValidBase64(content)) {
    throw new HttpsError("invalid-argument", "desktop-image-invalid");
  }
  if (base64DecodedBytes(content) > MAX_DESKTOP_UPLOAD_BYTES) throw new HttpsError("invalid-argument", "desktop-file-too-large");
  if (!isAllowedImageContent(content)) throw new HttpsError("invalid-argument", "desktop-image-invalid");
  return {wallDocId, bytes: Buffer.from(content, "base64")};
}

/** Withdraws an active submission and deletes its files and its doc. Approved files belong to the companion. */
async function retireLocked(ref: admin.firestore.DocumentReference, fallback?: admin.firestore.DocumentData): Promise<void> {
  const data = await db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data();
    if (current && ACTIVE.includes(current.state)) tx.update(ref, {state: "withdrawn", updatedAt: now()});
    return current ?? fallback;
  });
  if (!data) return;
  if (data.state === "approved") await clearRetired(str(data.shareId), ref.id);
  if (data.state !== "approved" && data.filesDeleted !== true) await deleteUnlinked(str(data.shareId), objectsOf(str(data.shareId), data));
  await ref.delete();
}

async function retire(ref: admin.firestore.DocumentReference): Promise<void> {
  const data = (await ref.get()).data();
  if (!data) return;
  await withStorageLease(str(data.shareId), () => retireLocked(ref));
}

export const submitDesktopVersion = onCall({region: CALLABLE_REGIONS, cors: true, secrets: r2Secrets, memory: "1GiB",
  timeoutSeconds: 120}, async (request: CallableRequest<unknown>) => {
  const uid = signedIn(request);
  const {wallDocId, bytes} = parseSubmitInput(request.data);
  const initial = await db.runTransaction((tx) => ownApprovedWall(tx, uid, wallDocId));
  await reserveUploadSlot(uid, false, Date.now());
  const rendered = await renderCreatorDesktop(bytes);

  return withStorageLease(initial.shareId, async () => {
    const ref = db.collection(DESKTOP_SUBMISSIONS).doc();
    const {shareId, files, stale} = await db.runTransaction(async (tx) => {
      const {wall, shareId} = await ownApprovedWall(tx, uid, wallDocId);
      if (shareId !== initial.shareId) throw new HttpsError("aborted", "desktop-wall-unavailable");
      const active = await tx.get(db.collection(DESKTOP_SUBMISSIONS).where("wallDocId", "==", wallDocId)
        .where("state", "in", [...ACTIVE, "withdrawn"]));
      const nowMs = Date.now();
      const stale: admin.firestore.DocumentReference[] = [];
      for (const doc of active.docs) {
        const lease = doc.data().leaseUntil;
        const expired = doc.data().state === "withdrawn" || doc.data().state === "uploading" &&
        (!(lease instanceof admin.firestore.Timestamp) || lease.toMillis() <= nowMs);
        if (!expired) throw new HttpsError("failed-precondition", "desktop-pending-exists");
        stale.push(doc.ref);
      }
      const files = filesFor(shareId, rendered);
      for (const doc of stale) tx.update(doc, {state: "withdrawn", updatedAt: now()});
      tx.create(ref, {wallDocId, shareId, creatorUid: uid, state: "uploading", ...files,
        source: {width: rendered.width, height: rendered.height, aspect: rendered.aspect},
        wallThumb: str(wall.wallpaper_thumb), wallTitle: str(wall.title), creatorName: str(wall.by),
        replaces: parseDesktopVariant(wall.desktopVariant) !== null,
        leaseUntil: admin.firestore.Timestamp.fromMillis(nowMs + DESKTOP_UPLOAD_LEASE_MS), createdAt: now(), updatedAt: now()});
      return {shareId, files, stale};
    });
    const own = objectsOf(shareId, files);
    try {
      for (const doc of stale) {
        const data = (await doc.get()).data();
        if (data?.state === "withdrawn") await deleteUnlinked(str(data.shareId), objectsOf(str(data.shareId), data), own);
        await doc.delete();
      }
      await store([[own[0], rendered.original], [own[1], rendered.wide], [own[2], rendered.thumb]]);
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(ref)).data();
        if (current?.state !== "uploading") throw new HttpsError("aborted", "desktop-upload-withdrawn");
        const wall = await ownApprovedWall(tx, uid, wallDocId);
        if (wall.shareId !== shareId) throw new HttpsError("aborted", "desktop-wall-unavailable");
        tx.update(ref, {state: "pending", leaseUntil: admin.firestore.FieldValue.delete(), updatedAt: now()});
      });
    } catch (error) {
      await retireLocked(ref, {shareId, ...files}).catch((err) =>
        logger.warn("desktop: could not clean a failed submission.", {id: ref.id, err}));
      throw error instanceof HttpsError ? error : new HttpsError("unavailable", "desktop-store-failed");
    }
    logger.info("desktop: submission pending.", {id: ref.id, wallDocId, aspect: rendered.aspect});
    return {submissionId: ref.id, state: "pending"};
  });
});

function parseReviewInput(raw: unknown) {
  const input = exactKeys(raw, ["submissionId", "decision", "reason", "reasonCode"], ["submissionId", "decision"]);
  const submissionId = wallDocumentId(input.submissionId);
  if (input.decision !== "approve" && input.decision !== "reject") throw new HttpsError("invalid-argument", "Invalid decision.");
  if (input.decision === "approve") return {submissionId, decision: "approve" as const};
  const reason = boundedDisplayText(input.reason, 500);
  if (!reason) throw new HttpsError("invalid-argument", "A reason is required.");
  const reasonCode = input.reasonCode === undefined ? "other" : input.reasonCode;
  if (!DESKTOP_REJECT_CODES.includes(reasonCode as typeof DESKTOP_REJECT_CODES[number])) {
    throw new HttpsError("invalid-argument", "Invalid reasonCode.");
  }
  return {submissionId, decision: "reject" as const, reason, reasonCode: reasonCode as string};
}

/** Links an approved submission as the wall's companion. The old companion's files are listed for deletion. */
async function approve(ref: admin.firestore.DocumentReference, adminUid: string) {
  return db.runTransaction(async (tx) => {
    const submission = (await tx.get(ref)).data();
    if (submission?.state === "approved") return {submission, changed: false};
    if (submission?.state !== "pending") throw new HttpsError("failed-precondition", "desktop-not-pending");
    const shareId = str(submission.shareId);
    const wallRef = db.collection("walls").doc(str(submission.wallDocId));
    const companionRef = db.collection(DESKTOP_COMPANIONS).doc(shareId);
    const [wallSnap, companionSnap] = await Promise.all([tx.get(wallRef), tx.get(companionRef)]);
    const wall = wallSnap.data();
    if (!wall || wall.review !== true || str(wall.id) !== shareId) {
      throw new HttpsError("failed-precondition", "desktop-wall-unavailable");
    }
    const owner = await activeWallOwner(tx, wall).catch(() => "");
    if (owner !== submission.creatorUid) throw new HttpsError("failed-precondition", "desktop-wall-unavailable");
    const companion = companionSnap.data();
    if (companion && !["ready", "rejected", "failed"].includes(str(companion.status))) {
      throw new HttpsError("failed-precondition", "desktop-companion-busy");
    }
    const files: DesktopFiles = {original: submission.original, wide: submission.wide, thumb: submission.thumb};
    const linked = new Set(objectsOf(shareId, files).map((item) => item.object));
    if (linked.size !== 3) throw new HttpsError("failed-precondition", "desktop-wall-unavailable");
    const retired = objectsOf(shareId, companion).filter((item) => !linked.has(item.object));
    const variant: DesktopVariant = {v: creatorDesktopVersion(files.original.sha256, files.wide.sha256), ...DESKTOP_SIZE,
      wideHeight: DESKTOP_WIDE_SIZE.height, thumb: files.thumb.url};
    tx.set(companionRef, {status: "ready", source: "creator", submissionId: ref.id, wallPath: wallRef.path, ...files,
      variant, ...(retired.length > 0 ? {pendingObjects: retired} : {}), updatedAt: now()});
    tx.update(wallRef, {desktopVariant: variant});
    tx.update(ref, {state: "approved", decidedBy: adminUid, decidedAt: now(), updatedAt: now()});
    return {submission, changed: true};
  });
}

/** Deletes the files an approval replaced, then forgets them, unless a later approval took over the manifest. */
async function clearRetired(shareId: string, submissionId: string): Promise<void> {
  const ref = db.collection(DESKTOP_COMPANIONS).doc(shareId);
  const manifest = (await ref.get()).data();
  if (manifest?.submissionId !== submissionId || !Array.isArray(manifest.pendingObjects)) return;
  await deleteUnlinked(shareId, objectsOf(shareId, {pendingObjects: manifest.pendingObjects}));
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data();
    if (current?.submissionId === submissionId &&
      JSON.stringify(current.pendingObjects) === JSON.stringify(manifest.pendingObjects)) {
      tx.update(ref, {pendingObjects: admin.firestore.FieldValue.delete()});
    }
  });
}

async function reject(ref: admin.firestore.DocumentReference, adminUid: string, reason: string, reasonCode: string) {
  return db.runTransaction(async (tx) => {
    const submission = (await tx.get(ref)).data();
    if (submission?.state === "rejected") return {submission, changed: false};
    if (submission?.state !== "pending") throw new HttpsError("failed-precondition", "desktop-not-pending");
    tx.update(ref, {state: "rejected", reason, reasonCode, decidedBy: adminUid, decidedAt: now(), updatedAt: now()});
    return {submission: {...submission, reason, reasonCode}, changed: true};
  });
}

async function notifyCreator(submission: admin.firestore.DocumentData, id: string, outcome: "approved" | "rejected",
  reason = ""): Promise<void> {
  const uid = str(submission.creatorUid);
  const user = (await db.collection("usersv2").doc(uid).get()).data();
  const email = str(user?.email);
  const wallTitle = str(submission.wallTitle);
  const copy = outcome === "approved" ?
    notificationCopyPayload({kind: "desktopVersionApproved", wallTitle}) :
    notificationCopyPayload({kind: "desktopVersionRejected", wallTitle, reason});
  await sendToUser({
    ...copy,
    data: {route: "wall", wall_id: str(submission.wallDocId), notification_kind: `desktop_version_${outcome}`},
    imageUrl: str(submission.thumb?.url) || undefined,
    modifier: email,
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `desktop_${id}`,
  }, {uid, email, loggedOut: isLoggedOut(user), legacyToken: user?.fcmToken});
}

export const reviewDesktopSubmission = onCall({region: CALLABLE_REGIONS, cors: true, secrets: r2Secrets},
  async (request: CallableRequest<unknown>) => {
    if (!request.auth?.uid || !(await isAdminCaller(request.auth))) {
      throw new HttpsError("permission-denied", "Only admins can review desktop versions.");
    }
    const adminUid = request.auth.uid;
    const input = parseReviewInput(request.data);
    const ref = db.collection(DESKTOP_SUBMISSIONS).doc(input.submissionId);
    const submission = (await ref.get()).data();
    if (!submission) throw new HttpsError("failed-precondition", "desktop-not-pending");
    return withStorageLease(str(submission.shareId), async () => {
      const result = input.decision === "approve" ?
        await approve(ref, adminUid) :
        await reject(ref, adminUid, input.reason, input.reasonCode);
      if (result.changed) {
        await notifyCreator(result.submission, ref.id, input.decision === "approve" ? "approved" : "rejected",
          input.decision === "reject" ? str(result.submission.reason) : "").catch((err) =>
          logger.warn("desktop: creator notification failed.", {id: ref.id, err}));
      }
      if (input.decision === "approve") await clearRetired(str(result.submission.shareId), ref.id);
      else if (result.submission.filesDeleted !== true) {
        const shareId = str(result.submission.shareId);
        await deleteUnlinked(shareId, objectsOf(shareId, result.submission));
        await ref.update({filesDeleted: true});
      }
      return {state: input.decision === "approve" ? "approved" : "rejected"};
    });
  });

/** Every submission of a deleted wall. The companion itself is removed by `onStudioWallDesktop`. */
export async function removeDesktopSubmissionsForWall(wallDocId: string): Promise<void> {
  const docs = (await db.collection(DESKTOP_SUBMISSIONS).where("wallDocId", "==", wallDocId).get()).docs;
  for (const doc of docs) await retire(doc.ref);
}

/** Every submission of a deleted account. An approved one stays live as the companion of the anonymized wall. */
export async function removeDesktopSubmissionsForAccount(uid: string): Promise<void> {
  const docs = (await db.collection(DESKTOP_SUBMISSIONS).where("creatorUid", "==", uid).get()).docs;
  for (const doc of docs) await retire(doc.ref);
}

export const onDesktopSubmissionWallDeleted = onDocumentDeleted({document: "walls/{wallId}", region: REGION, retry: true,
  secrets: r2Secrets}, async (event) => {
  await removeDesktopSubmissionsForWall(event.params.wallId);
});
