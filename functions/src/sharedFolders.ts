import * as admin from "firebase-admin";
import {randomInt} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, CALLABLE_REGIONS, readDailyCount, REGION, str, utcDateString} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {sendToUser} from "./notificationHelper";
import {folderIdFrom, publicFolderDeps} from "./publicFolders";

type Doc = admin.firestore.DocumentData;
type Tx = admin.firestore.Transaction;

const FOLDERS = "folders";
const ITEMS = "items";
const USERS = "usersv2";
export const FOLDER_INVITES = "folderInvites";
export const FOLDER_ACTIVITY = "folderActivity";
const INVITE_RATE = "folderInviteRateDaily";

/** Editors a folder can have, besides its owner. */
export const MAX_FOLDER_EDITORS = 10;
export const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_INVITES_PER_DAY = 30;
/** At most one activity push per folder in this time. */
export const ACTIVITY_PUSH_INTERVAL_MS = 60 * 60 * 1000;
/** A burst of adds waits this long, so it goes out as one push. */
export const ACTIVITY_SETTLE_MS = 10 * 60 * 1000;
const MAX_PENDING_ITEMS = 500;
const CHUNK_SIZE = 25;

// No look-alike characters (0 O 1 I l), as in the short link codes.
const INVITE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const INVITE_CODE_LENGTH = 10;
const INVITE_CODE = new RegExp(`^[${INVITE_ALPHABET}]{${INVITE_CODE_LENGTH}}$`);

export type FolderRole = "owner" | "editor";

/** A person who can add and remove walls. The owner comes from `ownerId`; editors from the server-owned `members` map. */
export interface FolderMember {
  uid: string;
  role: FolderRole;
  addedBy: string;
  addedAtMs: number;
}

/** `folderInvites/{code}`. Server only. Single use, valid for 7 days. */
export interface FolderInvite {
  code: string;
  folderId: string;
  createdBy: string;
  createdAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  folderCreatedAt: admin.firestore.Timestamp;
  usedBy: string | null;
  usedAt: admin.firestore.Timestamp | null;
}

export const JOIN_REFUSALS = ["not_found", "expired", "used", "full", "blocked", "account"] as const;
export type JoinRefusal = (typeof JOIN_REFUSALS)[number];
export type JoinDecision = "join" | "member" | "owner" | JoinRefusal;

const folderRef = (folderId: string) => db.collection(FOLDERS).doc(folderId);
const inviteRef = (code: string) => db.collection(FOLDER_INVITES).doc(code);
const activityRef = (folderId: string) => db.collection(FOLDER_ACTIVITY).doc(folderId);
const activityItemRef = (folderId: string, itemKey: string) => activityRef(folderId).collection("items").doc(itemKey);
const millis = (value: unknown): number => value instanceof admin.firestore.Timestamp ? value.toMillis() : 0;
const sameTimestamp = (a: unknown, b: unknown): boolean =>
  a instanceof admin.firestore.Timestamp && b instanceof admin.firestore.Timestamp && a.isEqual(b);
const isBefore = (a: admin.firestore.Timestamp, b: admin.firestore.Timestamp): boolean =>
  a.seconds < b.seconds || (a.seconds === b.seconds && a.nanoseconds < b.nanoseconds);

/** The editors in a folder doc, oldest first. */
export function editorsOf(folder: Doc | undefined): FolderMember[] {
  const members = folder?.members;
  if (!members || typeof members !== "object") return [];
  return Object.entries(members as Record<string, Doc>)
    .map(([uid, entry]) => ({uid, role: "editor" as const, addedBy: str(entry?.addedBy), addedAtMs: millis(entry?.addedAt)}))
    .sort((a, b) => a.addedAtMs - b.addedAtMs || (a.uid < b.uid ? -1 : 1));
}

/** The owner first, then the editors. */
export function membersOf(folder: Doc | undefined): FolderMember[] {
  const ownerId = str(folder?.ownerId);
  if (!ownerId) return [];
  const owner: FolderMember = {uid: ownerId, role: "owner", addedBy: ownerId, addedAtMs: millis(folder?.createdAt)};
  return [owner, ...editorsOf(folder).filter((m) => m.uid !== ownerId)];
}

/** `members` and `memberIds` always change together. The rules and the "Shared with you" query read `memberIds`. */
function editorFields(editors: Record<string, {addedBy: string; addedAt: admin.firestore.Timestamp}>) {
  return {members: editors, memberIds: Object.keys(editors).sort()};
}

function editorMap(folder: Doc | undefined) {
  const out: Record<string, {addedBy: string; addedAt: admin.firestore.Timestamp}> = {};
  const members = folder?.members;
  if (!members || typeof members !== "object") return out;
  for (const [uid, entry] of Object.entries(members as Record<string, Doc>)) {
    const addedAt = entry?.addedAt instanceof admin.firestore.Timestamp ? entry.addedAt :
      admin.firestore.Timestamp.fromMillis(0);
    out[uid] = {addedBy: str(entry?.addedBy), addedAt};
  }
  return out;
}

export function newInviteCode(pick: (max: number) => number = randomInt): string {
  let code = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) code += INVITE_ALPHABET[pick(INVITE_ALPHABET.length)];
  return code;
}

export function inviteCodeFrom(raw: unknown): string {
  if (typeof raw !== "string" || !INVITE_CODE.test(raw)) throw new HttpsError("invalid-argument", "code is invalid.");
  return raw;
}

/** What a join with this invite would do. Pure, so the preview and the join decide the same way. */
export function joinDecision(input: {
  invite: Doc | undefined;
  folder: Doc | undefined;
  folderCreatedAt?: admin.firestore.Timestamp;
  uid?: string;
  nowMs: number;
  blocked?: boolean;
  accountOpen?: boolean;
}): JoinDecision {
  const {invite, folder, uid} = input;
  if (!invite || !folder) return "not_found";
  if (!sameTimestamp(invite.folderCreatedAt, input.folderCreatedAt)) {
    return "not_found";
  }
  const ownerId = str(folder.ownerId);
  if (!ownerId || ownerId !== str(invite.createdBy)) return "not_found";
  if (uid && input.accountOpen === false) return "account";
  if (uid && uid === ownerId) return "owner";
  const editors = editorsOf(folder);
  if (uid && editors.some((m) => m.uid === uid)) return "member";
  if (input.blocked) return "blocked";
  if (str(invite.usedBy)) return "used";
  if (millis(invite.expiresAt) <= input.nowMs) return "expired";
  if (editors.length >= MAX_FOLDER_EDITORS) return "full";
  return "join";
}

async function accountOpen(tx: Tx, uid: string): Promise<boolean> {
  const [user, barrier] = await Promise.all([
    tx.get(db.collection(USERS).doc(uid)),
    tx.get(db.collection("creatorDeletionState").doc(uid)),
  ]);
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true;
}

/** True when [uid] and any of [others] has blocked the other, in either direction. */
async function blockedWithAny(tx: Tx, uid: string, others: string[]): Promise<boolean> {
  const refs = others.filter((other) => other && other !== uid).flatMap((other) => [
    db.collection(USERS).doc(uid).collection("blockedUsers").doc(other),
    db.collection(USERS).doc(other).collection("blockedUsers").doc(uid),
  ]);
  const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
  return snaps.some((snap) => snap.exists);
}

function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to use shared folders.");
  return uid;
}

const refuse = (reason: JoinRefusal) => new HttpsError("failed-precondition", reason);

/** The owner makes a single-use code for one folder. */
export const createFolderInvite = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{folderId?: unknown}>): Promise<{code: string; expiresAtMs: number}> => {
    const uid = requireUid(request);
    const folderId = folderIdFrom(request.data?.folderId);
    if (await publicFolderDeps.authDisabled(uid)) throw refuse("account");
    const rateRef = db.collection(INVITE_RATE).doc(`${uid}_${utcDateString()}`);
    return db.runTransaction(async (tx) => {
      const folder = await tx.get(folderRef(folderId));
      if (!folder.exists || str(folder.data()?.ownerId) !== uid) {
        throw new HttpsError("permission-denied", "Only the owner can invite people.");
      }
      if (!(await accountOpen(tx, uid))) throw refuse("account");
      if (editorsOf(folder.data()).length >= MAX_FOLDER_EDITORS) throw refuse("full");
      const today = utcDateString();
      const count = readDailyCount(await tx.get(rateRef), today);
      if (count >= MAX_INVITES_PER_DAY) throw new HttpsError("resource-exhausted", "Too many invites today.");
      const code = newInviteCode();
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + INVITE_TTL_MS);
      const invite: FolderInvite = {code, folderId, createdBy: uid, createdAt: now, expiresAt,
        folderCreatedAt: folder.createTime ?? now, usedBy: null, usedAt: null};
      // create() fails the transaction on the near-impossible code collision instead of overwriting an invite.
      tx.create(inviteRef(code), invite);
      tx.set(rateRef, {day: today, count: count + 1}, {merge: true});
      return {code, expiresAtMs: expiresAt.toMillis()};
    });
  },
);

export interface FolderInvitePreview {
  status: JoinDecision;
  folderId?: string;
  name?: string;
  ownerId?: string;
  itemCount?: number;
  covers?: string[];
  memberCount?: number;
}

/**
 * The folder behind a code, for the join page. Guests may look: the owner chose to share the link. A refused code
 * returns only its status, so a used, expired or blocked link shows nothing of the folder.
 */
export const getFolderInvite = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{code?: unknown}>): Promise<FolderInvitePreview> => {
    const uid = request.auth?.uid;
    const code = inviteCodeFrom(request.data?.code);
    if (uid && await publicFolderDeps.authDisabled(uid)) return {status: "not_found"};
    return db.runTransaction(async (tx) => {
      const invite = (await tx.get(inviteRef(code))).data();
      const folderId = str(invite?.folderId);
      const folderSnap = folderId ? await tx.get(folderRef(folderId)) : undefined;
      const folder = folderSnap?.data();
      const others = membersOf(folder).map((m) => m.uid);
      const blocked = uid ? await blockedWithAny(tx, uid, others) : false;
      const open = uid ? await accountOpen(tx, uid) : undefined;
      const decision = joinDecision({invite, folder, folderCreatedAt: folderSnap?.createTime, uid, nowMs: Date.now(),
        blocked, accountOpen: open});
      const status = blocked || decision === "blocked" || decision === "account" ? "not_found" : decision;
      if (status !== "join" && status !== "member" && status !== "owner") return {status};
      return {
        status,
        folderId,
        name: str(folder?.name),
        ownerId: str(folder?.ownerId),
        itemCount: Number(folder?.itemCount) || 0,
        covers: Array.isArray(folder?.covers) ? folder.covers.filter((c: unknown) => typeof c === "string").slice(0, 4) : [],
        memberCount: others.length,
      };
    });
  },
);

/** Spends the code and makes the caller an editor. Joining again as a member returns the folder without a change. */
export const joinFolder = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{code?: unknown}>): Promise<{folderId: string; joined: boolean}> => {
    const uid = requireUid(request);
    const code = inviteCodeFrom(request.data?.code);
    if (await publicFolderDeps.authDisabled(uid)) throw refuse("account");
    return db.runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteRef(code));
      const invite = inviteSnap.data();
      const folderId = str(invite?.folderId);
      const ref = folderRef(folderId || "_");
      const folderSnap = folderId ? await tx.get(ref) : undefined;
      const folder = folderSnap?.data();
      const blocked = await blockedWithAny(tx, uid, membersOf(folder).map((m) => m.uid));
      const open = await accountOpen(tx, uid);
      const decision = joinDecision({invite, folder, folderCreatedAt: folderSnap?.createTime, uid,
        nowMs: Date.now(), blocked, accountOpen: open});
      if (decision === "member" || decision === "owner") return {folderId, joined: false};
      if (decision !== "join") throw refuse(decision);
      const now = admin.firestore.Timestamp.now();
      const editors = editorMap(folder);
      editors[uid] = {addedBy: str(invite?.createdBy), addedAt: now};
      tx.update(ref, editorFields(editors));
      tx.update(inviteSnap.ref, {usedBy: uid, usedAt: now});
      return {folderId, joined: true};
    });
  },
);

/** Takes [uid] out of the folder's editors. True when it was an editor. */
async function removeEditor(folderId: string, uid: string, expectedOwner?: string): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(folderRef(folderId));
    const folder = snap.data();
    if (!folder || (expectedOwner !== undefined && str(folder.ownerId) !== expectedOwner)) return false;
    const editors = editorMap(folder);
    if (!(uid in editors)) return false;
    delete editors[uid];
    tx.update(snap.ref, editorFields(editors));
    return true;
  });
}

export const removeFolderMember = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{folderId?: unknown; uid?: unknown}>): Promise<{removed: boolean}> => {
    const caller = requireUid(request);
    const folderId = folderIdFrom(request.data?.folderId);
    const member = request.data?.uid;
    if (typeof member !== "string" || !member || member.length > 128) {
      throw new HttpsError("invalid-argument", "uid is invalid.");
    }
    const folder = (await folderRef(folderId).get()).data();
    if (!folder || str(folder.ownerId) !== caller) {
      throw new HttpsError("permission-denied", "Only the owner can remove people.");
    }
    return {removed: await removeEditor(folderId, member, caller)};
  },
);

export const leaveFolder = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{folderId?: unknown}>): Promise<{left: boolean}> => {
    const uid = requireUid(request);
    const folderId = folderIdFrom(request.data?.folderId);
    const folder = (await folderRef(folderId).get()).data();
    if (folder && str(folder.ownerId) === uid) {
      throw new HttpsError("invalid-argument", "The owner cannot leave. Delete the folder instead.");
    }
    return {left: await removeEditor(folderId, uid)};
  },
);

/** deleteAccount: the user leaves every shared folder and their open invites go. Their own folders go elsewhere. */
export async function removeAllFolderMemberships(uid: string): Promise<void> {
  const shared = await db.collection(FOLDERS).where("memberIds", "array-contains", uid).get();
  for (const folder of shared.docs) await removeEditor(folder.id, uid);
  const invites = await db.collection(FOLDER_INVITES).where("createdBy", "==", uid).get();
  await Promise.all(invites.docs.map((invite) => invite.ref.delete()));
}

/** blockUser: when one of the two owns a folder the other edits, the editor leaves it. */
export async function removeFolderMembershipsBetween(a: string, b: string): Promise<void> {
  for (const [owner, editor] of [[a, b], [b, a]]) {
    const shared = await db.collection(FOLDERS).where("memberIds", "array-contains", editor).get();
    for (const folder of shared.docs) {
      if (str(folder.data().ownerId) === owner) await removeEditor(folder.id, editor, owner);
    }
  }
}

/** onFolderWritten, after a delete: the folder's invites and pending push go too. */
export async function cleanupDeletedFolder(folderId: string): Promise<void> {
  const invites = await db.collection(FOLDER_INVITES).where("folderId", "==", folderId).get();
  const receipts = await activityRef(folderId).collection("items").get();
  const refs = [...invites.docs.map((invite) => invite.ref), ...receipts.docs.map((receipt) => receipt.ref),
    activityRef(folderId)];
  for (let offset = 0; offset < refs.length; offset += 400) {
    const cleaned = await db.runTransaction(async (tx) => {
      const folder = await tx.get(folderRef(folderId));
      if (folder.exists) return false;
      const snapshots = await Promise.all(refs.slice(offset, offset + 400).map((ref) => tx.get(ref)));
      snapshots.filter((snapshot) => snapshot.exists).forEach((snapshot) => tx.delete(snapshot.ref));
      return true;
    });
    if (!cleaned) return;
  }
}

/** Removes a receipt after a source item is deleted, unless that item key has already been reused. */
export async function forgetFolderActivityItem(folderId: string, itemKey: string,
  itemCreatedAt?: admin.firestore.Timestamp): Promise<void> {
  await db.runTransaction(async (tx) => {
    const source = await tx.get(folderRef(folderId).collection(ITEMS).doc(itemKey));
    const receipt = await tx.get(activityItemRef(folderId, itemKey));
    if (source.exists || !receipt.exists) return;
    if (itemCreatedAt && !sameTimestamp(receipt.data()?.createdAt, itemCreatedAt)) return;
    tx.delete(receipt.ref);
  });
}

/**
 * onFolderItemWritten, on a new item in a folder with editors. Pending adds are keyed by item, so a retried trigger
 * records the same add once.
 */
export async function recordFolderActivity(folderId: string, itemKey: string, item: Doc,
  itemCreatedAt: admin.firestore.Timestamp): Promise<void> {
  await db.runTransaction(async (tx) => {
    const folderSnap = await tx.get(folderRef(folderId));
    const sourceSnap = await tx.get(folderRef(folderId).collection(ITEMS).doc(itemKey));
    const receiptRef = activityItemRef(folderId, itemKey);
    const receipt = await tx.get(receiptRef);
    const folder = folderSnap.data();
    if (!folder || editorsOf(folder).length === 0) return;
    if (folderSnap.createTime && isBefore(itemCreatedAt, folderSnap.createTime)) return;
    if (!sourceSnap.exists || !sameTimestamp(sourceSnap.createTime, itemCreatedAt)) return;
    const ownerId = str(folder.ownerId);
    if (str(item.ownerId) !== ownerId) return;
    const adder = str(item.addedBy) || ownerId;
    const stateSnap = await tx.get(activityRef(folderId));
    let state = stateSnap.data();
    if (state && !sameTimestamp(state.folderCreatedAt, folderSnap.createTime)) state = undefined;
    const pending: Record<string, string> = {...(state?.pending ?? {})};
    const pendingCreatedAt: Record<string, admin.firestore.Timestamp> = {...(state?.pendingCreatedAt ?? {})};
    if (sameTimestamp(receipt.data()?.createdAt, itemCreatedAt)) return;
    if (pending[itemKey] === adder && sameTimestamp(pendingCreatedAt[itemKey], itemCreatedAt)) return;
    if (!(itemKey in pending) && Object.keys(pending).length >= MAX_PENDING_ITEMS) return;
    pending[itemKey] = adder;
    pendingCreatedAt[itemKey] = itemCreatedAt;
    const nowMs = Date.now();
    const firstMs = millis(state?.firstPendingAt) || nowMs;
    const lastSentMs = millis(state?.lastSentAt);
    const dueMs = Math.max(firstMs + ACTIVITY_SETTLE_MS, lastSentMs ? lastSentMs + ACTIVITY_PUSH_INTERVAL_MS : 0);
    tx.set(activityRef(folderId), {
      folderId,
      folderCreatedAt: folderSnap.createTime,
      pending,
      pendingCreatedAt,
      firstPendingAt: admin.firestore.Timestamp.fromMillis(firstMs),
      dueAt: admin.firestore.Timestamp.fromMillis(dueMs),
      lastSentAt: state?.lastSentAt ?? null,
    });
    tx.set(receiptRef, {createdAt: itemCreatedAt});
  });
}

/** One recipient's push: the adder with the most walls leads. Pure. */
export interface ActivityPush {
  uid: string;
  adderUid: string;
  wallCount: number;
  otherAdders: number;
}

/**
 * Plans one push per member. A member never hears about their own adds, nor about adds by someone they blocked or
 * who blocked them. [adds] maps item key to the adder.
 */
export function planActivityPushes(
  members: string[], adds: Record<string, string>, blockedPair: (a: string, b: string) => boolean,
): ActivityPush[] {
  const plans: ActivityPush[] = [];
  for (const uid of members) {
    const counts = new Map<string, number>();
    for (const adder of Object.values(adds)) {
      if (adder === uid || blockedPair(uid, adder)) continue;
      counts.set(adder, (counts.get(adder) ?? 0) + 1);
    }
    if (counts.size === 0) continue;
    const ranked = [...counts].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
    plans.push({
      uid,
      adderUid: ranked[0][0],
      wallCount: ranked.reduce((sum, [, n]) => sum + n, 0),
      otherAdders: ranked.length - 1,
    });
  }
  return plans;
}

export function folderActivityPayload(plan: ActivityPush, folderId: string, folderName: string, adderName: string,
  sentMs: number) {
  return {
    ...notificationCopyPayload({
      kind: "folderActivity",
      adderName,
      folderName,
      wallCount: plan.wallCount,
      otherCount: plan.otherAdders,
    }),
    data: {
      route: "folder",
      folder_id: folderId,
      url: `https://prismwalls.com/folder/${folderId}`,
      notification_kind: "folder_activity",
      push_kind: "post",
    },
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `folder_activity_${folderId}`,
    docId: `folder_activity_${plan.uid}_${folderId}_${sentMs}`,
  };
}

function displayName(user: Doc | undefined): string {
  const name = str(user?.name).trim();
  if (name) return name;
  const username = str(user?.username).trim();
  return username ? `@${username}` : "";
}

/** Claims the pending adds. Returns null when another run took them or they are not due. */
async function claimActivity(folderId: string, nowMs: number): Promise<{
  folder: Doc;
  folderCreatedAt: admin.firestore.Timestamp | undefined;
  adds: Record<string, string>;
  itemCreatedAt: Record<string, admin.firestore.Timestamp>;
} | null> {
  return db.runTransaction(async (tx) => {
    const ref = activityRef(folderId);
    const state = await tx.get(ref);
    const folderSnap = await tx.get(folderRef(folderId));
    const folder = folderSnap.data();
    if (!state.exists) return null;
    if (!folder) {
      tx.delete(ref);
      return null;
    }
    if (!sameTimestamp(state.data()?.folderCreatedAt, folderSnap.createTime)) {
      tx.delete(ref);
      return null;
    }
    const pending = (state.data()?.pending ?? {}) as Record<string, string>;
    if (millis(state.data()?.dueAt) > nowMs || Object.keys(pending).length === 0) return null;
    const itemCreatedAt = (state.data()?.pendingCreatedAt ?? {}) as Record<string, admin.firestore.Timestamp>;
    tx.set(ref, {folderId, folderCreatedAt: folderSnap.createTime, pending: {}, pendingCreatedAt: {}, firstPendingAt: null, dueAt: null,
      lastSentAt: admin.firestore.Timestamp.fromMillis(nowMs)});
    return {folder, folderCreatedAt: folderSnap.createTime, adds: pending, itemCreatedAt};
  });
}

/** Sends the due activity pushes. Every check runs again after the claim, against current data. */
export async function sendDueFolderActivity(nowMs: number): Promise<number> {
  const due = await db.collection(FOLDER_ACTIVITY).where("dueAt", "<=", admin.firestore.Timestamp.fromMillis(nowMs))
    .limit(200).get();
  let sent = 0;
  for (const doc of due.docs) {
    const claim = await claimActivity(doc.id, nowMs);
    if (!claim) continue;
    const currentFolder = await folderRef(doc.id).get();
    const folder = currentFolder.data();
    if (!folder || str(folder.ownerId) !== str(claim.folder.ownerId) ||
      !sameTimestamp(currentFolder.createTime, claim.folderCreatedAt)) continue;
    const ownerId = str(folder.ownerId);
    const keys = Object.keys(claim.adds);
    const items = await db.getAll(...keys.map((key) => folderRef(doc.id).collection(ITEMS).doc(key)));
    const adds: Record<string, string> = {};
    items.forEach((item, i) => {
      const itemData = item.data();
      const adder = str(itemData?.addedBy) || ownerId;
      const expectedCreatedAt = claim.itemCreatedAt[keys[i]];
      if (item.exists && str(itemData?.ownerId) === ownerId && adder === claim.adds[keys[i]] &&
        (!expectedCreatedAt || sameTimestamp(item.createTime, expectedCreatedAt))) adds[keys[i]] = claim.adds[keys[i]];
    });
    const members = membersOf(folder).map((m) => m.uid);
    const people = [...new Set([...members, ...Object.values(adds)])];
    const users = new Map((await db.getAll(...people.map((uid) => db.collection(USERS).doc(uid))))
      .map((snap) => [snap.id, snap.data()]));
    // An adder whose account is gone stays unnamed: drop their adds.
    for (const [key, adder] of Object.entries(adds)) {
      const user = users.get(adder);
      if (!user || user.deleted === true || !displayName(user)) delete adds[key];
    }
    const blockRefs = people.flatMap((a) => people.filter((b) => b !== a)
      .map((b) => db.collection(USERS).doc(a).collection("blockedUsers").doc(b)));
    const blocks = new Set((blockRefs.length ? await db.getAll(...blockRefs) : [])
      .filter((snap) => snap.exists).map((snap) => `${snap.ref.parent.parent?.id}|${snap.id}`));
    const blockedPair = (a: string, b: string) => blocks.has(`${a}|${b}`) || blocks.has(`${b}|${a}`);
    const plans = planActivityPushes(members, adds, blockedPair);
    for (let i = 0; i < plans.length; i += CHUNK_SIZE) {
      const results = await Promise.allSettled(plans.slice(i, i + CHUNK_SIZE).map(async (plan) => {
        const recipient = users.get(plan.uid);
        if (!recipient || recipient.deleted === true) return false;
        const session = (await db.doc(`${USERS}/${plan.uid}/private/session`).get()).data();
        const token = str(session?.folderAlertsToken);
        if (session?.folderAlerts !== true || !token || str(session?.fcmToken) !== token) return false;
        const email = str(recipient.email);
        return sendToUser(
          {...folderActivityPayload(plan, doc.id, str(folder.name), displayName(users.get(plan.adderUid)), nowMs),
            modifier: email},
          {uid: plan.uid, email, folderAlertsToken: token},
        );
      }));
      sent += results.filter((r) => r.status === "fulfilled" && r.value).length;
      results.filter((r): r is PromiseRejectedResult => r.status === "rejected")
        .forEach((r) => logger.warn("folderActivity: one push failed.", {folderId: doc.id, err: String(r.reason)}));
    }
  }
  return sent;
}

export const sendFolderActivityPushes = onSchedule(
  {schedule: "*/10 * * * *", timeZone: "UTC", region: REGION, retryCount: 0, timeoutSeconds: 300},
  async (event) => {
    const ms = Date.parse(event.scheduleTime);
    await sendDueFolderActivity(Number.isFinite(ms) ? ms : Date.now());
  },
);
