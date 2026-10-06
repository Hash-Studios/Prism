import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, REGION} from "./common";

const WALLPAPER_STATS = "wallpaper_stats";
const SETUP_STATS = "setup_stats";
const MAX_ID_LEN = 128;
const VIEW_COOLDOWN_MS = 60 * 60 * 1000;
/** Rate docs are only read within the cooldown; the TTL policy on `expireAt` deletes them after this. */
const RATE_DOC_TTL_MS = 24 * 60 * 60 * 1000;

interface RecordViewResponse {
  views: number;
}

function normalizeId(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "id must be a string.");
  }
  const trimmed = raw.trim().toUpperCase();
  if (trimmed.length === 0 || trimmed.length > MAX_ID_LEN) {
    throw new HttpsError("invalid-argument", "id has invalid length.");
  }
  if (!/^[A-Z0-9._-]+$/.test(trimmed)) {
    throw new HttpsError("invalid-argument", "id contains invalid characters.");
  }
  return trimmed;
}

export function isViewCooldownActive(lastAtMs: number | undefined, nowMs = Date.now()): boolean {
  return lastAtMs != null && Number.isFinite(lastAtMs) && nowMs - lastAtMs < VIEW_COOLDOWN_MS;
}

export function parseViews(raw: unknown): number {
  return typeof raw === "number" && Number.isFinite(raw) ? raw : Number.parseInt(String(raw ?? "0"), 10) || 0;
}

const ALREADY_EXISTS = 6;
const NOT_FOUND = 5;
const FAILED_PRECONDITION = 9;

/** Another call claimed the same view first: the create found a doc, or the doc changed since it was read. */
function isLostClaim(err: unknown): boolean {
  const code = (err as {code?: unknown}).code;
  return code === ALREADY_EXISTS || code === NOT_FOUND || code === FAILED_PRECONDITION;
}

async function incrementAndReadViews(uid: string, collection: string, docId: string): Promise<number> {
  const statsRef = db.collection(collection).doc(docId);
  const rateRef = db.collection("viewRate").doc(`${uid}_${collection}_${docId}`);
  const [rateSnap, statsSnap] = await Promise.all([rateRef.get(), statsRef.get()]);
  const rawViews = statsSnap.data()?.views;
  const views = parseViews(rawViews);
  const lastAt = rateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
  if (isViewCooldownActive(lastAt?.toMillis())) {
    return views;
  }
  const now = Date.now();
  const claim = {
    lastAt: admin.firestore.Timestamp.fromMillis(now),
    expireAt: admin.firestore.Timestamp.fromMillis(now + RATE_DOC_TTL_MS),
  };
  // The create, or the update pinned to the doc version that was read, succeeds for one concurrent call only.
  try {
    if (rateSnap.exists && rateSnap.updateTime) {
      await rateRef.update(claim, {lastUpdateTime: rateSnap.updateTime});
    } else {
      await rateRef.create(claim);
    }
  } catch (err) {
    if (isLostClaim(err)) return views;
    throw err;
  }
  // A legacy doc may hold views as a string, which FieldValue.increment would reset to 1.
  const next = typeof rawViews === "number" ? admin.firestore.FieldValue.increment(1) : views + 1;
  await statsRef.set({views: next}, {merge: true});
  return views + 1;
}

export const recordWallpaperView = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{wallId?: string}>): Promise<RecordViewResponse> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to record a view.");
    const wallId = normalizeId(request.data?.wallId ?? "");
    const views = await incrementAndReadViews(uid, WALLPAPER_STATS, wallId);
    return {views};
  },
);

export const recordSetupView = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{setupId?: string}>): Promise<RecordViewResponse> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to record a view.");
    const setupId = normalizeId(request.data?.setupId ?? "");
    const views = await incrementAndReadViews(uid, SETUP_STATS, setupId);
    return {views};
  },
);
