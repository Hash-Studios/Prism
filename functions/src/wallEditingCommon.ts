import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {HttpsError, type CallableRequest} from "firebase-functions/v2/https";
import {db} from "./common";
import {verifiedUidForEmail} from "./authoredContentUid";

export const digest = (text: string | Buffer): string => createHash("sha256").update(text).digest("hex");
export function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort()
      .map((k) => `${JSON.stringify(k)}:${stableJson((value as Record<string, unknown>)[k])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}
export function timestampKey(time: admin.firestore.Timestamp | undefined): string {
  if (!time || !Number.isInteger(time.seconds) || !Number.isInteger(time.nanoseconds)) {
    throw new HttpsError("failed-precondition", "Document timestamp is unavailable.");
  }
  return `${time.seconds}:${time.nanoseconds}`;
}
export function sameTimestamp(a: admin.firestore.Timestamp | undefined, b: admin.firestore.Timestamp | undefined): boolean {
  return !!a && !!b && a.seconds === b.seconds && a.nanoseconds === b.nanoseconds;
}
export function revisionOf(snapshot: admin.firestore.DocumentSnapshot): string {
  return digest(`${timestampKey(snapshot.createTime)}|${timestampKey(snapshot.updateTime)}`);
}
export function signedIn(request: CallableRequest<unknown>): string {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to edit uploads.");
  return request.auth.uid;
}
export async function openAccount(tx: admin.firestore.Transaction, uid: string): Promise<admin.firestore.DocumentData> {
  const [user, barrier] = await Promise.all([
    tx.get(db.collection("usersv2").doc(uid)), tx.get(db.collection("creatorDeletionState").doc(uid)),
  ]);
  if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) {
    throw new HttpsError("failed-precondition", "account-closed");
  }
  return user.data()!;
}
export async function activeWallOwner(tx: admin.firestore.Transaction, data: admin.firestore.DocumentData): Promise<string> {
  let uid: string | null;
  if (Object.prototype.hasOwnProperty.call(data, "creatorUid")) {
    uid = typeof data.creatorUid === "string" && data.creatorUid ? data.creatorUid : null;
  } else {
    const email = typeof data.email === "string" ? data.email.trim() : "";
    uid = email && !email.includes("/") ? await verifiedUidForEmail(email, tx) : null;
  }
  if (!uid) throw new HttpsError("permission-denied", "Wall ownership is unavailable.");
  await openAccount(tx, uid);
  return uid;
}
export function expectedRevision(raw: unknown): string {
  if (typeof raw !== "string" || !/^[a-f0-9]{64}$/.test(raw)) throw new HttpsError("invalid-argument", "Invalid expectedRevision.");
  return raw;
}
