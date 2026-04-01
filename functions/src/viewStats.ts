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

async function incrementAndReadViews(collection: string, docId: string): Promise<number> {
  const ref = db.collection(collection).doc(docId);
  await ref.set({views: admin.firestore.FieldValue.increment(1)}, {merge: true});
  const snap = await ref.get();
  const v = snap.data()?.views;
  if (typeof v === "number" && Number.isFinite(v)) {
    return v;
  }
  const parsed = parseInt(String(v ?? "0"), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

export const recordWallpaperView = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{wallId?: string}>): Promise<RecordViewResponse> => {
    const wallId = normalizeId(request.data?.wallId ?? "");
    const views = await incrementAndReadViews(WALLPAPER_STATS, wallId);
    return {views};
  },
);

export const recordSetupView = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{setupId?: string}>): Promise<RecordViewResponse> => {
    const setupId = normalizeId(request.data?.setupId ?? "");
    const views = await incrementAndReadViews(SETUP_STATS, setupId);
    return {views};
  },
);
