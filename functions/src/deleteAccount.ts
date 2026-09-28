import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const REGION = "asia-south1";
const USERS = "usersv2";
const COIN_TRANSACTIONS = "coinTransactions";
const AI_GENERATIONS = "aiGenerations";
const DRAFT_SETUPS = "draftSetups";

/** Mirrors the client's requirement in delete_account_service.dart: a fresh sign-in before deleting. */
const RECENT_LOGIN_WINDOW_S = 300;

async function deleteWhereEqual(
  collection: string,
  field: string,
  value: string,
  writer: admin.firestore.BulkWriter,
): Promise<void> {
  if (!value) return;
  const snap = await db.collection(collection).where(field, "==", value).get();
  for (const doc of snap.docs) {
    writer.delete(doc.ref);
  }
}

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
  await db.recursiveDelete(userRef.collection("private"));

  // 2-4. Owned records elsewhere in Firestore.
  const writer = db.bulkWriter();
  await deleteWhereEqual(COIN_TRANSACTIONS, "userId", callerUid, writer);
  await deleteWhereEqual(AI_GENERATIONS, "userId", callerUid, writer);
  if (email) await deleteWhereEqual(DRAFT_SETUPS, "email", email, writer);
  await writer.close();

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

  // 6. Delete the Firebase Auth user record.
  await admin.auth().deleteUser(callerUid);

  return {ok: true};
});
