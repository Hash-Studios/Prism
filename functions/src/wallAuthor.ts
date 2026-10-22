import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db, str} from "./common";

/** Collections whose docs copy the owner's name and photo into `by` and `userPhoto`. */
export const AUTHORED_COLLECTIONS = ["walls", "setups"];

/** Only Admin Auth can establish ownership of email-indexed records, including for legacy profiles. */
export async function verifiedEmailForUid(uid: string): Promise<string> {
  try {
    const identity = await admin.auth().getUser(uid);
    return identity.emailVerified ? str(identity.email) : "";
  } catch (err) {
    if (err instanceof Error && "code" in err && err.code === "auth/user-not-found") return "";
    throw err;
  }
}

/** The name and photo that the owner's uploads show. The username fills in when the profile has no name. */
export function authorOf(owner: admin.firestore.DocumentData): {by: string; userPhoto: string} {
  return {by: str(owner.name) || str(owner.username), userPhoto: str(owner.profilePhoto)};
}

/** The author fields of an upload that differ from its owner's profile. An empty name or photo is not copied. */
export function authorUpdate(
  upload: admin.firestore.DocumentData,
  owner: admin.firestore.DocumentData,
): Record<string, string> {
  const {by, userPhoto} = authorOf(owner);
  const update: Record<string, string> = {};
  if (by && by !== upload.by) update.by = by;
  if (userPhoto && userPhoto !== upload.userPhoto) update.userPhoto = userPhoto;
  return update;
}

/**
 * Writes the owner's current name and photo to each of their walls and setups, found by the email as typed or in
 * lower case. Returns the count of docs written.
 */
export async function syncAuthorFields(uid: string, owner: admin.firestore.DocumentData): Promise<number> {
  const email = await verifiedEmailForUid(uid);
  const changes: Array<{ref: admin.firestore.DocumentReference; update: Record<string, string>}> = [];
  for (const address of new Set(email ? [email, email.toLowerCase()] : [])) {
    for (const collection of AUTHORED_COLLECTIONS) {
      const snap = await db.collection(collection).where("email", "==", address).select("by", "userPhoto").get();
      for (const doc of snap.docs) {
        const update = authorUpdate(doc.data(), owner);
        if (Object.keys(update).length > 0) changes.push({ref: doc.ref, update});
      }
    }
  }
  if (changes.length === 0) return 0;

  const writer = db.bulkWriter();
  const writes = changes.map(({ref, update}) => writer.update(ref, update).then(() => true, () => false));
  await writer.close();
  const written = (await Promise.all(writes)).filter(Boolean).length;
  if (written < changes.length) {
    logger.warn("syncAuthorFields: some uploads kept the old name or photo.", {failed: changes.length - written});
  }
  return written;
}
