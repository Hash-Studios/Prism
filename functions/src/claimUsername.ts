import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {db, CALLABLE_REGIONS} from "./common";
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
export async function reserveUsername(uid: string, username: string, initial = false): Promise<{
  username: string; usernameLower: string;
}> {
  const lower = usernameLowerOf(username);
  const userRef = db.collection(USERS_V2).doc(uid);
  const nameRef = db.collection(USERNAMES).doc(lower);
  return db.runTransaction(async (tx) => {
    const [userSnap, deletion] = await Promise.all([
      tx.get(userRef), tx.get(db.collection("creatorDeletionState").doc(uid)),
    ]);
    if (!userSnap.exists || userSnap.data()?.deleted === true || deletion.data()?.closed === true) {
      throw new HttpsError("failed-precondition", "Your profile was not found.");
    }
    const user = userSnap.data();
    const oldUsername = typeof user?.username === "string" ? user.username : "";
    const oldLower = usernameLowerOf(oldUsername);
    const oldRef = oldLower && oldLower !== lower ? db.collection(USERNAMES).doc(oldLower) : null;
    const [nameSnap, holders, oldSnap] = await Promise.all([
      tx.get(nameRef),
      tx.get(db.collection(USERS_V2).where("usernameLower", "==", lower).limit(2)),
      oldRef ? tx.get(oldRef) : Promise.resolve(null),
    ]);
    // A callable may beat the creation trigger, or this may be a retried creation event.
    if (initial && oldLower && (oldRef ? oldSnap : nameSnap)?.data()?.uid === uid) {
      return {username: oldUsername, usernameLower: oldLower};
    }
    if ((nameSnap.exists && nameSnap.data()?.uid !== uid) || holders.docs.some((doc) => doc.id !== uid)) {
      throw new HttpsError("already-exists", "That username is taken.");
    }
    tx.set(nameRef, {uid, claimedAt: admin.firestore.FieldValue.serverTimestamp()});
    if (oldRef && oldSnap?.data()?.uid === uid) tx.delete(oldRef);
    tx.update(userRef, {username, usernameLower: lower,
      ...(typeof user?.name === "string" ? {nameLower: usernameLowerOf(user.name)} : {})});
    return {username, usernameLower: lower};
  });
}

/** Initial names use the same reservation transaction as explicit claims, never a query-then-write. */
export async function reserveInitialUsername(uid: string, raw: unknown) {
  const cleaned = typeof raw === "string" ? raw.replace(/\W/g, "").slice(0, 30) : "";
  const base = cleaned.length >= 3 ? cleaned : "user";
  const suffix = uid.replace(/\W/g, "").toLowerCase();
  const candidates = [base, ...[4, 8, 12, 20].map((length) =>
    `${base.slice(0, 29 - Math.min(length, suffix.length))}_${suffix.slice(0, length)}`)];
  for (const candidate of new Set(candidates)) {
    try {
      return await reserveUsername(uid, parseUsername(candidate), true);
    } catch (err) {
      if (!(err instanceof HttpsError) || err.code !== "already-exists") throw err;
    }
  }
  throw new HttpsError("already-exists", "Choose a different username.");
}

export const claimUsername = onCall(
  {
    region: CALLABLE_REGIONS,
    cors: true,
    maxInstances: 10,
  },
  async (request: CallableRequest<{username?: string; initial?: boolean}>): Promise<{username: string; usernameLower: string}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to choose a username.");
    if (request.data?.initial !== undefined && typeof request.data.initial !== "boolean") {
      throw new HttpsError("invalid-argument", "initial must be a boolean.");
    }
    if (request.data?.initial === true && typeof request.data.username !== "string") {
      throw new HttpsError("invalid-argument", "An initial username candidate must be a string.");
    }
    const result = request.data?.initial === true ?
      await reserveInitialUsername(uid, request.data?.username) :
      await reserveUsername(uid, parseUsername(request.data?.username));
    logger.info("claimUsername: claimed.", {uid});
    return result;
  },
);
