import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, CALLABLE_REGIONS, REGION} from "./common";
import {removeAllFolderFollows, removeOwnerPublicFolders} from "./publicFolders";
import {CREATOR_DIRECTORY} from "./creatorDirectory";

const USERS = "usersv2";
const PROFILES = "profiles";
const BLOCKED_USERS = "blockedUsers";
const MAX_UID_LENGTH = 128;
const PROFILE_FIELDS = ["name", "username", "profilePhoto", "bio", "links"] as const;
const PROFILE_LINK_KEYS = new Set([
  "behance", "bio.link", "buymeacoffee", "custom link", "deviantart", "dribbble", "email", "github", "gitlab",
  "instagram", "linkedin", "linktree", "medium", "patreon", "paypal", "reddit", "spotify", "telegram",
  "trello", "twitch", "twitter", "unsplash", "youtube",
]);

type Profile = Record<string, unknown>;

function uidFrom(raw: unknown): string {
  if (typeof raw !== "string" || !raw.trim() || raw.trim().length > MAX_UID_LENGTH ||
    raw.trim().includes("/") || raw.trim() === "." || raw.trim() === "..") {
    throw new HttpsError("invalid-argument", "targetUid is invalid.");
  }
  return raw.trim();
}

function nonEmptyStrings(values: unknown[]): string[] {
  return values.filter((v): v is string => typeof v === "string" && v.length > 0);
}

function cleanCount(value: number): number {
  return Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

export function projectedProfile(
  source: Record<string, unknown>, followerCount: number, followingCount = 0,
): Profile {
  const profile: Profile = {followerCount: cleanCount(followerCount), followingCount: cleanCount(followingCount)};
  for (const field of PROFILE_FIELDS) {
    const value = source[field];
    if (field === "links") {
      if (typeof value === "object" && value !== null && !Array.isArray(value)) {
        const links = Object.fromEntries(Object.entries(value)
          .filter((entry): entry is [string, string] => PROFILE_LINK_KEYS.has(entry[0]) && typeof entry[1] === "string"));
        if (Object.keys(links).length > 0) profile.links = links;
      }
    } else if (typeof value === "string") {
      profile[field] = value;
    }
  }
  if (typeof source.coverPhoto === "string") profile.coverPhoto = source.coverPhoto;
  if (Array.isArray(source.badges)) {
    profile.badges = nonEmptyStrings(source.badges.map((b) => (b as {id?: unknown} | null)?.id));
  }
  if (typeof source.xp === "number" && Number.isFinite(source.xp) && source.xp >= 0) {
    profile.xp = Math.trunc(source.xp);
  }
  const cosmetics = source.cosmetics as Record<string, unknown> | null | undefined;
  if (typeof cosmetics === "object" && cosmetics !== null && !Array.isArray(cosmetics)) {
    const picked: Record<string, string> = {};
    for (const key of ["frame", "nameGlow"]) {
      if (typeof cosmetics[key] === "string") picked[key] = cosmetics[key];
    }
    if (Object.keys(picked).length > 0) profile.cosmetics = picked;
  }
  return profile;
}

function stableJson(value: unknown): string {
  return JSON.stringify(value, (_, v) => v && typeof v === "object" && !Array.isArray(v) ?
    Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}

/** Re-read the private source inside the transaction so delayed events cannot restore stale profile data. */
export async function syncPublicProfile(uid: string): Promise<boolean> {
  const sourceRef = db.collection(USERS).doc(uid);
  const profileRef = db.collection(PROFILES).doc(uid);
  const deletionBarrierRef = db.collection("creatorDeletionState").doc(uid);
  const removeGraph = await db.runTransaction(async (tx) => {
    const [sourceSnap, profileSnap, deletionBarrier] = await Promise.all([
      tx.get(sourceRef), tx.get(profileRef), tx.get(deletionBarrierRef),
    ]);
    if (!sourceSnap.exists || sourceSnap.data()?.deleted === true || deletionBarrier.data()?.closed === true) {
      tx.delete(profileRef);
      return true;
    }
    const count = profileSnap.data()?.followerCount;
    const followingCount = profileSnap.data()?.followingCount;
    const next = projectedProfile(
      sourceSnap.data() ?? {}, typeof count === "number" ? count : 0,
      typeof followingCount === "number" ? followingCount : 0,
    );
    if (!profileSnap.exists || stableJson(profileSnap.data()) !== stableJson(next)) tx.set(profileRef, next);
    return false;
  });
  if (removeGraph) {
    await removeUidFollowGraph(uid);
    await db.collection(CREATOR_DIRECTORY).doc(uid).delete();
  }
  return removeGraph;
}

export const projectUserProfile = onDocumentWritten(
  {document: "usersv2/{uid}", region: REGION, retry: true},
  async (event) => {
    const shouldCleanFolders = await syncPublicProfile(event.params.uid);
    if (event.data?.after.data()?.creatorDirectoryOptOut === true) {
      await db.collection(CREATOR_DIRECTORY).doc(event.params.uid).delete();
    }
    if (shouldCleanFolders) {
      await removeOwnerPublicFolders(event.params.uid);
      await removeAllFolderFollows(event.params.uid);
    }
  },
);

type EdgeResult = "created" | "removed" | "unchanged";

/**
 * The only writer of follow edges. followerCount moves with the follower edge doc, so retries
 * and half-written edges never drift the count.
 */
export async function applyFollowEdge(
  {followerUid, targetUid, follow, notify = false}:
  {followerUid: string; targetUid: string; follow: boolean; notify?: boolean},
): Promise<EdgeResult> {
  const followerProfileRef = db.collection(PROFILES).doc(followerUid);
  const targetProfileRef = db.collection(PROFILES).doc(targetUid);
  const followingRef = followerProfileRef.collection("following").doc(targetUid);
  const followerRef = targetProfileRef.collection("followers").doc(followerUid);
  const followerUserRef = db.collection(USERS).doc(followerUid);
  const targetUserRef = db.collection(USERS).doc(targetUid);

  if (follow) {
    const [followerProfile, targetProfile] = await Promise.all([followerProfileRef.get(), targetProfileRef.get()]);
    if (!followerProfile.exists) await syncPublicProfile(followerUid);
    if (!targetProfile.exists) await syncPublicProfile(targetUid);
  }

  return db.runTransaction(async (tx) => {
    const [following, follower, targetProfile, followerUser, targetUser, followerBarrier, targetBarrier,
      followerBlock, targetBlock, followerProfileSnap] = await Promise.all([
      tx.get(followingRef), tx.get(followerRef), tx.get(targetProfileRef), tx.get(followerUserRef),
      tx.get(targetUserRef), tx.get(db.collection("creatorDeletionState").doc(followerUid)),
      tx.get(db.collection("creatorDeletionState").doc(targetUid)),
      tx.get(followerUserRef.collection(BLOCKED_USERS).doc(targetUid)),
      tx.get(targetUserRef.collection(BLOCKED_USERS).doc(followerUid)), tx.get(followerProfileRef),
    ]);
    const followingCount = Math.max(0, Number(followerProfileSnap.data()?.followingCount) || 0);
    const count = Math.max(0, Number(targetProfile.data()?.followerCount) || 0);

    if (!follow) {
      if (follower.exists) {
        tx.delete(followerRef);
        if (targetProfile.exists) tx.update(targetProfileRef, {followerCount: Math.max(0, count - 1)});
      }
      if (following.exists) {
        tx.delete(followingRef);
        if (followerProfileSnap.exists) tx.update(followerProfileRef, {followingCount: Math.max(0, followingCount - 1)});
      }
      return follower.exists || following.exists ? "removed" : "unchanged";
    }

    if (!followerUser.exists || !targetUser.exists) throw new HttpsError("not-found", "User not found.");
    if (followerUser.data()?.deleted === true || targetUser.data()?.deleted === true ||
      followerBarrier.data()?.closed === true || targetBarrier.data()?.closed === true || !targetProfile.exists) {
      throw new HttpsError("failed-precondition", "This profile is unavailable.");
    }
    if (followerBlock.exists || targetBlock.exists) {
      throw new HttpsError("failed-precondition", "This follow is not allowed.");
    }
    if (follower.exists && following.exists) return "unchanged";
    const createdAt = admin.firestore.FieldValue.serverTimestamp();
    if (!following.exists) {
      tx.set(followingRef, {targetUid, createdAt, notify});
      if (followerProfileSnap.exists) tx.update(followerProfileRef, {followingCount: followingCount + 1});
    }
    if (!follower.exists) {
      tx.set(followerRef, {followerUid, createdAt, notify});
      tx.update(targetProfileRef, {followerCount: count + 1});
    }
    return "created";
  });
}

export const setFollow = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{targetUid?: unknown; following?: unknown}>): Promise<{ok: true}> => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to follow users.");
    const targetUid = uidFrom(request.data?.targetUid);
    if (callerUid === targetUid) throw new HttpsError("invalid-argument", "You cannot follow yourself.");
    if (typeof request.data?.following !== "boolean") {
      throw new HttpsError("invalid-argument", "following must be a boolean.");
    }
    await applyFollowEdge({followerUid: callerUid, targetUid, follow: request.data.following, notify: true});
    return {ok: true};
  },
);

/** Removes both sides of every UID edge before the public profile is deleted. */
export async function removeUidFollowGraph(uid: string): Promise<void> {
  const profileRef = db.doc(`profiles/${uid}`);
  const [following, followers] = await Promise.all([
    profileRef.collection("following").get(),
    profileRef.collection("followers").get(),
  ]);
  for (const edge of following.docs) {
    const targetUid = edge.id;
    const targetProfile = db.doc(`profiles/${targetUid}`);
    const inverse = targetProfile.collection("followers").doc(uid);
    await db.runTransaction(async (tx) => {
      const [current, reverse, target] = await Promise.all([tx.get(edge.ref), tx.get(inverse), tx.get(targetProfile)]);
      if (!current.exists && !reverse.exists) return;
      tx.delete(edge.ref);
      tx.delete(inverse);
      if (target.exists) {
        tx.update(targetProfile, {
          followerCount: Math.max(0, (Number(target.data()?.followerCount) || 0) - 1),
        });
      }
    });
  }
  for (const edge of followers.docs) {
    const followerUid = edge.id;
    const followerProfile = db.doc(`profiles/${followerUid}`);
    const inverse = followerProfile.collection("following").doc(uid);
    await db.runTransaction(async (tx) => {
      const [current, reverse, follower] = await Promise.all([
        tx.get(edge.ref), tx.get(inverse), tx.get(followerProfile),
      ]);
      if (current.exists) tx.delete(edge.ref);
      if (reverse.exists) {
        tx.delete(inverse);
        if (follower.exists) {
          tx.update(followerProfile, {
            followingCount: Math.max(0, (Number(follower.data()?.followingCount) || 0) - 1),
          });
        }
      }
    });
  }
  await db.recursiveDelete(profileRef);
}
