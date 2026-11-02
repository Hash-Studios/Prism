import type * as admin from "firebase-admin";
import {db, str} from "../common";
import {STUDIO_ACCOUNT} from "./account";

const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;

/**
 * True for a wall posted by the Studio account with a candidate doc that points back at it. `origin` and the public
 * Studio metadata alone are not enough to identify a Studio wall.
 */
export async function isStudioWall(wallId: string, data: admin.firestore.DocumentData): Promise<boolean> {
  if (data.origin !== "studio" || data.email !== STUDIO_ACCOUNT.email) return false;
  const runId = str(data.studioRunId);
  const candidateId = str(data.studioCandidateId);
  if (!DOC_ID.test(runId) || !DOC_ID.test(candidateId)) return false;
  const candidate = await db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId).get();
  return candidate.data()?.wallId === wallId;
}
