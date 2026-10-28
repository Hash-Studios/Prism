import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, CALLABLE_REGIONS, readDailyCount, REGION, str, utcDateString} from "./common";
import {isAdminCaller} from "./adminConfig";
import {buildPushGallery, isPreviewUrl, type GalleryDeps} from "./pushGallery";
import {r2Secrets} from "./r2Storage";
import {isWotdEligible, premiumCollections} from "./wallOfTheDay";

export const PUBLIC_FOLDERS = "publicFolders";
export const FOLLOWED_FOLDERS = "followedFolders";
const FOLDERS = "folders";
const ITEMS = "items";
const FOLLOWERS = "followers";
const USERS = "usersv2";
const MAX_COVERS = 4;
const MAX_NAME_LENGTH = 50;
const FOLDER_ID = /^[A-Za-z0-9_-]{1,128}$/;
const WALL_PROVIDERS = new Set(["prism", "wall_of_the_day", "walloftheday"]);
const VISIBILITY_RATE = "folderVisibilityRateDaily";
const FOLLOW_RATE = "folderFollowRateDaily";
const MAX_VISIBILITY_CHANGES_PER_DAY = 30;
const MAX_FOLLOW_ACTIONS_PER_DAY = 200;
export const MAX_FOLLOWED_FOLDERS = 500;
const WRITE_CHUNK = 100;
const PROJECTION_STATE = "publicFolderState";

type Doc = admin.firestore.DocumentData;

/** Seams for tests: Auth and R2 are outside the fake database. */
export const publicFolderDeps: {
  authDisabled: (uid: string) => Promise<boolean>;
  premium: () => Promise<string[]>;
  gallery: GalleryDeps;
} = {
  premium: cachedPremiumCollections,
  authDisabled: async (uid) => {
    try {
      return (await admin.auth().getUser(uid)).disabled;
    } catch (err) {
      if ((err as {code?: string}).code === "auth/user-not-found") return true;
      throw err;
    }
  },
  gallery: {},
};

export function folderIdFrom(raw: unknown): string {
  if (typeof raw !== "string" || !FOLDER_ID.test(raw)) throw new HttpsError("invalid-argument", "folderId is invalid.");
  return raw;
}

/**
 * The name others see, or null when it may not be public. Prism has no word filter for public text, so this is the
 * same 1 to 50 character rule as private folders, plus no control, format or bidi characters that hide or reorder text.
 */
export function publicFolderName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const name = raw.replace(/\s+/g, " ").trim();
  if (!name || name.length > MAX_NAME_LENGTH || /[\p{Cc}\p{Cf}\p{Co}\p{Cn}]/u.test(name)) return null;
  return name;
}

/** True when the owner may have public folders: not deleted, not in account deletion, not disabled in Auth. */
async function ownerOpen(uid: string): Promise<boolean> {
  if (!uid) return false;
  const [user, barrier] = await Promise.all([
    db.collection(USERS).doc(uid).get(),
    db.collection("creatorDeletionState").doc(uid).get(),
  ]);
  if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) return false;
  return !(await publicFolderDeps.authDisabled(uid));
}

interface Wanted {ownerId: string; name: string; sourceCreatedAt: admin.firestore.Timestamp}
class OwnerChanged extends Error {}

/** Auth is external; all Firestore lifecycle gates and source data belong to the committing transaction. */
async function folderTransaction<T>(folderId: string, run: (
  tx: admin.firestore.Transaction, want: Wanted | null,
) => Promise<T>): Promise<T> {
  const source = db.collection(FOLDERS).doc(folderId);
  for (;;) {
    const before = (await source.get()).data();
    const ownerId = str(before?.ownerId);
    // Auth is read only for a public folder, so item writes in private folders cost no Auth call. A folder that
    // turns public after this read gets its own sync from the folder trigger.
    const enabled = ownerId !== "" && before?.public === true && !(await publicFolderDeps.authDisabled(ownerId));
    try {
      return await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(source);
        const folder = snapshot.data();
        if (str(folder?.ownerId) !== ownerId) throw new OwnerChanged();
        const [user, barrier] = ownerId ? await Promise.all([
          tx.get(db.collection(USERS).doc(ownerId)), tx.get(db.collection("creatorDeletionState").doc(ownerId)),
        ]) : [undefined, undefined];
        const name = publicFolderName(folder?.name);
        const want = enabled && user?.exists && user.data()?.deleted !== true && barrier?.data()?.closed !== true &&
          folder?.public === true && folder.moderationHidden !== true && name ?
          {ownerId, name, sourceCreatedAt: snapshot.createTime as admin.firestore.Timestamp} : null;
        const result = await run(tx, want);
        // This write is based on this transaction's name, never a stale invalid-name snapshot.
        if (folder?.public === true && !name) tx.update(source, {public: false});
        return result;
      });
    } catch (err) {
      if (!(err instanceof OwnerChanged)) throw err;
    }
  }
}

/**
 * A wall that may show in a public folder: the free gallery gate. Approved, protected original, not streak-exclusive,
 * not in a drop, and not in a premium collection. The app shows the same walls on the folder page.
 */
export function isPublicWall(wall: Doc | undefined, premium: string[]): wall is Doc {
  return Boolean(wall) && wall?.review === true && isWotdEligible(wall, premium);
}

let premiumCache: {at: number; value: Promise<string[]>} | undefined;

/** Remote Config premium collections, kept for 10 minutes so a sync does not read the template per item. */
function cachedPremiumCollections(): Promise<string[]> {
  if (!premiumCache || Date.now() - premiumCache.at > 10 * 60_000) {
    premiumCache = {at: Date.now(), value: premiumCollections()};
  }
  return premiumCache.value;
}

/**
 * The public copy of one private item, or null when it must stay out. Only Prism walls are shown. Every field comes
 * from the server's wall doc, except addedAt, which is clamped so a client cannot pin an item to the top.
 */
export async function projectedItem(
  item: Doc | undefined, ownerId: string, tx?: admin.firestore.Transaction,
): Promise<Doc | null> {
  if (!item || item.ownerId !== ownerId) return null;
  if (!WALL_PROVIDERS.has(str(item.provider).toLowerCase())) return null;
  const docId = str(item.wallpaperDocumentId);
  const id = str(item.id);
  // An item without a doc id is an older favourite: find its wall by id. An item with one never falls back, so a
  // deleted wall cannot be replaced by another wall that shares its id.
  const wallRef = docId && !docId.includes("/") ? db.collection("walls").doc(docId) : undefined;
  const query = db.collection("walls").where("id", "==", id).limit(1);
  const wall = docId ? (wallRef ? await (tx ? tx.get(wallRef) : wallRef.get()) : undefined) :
    id ? (await (tx ? tx.get(query) : query.get())).docs[0] : undefined;
  const data = wall?.data();
  if (!wall?.exists || !isPublicWall(data, await publicFolderDeps.premium())) return null;
  const thumb = str(data.wallpaper_thumb);
  const wallId = str(data.id) || wall.id;
  if (!isPreviewUrl(thumb)) return null;
  const now = admin.firestore.Timestamp.now();
  const added = item.addedAt instanceof admin.firestore.Timestamp && item.addedAt.toMillis() <= now.toMillis() ?
    item.addedAt : now;
  return {id: wallId, provider: "Prism", thumb, wallpaperDocumentId: wall.id, addedAt: added};
}

const publicRef = (folderId: string) => db.collection(PUBLIC_FOLDERS).doc(folderId);
const stateRef = (folderId: string) => db.collection(PROJECTION_STATE).doc(folderId);

function currentHeader(head: admin.firestore.DocumentSnapshot, fence: admin.firestore.DocumentSnapshot, want: Wanted | null) {
  const data = head.data();
  return want !== null && head.exists && data?.ownerId === want.ownerId && fence.data()?.deleting !== true &&
    (!fence.exists || data?.generation === fence.data()?.generation) &&
    (!(data?.sourceCreatedAt instanceof admin.firestore.Timestamp) || data.sourceCreatedAt.isEqual(want.sourceCreatedAt));
}

async function inChunks<T>(values: T[], run: (value: T) => Promise<unknown>): Promise<void> {
  for (let i = 0; i < values.length; i += WRITE_CHUNK) await Promise.all(values.slice(i, i + WRITE_CHUNK).map(run));
}

/** Removes one follow edge pair and lowers the count when the follower edge existed. */
async function dropFollowEdge(folderId: string, followerUid: string, expectedOwner?: string): Promise<boolean> {
  const header = publicRef(folderId);
  const follower = header.collection(FOLLOWERS).doc(followerUid);
  const reverse = db.collection(USERS).doc(followerUid).collection(FOLLOWED_FOLDERS).doc(folderId);
  return db.runTransaction(async (tx) => {
    const [head, edge, back] = await Promise.all([tx.get(header), tx.get(follower), tx.get(reverse)]);
    if (expectedOwner && ((head.exists && head.data()?.ownerId !== expectedOwner) ||
        (back.exists && back.data()?.ownerId !== expectedOwner))) return false;
    if (edge.exists) tx.delete(follower);
    if (back.exists) tx.delete(reverse);
    if (edge.exists && head.exists) {
      tx.update(header, {followerCount: Math.max(0, (Number(head.data()?.followerCount) || 0) - 1)});
    }
    return edge.exists || back.exists;
  });
}

/** A private fence keeps the header absent until every old child and reverse edge is gone. */
async function finishRemoval(folderId: string, generation: string): Promise<void> {
  const header = publicRef(folderId);
  const state = stateRef(folderId);
  const followers = await header.collection(FOLLOWERS).get();
  await inChunks(followers.docs, (edge) => db.runTransaction(async (tx) => {
    const reverse = db.collection(USERS).doc(edge.id).collection(FOLLOWED_FOLDERS).doc(folderId);
    const [fence, head, current, back] = await Promise.all([
      tx.get(state), tx.get(header), tx.get(edge.ref), tx.get(reverse),
    ]);
    if (fence.data()?.generation !== generation || fence.data()?.deleting !== true || head.exists) return;
    if (current.exists) tx.delete(edge.ref);
    if (back.exists) tx.delete(reverse);
  }));
  const items = await header.collection(ITEMS).get();
  await inChunks(items.docs, (item) => db.runTransaction(async (tx) => {
    const [fence, head] = await Promise.all([tx.get(state), tx.get(header)]);
    if (fence.data()?.generation === generation && fence.data()?.deleting === true && !head.exists) tx.delete(item.ref);
  }));
  const reverses = await db.collectionGroup(FOLLOWED_FOLDERS).where("folderId", "==", folderId).get();
  await inChunks(reverses.docs, (back) => db.runTransaction(async (tx) => {
    const [fence, head] = await Promise.all([tx.get(state), tx.get(header)]);
    if (fence.data()?.generation === generation && fence.data()?.deleting === true && !head.exists) tx.delete(back.ref);
  }));
  await db.runTransaction(async (tx) => {
    const fence = await tx.get(state);
    if (fence.data()?.generation === generation && fence.data()?.deleting === true) tx.update(state, {deleting: false});
  });
}

/** Lifecycle callers pass their owner so a delayed old-owner cleanup cannot remove a transferred folder. */
export async function removePublicFolder(folderId: string, ownerId?: string, expectedGeneration?: string): Promise<void> {
  const generation = await db.runTransaction(async (tx) => {
    const header = publicRef(folderId);
    const state = stateRef(folderId);
    const [head, fence] = await Promise.all([tx.get(header), tx.get(state)]);
    if (ownerId && head.exists && head.data()?.ownerId !== ownerId) return null;
    if (ownerId && !head.exists && fence.exists && fence.data()?.ownerId !== ownerId) return null;
    if (expectedGeneration !== undefined && head.exists && str(head.data()?.generation) !== expectedGeneration) return null;
    if (fence.data()?.deleting === true) return str(fence.data()?.generation);
    const next = randomUUID();
    tx.set(state, {generation: next, deleting: true, ownerId: str(head.data()?.ownerId) || ownerId || ""});
    if (head.exists) tx.delete(header);
    return next;
  });
  if (generation) await finishRemoval(folderId, generation);
}

/** Count, newest covers and share image from the projected items. Never creates the header. */
async function refreshHeader(folderId: string): Promise<void> {
  const header = publicRef(folderId);
  const items = header.collection(ITEMS);
  const rendered = await folderTransaction(folderId, async (tx, want) => {
    const [head, fence] = await Promise.all([tx.get(header), tx.get(stateRef(folderId))]);
    if (!want || !currentHeader(head, fence, want)) return null;
    const count = (await tx.get(items.count())).data().count;
    const newest = await tx.get(items.orderBy("addedAt", "desc").limit(MAX_COVERS));
    const latestProjection = await tx.get(items.orderBy("projectedAt", "desc").limit(1));
    const projectedAt = latestProjection.docs[0]?.data().projectedAt;
    const previousAddedAt = head.data()?.lastAddedAt;
    const lastAddedAt = projectedAt instanceof admin.firestore.Timestamp &&
      (!(previousAddedAt instanceof admin.firestore.Timestamp) || projectedAt.toMillis() > previousAddedAt.toMillis()) ?
      projectedAt : previousAddedAt;
    const candidates = await Promise.all(newest.docs.map(async (d) => {
      const source = await tx.get(db.collection(FOLDERS).doc(folderId).collection(ITEMS).doc(d.id));
      const current = await projectedItem(source.data(), want.ownerId, tx);
      return current && current.thumb === d.data().thumb && current.id === d.data().id ?
        {key: d.id, id: str(current.id), thumb: str(current.thumb), tags: [] as string[]} : null;
    }));
    const walls = candidates.filter((w): w is NonNullable<typeof w> => w !== null);
    const next: Doc = {
      ownerId: want.ownerId,
      name: want.name,
      itemCount: count,
      covers: walls.map((w) => w.thumb),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(lastAddedAt instanceof admin.firestore.Timestamp ? {lastAddedAt} : {}),
    };
    const coversChanged = JSON.stringify(head.data()?.covers ?? []) !== JSON.stringify(next.covers);
    const needsShareImage = coversChanged || !head.data()?.shareImage;
    if (coversChanged) next.shareImage = admin.firestore.FieldValue.delete();
    tx.update(header, next);
    return needsShareImage ? {walls, generation: str(head.data()?.generation)} : null;
  });
  if (!rendered) return;
  const {walls: covers, generation} = rendered;
  const gallery = await buildPushGallery(covers.filter((w) => isPreviewUrl(w.thumb)), publicFolderDeps.gallery);
  if (!gallery) return;
  await folderTransaction(folderId, async (tx, want) => {
    const [head, fence] = await Promise.all([tx.get(header), tx.get(stateRef(folderId))]);
    // A newer change replaced the covers while the image was made. That change makes its own image.
    if (!want || !currentHeader(head, fence, want) ||
        str(head.data()?.generation) !== generation ||
        JSON.stringify(head.data()?.covers) !== JSON.stringify(covers.map((w) => w.thumb))) return;
    for (const cover of covers) {
      const source = await tx.get(db.collection(FOLDERS).doc(folderId).collection(ITEMS).doc(cover.key));
      const current = await projectedItem(source.data(), want.ownerId, tx);
      if (!current || current.id !== cover.id || current.thumb !== cover.thumb) return;
    }
    tx.update(header, {shareImage: gallery.stripUrl});
  });
}

/** Returns only once the header is safe to use, or the current source is no longer public. */
async function ensureHeader(folderId: string): Promise<boolean> {
  for (;;) {
    const result = await folderTransaction(folderId, async (tx, want) => {
      const header = publicRef(folderId);
      const state = stateRef(folderId);
      const [head, fence] = await Promise.all([tx.get(header), tx.get(state)]);
      if (fence.data()?.deleting === true) return {cleanup: str(fence.data()?.generation)};
      if (!want && !head.exists && !fence.exists) return {ready: false};
      // A brand-new projection first clears any legacy orphan children. Owner transfers clear old follows too.
      const replacedSource = want && head.data()?.sourceCreatedAt instanceof admin.firestore.Timestamp &&
        !head.data()?.sourceCreatedAt.isEqual(want.sourceCreatedAt);
      if ((!want && head.exists) || (want && head.exists && (head.data()?.ownerId !== want.ownerId || replacedSource)) ||
          (!head.exists && !fence.exists)) {
        const generation = randomUUID();
        tx.set(state, {generation, deleting: true, ownerId: str(head.data()?.ownerId) || want?.ownerId || ""});
        if (head.exists) tx.delete(header);
        return {cleanup: generation};
      }
      if (!want) return {ready: false};
      const generation = str(fence.data()?.generation) || randomUUID();
      if (!fence.exists || fence.data()?.ownerId !== want.ownerId) {
        tx.set(state, {generation, deleting: false, ownerId: want.ownerId});
      }
      if (!head.exists) {
        tx.set(header, {
          generation, ownerId: want.ownerId, sourceCreatedAt: want.sourceCreatedAt, name: want.name,
          itemCount: 0, covers: [], followerCount: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else if (!head.data()?.generation || !head.data()?.sourceCreatedAt) {
        tx.update(header, {generation, sourceCreatedAt: want.sourceCreatedAt});
      }
      return {ready: true};
    });
    if (result.cleanup) await finishRemoval(folderId, result.cleanup);
    else return result.ready === true;
  }
}

/** Reads the current item and wall in the same transaction as the public write, including stale-item removals. */
async function projectCurrentItem(folderId: string, itemKey: string): Promise<void> {
  return folderTransaction(folderId, async (tx, want) => {
    const header = publicRef(folderId);
    const target = header.collection(ITEMS).doc(itemKey);
    const [head, fence, source, previous] = await Promise.all([
      tx.get(header), tx.get(stateRef(folderId)),
      tx.get(db.collection(FOLDERS).doc(folderId).collection(ITEMS).doc(itemKey)), tx.get(target),
    ]);
    if (!want || !currentHeader(head, fence, want)) return;
    const doc = await projectedItem(source.data(), want.ownerId, tx);
    if (doc) tx.set(target, {...doc, projectedAt: previous.data()?.projectedAt ?? admin.firestore.FieldValue.serverTimestamp()});
    else if (previous.exists) tx.delete(target);
  });
}

/** Query results supply keys only. Every write rechecks the current private source transactionally. */
export async function syncPublicFolder(folderId: string): Promise<void> {
  if (!(await ensureHeader(folderId))) return;
  const [source, existing] = await Promise.all([
    db.collection(FOLDERS).doc(folderId).collection(ITEMS).get(), publicRef(folderId).collection(ITEMS).get(),
  ]);
  await inChunks([...new Set([...source.docs, ...existing.docs].map((d) => d.id))], (key) => projectCurrentItem(folderId, key));
  await refreshHeader(folderId);
  // If privacy changed after header creation, complete the now-required cleanup as part of this invocation too.
  await ensureHeader(folderId);
}

/** Projects or removes one item after a private item write. */
export async function syncPublicFolderItem(folderId: string, itemKey: string): Promise<void> {
  if (!(await publicRef(folderId).get()).exists) return syncPublicFolder(folderId);
  if (!(await ensureHeader(folderId))) return;
  await projectCurrentItem(folderId, itemKey);
  await refreshHeader(folderId);
  await ensureHeader(folderId);
}

/**
 * Re-projects the public copies of a wall that stopped passing the gate or changed its thumbnail, for example a wall
 * held after reports, deleted, or moved into a drop. A wall that becomes eligible again shows at the next folder sync.
 */
export async function refreshWallInPublicFolders(wallId: string, before: Doc | undefined, after: Doc | undefined) {
  const premium = await publicFolderDeps.premium();
  const was = isPublicWall(before, premium) ? str(before.wallpaper_thumb) : null;
  const now = isPublicWall(after, premium) ? str(after.wallpaper_thumb) : null;
  if (was === null || was === now) return;
  const items = await db.collectionGroup(ITEMS).where("wallpaperDocumentId", "==", wallId).get();
  const copies = items.docs.map((d) => d.ref.path.split("/"))
    .filter((parts) => parts.length === 4 && parts[0] === PUBLIC_FOLDERS);
  await inChunks(copies, async ([, folderId, , itemKey]) => {
    await projectCurrentItem(folderId, itemKey);
    await refreshHeader(folderId);
  });
}

export const onWallPublicGateChanged = onDocumentWritten(
  {document: "walls/{wallId}", region: REGION, retry: true, secrets: r2Secrets},
  async (event) => refreshWallInPublicFolders(event.params.wallId, event.data?.before?.data(), event.data?.after?.data()),
);

/** Removes every public folder of a user. Used when the account closes or is deleted. */
export async function removeOwnerPublicFolders(uid: string): Promise<void> {
  const [owned, pending] = await Promise.all([
    db.collection(PUBLIC_FOLDERS).where("ownerId", "==", uid).get(),
    db.collection(PROJECTION_STATE).where("ownerId", "==", uid).get(),
  ]);
  await inChunks(owned.docs, (d) => removePublicFolder(d.id, uid, str(d.data().generation)));
  await inChunks(pending.docs.filter((d) => d.data().deleting === true),
    (d) => finishRemoval(d.id, str(d.data().generation)));
}

/** Drops every folder follow between two users, both ways. Used after a block. */
export async function removeFolderFollowsBetween(a: string, b: string): Promise<void> {
  for (const [follower, owner] of [[a, b], [b, a]]) {
    const edges = await db.collection(USERS).doc(follower).collection(FOLLOWED_FOLDERS).where("ownerId", "==", owner).get();
    await inChunks(edges.docs, (edge) => dropFollowEdge(edge.id, follower, owner));
  }
}

/** Removes every folder the user follows. Used by account deletion. */
export async function removeAllFolderFollows(uid: string): Promise<void> {
  const edges = await db.collection(USERS).doc(uid).collection(FOLLOWED_FOLDERS).get();
  await inChunks(edges.docs, (edge) => dropFollowEdge(edge.id, uid));
}

async function countDaily(tx: admin.firestore.Transaction, ref: admin.firestore.DocumentReference, max: number) {
  const today = utcDateString();
  const count = readDailyCount(await tx.get(ref), today);
  if (count >= max) throw new HttpsError("resource-exhausted", "Too many changes today. Try again tomorrow.");
  return () => tx.set(ref, {day: today, count: count + 1}, {merge: true});
}

export const setFolderPublic = onCall(
  {region: CALLABLE_REGIONS, cors: true, secrets: r2Secrets},
  async (request: CallableRequest<{folderId?: unknown; public?: unknown}>): Promise<{public: boolean}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to share folders.");
    const folderId = folderIdFrom(request.data?.folderId);
    const makePublic = request.data?.public;
    if (typeof makePublic !== "boolean") throw new HttpsError("invalid-argument", "public must be a boolean.");
    if (makePublic && !(await ownerOpen(uid))) throw new HttpsError("failed-precondition", "This account cannot share folders.");
    const folderRef = db.collection(FOLDERS).doc(folderId);
    await db.runTransaction(async (tx) => {
      const folder = await tx.get(folderRef);
      const [user, barrier] = makePublic ? await Promise.all([
        tx.get(db.collection(USERS).doc(uid)), tx.get(db.collection("creatorDeletionState").doc(uid)),
      ]) : [undefined, undefined];
      if (!folder.exists || folder.data()?.ownerId !== uid) throw new HttpsError("not-found", "Folder not found.");
      if (makePublic && (!user?.exists || user.data()?.deleted === true || barrier?.data()?.closed === true)) {
        throw new HttpsError("failed-precondition", "This account cannot share folders.");
      }
      if ((folder.data()?.public === true) === makePublic) return;
      if (makePublic && folder.data()?.moderationHidden === true) {
        throw new HttpsError("failed-precondition", "hidden");
      }
      if (makePublic && !publicFolderName(folder.data()?.name)) throw new HttpsError("failed-precondition", "name");
      const count = await countDaily(tx, db.collection(VISIBILITY_RATE).doc(`${uid}_${utcDateString()}`),
        MAX_VISIBILITY_CHANGES_PER_DAY);
      tx.update(folderRef, {public: makePublic});
      count();
    });
    await syncPublicFolder(folderId);
    return {public: (await publicRef(folderId).get()).exists};
  },
);

export const setFolderFollow = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{folderId?: unknown; following?: unknown}>): Promise<{following: boolean}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to follow folders.");
    const folderId = folderIdFrom(request.data?.folderId);
    const follow = request.data?.following;
    if (typeof follow !== "boolean") throw new HttpsError("invalid-argument", "following must be a boolean.");
    const header = publicRef(folderId);
    const follower = header.collection(FOLLOWERS).doc(uid);
    const userRef = db.collection(USERS).doc(uid);
    const reverse = userRef.collection(FOLLOWED_FOLDERS).doc(folderId);
    const rateRef = db.collection(FOLLOW_RATE).doc(`${uid}_${utcDateString()}`);
    if (!follow) {
      await dropFollowEdge(folderId, uid);
      return {following: false};
    }
    const precheck = (await header.get()).data();
    const ownerId = str(precheck?.ownerId);
    if (!precheck) throw new HttpsError("failed-precondition", "This folder is private or no longer exists.");
    if (ownerId === uid) throw new HttpsError("invalid-argument", "You cannot follow your own folder.");
    if (!(await ownerOpen(uid))) throw new HttpsError("failed-precondition", "This account cannot follow folders.");
    await folderTransaction(folderId, async (tx, want) => {
      const [head, edge, back, followed, mine, theirs, user, barrier, fence] = await Promise.all([
        tx.get(header), tx.get(follower), tx.get(reverse), tx.get(userRef.collection(FOLLOWED_FOLDERS).count()),
        tx.get(userRef.collection("blockedUsers").doc(ownerId)),
        tx.get(db.collection(USERS).doc(ownerId).collection("blockedUsers").doc(uid)),
        tx.get(userRef), tx.get(db.collection("creatorDeletionState").doc(uid)), tx.get(stateRef(folderId)),
      ]);
      if (!want || want.ownerId !== ownerId || !currentHeader(head, fence, want)) {
        throw new HttpsError("failed-precondition", "This folder is private or no longer exists.");
      }
      if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) {
        throw new HttpsError("failed-precondition", "This account cannot follow folders.");
      }
      if (mine.exists || theirs.exists) throw new HttpsError("failed-precondition", "This follow is not allowed.");
      if (edge.exists && back.exists) return;
      const count = await countDaily(tx, rateRef, MAX_FOLLOW_ACTIONS_PER_DAY);
      if (!back.exists && followed.data().count >= MAX_FOLLOWED_FOLDERS) {
        throw new HttpsError("resource-exhausted", "You follow the most folders you can.");
      }
      count();
      const createdAt = admin.firestore.FieldValue.serverTimestamp();
      if (!back.exists) tx.set(reverse, {folderId, ownerId, createdAt});
      if (!edge.exists) {
        tx.set(follower, {uid, createdAt});
        tx.update(header, {followerCount: (Number(head.data()?.followerCount) || 0) + 1});
      }
    });
    return {following: true};
  },
);

/** Moderators hide or show one public folder. A hidden folder cannot be made public again by its owner. */
export const setFolderHidden = onCall(
  {region: CALLABLE_REGIONS, cors: true, secrets: r2Secrets},
  async (request: CallableRequest<{folderId?: unknown; hidden?: unknown}>): Promise<{ok: true}> => {
    if (!(await isAdminCaller(request.auth))) throw new HttpsError("permission-denied", "Admins only.");
    const folderId = folderIdFrom(request.data?.folderId);
    if (typeof request.data?.hidden !== "boolean") throw new HttpsError("invalid-argument", "hidden must be a boolean.");
    await hideFolder(folderId, request.data.hidden);
    return {ok: true};
  },
);

export async function hideFolder(folderId: string, hidden: boolean): Promise<void> {
  const folderRef = db.collection(FOLDERS).doc(folderId);
  if (!(await folderRef.get()).exists) throw new HttpsError("not-found", "Folder not found.");
  await folderRef.update({moderationHidden: hidden});
  await syncPublicFolder(folderId);
}
