import * as admin from "firebase-admin";
import {db, utcDateString} from "./common";

export const FOLDER_STATS_DAILY = "folderStatsDaily";
export const FOLDER_SIGNAL_RATE = "folderSignalRate";
export const FOLDER_TRENDING = "folderTrending";
export const FOLDER_TRENDING_DOC = "current";
/** A public folder needs this many public walls to show in discovery. */
export const MIN_DISCOVER_WALLS = 8;
/** The `webPages` key of the web catalogue's /folders page. */
export const DISCOVER_WEB_PAGE = "folders";

export type FolderSignal = "follow" | "save" | "open";
export const FOLDER_SIGNAL_FIELD: Record<FolderSignal, "follows" | "saves" | "opens"> = {
  follow: "follows", save: "saves", open: "opens",
};

const DAY_MS = 24 * 60 * 60 * 1000;
/** One account counts once per folder and signal in the 7 day scoring window. */
export const SIGNAL_COOLDOWN_MS = 7 * DAY_MS;
/** Accounts younger than this do not move the ranking, so fresh sign-ups cannot farm follows or opens. */
export const MIN_ACTOR_AGE_MS = 7 * DAY_MS;
const DAILY_DOC_TTL_MS = 14 * DAY_MS;

/** Seam for tests: Auth is outside the fake database. */
export const folderSignalDeps: {accountCreatedMs: (uid: string) => Promise<number | null>} = {
  accountCreatedMs: async (uid) => {
    try {
      const created = Date.parse((await admin.auth().getUser(uid)).metadata.creationTime);
      return Number.isFinite(created) ? created : null;
    } catch (err) {
      if ((err as {code?: string}).code === "auth/user-not-found") return null;
      throw err;
    }
  },
};

/**
 * Counts one follow, save or open of a public folder in `folderStatsDaily`. The owner never counts, each account
 * counts once per folder and signal in 7 days, and accounts younger than 7 days do not count. Returns true when counted.
 */
export async function countFolderSignal(
  uid: string, folderId: string, ownerId: string, signal: FolderSignal, nowMs = Date.now(),
): Promise<boolean> {
  if (!uid || !ownerId || uid === ownerId) return false;
  const rateRef = db.collection(FOLDER_SIGNAL_RATE).doc(`${uid}_${folderId}_${signal}`);
  const cachedRate = await rateRef.get();
  const cachedLastAt = cachedRate.data()?.lastAt;
  if (cachedLastAt instanceof admin.firestore.Timestamp && nowMs - cachedLastAt.toMillis() < SIGNAL_COOLDOWN_MS) {
    return false;
  }
  // Check age before spending the cooldown claim. A young account should be able to count its first action once it
  // ages past the threshold, and an Auth outage must not consume the claim either. The cheap cooldown read above
  // avoids an Auth lookup for repeated signals.
  const created = await folderSignalDeps.accountCreatedMs(uid);
  if (created === null || nowMs - created < MIN_ACTOR_AGE_MS) return false;
  const day = utcDateString(new Date(nowMs)).replace(/-/g, "");
  const headerRef = db.collection("publicFolders").doc(folderId);
  const statsRef = db.collection(FOLDER_STATS_DAILY).doc(`${day}_${folderId}`);
  return db.runTransaction(async (tx) => {
    const [rate, header] = await Promise.all([tx.get(rateRef), tx.get(headerRef)]);
    if (!header.exists || header.data()?.ownerId !== ownerId) return false;
    // A folder that cannot be listed must not take one of the job's scored candidate slots.
    if (header.data()?.discoveryHidden === true || Number(header.data()?.itemCount ?? 0) < MIN_DISCOVER_WALLS) return false;
    const lastAt = rate.data()?.lastAt;
    if (lastAt instanceof admin.firestore.Timestamp && nowMs - lastAt.toMillis() < SIGNAL_COOLDOWN_MS) return false;
    tx.set(rateRef, {
      lastAt: admin.firestore.Timestamp.fromMillis(nowMs),
      expireAt: admin.firestore.Timestamp.fromMillis(nowMs + SIGNAL_COOLDOWN_MS),
    });
    tx.set(statsRef, {
      folderId,
      day,
      [FOLDER_SIGNAL_FIELD[signal]]: admin.firestore.FieldValue.increment(1),
      expireAt: admin.firestore.Timestamp.fromMillis(nowMs + DAILY_DOC_TTL_MS),
    }, {merge: true});
    return true;
  });
}

/**
 * Removes a folder from the discover lists and the web /folders page at once, without waiting for the next build.
 * Used when a folder leaves the projection or a moderator hides it from discovery. Writes only when it is listed.
 */
export async function dropFromDiscovery(folderId: string, expectedGeneration?: string): Promise<void> {
  const refs = [
    db.collection(FOLDER_TRENDING).doc(FOLDER_TRENDING_DOC),
    db.collection("webPages").doc(DISCOVER_WEB_PAGE),
  ];
  await Promise.all(refs.map((ref) => db.runTransaction(async (tx) => {
    if (expectedGeneration !== undefined) {
      const fence = await tx.get(db.collection("publicFolderState").doc(folderId));
      if (fence.data()?.generation !== expectedGeneration || fence.data()?.deleting !== true) return;
    }
    const data = (await tx.get(ref)).data();
    if (!data) return;
    const update: Record<string, unknown> = {};
    for (const list of ["trending", "new"]) {
      const entries = Array.isArray(data[list]) ? data[list] as Array<{id?: unknown}> : [];
      const kept = entries.filter((entry) => entry?.id !== folderId);
      if (kept.length !== entries.length) update[list] = kept;
    }
    if (Object.keys(update).length) tx.update(ref, update);
  })));
}
