import * as crypto from "node:crypto";
import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REGION = "asia-south1";
const CONTENT_REPORTS = "contentReports";
const RATE_TARGET = "contentReportRateByTarget";
const RATE_DAILY = "contentReportRateDaily";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const MIN_MS_BETWEEN_SAME_TARGET = MS_PER_DAY;
const MAX_REPORTS_PER_DAY = 20;

const ALLOWED_REASONS = new Set(["copyright", "harassment", "sexual", "spam", "other"]);

const MAX_DETAILS_LEN = 2000;
const MAX_DOC_ID_LEN = 256;

function normalizeTargetDocId(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "targetFirestoreDocId must be a string.");
  }
  const t = raw.trim();
  if (t.length === 0 || t.length > MAX_DOC_ID_LEN) {
    throw new HttpsError("invalid-argument", "targetFirestoreDocId has invalid length.");
  }
  if (t.includes("/") || t.includes("..")) {
    throw new HttpsError("invalid-argument", "targetFirestoreDocId is invalid.");
  }
  return t;
}

function normalizeContentType(raw: unknown): "wall" | "setup" {
  if (raw !== "wall" && raw !== "setup") {
    throw new HttpsError("invalid-argument", "contentType must be 'wall' or 'setup'.");
  }
  return raw;
}

function normalizeReason(raw: unknown): string {
  if (typeof raw !== "string" || !ALLOWED_REASONS.has(raw)) {
    throw new HttpsError("invalid-argument", "reason is invalid.");
  }
  return raw;
}

function normalizeDetails(raw: unknown): string {
  if (raw == null) {
    return "";
  }
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "details must be a string.");
  }
  const t = raw.trim();
  if (t.length > MAX_DETAILS_LEN) {
    throw new HttpsError("invalid-argument", "details is too long.");
  }
  return t;
}

function normalizeAppVersion(raw: unknown): string {
  if (raw == null) {
    return "";
  }
  if (typeof raw !== "string") {
    return "";
  }
  return raw.trim().slice(0, 64);
}

function utcDateString(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function rateTargetDocId(uid: string, contentType: string, targetId: string): string {
  const safe = `${uid}_${contentType}_${targetId}`.replace(/[/\s]/g, "_");
  if (safe.length <= 1200) {
    return safe;
  }
  const h = crypto.createHash("sha256").update(`${uid}|${contentType}|${targetId}`).digest("hex");
  return `h_${uid.slice(0, 24)}_${h}`;
}

interface SubmitReportData {
  contentType?: string;
  targetFirestoreDocId?: string;
  reason?: string;
  details?: string;
  appVersion?: string;
}

interface SubmitReportResponse {
  reportId: string;
}

export const submitContentReport = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<SubmitReportData>): Promise<SubmitReportResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to submit a report.");
    }

    const contentType = normalizeContentType(request.data?.contentType);
    const targetFirestoreDocId = normalizeTargetDocId(request.data?.targetFirestoreDocId);
    const reason = normalizeReason(request.data?.reason);
    const details = normalizeDetails(request.data?.details);
    const appVersion = normalizeAppVersion(request.data?.appVersion);

    const collection = contentType === "wall" ? "walls" : "setups";
    const targetSnap = await db.collection(collection).doc(targetFirestoreDocId).get();
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "Content was not found.");
    }

    const reporterEmail = (request.auth?.token?.email ?? "").toString().trim();

    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();
    const today = utcDateString(new Date(nowMs));

    const targetRateRef = db.collection(RATE_TARGET).doc(rateTargetDocId(uid, contentType, targetFirestoreDocId));
    const dailyRateRef = db.collection(RATE_DAILY).doc(`${uid}_${today}`);

    const reportRef = db.collection(CONTENT_REPORTS).doc();

    await db.runTransaction(async (tx) => {
      const [targetRateSnap, dailyRateSnap] = await Promise.all([tx.get(targetRateRef), tx.get(dailyRateRef)]);

      if (targetRateSnap.exists) {
        const last = targetRateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
        if (last) {
          const elapsed = nowMs - last.toMillis();
          if (elapsed >= 0 && elapsed < MIN_MS_BETWEEN_SAME_TARGET) {
            throw new HttpsError(
              "resource-exhausted",
              "You already reported this content recently. Try again later.",
            );
          }
        }
      }

      let dailyCount = 0;
      if (dailyRateSnap.exists) {
        const d = dailyRateSnap.data()?.day as string | undefined;
        const c = dailyRateSnap.data()?.count;
        if (d === today && typeof c === "number") {
          dailyCount = c;
        }
      }
      if (dailyCount >= MAX_REPORTS_PER_DAY) {
        throw new HttpsError("resource-exhausted", "Daily report limit reached. Try again tomorrow.");
      }

      tx.set(reportRef, {
        contentType,
        targetFirestoreDocId,
        reason,
        details,
        reporterUid: uid,
        reporterEmail: reporterEmail || null,
        appVersion: appVersion || null,
        status: "open",
        createdAt: now,
        targetCollection: collection,
      });

      tx.set(targetRateRef, {lastAt: now, contentType, targetFirestoreDocId, reporterUid: uid}, {merge: true});

      tx.set(
        dailyRateRef,
        {
          day: today,
          count: dailyCount + 1,
          reporterUid: uid,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    logger.info("submitContentReport: created", {
      reportId: reportRef.id,
      contentType,
      targetFirestoreDocId,
      reason,
      reporterUid: uid,
    });

    return {reportId: reportRef.id};
  },
);
