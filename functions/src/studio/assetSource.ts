import type * as admin from "firebase-admin";
import {db, str} from "../common";
import {STUDIO_ACCOUNT} from "./account";

/** Public worker URL base of Studio wall images. The worker serves `ai/studio/{candidateId}.jpg` under it. */
export const STUDIO_ASSET_BASE = "https://prismwalls.com/api/ai/assets";
const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;

export type StudioSource = {runId: string; candidateId: string; wallKey: string; thumbKey: string;
  wallUrl: string; thumbUrl: string};

/**
 * The exact Studio URL pair of an unconverted wall, or null. `origin` alone is not trusted: the pair must match
 * `studioCandidateId` and the wall must be posted by the server-owned Studio account.
 */
export function parseStudioSource(data: admin.firestore.DocumentData): StudioSource | null {
  if (data.origin !== "studio" || data.email !== STUDIO_ACCOUNT.email) return null;
  const runId = str(data.studioRunId);
  const candidateId = str(data.studioCandidateId);
  if (!DOC_ID.test(runId) || !DOC_ID.test(candidateId)) return null;
  const wallKey = `ai/studio/${candidateId}.jpg`;
  const thumbKey = `ai/studio/thumb_${candidateId}.jpg`;
  const wallUrl = `${STUDIO_ASSET_BASE}/${wallKey}`;
  const thumbUrl = `${STUDIO_ASSET_BASE}/${thumbKey}`;
  if (data.wallpaper_url !== wallUrl || data.wallpaper_thumb !== thumbUrl) return null;
  return {runId, candidateId, wallKey, thumbKey, wallUrl, thumbUrl};
}

/** `parseStudioSource` plus the server-owned backlink `studioRuns/{run}/candidates/{id}.wallId`, which clients cannot write. */
export async function verifiedStudioSource(wallId: string, data: admin.firestore.DocumentData,
  tx?: admin.firestore.Transaction): Promise<StudioSource | null> {
  const source = parseStudioSource(data);
  if (!source) return null;
  const ref = db.collection("studioRuns").doc(source.runId).collection("candidates").doc(source.candidateId);
  const candidate = (tx ? await tx.get(ref) : await ref.get()).data();
  return candidate?.wallId === wallId ? source : null;
}
