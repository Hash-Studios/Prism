import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REGION = "asia-south1";
const WALLPAPER_STATS = "wallpaper_stats";
const SETUP_STATS = "setup_stats";
const MAX_ID_LEN = 128;
const VIEW_COOLDOWN_MS = 60 * 60 * 1000;

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

async function incrementAndReadViews(uid: string, collection: string, docId: string): Promise<number> {
  const statsRef = db.collection(collection).doc(docId);
  const rateRef = db.collection("viewRate").doc(`${uid}_${collection}_${docId}`);
  let views = 0;
  await db.runTransaction(async (tx) => {
    const [rateSnap, statsSnap] = await Promise.all([tx.get(rateRef), tx.get(statsRef)]);
    const current = statsSnap.data()?.views;
    views = typeof current === "number" && Number.isFinite(current) ? current :
      Number.parseInt(String(current ?? "0"), 10) || 0;
    const lastAt = rateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
    if (isViewCooldownActive(lastAt?.toMillis())) {
      return;
    }
    views += 1;
    tx.set(statsRef, {views}, {merge: true});
    tx.set(rateRef, {lastAt: admin.firestore.Timestamp.now()}, {merge: true});
  });
  return views;
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
