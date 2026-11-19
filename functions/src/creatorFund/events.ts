import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import type {FundEvent} from "./score";
import {approvedWall} from "../creatorProgress";
import {db} from "../common";
import {CREATOR_FUND_METRICS, type CreatorFundMetric, weekKey} from "../economy";

export const FUND_EVENTS = "creatorFundEvents";
export const FUND_RETENTION_MS = 63 * 86_400_000;

function eventId(week: string, wall: string, metric: CreatorFundMetric, uid: string) {
  return createHash("sha256").update(JSON.stringify([week, wall, metric, uid])).digest("hex");
}

export function ledgerEvent(doc: admin.firestore.QueryDocumentSnapshot, week: string): FundEvent | null {
  const {wallId, metric, actorUid, wallStamp, resolveAt} = doc.data();
  if (typeof wallId !== "string" || !CREATOR_FUND_METRICS.includes(metric) ||
    typeof actorUid !== "string" || !actorUid || actorUid.includes("/") || actorUid.length > 128 ||
    doc.id !== eventId(week, wallId, metric, actorUid)) return null;
  return {wallId, metric, actorUid, wallStamp, resolveAt};
}

/**
 * The server-recorded action that the Creator fund scores. The document ID is one per week, wall, metric and actor,
 * so a repeat of the same action in the same week writes the same document and counts once.
 */
export function fundEventWrite(wallId: string, metric: CreatorFundMetric, actorUid: string, nowMs: number) {
  const week = weekKey(nowMs);
  const id = eventId(week, wallId, metric, actorUid);
  return {
    ref: db.collection(FUND_EVENTS).doc(id),
    data: {
      week, wallId, metric, actorUid,
      at: admin.firestore.Timestamp.fromMillis(nowMs),
      expireAt: admin.firestore.Timestamp.fromMillis(nowMs + FUND_RETENTION_MS),
    },
  };
}

export function fundWallStamp(wall: admin.firestore.DocumentSnapshot): string {
  return createHash("sha256").update(JSON.stringify([wall.ref.path, wall.createTime?.seconds,
    wall.createTime?.nanoseconds, wall.data()?.id, wall.data()?.creatorUid])).digest("hex");
}

export async function prepareFundEvent(tx: admin.firestore.Transaction, wallId: string, metric: CreatorFundMetric,
  actorUid: string, at: number, source: string | admin.firestore.DocumentSnapshot) {
  if (!actorUid || actorUid.includes("/")) return null;
  const barrier = await tx.get(db.doc(`creatorDeletionState/${actorUid}`));
  if (barrier.data()?.closed) return null;
  let wall: admin.firestore.DocumentSnapshot;
  if (typeof source === "string") {
    const candidates = [...new Set([source, wallId, wallId.toLowerCase()])];
    const match = await tx.get(db.collection("walls").where("id", "in", candidates).limit(2));
    if (match.empty) {
      const event = fundEventWrite(wallId, metric, actorUid, at);
      if ((await tx.get(event.ref)).data()?.wallStamp) return null;
      return {...event, data: {...event.data, resolveAt: at}};
    }
    if (match.size !== 1) return null;
    wall = match.docs[0];
  } else {
    wall = source;
  }
  const data = wall.data();
  if (!data || !approvedWall(data) || !data.creatorUid || data.creatorUid === actorUid ||
    !wall.createTime || wall.createTime.toMillis() > at) return null;
  const event = fundEventWrite(wallId, metric, actorUid, at);
  return {...event, data: {...event.data, wallStamp: fundWallStamp(wall)}};
}
