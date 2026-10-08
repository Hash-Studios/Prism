import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {db, REGION} from "./common";
import {usernameLowerOf} from "./usernameLower";

const USERNAMES = "usernames";
const USERS_V2 = "usersv2";
const USERNAME_PATTERN = /^\w{3,30}$/;

/** A username is 3 to 30 letters, digits or underscores, the same characters the app keeps in `sanitizeUsername`. */
export function parseUsername(raw: unknown): string {
  const username = typeof raw === "string" ? raw.trim() : "";
  if (!USERNAME_PATTERN.test(username)) {
    throw new HttpsError("invalid-argument", "Use 3 to 30 letters, numbers or underscores.");
  }
  return username;
}

/**
 * Gives the caller a username that nobody else holds. The `usernames/{lowercase}` registry decides who owns a name.
 * A name that only a profile holds, with no registry doc yet, counts as taken too. The previous registry doc of the
 * caller is released. The server writes `username` and `usernameLower` on the profile.
 */
export const claimUsername = onCall(
  {
    region: REGION,
    cors: true,
    maxInstances: 10,
  },
  async (request: CallableRequest<{username?: string}>): Promise<{username: string; usernameLower: string}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to choose a username.");
    const username = parseUsername(request.data?.username);
    const lower = usernameLowerOf(username);

    const userRef = db.collection(USERS_V2).doc(uid);
    const nameRef = db.collection(USERNAMES).doc(lower);
    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("failed-precondition", "Your profile was not found.");
      const oldLower = usernameLowerOf(userSnap.data()?.username);
      const oldRef = oldLower && oldLower !== lower ? db.collection(USERNAMES).doc(oldLower) : null;
      const [nameSnap, holders, oldSnap] = await Promise.all([
        tx.get(nameRef),
        tx.get(db.collection(USERS_V2).where("usernameLower", "==", lower).limit(2)),
        oldRef ? tx.get(oldRef) : Promise.resolve(null),
      ]);
      const registryOwner = nameSnap.data()?.uid;
      if ((nameSnap.exists && registryOwner !== uid) || holders.docs.some((doc) => doc.id !== uid)) {
        throw new HttpsError("already-exists", "That username is taken.");
      }
      tx.set(nameRef, {uid, claimedAt: admin.firestore.FieldValue.serverTimestamp()});
      if (oldRef && oldSnap?.data()?.uid === uid) tx.delete(oldRef);
      tx.update(userRef, {username, usernameLower: lower});
    });
    logger.info("claimUsername: claimed.", {uid});
    return {username, usernameLower: lower};
  },
);
