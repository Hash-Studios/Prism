import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, findUserByEmail, int, REGION, str} from "./common";
import {activeOwner, addHistory, hash, historyRef, incarnation, type History} from "./creatorStatsHistory";
import {notificationCopyPayload} from "./notificationCatalog";

export const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;
export const REMIX_LEDGER = "wallRemixes";
export const REMIX_NOTICES = "wallRemixNotices";

export type RemixNotice = {
  remixId: string;
  originalId: string;
  originalCreateTime: admin.firestore.Timestamp;
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
  return data?.review === true && data.isAiGenerated === true && typeof data.aiPrompt === "string" &&
    data.aiPrompt.trim() !== "";
}

/**
 * Decides whether a new wall keeps its `remixOf`. Rejects a self reference, an original that is not a remixable AI
 * wall, and an original whose own `remixOf` points back at this wall.
 */
export async function keepRemixOf(wallId: string, data: admin.firestore.DocumentData): Promise<boolean> {
  const target = remixTarget(data);
  if (target === null || target === wallId || data.isAiGenerated !== true) return false;
  const first = (await db.doc(`walls/${target}`).get()).data();
  if (!isRemixableOriginal(first)) return false;
  const visited = new Set([wallId, target]);
  let currentId = remixTarget(first);
  while (currentId !== null) {
    if (visited.has(currentId)) return false;
    visited.add(currentId);
    const next = (await db.doc(`walls/${currentId}`).get()).data();
    if (!next) return true;
    currentId = remixTarget(next);
  }
  return currentId === null;
}

/** A remix of your own wall never counts. Emails are compared without case or spaces. */
function sameOwner(remix: admin.firestore.DocumentData | undefined, original: admin.firestore.DocumentData | undefined) {
  const email = str(remix?.email).toLowerCase();
  return email !== "" && email === str(original?.email).toLowerCase();
}

/** Deletes an invalid submitted link only while the event still refers to the same wall incarnation and link value. */
export async function removeRemixOfIfUnchanged(
  expected: admin.firestore.DocumentSnapshot,
  remixOf: unknown,
): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const current = await tx.get(expected.ref);
    const data = current.data();
    if (!expected.createTime || !current.createTime?.isEqual(expected.createTime) ||
      JSON.stringify(data?.remixOf) !== JSON.stringify(remixOf)) return false;
    const target = remixTarget(data);
    if (target !== null && data?.isAiGenerated === true) {
      const original = (await tx.get(db.doc(`walls/${target}`))).data();
      if (isRemixableOriginal(original) && await acyclicTarget(tx, expected.id, target, original)) return false;
    }
    tx.update(expected.ref, {remixOf: admin.firestore.FieldValue.delete()});
    return true;
  });
}

async function acyclicTarget(
  tx: admin.firestore.Transaction,
  remixId: string,
  target: string,
  firstOriginal: admin.firestore.DocumentData | undefined,
): Promise<boolean> {
  const visited = new Set([remixId]);
  let currentId: string | null = target;
  let current = firstOriginal;
  let first = true;
  while (currentId !== null) {
    if (visited.has(currentId)) return false;
    if (!current) return false;
    if (first && !isRemixableOriginal(current)) return false;
    first = false;
    visited.add(currentId);
    const next = remixTarget(current);
    if (next === null) return true;
    if (visited.has(next)) return false;
    currentId = next;
    current = (await tx.get(db.doc(`walls/${currentId}`))).data();
    if (!current) return true;
  }
  return currentId === null;
}

async function reconcileRemixesOf(originalId: string): Promise<void> {
  const visited = new Set<string>();
  const pending = [originalId];
  while (pending.length > 0) {
    const currentId = pending.shift();
    if (!currentId || visited.has(currentId)) continue;
    visited.add(currentId);
    const rows = await db.collection("walls").where("remixOf", "==", currentId).get();
    for (const row of rows.docs) {
      pending.push(row.id);
      const notice = await syncRemixCredit(row.id);
      if (notice) await sendRemixNotice(notice);
    }
  }
  await Promise.all([...visited].map(async (wallId) => {
    const wallRef = db.doc(`walls/${wallId}`);
    const ledgerQuery = db.collection(REMIX_LEDGER).where("originalId", "==", wallId);
    await db.runTransaction(async (tx) => {
      const wall = await tx.get(wallRef);
      const ledgers = await tx.get(ledgerQuery);
      if (!wall.exists) return;
      const count = ledgers.size;
      if (int(wall.data()?.remixCount) !== count) tx.update(wallRef, {remixCount: count});
    });
  }));
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
    const originalSnap = originalRef ? await tx.get(originalRef) : null;
    const original = originalSnap?.data();
    const wanted = target !== null && isRemixableOriginal(original) && !sameOwner(remix, original) &&
      await acyclicTarget(tx, remixId, target, original) ? target : "";
    const credited = str(ledgerSnap.data()?.originalId);
    const oldRef = credited !== "" && credited !== wanted ? db.doc(`walls/${credited}`) : null;
    const old = oldRef ? (await tx.get(oldRef)).data() : undefined;
    const currentIncarnation = originalSnap?.createTime;

    const creatorUid = str(original?.creatorUid);
    if (wanted && originalSnap && remixSnap.exists && creatorUid && await activeOwner(tx, creatorUid)) {
      const firstRef = db.collection("creatorStatsRemixMarkers").doc(hash(
        `${remixRef.path}:${incarnation(remixSnap)}`,
      ));
      const first = await tx.get(firstRef);
      if (!first.exists) {
        if (credited !== wanted && !noticeSnap.exists) {
          const ref = historyRef(originalSnap);
          const history = await tx.get(ref);
          const now = Date.now();
          const next = addHistory(originalSnap, history.data() as History | undefined, {remixes: 1}, now, now);
          tx.create(firstRef, {counted: true});
          tx.set(ref, next);
        } else {
          tx.create(firstRef, {counted: false});
        }
      }
    }

    if (credited !== wanted) {
      if (credited !== "") {
        tx.delete(ledgerRef);
        if (oldRef && old) tx.update(oldRef, {remixCount: Math.max(0, int(old.remixCount) - 1)});
      }
      if (originalRef && wanted !== "") {
        tx.set(ledgerRef, {
          originalId: wanted,
          remixId,
          creditedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(originalRef, {remixCount: int(original?.remixCount) + 1});
      }
    }

    if (wanted === "") return null;
    const notice: RemixNotice = {
      remixId,
      originalId: wanted,
      originalCreateTime: currentIncarnation as admin.firestore.Timestamp,
      ownerEmail: str(original?.email),
      remixerName: str(remix?.by) || "A creator",
      wallTitle: str(original?.title),
      thumb: str(remix?.wallpaper_thumb),
    };
    if (!noticeSnap.exists) {
      tx.set(noticeRef, {
        originalId: wanted,
        remixId,
        originalCreateTime: currentIncarnation,
        sent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return notice;
    }
    const noticeData = noticeSnap.data();
    if (noticeData?.sent === true) return null;
    if (noticeData?.originalId !== wanted ||
      !(noticeData.originalCreateTime as admin.firestore.Timestamp | undefined)?.isEqual(currentIncarnation as admin.firestore.Timestamp)) {
      tx.update(noticeRef, {originalId: wanted, originalCreateTime: currentIncarnation});
    }
    return notice;
  });
}

/**
 * Writes the original owner's inbox notice for a remix, without a push, then marks the notice sent. An owner with no
 * account or with post alerts off gets no inbox doc, and the notice is still marked sent.
 */
export async function sendRemixNotice(notice: RemixNotice): Promise<void> {
  const owner = notice.ownerEmail ? await findUserByEmail(notice.ownerEmail) : null;
  const remixRef = db.doc(`walls/${notice.remixId}`);
  const originalRef = db.doc(`walls/${notice.originalId}`);
  const noticeRef = db.doc(`${REMIX_NOTICES}/${notice.remixId}`);
  const inboxRef = db.doc(`notifications/remix_${notice.remixId}`);
  const ownerRef = owner ? db.doc(`usersv2/${owner.id}`) : null;
  const sessionRef = owner ? db.doc(`usersv2/${owner.id}/private/session`) : null;

  await db.runTransaction(async (tx) => {
    const remix = (await tx.get(remixRef)).data();
    const originalSnap = await tx.get(originalRef);
    const original = originalSnap.data();
    const marker = (await tx.get(noticeRef)).data();
    const currentTarget = remixTarget(remix);
    const currentChainIsValid = remix?.isAiGenerated === true && currentTarget === notice.originalId &&
      isRemixableOriginal(original) && await acyclicTarget(tx, notice.remixId, notice.originalId, original);
    const ownerData = ownerRef ? (await tx.get(ownerRef)).data() : undefined;
    const session = sessionRef ? (await tx.get(sessionRef)).data() : undefined;
    if (!marker || marker.sent === true) return;
    if (!remix || remix.review !== true || !currentChainIsValid || sameOwner(remix, original) ||
      !originalSnap.createTime?.isEqual(notice.originalCreateTime) || marker.originalId !== notice.originalId ||
      !(marker.originalCreateTime as admin.firestore.Timestamp | undefined)?.isEqual(notice.originalCreateTime) ||
      str(original?.email).toLowerCase() !== notice.ownerEmail.toLowerCase()) return;

    if (ownerRef && ownerData && str(ownerData.email).toLowerCase() === notice.ownerEmail.toLowerCase() &&
      session?.postAlerts !== false) {
      const copy = notificationCopyPayload({
        kind: "wallRemixed",
        remixerName: str(remix.by) || "A creator",
        wallTitle: str(original?.title),
      });
      tx.set(inboxRef, {
        notification: {title: copy.title, body: copy.body},
        ...(copy.message ? {message: {kind: copy.message.kind, args: copy.message.args}} : {}),
        data: {
          route: "wall",
          imageUrl: str(remix.wallpaper_thumb),
          url: "",
          pageName: "",
          arguments: [],
          wall_id: notice.remixId,
          notification_kind: "wall_remixed",
        },
        modifier: notice.ownerEmail,
        pushHandled: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    tx.update(noticeRef, {sent: true});
  });
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
    const wallId = event.params.wallId;
    const remixStateChanged = !before || !after || before.review !== after.review || before.remixOf !== after.remixOf ||
      before.isAiGenerated !== after.isAiGenerated || before.email !== after.email;
    if (remixStateChanged && (typeof before?.remixOf === "string" || typeof after?.remixOf === "string")) {
      const notice = await syncRemixCredit(wallId);
      if (notice) await sendRemixNotice(notice);
    }
    const couldBeOriginal = before?.isAiGenerated === true || after?.isAiGenerated === true;
    if (couldBeOriginal && (!before || !after || before.review !== after.review ||
      before.isAiGenerated !== after.isAiGenerated || before.aiPrompt !== after.aiPrompt ||
      before.email !== after.email || before.remixOf !== after.remixOf)) {
      await reconcileRemixesOf(wallId);
    }
  },
);
