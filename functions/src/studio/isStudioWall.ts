import type * as admin from "firebase-admin";
import {db, str} from "../common";

const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;

/**
 * True for a wall that processStudioCandidate made: origin "studio" and a candidate doc that points back at it.
 * A client can write `origin` on its own wall, but it cannot write studioRuns.
 */
export async function isStudioWall(wallId: string, data: admin.firestore.DocumentData): Promise<boolean> {
  if (data.origin !== "studio") return false;
  const runId = str(data.studioRunId);
  const candidateId = str(data.studioCandidateId);
  if (!DOC_ID.test(runId) || !DOC_ID.test(candidateId)) return false;
  const candidate = await db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId).get();
  return candidate.data()?.wallId === wallId;
}
