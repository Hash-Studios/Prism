import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {db, REGION, utcDateString} from "./common";
import {parseViews, WALLPAPER_STATS, WALLPAPER_STATS_DAILY} from "./viewStats";

const TRENDING_DAYS = 7;
const DAY_DECAY = 0.8;
const LIST_SIZE = 100;
const POPULAR_CANDIDATES = 500;
const MAX_DAILY_DOCS = 50_000;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

type Counts = Record<string, unknown>;

const count = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? Math.max(0, value) : 0;

/** The UTC days of the trending window, newest first, as `yyyymmdd`. */
export function trendingDays(nowMs: number): string[] {
  return Array.from({length: TRENDING_DAYS}, (_, ago) =>
    utcDateString(new Date(nowMs - ago * MS_PER_DAY)).replace(/-/g, ""));
}

function topIds(scores: Map<string, number>): string[] {
  return [...scores.entries()]
    .filter(([, score]) => score > 0)
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1))
    .slice(0, LIST_SIZE)
    .map(([id]) => id);
}

/** Recent activity per wallpaper. An event counts 0.8 times as much for every day it is old. */
export function trendingWallIds(
  dailyDocs: Array<{wallId?: unknown; day?: unknown} & Counts>,
  days: string[],
): string[] {
  const scores = new Map<string, number>();
  for (const doc of dailyDocs) {
    const ago = days.indexOf(String(doc.day));
    if (ago < 0 || typeof doc.wallId !== "string" || doc.wallId === "") continue;
    const day = count(doc.sets) * 3 + count(doc.downloads) * 2 + count(doc.favs) * 2 + count(doc.shares) * 2 +
      count(doc.views);
    scores.set(doc.wallId, (scores.get(doc.wallId) ?? 0) + day * DAY_DECAY ** ago);
  }
  return topIds(scores);
}

/** All-time score of each wallpaper in `stats` (doc id and counters). */
export function popularWallIds(stats: Array<{id: string; data: Counts}>): string[] {
  const scores = new Map<string, number>();
  for (const {id, data} of stats) {
    scores.set(id, count(data.sets) * 3 + count(data.downloads) * 2 + count(data.favs) * 2 + parseViews(data.views));
  }
  return topIds(scores);
}

/**
 * Every 3 hours: writes `trending/current` (last 7 days, newer days count more) and `popular/current` (all time).
 * Both hold at most 100 wallpaper ids, the keys of `wallpaper_stats`. The app reads them.
 */
export const computeTrending = onSchedule(
  {
    schedule: "0 */3 * * *",
    timeZone: "UTC",
    region: REGION,
    retryCount: 1,
  },
  async () => {
    const days = trendingDays(Date.now());
    const dailySnap = await db.collection(WALLPAPER_STATS_DAILY).where("day", "in", days).limit(MAX_DAILY_DOCS).get();
    if (dailySnap.size >= MAX_DAILY_DOCS) logger.warn("computeTrending: daily docs hit the read cap.", {cap: MAX_DAILY_DOCS});
    const trending = trendingWallIds(dailySnap.docs.map((doc) => doc.data()), days);

    const statsSnap = await db.collection(WALLPAPER_STATS).orderBy("views", "desc").limit(POPULAR_CANDIDATES).get();
    const popular = popularWallIds(statsSnap.docs.map((doc) => ({id: doc.id, data: doc.data()})));

    const updatedAt = admin.firestore.Timestamp.now();
    await db.collection("trending").doc("current").set({wallIds: trending, updatedAt});
    await db.collection("popular").doc("current").set({wallIds: popular, updatedAt});
    logger.info("computeTrending: updated.", {trending: trending.length, popular: popular.length});
  },
);
