import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {type EconomyConfig, loadEconomy, rankFor, weekKey} from "./economy";

const USERS = "usersv2";
const LEADERBOARDS = "leaderboards";
const TOP = 50;
// Extra rows so the board still holds 50 after deleted and new accounts are left out.
const CANDIDATES = 100;
const AUTH_BATCH = 100;
const MIN_ACCOUNT_AGE_MS = 7 * 86_400_000;

/** Overridable in tests. */
export const leaderboardIo = {
  /** Account creation time from Firebase Auth by uid. The client can write `usersv2.createdAt`, Auth it cannot. */
  async accountCreatedMs(uids: string[]): Promise<Map<string, number>> {
    const created = new Map<string, number>();
    for (let i = 0; i < uids.length; i += AUTH_BATCH) {
      const result = await admin.auth().getUsers(uids.slice(i, i + AUTH_BATCH).map((uid) => ({uid})));
      for (const user of result.users) created.set(user.uid, Date.parse(user.metadata.creationTime));
    }
    return created;
  },
};

export interface LeaderboardEntry {
  uid: string;
  name: string;
  username: string;
  photo: string;
  xp: number;
  frame: string | null;
  rank: string;
  premium: boolean;
}

/**
 * Entries for the top 50 users, in the order given. Deleted users and accounts under 7 days old are left out; an
 * account with no creation time in `createdMs` counts as too new.
 */
export function leaderboardEntries(
  docs: Array<{id: string; data: admin.firestore.DocumentData}>,
  createdMs: Map<string, number>,
  config: EconomyConfig,
  nowMs: number,
): LeaderboardEntry[] {
  return docs
    .filter(({id, data}) => {
      const created = createdMs.get(id);
      return data.deleted !== true && created !== undefined && Number.isFinite(created) &&
        nowMs - created >= MIN_ACCOUNT_AGE_MS;
    })
    .slice(0, TOP)
    .map(({id, data}) => {
      const xp = typeof data.xpWeek?.xp === "number" ? Math.trunc(data.xpWeek.xp) : 0;
      return {
        uid: id,
        name: str(data.name),
        username: str(data.username),
        photo: str(data.profilePhoto),
        xp,
        frame: str(data.cosmetics?.frame) || null,
        rank: rankFor(typeof data.xp === "number" ? data.xp : xp, config).id,
        premium: data.premium === true,
      };
    });
}

export async function runSnapshotLeaderboard(nowMs: number): Promise<void> {
  const key = weekKey(nowMs);
  const config = await loadEconomy(nowMs);
  const snap = await db.collection(USERS)
    .where("xpWeek.weekKey", "==", key)
    .orderBy("xpWeek.xp", "desc")
    .limit(CANDIDATES)
    .get();
  const docs = snap.docs.map((doc) => ({id: doc.id, data: doc.data()}));
  const createdMs = await leaderboardIo.accountCreatedMs(docs.filter((d) => d.data.deleted !== true).map((d) => d.id));
  const entries = leaderboardEntries(docs, createdMs, config, nowMs);
  const board = {weekKey: key, updatedAt: admin.firestore.Timestamp.fromMillis(nowMs), entries};
  await db.collection(LEADERBOARDS).doc(key).set(board);
  await db.collection(LEADERBOARDS).doc("current").set(board);
  logger.info("snapshotLeaderboard: updated.", {weekKey: key, entries: entries.length});
}

/** Every 3 hours: the top 50 users by XP this week, in `leaderboards/{weekKey}` and `leaderboards/current`. */
export const snapshotLeaderboard = onSchedule(
  {schedule: "0 */3 * * *", timeZone: "UTC", region: REGION, retryCount: 1},
  async () => {
    await runSnapshotLeaderboard(Date.now());
  },
);
