import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {claimDay, localDay, offsetsAtDigestTime, releaseDay} from "./followDigest";
import {notificationCopyPayload} from "./notificationCatalog";
import {sendToUser} from "./notificationHelper";
import {FOLLOWED_FOLDERS, PUBLIC_FOLDERS} from "./publicFolders";
import {galleryTags, galleryWall, tagsLine, type GalleryWall} from "./pushGallery";
import {premiumCollections} from "./wallOfTheDay";

/** 13:00 local, away from the 19:00 follow digest, so one person never gets both in the same minute. */
const FOLDER_DIGEST_MINUTE = 13 * 60;
const WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_WALLS_PER_FOLDER = 12;
const CHUNK_SIZE = 25;
const MARKER = "folderDigest";

/** A wall added to a public folder in the window. */
export interface FolderWall {
  docId: string;
  addedMs: number;
  wall: GalleryWall;
}

/** A public folder with new walls, newest first. */
export interface RecentFolder {
  folderId: string;
  ownerId: string;
  name: string;
  walls: FolderWall[];
}

/** One follower's digest. Folders with the most new walls come first; walls alternate between folders. */
export interface FolderDigest {
  uid: string;
  folders: RecentFolder[];
  walls: FolderWall[];
}

/** Groups the new walls into one digest per follower. A wall in two followed folders shows once. */
export function planFolderDigests(folders: RecentFolder[], followersByFolder: Map<string, string[]>): FolderDigest[] {
  const byId = new Map(folders.filter((f) => f.walls.length > 0).map((f) => [f.folderId, f]));
  const foldersOf = new Map<string, RecentFolder[]>();
  for (const [folderId, followers] of followersByFolder) {
    const folder = byId.get(folderId);
    if (!folder) continue;
    for (const uid of new Set(followers)) {
      if (uid !== folder.ownerId) foldersOf.set(uid, [...(foldersOf.get(uid) ?? []), folder]);
    }
  }
  return [...foldersOf].map(([uid, followed]) => {
    const groups = [...followed].sort((a, b) => b.walls.length - a.walls.length ||
      b.walls[0].addedMs - a.walls[0].addedMs || (a.folderId < b.folderId ? -1 : 1));
    const seen = new Set<string>();
    const walls: FolderWall[] = [];
    const longest = Math.max(...groups.map((g) => g.walls.length));
    for (let i = 0; i < longest; i++) {
      for (const group of groups) {
        const wall = group.walls[i];
        if (wall && !seen.has(wall.wall.id)) {
          seen.add(wall.wall.id);
          walls.push(wall);
        }
      }
    }
    return {uid, folders: groups, walls};
  });
}

/**
 * The push for one digest. It keeps a single image: the Wall of the Day or the Drop push is the day's one gallery
 * push. A tap opens the lead folder, where the new walls are first.
 */
export function folderDigestPayload(digest: FolderDigest, day: string) {
  const lead = digest.folders[0];
  return {
    ...notificationCopyPayload({
      kind: "folderDigest",
      folderName: lead.name,
      folderCount: digest.folders.length,
      wallCount: digest.walls.length,
      tags: tagsLine(galleryTags(digest.walls.map((w) => w.wall))),
    }),
    data: {
      route: "folder",
      folder_id: lead.folderId,
      folder_count: String(digest.folders.length),
      url: `https://prismwalls.com/folder/${lead.folderId}`,
      notification_kind: "folder_digest",
      push_kind: "post",
    },
    imageUrl: digest.walls[0].wall.thumb,
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `folder_digest_${day}`,
    docId: `folder_digest_${digest.uid}_${day}`,
  };
}

async function recentFolders(nowMs: number): Promise<RecentFolder[]> {
  const since = admin.firestore.Timestamp.fromMillis(nowMs - WINDOW_MS);
  const headers = await db.collection(PUBLIC_FOLDERS).where("lastAddedAt", ">=", since).get();
  if (headers.empty) return [];
  const premium = await premiumCollections();
  return Promise.all(headers.docs.map(async (header) => {
    const items = await header.ref.collection("items").where("projectedAt", ">=", since)
      .orderBy("projectedAt", "desc").limit(MAX_WALLS_PER_FOLDER).get();
    const walls = await Promise.all(items.docs.map(async (item): Promise<FolderWall | null> => {
      const docId = str(item.data().wallpaperDocumentId);
      if (!docId || docId.includes("/")) return null;
      const snap = await db.collection("walls").doc(docId).get();
      // The push uses the gallery gate: only approved walls that a free user can open.
      const wall = snap.exists ? galleryWall({id: snap.id, data: snap.data() ?? {}}, premium) : null;
      const projected = item.data().projectedAt as admin.firestore.Timestamp | undefined;
      return wall ? {docId, addedMs: projected?.toMillis?.() ?? nowMs, wall} : null;
    }));
    return {
      folderId: header.id,
      ownerId: str(header.data().ownerId),
      name: str(header.data().name),
      walls: walls.filter((w): w is FolderWall => w !== null),
    };
  }));
}

/**
 * Drops folders whose owner blocked the follower or that the follower blocked, and folders the follower no longer
 * follows. Returns null when the follower must get no digest: deleted, signed out, not at 13:00 local, or without
 * the folder push switch on this device's token.
 */
async function deliverable(digest: FolderDigest, offsets: number[]):
  Promise<{digest: FolderDigest; offset: number; email: string} | null> {
  const user = (await db.doc(`usersv2/${digest.uid}`).get()).data();
  const offset = user?.appOpenTimezoneOffsetMinutes;
  const email = str(user?.email);
  if (!user || !email || user.deleted === true || user.loggedIn === false || !offsets.includes(offset)) return null;
  const session = (await db.doc(`usersv2/${digest.uid}/private/session`).get()).data();
  if (session?.folderAlerts !== true || typeof session.fcmToken !== "string" || !session.fcmToken.trim() ||
    session.folderAlertsToken !== session.fcmToken) return null;
  const keep = await Promise.all(digest.folders.map(async (folder) => {
    const [mine, theirs, follows] = await Promise.all([
      db.doc(`usersv2/${digest.uid}/blockedUsers/${folder.ownerId}`).get(),
      db.doc(`usersv2/${folder.ownerId}/blockedUsers/${digest.uid}`).get(),
      db.doc(`usersv2/${digest.uid}/${FOLLOWED_FOLDERS}/${folder.folderId}`).get(),
    ]);
    return !mine.exists && !theirs.exists && follows.exists;
  }));
  const folders = digest.folders.filter((_, i) => keep[i]);
  const replanned = planFolderDigests(folders, new Map(folders.map((f) => [f.folderId, [digest.uid]])))[0];
  return replanned ? {digest: replanned, offset, email} : null;
}

/** Sends the folder digests due at `nowMs`. Returns the number sent. */
export async function sendDueFolderDigests(nowMs: number): Promise<number> {
  const offsets = offsetsAtDigestTime(nowMs, FOLDER_DIGEST_MINUTE);
  const folders = (await recentFolders(nowMs)).filter((f) => f.walls.length > 0);
  if (folders.length === 0) return 0;
  const followersByFolder = new Map<string, string[]>();
  for (const folder of folders) {
    const snap = await db.collection(PUBLIC_FOLDERS).doc(folder.folderId).collection("followers").get();
    followersByFolder.set(folder.folderId, snap.docs.map((d) => d.id));
  }
  // ponytail: every 15 minute run reads each follower's user doc; precompute per-offset lists if followers grow large.
  const digests = planFolderDigests(folders, followersByFolder);
  let sent = 0;
  const failures: unknown[] = [];
  for (let i = 0; i < digests.length; i += CHUNK_SIZE) {
    const results = await Promise.allSettled(digests.slice(i, i + CHUNK_SIZE).map(async (planned) => {
      const ready = await deliverable(planned, offsets);
      if (!ready) return false;
      const day = localDay(nowMs, ready.offset);
      const claim = await claimDay(planned.uid, day, MARKER);
      if (!claim) return false;
      let delivered = false;
      try {
        delivered = await sendToUser({...folderDigestPayload(ready.digest, day), modifier: ready.email},
          {uid: planned.uid, email: ready.email});
        if (!delivered) throw new Error("folderDigest: push delivery failed.");
      } finally {
        if (!delivered) await releaseDay(planned.uid, day, claim.previous, MARKER);
      }
      return true;
    }));
    sent += results.filter((r) => r.status === "fulfilled" && r.value).length;
    results.filter((r): r is PromiseRejectedResult => r.status === "rejected").forEach((r) => {
      failures.push(r.reason);
      logger.warn("folderDigest: one digest failed.", {err: String(r.reason)});
    });
  }
  logger.info("folderDigest: run done.", {offsets, folders: folders.length, digests: digests.length, sent});
  if (failures.length > 0) throw new Error(`folderDigest: ${failures.length} digest delivery failure(s).`);
  return sent;
}

export const sendFolderDigests = onSchedule(
  {schedule: "*/15 * * * *", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540},
  async (event) => {
    const ms = Date.parse(event.scheduleTime);
    await sendDueFolderDigests(Number.isFinite(ms) ? ms : Date.now());
  },
);
