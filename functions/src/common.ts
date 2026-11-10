import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const REGION = "asia-south1";
export const US_REGION = "us-central1";
export const CALLABLE_REGIONS = [REGION, US_REGION];

/** Cloud Run "Total CPU allocation" quota (run.googleapis.com/cpu_allocation) in each region, in vCPU. */
export const REGION_CPU_QUOTA_VCPU = 200;
/**
 * The sum of maxInstances x vCPU over the functions in one region stays at or under this. The quota counts live
 * instances, including idle instances and overlapping revisions.
 */
export const REGION_CPU_BUDGET_VCPU = REGION_CPU_QUOTA_VCPU * 0.8;

// Every function module imports this file, so this runs before any function is defined.
setGlobalOptions({maxInstances: 1});

/** Admin-only callables: 1st gen CPU for the memory size, so one request per instance. */
export const ADMIN_CALLABLE = {cpu: "gcf_gen1", maxInstances: 1} as const;

export function utcDateString(d = new Date()): string {
  return d.toISOString().slice(0, 10);
}

export function str(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

export function int(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

/** Count from a `{day, count}` rate-limit doc, or 0 when the doc is missing or from another day. */
export function readDailyCount(snap: admin.firestore.DocumentSnapshot, today: string): number {
  const data = snap.data();
  return data?.day === today && typeof data.count === "number" ? data.count : 0;
}

/** First `usersv2` doc whose email equals `email`, or its lowercase form. */
export async function findUserByEmail(email: string): Promise<admin.firestore.QueryDocumentSnapshot | null> {
  const users = db.collection("usersv2");
  const exact = await users.where("email", "==", email).limit(1).get();
  if (!exact.empty) return exact.docs[0];
  const lower = email.toLowerCase();
  if (lower === email) return null;
  const lowerSnap = await users.where("email", "==", lower).limit(1).get();
  return lowerSnap.empty ? null : lowerSnap.docs[0];
}

export function coinTransactionDoc(params: {
  id: string;
  userId: string;
  at: admin.firestore.Timestamp;
  delta: number;
  balanceBefore: number;
  action: string;
  description: string;
  sourceTag: string;
  reason: string;
}): Record<string, unknown> {
  return {
    id: params.id,
    userId: params.userId,
    createdAt: params.at,
    updatedAt: params.at,
    delta: params.delta,
    balanceBefore: params.balanceBefore,
    balanceAfter: params.balanceBefore + params.delta,
    action: params.action,
    description: params.description,
    sourceTag: params.sourceTag,
    reason: params.reason,
    status: "completed",
    type: params.delta >= 0 ? "credit" : "debit",
  };
}
