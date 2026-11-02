import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {isValidRequestId} from "./coinsCallables";
import {CALLABLE_REGIONS, db, findUserByEmail, str} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {emailHash, isLoggedOut, sendToUser} from "./notificationHelper";
import {isStudioWall} from "./studio/isStudioWall";
import {isWotdEligible, premiumCollections, readyWall} from "./wallEligibility";

const CALLABLE_OPTIONS = {region: CALLABLE_REGIONS, cors: true, maxInstances: 10};
const WALL_ID = /^[A-Za-z0-9_-]{1,128}$/;
const REQUESTS = "editorsChoiceRequests";
/** One doc per wall that ever had the creator push. A pick, clear and pick again pushes once. */
const NOTICES = "editorsChoiceNotices";

export interface EditorsChoiceInput {
  wallId: string;
  picked: boolean;
  requestId: string;
}

export interface EditorsChoiceResult {
  wallId: string;
  picked: boolean;
}

/** Seams for tests: the Remote Config read, the owned-delivery check and the push sender. */
export const editorsChoiceIo = {
  premiumCollections,
  readyWall,
  sendToUser,
};

export function parseEditorsChoiceInput(raw: unknown): EditorsChoiceInput {
  const data = (raw ?? {}) as Record<string, unknown>;
  if (typeof data.wallId !== "string" || !WALL_ID.test(data.wallId)) {
    throw new HttpsError("invalid-argument", "wallId is invalid.");
  }
  if (typeof data.picked !== "boolean") throw new HttpsError("invalid-argument", "picked is invalid.");
  if (!isValidRequestId(data.requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  return {wallId: data.wallId, picked: data.picked, requestId: data.requestId};
}

/**
 * Admin only. Sets or clears the Editors' Choice pick of one approved wall. A pick must pass the same check as the free
 * daily pick (wallEligibility), because the Home row shows it to every user. A retried requestId replays its result.
 * The creator hears about a wall's first pick only.
 */
export const setEditorsChoice = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<unknown>) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!await isAdminCaller(request.auth)) throw new HttpsError("permission-denied", "Admins only.");
  const adminUid = request.auth.uid;
  const input = parseEditorsChoiceInput(request.data);
  const requestRef = db.collection(REQUESTS).doc(input.requestId);
  const wallRef = db.collection("walls").doc(input.wallId);
  const {result, firstWrite} = await db.runTransaction(async (tx) => {
    const [prior, wall] = await Promise.all([tx.get(requestRef), tx.get(wallRef)]);
    if (prior.exists) {
      const stored = prior.data() ?? {};
      if (stored.uid !== adminUid || stored.wallId !== input.wallId || stored.picked !== input.picked) {
        throw new HttpsError("already-exists", "requestId was used for another change.");
      }
      return {result: {wallId: input.wallId, picked: input.picked}, firstWrite: false};
    }
    const premium = input.picked ? await editorsChoiceIo.premiumCollections() : [];
    if (input.picked && !await editorsChoiceIo.readyWall(input.wallId, premium)) {
      throw new HttpsError("failed-precondition", "This wall cannot be an Editors' Choice.");
    }
    const data = wall.data();
    if (!data) throw new HttpsError("not-found", "No such wall.");
    if (input.picked) {
      if (data.review !== true || !isWotdEligible(data, premium)) {
        throw new HttpsError("failed-precondition", "This wall cannot be an Editors' Choice.");
      }
      tx.update(wallRef, {
        editorsChoiceAt: data.editorsChoiceAt instanceof admin.firestore.Timestamp ?
          data.editorsChoiceAt :
          admin.firestore.FieldValue.serverTimestamp(),
        editorsChoiceBy: adminUid,
      });
    } else if (data.editorsChoiceAt !== undefined || data.editorsChoiceBy !== undefined) {
      tx.update(wallRef, {
        editorsChoiceAt: admin.firestore.FieldValue.delete(),
        editorsChoiceBy: admin.firestore.FieldValue.delete(),
      });
    }
    tx.set(requestRef, {
      uid: adminUid,
      wallId: input.wallId,
      picked: input.picked,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {result: {wallId: input.wallId, picked: input.picked}, firstWrite: true};
  });
  logger.info("setEditorsChoice", {wallId: input.wallId, picked: input.picked, replayed: !firstWrite});
  if (input.picked) await notifyCreator(input.wallId);
  return result satisfies EditorsChoiceResult;
});

/** Claims the wall's notice doc, then sends the creator one inbox item and push. Studio walls have no creator to tell. */
async function notifyCreator(wallId: string): Promise<void> {
  try {
    const wallRef = db.collection("walls").doc(wallId);
    const wall = (await wallRef.get()).data();
    const email = str(wall?.email);
    if (!wall || !email || wall.editorsChoiceAt == null || await isStudioWall(wallId, wall)) return;
    const creator = await findUserByEmail(email);
    const session = creator ? (await db.doc(`usersv2/${creator.id}/private/session`).get()).data() : undefined;
    const noticeRef = db.collection(NOTICES).doc(wallId);
    const claimed = await db.runTransaction(async (tx) => {
      if ((await tx.get(noticeRef)).exists) return false;
      tx.create(noticeRef, {wallId, createdAt: admin.firestore.FieldValue.serverTimestamp()});
      return true;
    });
    if (!claimed) return;
    let delivered = false;
    try {
      delivered = await editorsChoiceIo.sendToUser(
        {
          ...notificationCopyPayload({kind: "editorsChoicePicked", wallTitle: str(wall.title)}),
          data: {route: "wall", wall_id: wallId, notification_kind: "editors_choice"},
          imageUrl: str(wall.wallpaper_thumb) || undefined,
          modifier: email,
          channelId: "posts",
          scoreKind: "post",
          collapseKey: `editors_choice_${wallId}`,
          docId: `editors_choice_${wallId}`,
        },
        {uid: creator?.id, email, loggedOut: isLoggedOut(creator?.data())},
        session?.postAlerts !== false,
      );
      // sendNotification logs and swallows a failed inbox write, so check the inbox item itself.
      delivered = delivered && (await db.collection("notifications").doc(`editors_choice_${wallId}`).get()).exists;
    } finally {
      // A failed send frees the claim so a replay or a later pick can deliver. The fixed inbox doc id and collapse key
      // make that retry replace, not repeat, anything that did arrive.
      if (!delivered) await noticeRef.delete().catch((err) => logger.warn("setEditorsChoice: claim release failed.", {wallId, err}));
    }
    if (delivered) logger.info("setEditorsChoice: creator notified.", {wallId, creatorHash: emailHash(email)});
  } catch (err) {
    logger.warn("setEditorsChoice: creator notice failed.", {wallId, err});
  }
}
