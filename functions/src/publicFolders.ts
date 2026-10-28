import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, CALLABLE_REGIONS, readDailyCount, str, utcDateString} from "./common";
import {isAdminCaller} from "./adminConfig";
import {buildPushGallery, isPreviewUrl, type GalleryDeps} from "./pushGallery";

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

type Doc = admin.firestore.DocumentData;

/** Seams for tests: Auth and R2 are outside the fake database. */
export const publicFolderDeps: {authDisabled: (uid: string) => Promise<boolean>; gallery: GalleryDeps} = {
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

interface Wanted {ownerId: string; name: string}

/** What the projection must show now, or null when it must not exist. Reads the private source every time. */
async function wanted(folderId: string): Promise<Wanted | null> {
  const folderRef = db.collection(FOLDERS).doc(folderId);
  const folder = (await folderRef.get()).data();
  if (!folder || folder.public !== true || folder.moderationHidden === true) return null;
  const ownerId = str(folder.ownerId);
  const name = publicFolderName(folder.name);
  if (!name) {
    // A rename to a name that may not be public makes the folder private again. The owner sees the switch go off.
    await folderRef.update({public: false}).catch(() => undefined);
    return null;
  }
  return (await ownerOpen(ownerId)) ? {ownerId, name} : null;
}

/** A wall that may show in a public folder. Same gates as a free feed: approved, not exclusive, not in a drop. */
export function isPublicWall(wall: Doc | undefined): wall is Doc {
  return Boolean(wall) && wall?.review === true && wall.is_streak_exclusive !== true &&
    wall.dropReserved !== true && !wall.dropWeek;
}

/**
 * The public copy of one private item, or null when it must stay out. Only Prism walls are shown. Every field comes
 * from the server's wall doc, except addedAt, which is clamped so a client cannot pin an item to the top.
 */
export async function projectedItem(item: Doc | undefined, ownerId: string): Promise<Doc | null> {
  if (!item || item.ownerId !== ownerId) return null;
  if (!WALL_PROVIDERS.has(str(item.provider).toLowerCase())) return null;
  const docId = str(item.wallpaperDocumentId);
  const id = str(item.id);
  // An item without a doc id is an older favourite: find its wall by id. An item with one never falls back, so a
  // deleted wall cannot be replaced by another wall that shares its id.
  const wall = docId ? (docId.includes("/") ? undefined : await db.collection("walls").doc(docId).get()) :
    id ? (await db.collection("walls").where("id", "==", id).limit(1).get()).docs[0] : undefined;
  const data = wall?.data();
  if (!wall?.exists || !isPublicWall(data)) return null;
  const thumb = str(data.wallpaper_thumb);
  const wallId = str(data.id) || wall.id;
  if (!thumb.startsWith("https://")) return null;
  const now = admin.firestore.Timestamp.now();
  const added = item.addedAt instanceof admin.firestore.Timestamp && item.addedAt.toMillis() <= now.toMillis() ?
    item.addedAt : now;
  return {id: wallId, provider: "Prism", thumb, wallpaperDocumentId: wall.id, addedAt: added};
}

const publicRef = (folderId: string) => db.collection(PUBLIC_FOLDERS).doc(folderId);

async function inChunks<T>(values: T[], run: (value: T) => Promise<unknown>): Promise<void> {
  for (let i = 0; i < values.length; i += WRITE_CHUNK) await Promise.all(values.slice(i, i + WRITE_CHUNK).map(run));
}

/** Removes one follow edge pair and lowers the count when the follower edge existed. */
async function dropFollowEdge(folderId: string, followerUid: string): Promise<boolean> {
  const header = publicRef(folderId);
  const follower = header.collection(FOLLOWERS).doc(followerUid);
  const reverse = db.collection(USERS).doc(followerUid).collection(FOLLOWED_FOLDERS).doc(folderId);
  return db.runTransaction(async (tx) => {
    const [head, edge, back] = await Promise.all([tx.get(header), tx.get(follower), tx.get(reverse)]);
    if (edge.exists) tx.delete(follower);
    if (back.exists) tx.delete(reverse);
    if (edge.exists && head.exists) {
      tx.update(header, {followerCount: Math.max(0, (Number(head.data()?.followerCount) || 0) - 1)});
    }
    return edge.exists || back.exists;
  });
}

/**
 * Deletes the projection. The header goes first, so the follow callable refuses new followers, and the rules refuse
 * item reads, while the rest is removed. Then every follower edge pair, then the items.
 */
export async function removePublicFolder(folderId: string): Promise<void> {
  const header = publicRef(folderId);
  await header.delete();
  const followers = await header.collection(FOLLOWERS).get();
  await inChunks(followers.docs, (edge) => dropFollowEdge(folderId, edge.id));
  const items = await header.collection(ITEMS).get();
  await inChunks(items.docs, (item) => item.ref.delete());
}

/** Count, newest covers and share image from the projected items. Never creates the header. */
async function refreshHeader(folderId: string, wantedNow: Wanted, added: boolean): Promise<void> {
  const header = publicRef(folderId);
  const items = header.collection(ITEMS);
  const covers = await db.runTransaction(async (tx) => {
    const head = await tx.get(header);
    if (!head.exists) return null;
    const count = (await tx.get(items.count())).data().count;
    const newest = await tx.get(items.orderBy("addedAt", "desc").limit(MAX_COVERS));
    const walls = newest.docs.map((d) => ({id: str(d.data().id), thumb: str(d.data().thumb), tags: [] as string[]}));
    const next: Doc = {
      ownerId: wantedNow.ownerId,
      name: wantedNow.name,
      itemCount: count,
      covers: walls.map((w) => w.thumb),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(added ? {lastAddedAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
    };
    const coversChanged = JSON.stringify(head.data()?.covers ?? []) !== JSON.stringify(next.covers);
    if (coversChanged) next.shareImage = admin.firestore.FieldValue.delete();
    tx.update(header, next);
    return coversChanged ? walls : null;
  });
  if (!covers) return;
  const gallery = await buildPushGallery(covers.filter((w) => isPreviewUrl(w.thumb)), publicFolderDeps.gallery);
  if (!gallery) return;
  await db.runTransaction(async (tx) => {
    const head = await tx.get(header);
    // A newer change replaced the covers while the image was made. That change makes its own image.
    if (!head.exists || JSON.stringify(head.data()?.covers) !== JSON.stringify(covers.map((w) => w.thumb))) return;
    tx.update(header, {shareImage: gallery.stripUrl});
  });
}

/** Writes the full projection from the private folder: header, then every item, then stale items out. */
async function projectFolder(folderId: string, want: Wanted): Promise<void> {
  const header = publicRef(folderId);
  const source = await db.collection(FOLDERS).doc(folderId).collection(ITEMS).where("ownerId", "==", want.ownerId).get();
  const projected = await Promise.all(source.docs.map(async (d) => ({key: d.id, doc: await projectedItem(d.data(), want.ownerId)})));
  await db.runTransaction(async (tx) => {
    const head = await tx.get(header);
    if (head.exists) return;
    tx.set(header, {
      ownerId: want.ownerId, name: want.name, itemCount: 0, covers: [], followerCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  const keep = new Map(projected.filter((p) => p.doc).map((p) => [p.key, p.doc as Doc]));
  const existing = await header.collection(ITEMS).get();
  const existingKeys = new Set(existing.docs.map((d) => d.id));
  await inChunks([...keep], ([key, doc]) => header.collection(ITEMS).doc(key).set(
    existingKeys.has(key) ? doc : {...doc, projectedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true}));
  await inChunks(existing.docs.filter((d) => !keep.has(d.id)), (d) => d.ref.delete());
  await refreshHeader(folderId, want, false);
}

/**
 * Makes the projection match the private folder. Each pass re-reads the source after it writes, so when a toggle,
 * rename or delete lands during a pass, the next pass repairs what the first wrote.
 */
export async function syncPublicFolder(folderId: string, passes = 3): Promise<void> {
  for (let pass = 0; pass < passes; pass++) {
    const want = await wanted(folderId);
    if (want) await projectFolder(folderId, want);
    else await removePublicFolder(folderId);
    const now = await wanted(folderId);
    if (want === null ? now === null : now !== null && now.name === want.name && now.ownerId === want.ownerId) return;
  }
  logger.warn("publicFolders: folder changed during every sync pass.", {folderId});
}

/** Projects or removes one item after a private item write. */
export async function syncPublicFolderItem(folderId: string, itemKey: string): Promise<void> {
  const want = await wanted(folderId);
  const header = publicRef(folderId);
  if (!want) {
    if ((await header.get()).exists) await syncPublicFolder(folderId);
    return;
  }
  if (!(await header.get()).exists) return syncPublicFolder(folderId);
  const item = (await db.collection(FOLDERS).doc(folderId).collection(ITEMS).doc(itemKey).get()).data();
  const doc = await projectedItem(item, want.ownerId);
  const target = header.collection(ITEMS).doc(itemKey);
  let added = false;
  if (doc) {
    added = !(await target.get()).exists;
    await target.set(added ? {...doc, projectedAt: admin.firestore.FieldValue.serverTimestamp()} : doc, {merge: true});
  } else {
    await target.delete();
  }
  await refreshHeader(folderId, want, added);
  // The folder may have gone private while this item was written. The full sync removes it again.
  if (!(await wanted(folderId))) await syncPublicFolder(folderId);
}

/** Removes every public folder of a user. Used when the account closes or is deleted. */
export async function removeOwnerPublicFolders(uid: string): Promise<void> {
  const owned = await db.collection(PUBLIC_FOLDERS).where("ownerId", "==", uid).get();
  await inChunks(owned.docs, (d) => removePublicFolder(d.id));
}

/** Drops every folder follow between two users, both ways. Used after a block. */
export async function removeFolderFollowsBetween(a: string, b: string): Promise<void> {
  for (const [follower, owner] of [[a, b], [b, a]]) {
    const edges = await db.collection(USERS).doc(follower).collection(FOLLOWED_FOLDERS).where("ownerId", "==", owner).get();
    await inChunks(edges.docs, (edge) => dropFollowEdge(edge.id, follower));
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
  {region: CALLABLE_REGIONS, cors: true},
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
      if (!folder.exists || folder.data()?.ownerId !== uid) throw new HttpsError("not-found", "Folder not found.");
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
      await db.runTransaction(async (tx) => (await countDaily(tx, rateRef, MAX_FOLLOW_ACTIONS_PER_DAY))());
      await dropFollowEdge(folderId, uid);
      return {following: false};
    }
    const precheck = (await header.get()).data();
    const ownerId = str(precheck?.ownerId);
    if (!precheck) throw new HttpsError("failed-precondition", "This folder is private or no longer exists.");
    if (ownerId === uid) throw new HttpsError("invalid-argument", "You cannot follow your own folder.");
    if (!(await ownerOpen(uid))) throw new HttpsError("failed-precondition", "This account cannot follow folders.");
    await db.runTransaction(async (tx) => {
      const [head, edge, back, followed, mine, theirs, barrier] = await Promise.all([
        tx.get(header), tx.get(follower), tx.get(reverse), tx.get(userRef.collection(FOLLOWED_FOLDERS).count()),
        tx.get(userRef.collection("blockedUsers").doc(ownerId)),
        tx.get(db.collection(USERS).doc(ownerId).collection("blockedUsers").doc(uid)),
        tx.get(db.collection("creatorDeletionState").doc(ownerId)),
      ]);
      const count = await countDaily(tx, rateRef, MAX_FOLLOW_ACTIONS_PER_DAY);
      if (!head.exists || head.data()?.ownerId !== ownerId || barrier.data()?.closed === true) {
        throw new HttpsError("failed-precondition", "This folder is private or no longer exists.");
      }
      if (mine.exists || theirs.exists) throw new HttpsError("failed-precondition", "This follow is not allowed.");
      count();
      if (edge.exists && back.exists) return;
      if (!back.exists && followed.data().count >= MAX_FOLLOWED_FOLDERS) {
        throw new HttpsError("resource-exhausted", "You follow the most folders you can.");
      }
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
  {region: CALLABLE_REGIONS, cors: true},
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
