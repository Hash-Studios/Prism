import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";

/** Shared eligibility rule for trigger and backfill ownership reconciliation. */
export function isActiveContentOwner(
  user: {exists: boolean; data: () => admin.firestore.DocumentData | undefined},
  barrier: {data: () => admin.firestore.DocumentData | undefined},
): boolean {
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true;
}

/** Auth-verified UID for an email, or null. Never use usersv2.email for ownership. */
export async function verifiedUidForEmail(email: string): Promise<string | null> {
  try {
    const identity = await admin.auth().getUserByEmail(email);
    return identity.emailVerified ? identity.uid : null;
  } catch (err) {
    if (err instanceof Error && "code" in err && err.code === "auth/user-not-found") return null;
    throw err;
  }
}

export type OwnerSyncOptions = {apply?: boolean; lookup?: (email: string) => Promise<string | null>};

/** Resolves legacy email-authored content to an Auth-verified UID and returns what changed (or would change). */
export async function syncAuthoredContentUid(
  collection: "walls" | "setups",
  id: string,
  eventEmail: unknown,
  {apply = true, lookup = verifiedUidForEmail}: OwnerSyncOptions = {},
): Promise<"assigned" | "cleared" | "skipped"> {
  const email = str(eventEmail);
  const resolvedUid = email ? await lookup(email) : null;

  const contentRef = db.collection(collection).doc(id);
  return db.runTransaction(async (tx) => {
    const content = await tx.get(contentRef);
    if (!content.exists || str(content.data()?.email) !== email) return "skipped";

    let ownerUid = "";
    if (resolvedUid) {
      const [user, barrier] = await Promise.all([
        tx.get(db.collection("usersv2").doc(resolvedUid)),
        tx.get(db.collection("creatorDeletionState").doc(resolvedUid)),
      ]);
      if (isActiveContentOwner(user, barrier)) ownerUid = resolvedUid;
    }
    const current = content.data()?.creatorUid;
    if (ownerUid) {
      if (current === ownerUid) return "skipped";
      if (apply) tx.update(contentRef, {creatorUid: ownerUid});
      return "assigned";
    }
    if (!current) return "skipped";
    if (apply) tx.update(contentRef, {creatorUid: admin.firestore.FieldValue.delete()});
    return "cleared";
  });
}

/** Walls take frequent counter writes; skip them unless the owner email changed or creatorUid is missing. */
function unchangedOwner(event: {data?: {before: {exists: boolean; data: () => unknown}; after: {data: () => unknown}}}): boolean {
  const before = event.data?.before.exists ? event.data.before.data() as Record<string, unknown> : undefined;
  const after = event.data?.after.data() as Record<string, unknown> | undefined;
  return !!before && !!after?.creatorUid && str(before.email) === str(after.email);
}

export const onWallAuthoredContentWritten = onDocumentWritten(
  {document: "walls/{contentId}", region: REGION},
  async (event) => {
    if (!event.data?.after.exists || unchangedOwner(event)) return;
    await syncAuthoredContentUid("walls", event.params.contentId, event.data.after.data()?.email);
  },
);

export const onSetupAuthoredContentWritten = onDocumentWritten(
  {document: "setups/{contentId}", region: REGION},
  async (event) => {
    if (!event.data?.after.exists || unchangedOwner(event)) return;
    await syncAuthoredContentUid("setups", event.params.contentId, event.data.after.data()?.email);
  },
);
