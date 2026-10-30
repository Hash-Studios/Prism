import * as admin from "firebase-admin";
import {removeChallengeVotesForAccount} from "./weeklyChallenges";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {db, CALLABLE_REGIONS, str} from "./common";
import {closeCreatorProgressForDeletion} from "./creatorProgressDeletion";
import {verifiedEmailForUid} from "./wallAuthor";
import {removeUidFollowGraph} from "./profiles";
import {FOLDERS, FOLDER_ITEMS, isFolderItemPath} from "./folders";
import {removeWallRequestsForAccount, REQUEST_RATE_DAILY, VOTE_RATE_DAILY} from "./wallRequests";
import {FOLLOWED_FOLDERS, removeAllFolderFollows, removeOwnerPublicFolders} from "./publicFolders";

const USERS = "usersv2";
const COIN_TRANSACTIONS = "coinTransactions";
const AI_GENERATIONS = "aiGenerations";
const DRAFT_SETUPS = "draftSetups";
const BLOCKED_USERS = "blockedUsers";
const GITHUB_UPLOADS = "githubUploads";
const DRAW_TICKETS = "drawTickets";
const BOOSTS = "boosts";
const DELETED_NAME = "Deleted Account";
/** Docs keyed by the bare uid. The last two are legacy collections. */
const UID_KEYED = ["referralStats", "subscriptionSync", "githubUploadStats", "badgeCheckRate", "users", "tokens"];
/** Docs keyed `<uid>_<day>`. */
const UID_PREFIX_KEYED = [
  "coinAdRateDaily", "coinRefundDaily", "contentReportRateDaily", "userBlockRateDaily", REQUEST_RATE_DAILY, VOTE_RATE_DAILY,
];
/** Public docs that carry the caller's email: they stay, with the creator details blanked. */
const SCRUBBED_BY_EMAIL = ["walls", "setups"];
/** Docs that carry the caller's email and are deleted. */
const DELETED_BY_EMAIL = ["rejectedWalls", "rejectedSetups"];

/** Mirrors the client's requirement in delete_account_service.dart: a fresh sign-in before deleting. */
const RECENT_LOGIN_WINDOW_S = 300;

type QueueDelete = (ref: admin.firestore.DocumentReference) => void;
type QueueUpdate = (ref: admin.firestore.DocumentReference, data: admin.firestore.UpdateData<admin.firestore.DocumentData>) => void;

async function queueDeleteWhereEqual(
  collection: string,
  field: string,
  value: string,
  queue: QueueDelete,
): Promise<void> {
  if (!value) return;
  const snap = await db.collection(collection).where(field, "==", value).get();
  snap.docs.forEach((doc) => queue(doc.ref));
}

async function queueUpdateWhere(
  collection: string,
  field: string,
  op: admin.firestore.WhereFilterOp,
  value: string,
  data: admin.firestore.UpdateData<admin.firestore.DocumentData>,
  queue: QueueUpdate,
): Promise<void> {
  const snap = await db.collection(collection).where(field, op, value).get();
  snap.docs.forEach((doc) => queue(doc.ref, data));
}

/** Deletes the user's boosts and clears `boostedUntil` on the walls they boosted. */
async function queueBoosts(uid: string, queue: QueueDelete, queueUpdate: QueueUpdate): Promise<void> {
  const snap = await db.collection(BOOSTS).where("uid", "==", uid).get();
  for (const doc of snap.docs) {
    queue(doc.ref);
    const wallRef = db.collection("walls").doc(str(doc.data().wallId) || doc.id);
    if ((await wallRef.get()).exists) queueUpdate(wallRef, {boostedUntil: admin.firestore.FieldValue.delete()});
  }
}

async function queueDeleteByIdPrefix(collection: string, prefix: string, queue: QueueDelete): Promise<void> {
  const snap = await db.collection(collection)
    .where(admin.firestore.FieldPath.documentId(), ">=", prefix)
    .where(admin.firestore.FieldPath.documentId(), "<", `${prefix}\uf8ff`)
    .get();
  snap.docs.forEach((doc) => queue(doc.ref));
}

/** Deleted names may be reused. Include stale reservations, but never delete a reassigned name on retry. */
async function releaseUsernames(uid: string): Promise<void> {
  const names = await db.collection("usernames").where("uid", "==", uid).get();
  for (const name of names.docs) {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(name.ref);
      if (current.data()?.uid === uid) tx.delete(name.ref);
    });
  }
}

/**
 * Every step before the auth deletion can run again: deletes of missing docs succeed, the email used to find
 * draft setups is read before the profile is anonymized, and any failed delete throws before the profile is
 * anonymized or the auth user is removed. A retry therefore finishes what an earlier call left.
 */
export const deleteAccount = onCall({region: CALLABLE_REGIONS, cors: true, timeoutSeconds: 300}, async (request: CallableRequest<unknown>) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to delete your account.");

  const authTimeS = request.auth?.token?.auth_time;
  const nowS = Date.now() / 1000;
  if (typeof authTimeS !== "number" || nowS - authTimeS > RECENT_LOGIN_WINDOW_S) {
    throw new HttpsError("failed-precondition", "requires-recent-login");
  }

  const userRef = db.collection(USERS).doc(callerUid);
  const email = await verifiedEmailForUid(callerUid);

  // Close rewards before deleting private state, including cross-user member receipts.
  await closeCreatorProgressForDeletion(callerUid);
  await removeUidFollowGraph(callerUid);
  await removeWallRequestsForAccount(callerUid);
  await removeChallengeVotesForAccount(callerUid);
  // The deletion barrier is closed, so no sync can project these folders again.
  await removeOwnerPublicFolders(callerUid);
  await removeAllFolderFollows(callerUid);

  // 1. Favourite/private subcollections — same set the client wipes in delete_account_service.dart.
  await db.recursiveDelete(userRef.collection("images"));
  await db.recursiveDelete(userRef.collection("setups"));
  await db.recursiveDelete(userRef.collection(BLOCKED_USERS));
  await db.recursiveDelete(userRef.collection("private"));
  await db.recursiveDelete(userRef.collection("history"));
  await db.recursiveDelete(userRef.collection("wallActionReceipts"));
  await db.recursiveDelete(userRef.collection(FOLLOWED_FOLDERS));
  // Items are found by owner, not through their folder, so items whose folder is already gone are deleted too.
  // The owner filter keeps another owner's items in a reused folder id. Items go before their folders.
  const items = (await db.collectionGroup(FOLDER_ITEMS).where("ownerId", "==", callerUid).get())
    .docs.filter((item) => isFolderItemPath(item.ref.path));
  for (let start = 0; start < items.length; start += 400) {
    const batch = db.batch();
    for (const item of items.slice(start, start + 400)) {
      batch.delete(item.ref, {lastUpdateTime: item.updateTime});
    }
    await batch.commit();
  }
  const folders = await db.collection(FOLDERS).where("ownerId", "==", callerUid).get();

  // 2-4. Owned records elsewhere in Firestore.
  const writer = db.bulkWriter();
  // A handler is attached as each delete is queued, so an early failure is never an unhandled rejection.
  const outcomes: Promise<boolean>[] = [];
  const track = (ref: admin.firestore.DocumentReference, write: Promise<unknown>) => {
    outcomes.push(write.then(() => true, (err) => {
      logger.warn("deleteAccount: a write failed.", {path: ref.path, err});
      return false;
    }));
  };
  const queue: QueueDelete = (ref) => track(ref, writer.delete(ref));
  const queueUpdate: QueueUpdate = (ref, data) => track(ref, writer.update(ref, data));
  try {
    await queueDeleteWhereEqual(COIN_TRANSACTIONS, "userId", callerUid, queue);
    await queueDeleteWhereEqual(AI_GENERATIONS, "userId", callerUid, queue);
    await queueDeleteWhereEqual(GITHUB_UPLOADS, "uid", callerUid, queue);
    await queueDeleteWhereEqual(DRAW_TICKETS, "uid", callerUid, queue);
    await queueBoosts(callerUid, queue, queueUpdate);
    // No update-time precondition: the repair trigger updates a folder while its items are deleted above.
    folders.docs.forEach((folder) => queue(folder.ref));
    // The email may be stored as typed or in lower case.
    for (const address of new Set(email ? [email, email.toLowerCase()] : [])) {
      await queueDeleteWhereEqual(DRAFT_SETUPS, "email", address, queue);
      for (const collection of SCRUBBED_BY_EMAIL) {
        await queueUpdateWhere(collection, "email", "==", address,
          {by: DELETED_NAME, userPhoto: "", email: ""}, queueUpdate);
      }
      for (const collection of DELETED_BY_EMAIL) await queueDeleteWhereEqual(collection, "email", address, queue);
      await queueDeleteWhereEqual("notifications", "modifier", address, queue);
      for (const field of ["followers", "following"]) {
        await queueUpdateWhere(USERS, field, "array-contains", address,
          {[field]: admin.firestore.FieldValue.arrayRemove(address)}, queueUpdate);
      }
      await queueUpdateWhere("contentReports", "reporterEmail", "==", address, {reporterEmail: null}, queueUpdate);
    }
    for (const collection of UID_KEYED) queue(db.collection(collection).doc(callerUid));
    for (const collection of UID_PREFIX_KEYED) {
      await queueDeleteByIdPrefix(collection, `${callerUid}_`, queue);
    }
  } finally {
    await writer.close();
  }
  if ((await Promise.all(outcomes)).includes(false)) {
    throw new HttpsError("internal", "Could not delete all account data. Try again.");
  }

  // The deletion barrier already prevents new claims by this UID while its old names are released.
  await releaseUsernames(callerUid);
  // 5. Anonymize usersv2 doc — same fields/shape as the client's anonymize step (full overwrite, not merge),
  // so uploaded walls/setups still resolve to "Deleted Account".
  await userRef.set({
    name: "Deleted Account",
    profilePhoto: "",
    bio: "",
    email: "",
    following: [],
    followers: [],
    premium: false,
    loggedIn: false,
    deleted: true,
    interestCategories: [],
    onboardingV2: {},
    coinState: {},
    coins: 0,
  });

  // 6. Delete the Firebase Auth user record. Already gone means an earlier call finished this step.
  try {
    await admin.auth().deleteUser(callerUid);
  } catch (err) {
    if ((err as {code?: string}).code !== "auth/user-not-found") throw err;
  }

  return {ok: true};
});
