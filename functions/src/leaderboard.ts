import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {type EconomyConfig, loadEconomy, rankFor, weekKey} from "./economy";

const USERS = "usersv2";
const LEADERBOARDS = "leaderboards";
const TOP = 50;
const MIN_ACCOUNT_AGE_MS = 7 * 86_400_000;

export interface LeaderboardEntry {
  uid: string;
  name: string;
  username: string;
  photo: string;
  xp: number;
  frame: string | null;
  rank: string;
}

/** `createdAt` is an ISO string in the app. A missing or unreadable value counts as too new. */
function accountAgeOk(createdAt: unknown, nowMs: number): boolean {
  const ms = typeof createdAt === "string" ? Date.parse(createdAt) :
    typeof createdAt === "number" ? createdAt :
      createdAt instanceof admin.firestore.Timestamp ? createdAt.toMillis() : NaN;
  return Number.isFinite(ms) && nowMs - ms >= MIN_ACCOUNT_AGE_MS;
}

/** Entries for the top users, in the order given. Deleted users and accounts under 7 days old are left out. */
export function leaderboardEntries(
  docs: Array<{id: string; data: admin.firestore.DocumentData}>,
  config: EconomyConfig,
  nowMs: number,
): LeaderboardEntry[] {
  return docs
    .filter(({data}) => data.deleted !== true && accountAgeOk(data.createdAt, nowMs))
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
      };
    });
}

export async function runSnapshotLeaderboard(nowMs: number): Promise<void> {
  const key = weekKey(nowMs);
  const config = await loadEconomy(nowMs);
  const snap = await db.collection(USERS)
    .where("xpWeek.weekKey", "==", key)
    .orderBy("xpWeek.xp", "desc")
    .limit(TOP)
    .get();
  const entries = leaderboardEntries(snap.docs.map((doc) => ({id: doc.id, data: doc.data()})), config, nowMs);
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
