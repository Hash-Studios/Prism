import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, REGION} from "./common";

const USERS = "usersv2";
const COIN_TRANSACTIONS = "coinTransactions";
const AI_GENERATIONS = "aiGenerations";
const DRAFT_SETUPS = "draftSetups";
const BLOCKED_USERS = "blockedUsers";
/** Docs keyed by the bare uid. */
const UID_KEYED = ["referralStats", "subscriptionSync", "githubUploadStats", "badgeCheckRate"];
/** Docs keyed `<uid>_<day>`. */
const UID_PREFIX_KEYED = ["coinAdRateDaily"];

/** Mirrors the client's requirement in delete_account_service.dart: a fresh sign-in before deleting. */
const RECENT_LOGIN_WINDOW_S = 300;

/** Queues the deletes and returns their promises, so a failed delete fails the call instead of going unseen. */
async function queueDeleteWhereEqual(
  collection: string,
  field: string,
  value: string,
  writer: admin.firestore.BulkWriter,
): Promise<Promise<unknown>[]> {
  if (!value) return [];
  const snap = await db.collection(collection).where(field, "==", value).get();
  return snap.docs.map((doc) => writer.delete(doc.ref));
}

async function queueDeleteByIdPrefix(
  collection: string,
  prefix: string,
  writer: admin.firestore.BulkWriter,
): Promise<Promise<unknown>[]> {
  const snap = await db.collection(collection)
    .where(admin.firestore.FieldPath.documentId(), ">=", prefix)
    .where(admin.firestore.FieldPath.documentId(), "<", `${prefix}\uf8ff`)
    .get();
  return snap.docs.map((doc) => writer.delete(doc.ref));
}

/**
 * Every step before the auth deletion can run again: deletes of missing docs succeed, the email used to find
 * draft setups is read before the profile is anonymized, and any failed delete throws before the profile is
 * anonymized or the auth user is removed. A retry therefore finishes what an earlier call left.
 */
export const deleteAccount = onCall({region: REGION, cors: true}, async (request: CallableRequest<unknown>) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to delete your account.");

  const authTimeS = request.auth?.token?.auth_time;
  const nowS = Date.now() / 1000;
  if (typeof authTimeS !== "number" || nowS - authTimeS > RECENT_LOGIN_WINDOW_S) {
    throw new HttpsError("failed-precondition", "requires-recent-login");
  }

  const userRef = db.collection(USERS).doc(callerUid);
  const userSnap = await userRef.get();
  const email = ((userSnap.data()?.email ?? "") as string).toString().trim();

  // 1. Favourite/private subcollections — same set the client wipes in delete_account_service.dart.
  await db.recursiveDelete(userRef.collection("images"));
  await db.recursiveDelete(userRef.collection("setups"));
  await db.recursiveDelete(userRef.collection(BLOCKED_USERS));
  await db.recursiveDelete(userRef.collection("private"));

  // 2-4. Owned records elsewhere in Firestore.
  const writer = db.bulkWriter();
  const queued: Promise<unknown>[] = [
    ...(await queueDeleteWhereEqual(COIN_TRANSACTIONS, "userId", callerUid, writer)),
    ...(await queueDeleteWhereEqual(AI_GENERATIONS, "userId", callerUid, writer)),
    ...(email ? await queueDeleteWhereEqual(DRAFT_SETUPS, "email", email, writer) : []),
    ...UID_KEYED.map((collection) => writer.delete(db.collection(collection).doc(callerUid))),
  ];
  for (const collection of UID_PREFIX_KEYED) {
    queued.push(...(await queueDeleteByIdPrefix(collection, `${callerUid}_`, writer)));
  }
  await writer.close();
  const failed = (await Promise.allSettled(queued)).filter((result) => result.status === "rejected");
  if (failed.length > 0) {
    throw new HttpsError("internal", "Could not delete all account data. Try again.");
  }

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
