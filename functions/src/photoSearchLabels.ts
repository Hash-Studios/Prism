import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {isValidRequestId} from "./coinsCallables";
import {CALLABLE_REGIONS, db, readDailyCount, utcDateString} from "./common";
import {DEFAULT_CATEGORY, detectLabelsInImage, mapLabelsToCategory} from "./wallCategory";

export const PHOTO_SEARCH_RATE = "photoSearchRate";
export const MAX_PHOTO_SEARCHES_PER_DAY = 20;
export const MAX_PHOTO_BYTES = 512 * 1024;
export const MAX_PHOTO_LABELS = 5;
const DAY_MS = 24 * 60 * 60 * 1000;
const STALE_PENDING_MS = 90 * 1000;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

export type PhotoLabels = {labels: string[]; category: string | null};
type Claim = {used: number; day: string; now: number};
type Slot = {pending: true; at: number} | PhotoLabels;

/** The decoded JPEG or PNG bytes of [raw], a base64 string. Refuses anything else and anything over 512 KiB. */
export function parsePhoto(raw: unknown): Buffer {
  if (typeof raw !== "string" || raw.length === 0) {
    throw new HttpsError("invalid-argument", "image must be a base64 JPEG or PNG.");
  }
  if (raw.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4) {
    throw new HttpsError("invalid-argument", "image is over 512 KiB. Downscale it to 512 px first.");
  }
  if (raw.length % 4 !== 0 || !BASE64.test(raw)) {
    throw new HttpsError("invalid-argument", "image must be a base64 JPEG or PNG.");
  }
  const bytes = Buffer.from(raw, "base64");
  if (bytes.length > MAX_PHOTO_BYTES) {
    throw new HttpsError("invalid-argument", "image is over 512 KiB. Downscale it to 512 px first.");
  }
  const jpeg = bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  if (!jpeg && !png) throw new HttpsError("invalid-argument", "image must be a base64 JPEG or PNG.");
  return bytes;
}

function slotsOf(data: admin.firestore.DocumentData | undefined, day: string): Record<string, Slot> {
  return data?.day === day && data.results && typeof data.results === "object" ? {...data.results} : {};
}

function isLabels(slot: Slot | undefined): slot is PhotoLabels {
  return !!slot && Array.isArray((slot as PhotoLabels).labels);
}

function isPendingClaim(slot: Slot | undefined, claim: Claim): boolean {
  return !!slot && "pending" in slot && slot.pending && slot.at === claim.now;
}

/**
 * Labels for a photo the user picked in Search. The image is sent to Cloud Vision in the request body and is never
 * written anywhere. The day's doc keeps only a count and each request's labels, so a retried requestId returns the
 * same labels without a second Vision call or a second count. Every Vision call counts, including a failed one and a
 * retry of a request that stopped while it was running, so a user never gets more than 20 Vision calls a day.
 */
export const photoSearchLabels = onCall({region: CALLABLE_REGIONS, timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid || request.auth?.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Sign in to search by photo.");
  }
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const image = parsePhoto(request.data?.image);

  const ref = db.collection(PHOTO_SEARCH_RATE).doc(uid);
  const claim = await db.runTransaction(async (tx): Promise<Claim & {replay?: PhotoLabels}> => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const day = utcDateString(new Date(now));
    const used = readDailyCount(snap, day);
    const slots = slotsOf(snap.data(), day);
    const slot = slots[requestId];
    if (isLabels(slot)) return {replay: {labels: slot.labels, category: slot.category ?? null}, used, day, now};
    if (slot && now - slot.at < STALE_PENDING_MS) {
      throw new HttpsError("aborted", "This photo search is still running.");
    }
    if (used >= MAX_PHOTO_SEARCHES_PER_DAY) {
      throw new HttpsError("resource-exhausted", "Daily photo search limit reached.");
    }
    tx.set(ref, {
      day,
      count: used + 1,
      results: {...slots, [requestId]: {pending: true, at: now}},
      expireAt: admin.firestore.Timestamp.fromMillis(now + 2 * DAY_MS),
    });
    return {used: used + 1, day, now};
  });
  if (claim.replay) return {...claim.replay, remaining: Math.max(0, MAX_PHOTO_SEARCHES_PER_DAY - claim.used)};

  let labels: string[];
  try {
    labels = (await detectLabelsInImage(image)).slice(0, MAX_PHOTO_LABELS);
  } catch {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const slots = slotsOf(snap.data(), claim.day);
      if (!isPendingClaim(slots[requestId], claim)) return;
      delete slots[requestId];
      tx.update(ref, {results: slots});
    });
    // Vision SDK errors can contain request details. Do not log error-derived data for photo requests.
    logger.warn("photoSearchLabels: Vision failed.", {uid});
    throw new HttpsError("unavailable", "Could not read the photo. Try again.");
  }
  const category = mapLabelsToCategory(labels);
  const result: PhotoLabels = {labels, category: category === DEFAULT_CATEGORY ? null : category};
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const slots = slotsOf(snap.data(), claim.day);
      if (!isPendingClaim(slots[requestId], claim)) return;
      tx.update(ref, {results: {...slots, [requestId]: result}});
    });
  } catch {
    // The counted Vision result is still useful to this caller. Do not log error-derived data for photo requests.
    logger.warn("photoSearchLabels: Result cache failed.", {uid});
  }
  return {...result, remaining: Math.max(0, MAX_PHOTO_SEARCHES_PER_DAY - claim.used)};
});
