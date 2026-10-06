import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {sendNotification} from "./notificationHelper";
import {db, REGION, utcDateString} from "./common";

const DEFAULT_PREMIUM_COLLECTIONS = ["space", "abstract", "flat", "mesh gradients", "fluids"];
const BUCKET_STEP_MINUTES = 15;
const PUSH_LOCAL_MINUTE = 9 * 60;
const MAX_PICK_AGE_MS = 30 * 60 * 60 * 1000;

/** Walls that a free user cannot open are never the free daily pick. */
export function isWotdEligible(wall: admin.firestore.DocumentData, premiumCollections: string[]): boolean {
  if (wall.is_streak_exclusive === true) return false;
  const collections: unknown[] = Array.isArray(wall.collections) ? wall.collections : [];
  return !collections.some((c) => premiumCollections.includes(String(c).trim()));
}

/** Parses the app's Remote Config list format: `["a", "b"]` or `a, b`. */
export function parseCollectionList(raw: string): string[] {
  return raw.replace(/["[\]]/g, "").split(",").map((e) => e.trim()).filter((e) => e.length > 0);
}

async function premiumCollections(): Promise<string[]> {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const value = (template.parameters?.premiumCollections?.defaultValue as {value?: string} | undefined)?.value;
    const parsed = value ? parseCollectionList(value) : [];
    return parsed.length > 0 ? parsed : DEFAULT_PREMIUM_COLLECTIONS;
  } catch (err) {
    logger.warn("Could not read premiumCollections from Remote Config; using the app defaults.", {err});
    return DEFAULT_PREMIUM_COLLECTIONS;
  }
}

/** Topic of the devices whose clock is `offsetMinutes` ahead of UTC, for example `wall_of_the_day_utc_p0530`. FCM topic names cannot hold `+`, so `p` marks east of UTC and `m` west. */
export function wotdBucketTopic(offsetMinutes: number): string {
  const abs = Math.abs(offsetMinutes);
  const hh = String(Math.floor(abs / 60)).padStart(2, "0");
  const mm = String(abs % 60).padStart(2, "0");
  return `wall_of_the_day_utc_${offsetMinutes < 0 ? "m" : "p"}${hh}${mm}`;
}

/** UTC offsets (minutes, in 15 minute steps, -12:00 to +14:00) where it is 09:00 local at `nowMs`. */
export function offsetsAtNineLocal(nowMs: number): number[] {
  const utcMinutes = Math.round((nowMs / 60_000 % 1440) / BUCKET_STEP_MINUTES) * BUCKET_STEP_MINUTES;
  const base = (((PUSH_LOCAL_MINUTE - utcMinutes) % 1440) + 1440) % 1440;
  return [base, base - 1440].filter((offset) => offset >= -720 && offset <= 840);
}

function isRecentPick(date: unknown, nowMs: number, maxAgeMs: number): boolean {
  return date instanceof admin.firestore.Timestamp && nowMs - date.toMillis() < maxAgeMs && date.toMillis() <= nowMs;
}

function isSameUtcDay(date: unknown, now: Date): boolean {
  return date instanceof admin.firestore.Timestamp && date.toDate().toISOString().slice(0, 10) ===
    now.toISOString().slice(0, 10);
}

/**
 * Scheduled Cloud Function — runs daily at 9:00 AM IST (03:30 UTC).
 *
 * What it does:
 *   1. Skips when wall_of_the_day/current already holds today's pick (a retry or a second run).
 *   2. Archives { wallId, date } to past_picks/{yyyy-MM-dd} for dedup.
 *   3. Picks a new wall from the `walls` collection that hasn't appeared
 *      in past_picks within the last 30 days, is not streak-exclusive and is not in a premium collection.
 *   4. Writes the new wall to wall_of_the_day/current.
 *   5. Sends an FCM topic push to the legacy `wall_of_the_day` topic (clients without a time zone bucket).
 *   6. Sends the new wall to the bucket whose 09:00 local is in this 15 minute slot, because
 *      `sendWallOfTheDayBuckets` runs in the same slot and may have seen yesterday's pick.
 *
 * Any failure throws, so Cloud Scheduler retries the run. `sendWallOfTheDayBuckets` sends the 09:00 local push.
 */
export const wallOfTheDay = onSchedule(
  {
    schedule: "30 3 * * *", // 03:30 UTC = 09:00 AM IST
    timeZone: "UTC",
    region: REGION,
    retryCount: 2,
  },
  async () => {
    const currentRef = db.collection("wall_of_the_day").doc("current");
    const data = (await currentRef.get()).data();
    if (data && isSameUtcDay(data.date, new Date())) {
      if (data.pushedAt == null) {
        logger.info("Today's wall of the day is set but not announced; announcing it.", {wallId: data.wallId});
        await announce(String(data.wallId ?? ""));
      } else {
        logger.info("Today's wall of the day is already set and announced; skipping.", {wallId: data.wallId});
      }
      await sendDueBuckets(String(data.wallId ?? ""), Date.now());
      return;
    }

    try {
      if (data) {
        // Archive pointer only: `past_picks/{yyyy-MM-dd}` holds wallId + date for dedup queries.
        const archiveDate = firestoreTimestampToDateString(data.date) ?? yesterdayDateString();
        const archivePayload = {
          wallId: data.wallId ?? "",
          date: data.date ?? admin.firestore.Timestamp.now(),
        };
        await db.collection("past_picks").doc(archiveDate).set(archivePayload);
        logger.info(`Archived wall_of_the_day → past_picks/${archiveDate}`, {
          wallId: data.wallId ?? null,
        });
      }
    } catch (err) {
      logger.warn("Could not archive current wall (may not exist yet).", {err});
    }

    const excludedWallIds = new Set<string>();
    try {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 30);

      const recentPicksSnap = await db
        .collection("past_picks")
        .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
        .select("wallId")
        .get();

      recentPicksSnap.forEach((doc) => {
        const wid = doc.data().wallId;
        if (wid) excludedWallIds.add(wid);
      });
    } catch (err) {
      logger.warn("Could not fetch past_picks for dedup; proceeding without exclusion.", {err});
    }

    // Pick a random approved wall, retrying up to MAX_RETRIES times to avoid one from the last 30 days.
    //   a) Count approved walls with a count() aggregate.
    //   b) Fetch one doc at a random offset, ordered by document ID (stable, index-free).
    //   c) If it was picked recently or is not eligible, retry with a fresh offset.
    //   d) If every retry hit an excluded wall, take the first non-excluded wall from the 100 newest.
    const MAX_RETRIES = 5;
    const premium = await premiumCollections();

    let newWall: admin.firestore.DocumentData | null = null;
    let newWallId: string | null = null;

    const countSnap = await db
      .collection("walls")
      .where("review", "==", true)
      .count()
      .get();
    const totalCount = countSnap.data().count;
    logger.info(`Total approved walls: ${totalCount}`);

    if (totalCount > 0) {
      for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
        const randomOffset = Math.floor(Math.random() * totalCount);
        const snap = await db
          .collection("walls")
          .where("review", "==", true)
          .orderBy(admin.firestore.FieldPath.documentId())
          .offset(randomOffset)
          .limit(1)
          .get();

        if (!snap.empty) {
          const doc = snap.docs[0];
          if (!excludedWallIds.has(doc.id) && isWotdEligible(doc.data(), premium)) {
            newWall = doc.data();
            newWallId = doc.id;
            logger.info(`Selected wall on attempt ${attempt + 1} at offset ${randomOffset}.`, {
              wallId: newWallId,
            });
            break;
          }
          logger.info(
            `Attempt ${attempt + 1}: wall ${doc.id} is excluded or not eligible, retrying.`,
          );
        }
      }
    }

    if (!newWall) {
      logger.warn(
        `All ${MAX_RETRIES} random attempts hit excluded walls; falling back to newest-first scan.`,
      );
      const fallbackSnap = await db
        .collection("walls")
        .where("review", "==", true)
        .orderBy("createdAt", "desc")
        .limit(100)
        .get();

      const eligible = fallbackSnap.docs.filter((doc) => isWotdEligible(doc.data(), premium));
      const pick = eligible.find((doc) => !excludedWallIds.has(doc.id));
      if (pick) {
        newWall = pick.data();
        newWallId = pick.id;
      } else if (eligible.length > 0) {
        // Last-resort: the latest eligible wall, even if it was a recent pick.
        newWall = eligible[0].data();
        newWallId = eligible[0].id;
        logger.warn("Last-resort fallback: all eligible newest walls were recent picks; using latest.", {
          wallId: newWallId,
        });
      }
    }

    if (!newWall || !newWallId) {
      throw new Error("No eligible walls found for wall_of_the_day.");
    }

    const wotdDoc = {
      wallId: newWallId,
      date: admin.firestore.Timestamp.now(),
    };

    await currentRef.set(wotdDoc);
    logger.info("wall_of_the_day/current updated", {
      wallId: newWallId,
    });
    await announce(newWallId);
    await sendDueBuckets(newWallId, Date.now());
  },
);

/** Sends the legacy global-topic push (with the in-app doc) and stamps `pushedAt`. Throws when the push fails. */
async function announce(wallId: string): Promise<void> {
  const payload = await wotdPushPayload(wallId);
  const delivered = await sendNotification({
    ...payload,
    modifier: "all",
    fcmTarget: {topic: "wall_of_the_day"},
    docId: `wotd_${utcDateString()}`,
  });
  if (!delivered) {
    throw new Error("Wall of the day push failed.");
  }
  await db.collection("wall_of_the_day").doc("current").update({pushedAt: admin.firestore.Timestamp.now()});
  logger.info("WOTD notification sent and in-app doc written.", {wallId});
}

async function wotdPushPayload(wallId: string): Promise<{
  title: string;
  body: string;
  data: {route: string; wall_id: string; url: string};
  imageUrl?: string;
  channelId: string;
}> {
  const wall = (await db.collection("walls").doc(wallId).get()).data() ?? {};
  const wallTitle = (wall.title as string | undefined)?.trim() || "Check it out";
  const wallpaperUrl = String(wall.wallpaper_url ?? "");
  const thumbnailUrl = String(wall.wallpaper_thumb ?? "");
  // Share links resolve walls by their `id` field, which is not the doc id.
  const shareId = typeof wall.id === "string" && wall.id.trim() ? wall.id.trim() : wallId;
  return {
    title: "Today's Wall of the Day is here",
    body: wallTitle,
    data: {
      route: "wall_of_the_day",
      wall_id: wallId,
      url: wallShareUrl({wallId: shareId, wallpaperUrl, thumbnailUrl}),
    },
    imageUrl: thumbnailUrl || undefined,
    channelId: "wall_of_the_day",
  };
}

const BUCKET_DELIVERIES_DOC = "bucket_deliveries";

function bucketDeliveriesRef() {
  return db.collection("wall_of_the_day").doc(BUCKET_DELIVERIES_DOC);
}

/**
 * Records `wallId` as the last wall sent to `topic`, unless it already is. Returns whether this call won the claim
 * and the wall that was recorded before, so a failed send can restore it.
 */
async function claimBucket(topic: string, wallId: string): Promise<{won: boolean; previous?: string}> {
  const ref = bucketDeliveriesRef();
  return db.runTransaction(async (tx) => {
    const buckets = (await tx.get(ref)).data()?.buckets as Record<string, unknown> | undefined;
    const previous = typeof buckets?.[topic] === "string" ? buckets[topic] as string : undefined;
    if (previous === wallId) return {won: false};
    tx.set(ref, {buckets: {[topic]: wallId}}, {merge: true});
    return {won: true, previous};
  });
}

/** Undoes a claim after a failed send, unless a later run has already recorded another wall. */
async function releaseBucket(topic: string, wallId: string, previous: string | undefined): Promise<void> {
  const ref = bucketDeliveriesRef();
  await db.runTransaction(async (tx) => {
    const buckets = (await tx.get(ref)).data()?.buckets as Record<string, unknown> | undefined;
    if (buckets?.[topic] !== wallId) return;
    tx.set(ref, {buckets: {[topic]: previous ?? admin.firestore.FieldValue.delete()}}, {merge: true});
  });
}

/**
 * Sends `wallId` to the buckets whose 09:00 local is in the slot of `nowMs`, once per bucket and wall.
 * A bucket that already received this wall is skipped, so the picker and the bucket job can both call it.
 */
async function sendDueBuckets(wallId: string, nowMs: number): Promise<void> {
  if (!wallId) return;
  let payload: Awaited<ReturnType<typeof wotdPushPayload>> | undefined;
  for (const offset of offsetsAtNineLocal(nowMs)) {
    const topic = wotdBucketTopic(offset);
    const claim = await claimBucket(topic, wallId);
    if (!claim.won) {
      logger.info("sendDueBuckets: bucket already has this wall; skipping.", {topic, wallId});
      continue;
    }
    let delivered = false;
    try {
      payload ??= await wotdPushPayload(wallId);
      delivered = await sendNotification({...payload, modifier: "all", fcmTarget: {topic}, pushOnly: true});
    } finally {
      if (!delivered) await releaseBucket(topic, wallId, claim.previous);
    }
    if (!delivered) throw new Error(`Wall of the day bucket push failed for ${topic}.`);
    logger.info("sendDueBuckets: sent.", {topic, wallId});
  }
}

/**
 * Every 15 minutes: sends today's wall to the topic of the UTC offset where it is 09:00 local right now
 * (`wall_of_the_day_utc_p0530`). Offsets come in 15 minute steps, so an hourly job would miss +05:30 and +05:45.
 * Clients subscribe to their bucket and leave the legacy global topic. A durable per-bucket marker keeps one
 * delivery per wall, so the 03:30 UTC picker and this job can run in the same slot without a stale or double push.
 */
export const sendWallOfTheDayBuckets = onSchedule(
  {
    schedule: "*/15 * * * *",
    timeZone: "UTC",
    region: REGION,
    retryCount: 1,
  },
  async () => {
    const nowMs = Date.now();
    const current = (await db.collection("wall_of_the_day").doc("current").get()).data();
    if (!current?.wallId || !isRecentPick(current.date, nowMs, MAX_PICK_AGE_MS)) {
      logger.warn("sendWallOfTheDayBuckets: no recent pick; skipping.", {wallId: current?.wallId ?? null});
      return;
    }
    await sendDueBuckets(String(current.wallId), nowMs);
  },
);

function yesterdayDateString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d.toISOString().split("T")[0];
}

function firestoreTimestampToDateString(
  value: admin.firestore.Timestamp | Date | null | undefined,
): string | null {
  if (!value) return null;
  try {
    const date = value instanceof Date ? value : value.toDate();
    return date.toISOString().split("T")[0];
  } catch {
    return null;
  }
}

function wallShareUrl({
  wallId,
  wallpaperUrl,
  thumbnailUrl,
}: {
  wallId: string;
  wallpaperUrl: string;
  thumbnailUrl: string;
}): string {
  const thumb = thumbnailUrl.trim() || wallpaperUrl.trim();
  const params = new URLSearchParams({
    id: wallId,
    source: "prism",
    provider: "Prism",
    thumb,
  });
  const full = wallpaperUrl.trim();
  if (full) {
    params.set("url", full);
  }
  return `https://prismwalls.com/share?${params.toString()}`;
}
