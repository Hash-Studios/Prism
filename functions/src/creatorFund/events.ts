import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {db} from "../common";
import {type CreatorFundMetric, weekKey} from "../economy";

export const FUND_EVENTS = "creatorFundEvents";
const RETENTION_MS = 63 * 86_400_000;

/**
 * The server-recorded action that the Creator fund scores. The document ID is one per week, wall, metric and actor,
 * so a repeat of the same action in the same week writes the same document and counts once.
 */
export function fundEventWrite(wallId: string, metric: CreatorFundMetric, actorUid: string, nowMs: number) {
  const week = weekKey(nowMs);
  const id = createHash("sha256").update(JSON.stringify([week, wallId, metric, actorUid])).digest("hex");
  return {
    ref: db.collection(FUND_EVENTS).doc(id),
    data: {
      week, wallId, metric, actorUid,
      at: admin.firestore.Timestamp.fromMillis(nowMs),
      expireAt: admin.firestore.Timestamp.fromMillis(nowMs + RETENTION_MS),
    },
  };
}
