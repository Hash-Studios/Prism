import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, findUserByEmail, int, REGION, str} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {isLoggedOut, sendToUser} from "./notificationHelper";

export const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;
export const REMIX_LEDGER = "wallRemixes";
export const REMIX_NOTICES = "wallRemixNotices";

export type RemixNotice = {
  remixId: string;
  ownerEmail: string;
  remixerName: string;
  wallTitle: string;
  thumb: string;
};

/** The original a remix names in `remixOf`, when the id is well formed. The original is not checked here. */
export function remixTarget(data: admin.firestore.DocumentData | undefined): string | null {
  const target = data?.remixOf;
  return typeof target === "string" && DOC_ID.test(target) ? target : null;
}

/** True for an approved AI wall with a prompt. Only such a wall can be credited as an original. */
export function isRemixableOriginal(data: admin.firestore.DocumentData | undefined): boolean {
  return data?.review === true && data.isAiGenerated === true && str(data.aiPrompt).trim() !== "";
}

/**
 * Decides whether a new wall keeps its `remixOf`. Rejects a self reference, an original that is not a remixable AI
 * wall, and an original whose own `remixOf` points back at this wall.
 */
export async function keepRemixOf(wallId: string, data: admin.firestore.DocumentData): Promise<boolean> {
  const target = remixTarget(data);
  if (target === null || target === wallId || data.isAiGenerated !== true) return false;
  const original = (await db.doc(`walls/${target}`).get()).data();
  return isRemixableOriginal(original) && original?.remixOf !== wallId;
}

/** A remix of your own wall never counts. Emails are compared without case or spaces. */
function sameOwner(remix: admin.firestore.DocumentData | undefined, original: admin.firestore.DocumentData | undefined) {
  const email = str(remix?.email).toLowerCase();
  return email !== "" && email === str(original?.email).toLowerCase();
}

/**
 * Moves the remix credit of one wall to the original it names now, in one transaction. The ledger
 * `wallRemixes/{remixId}` records the credited original, so a replayed event changes nothing, and a withdrawn or
 * deleted remix gives its credit back without going below zero. Returns the notice to send, which is returned once
 * per remix until it is marked sent.
 */
export async function syncRemixCredit(remixId: string): Promise<RemixNotice | null> {
  const remixRef = db.doc(`walls/${remixId}`);
  const ledgerRef = db.doc(`${REMIX_LEDGER}/${remixId}`);
  const noticeRef = db.doc(`${REMIX_NOTICES}/${remixId}`);
  return db.runTransaction(async (tx) => {
    const remixSnap = await tx.get(remixRef);
    const ledgerSnap = await tx.get(ledgerRef);
    const noticeSnap = await tx.get(noticeRef);
    const remix = remixSnap.data();
    const requested = remix?.review === true && remix.isAiGenerated === true ? remixTarget(remix) : null;
    const target = requested === remixId ? null : requested;
    const originalRef = target === null ? null : db.doc(`walls/${target}`);
    const original = originalRef ? (await tx.get(originalRef)).data() : undefined;
    const wanted = target !== null && isRemixableOriginal(original) && !sameOwner(remix, original) ? target : "";
    const credited = str(ledgerSnap.data()?.originalId);
    const oldRef = credited !== "" && credited !== wanted ? db.doc(`walls/${credited}`) : null;
    const old = oldRef ? (await tx.get(oldRef)).data() : undefined;

    if (credited !== wanted) {
      if (credited !== "") {
        tx.delete(ledgerRef);
        if (oldRef && old) tx.update(oldRef, {remixCount: Math.max(0, int(old.remixCount) - 1)});
      }
      if (originalRef && wanted !== "") {
        tx.set(ledgerRef, {originalId: wanted, remixId, creditedAt: admin.firestore.FieldValue.serverTimestamp()});
        tx.update(originalRef, {remixCount: int(original?.remixCount) + 1});
      }
    }

    if (wanted === "") return null;
    const notice: RemixNotice = {
      remixId,
      ownerEmail: str(original?.email),
      remixerName: str(remix?.by) || "A creator",
      wallTitle: str(original?.title),
      thumb: str(remix?.wallpaper_thumb),
    };
    if (!noticeSnap.exists) {
      tx.set(noticeRef, {
        originalId: wanted,
        remixId,
        sent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return notice;
    }
    return noticeSnap.data()?.sent !== true ? notice : null;
  });
}

/**
 * Writes the original owner's inbox notice for a remix, without a push, then marks the notice sent. An owner with no
 * account or with post alerts off gets no inbox doc, and the notice is still marked sent.
 */
export async function sendRemixNotice(notice: RemixNotice): Promise<void> {
  const owner = notice.ownerEmail ? await findUserByEmail(notice.ownerEmail) : null;
  if (owner) {
    const session = await db.doc(`usersv2/${owner.id}/private/session`).get();
    if (session.data()?.postAlerts !== false) {
      const ownerData = owner.data();
      await sendToUser({
        ...notificationCopyPayload({
          kind: "wallRemixed",
          remixerName: notice.remixerName,
          wallTitle: notice.wallTitle,
        }),
        data: {route: "wall", wall_id: notice.remixId, notification_kind: "wall_remixed"},
        imageUrl: notice.thumb || undefined,
        modifier: notice.ownerEmail,
        channelId: "posts",
        scoreKind: "post",
        docId: `remix_${notice.remixId}`,
      }, {
        uid: owner.id,
        email: notice.ownerEmail,
        loggedOut: isLoggedOut(ownerData),
        legacyToken: ownerData.fcmToken,
      }, false);
    }
  }
  await db.collection(REMIX_NOTICES).doc(notice.remixId).update({sent: true});
}

/**
 * Keeps the remix credit in step with every write of a wall that names an original. Approval, withdrawal, a changed
 * `remixOf` or a deletion moves the original's `remixCount`, and the owner gets one inbox notice per remix.
 */
export const onWallRemixWritten = onDocumentWritten(
  {
    document: "walls/{wallId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (typeof before?.remixOf !== "string" && typeof after?.remixOf !== "string") return;
    if (before && after && before.review === after.review && before.remixOf === after.remixOf &&
      before.isAiGenerated === after.isAiGenerated) return;

    const notice = await syncRemixCredit(event.params.wallId);
    if (notice) await sendRemixNotice(notice);
  },
);
