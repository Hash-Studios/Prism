import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {sendNotification} from "./notificationHelper";

// Initialize the Admin SDK once (guarded for module reuse across functions).
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Scheduled Cloud Function — runs daily at 9:00 AM IST (03:30 UTC).
 *
 * What it does:
 *   1. Reads the current wall_of_the_day/current doc.
 *   2. Archives it to past_picks/{yyyy-MM-dd} so it's never repeated.
 *   3. Picks a new wall from the `walls` collection that hasn't appeared
 *      in past_picks within the last 30 days.
 *   4. Writes the new wall to wall_of_the_day/current.
 *   5. Sends an FCM topic push to the `wall_of_the_day` topic.
 */
export const wallOfTheDay = onSchedule(
  {
    schedule: "30 3 * * *", // 03:30 UTC = 09:00 AM IST
    timeZone: "UTC",
    region: "asia-south1", // Mumbai — lowest latency for India-first app
  },
  async () => {
    const today = _todayDateString();

    // ------------------------------------------------------------------ //
    // 1. Archive yesterday's wall
    // ------------------------------------------------------------------ //
    let currentWallId: string | null = null;
    let currentWallTitle = "Today's Wall";

    try {
      const currentSnap = await db
        .collection("wall_of_the_day")
        .doc("current")
        .get();

      if (currentSnap.exists) {
        const data = currentSnap.data()!;
        currentWallId = data.wallId ?? null;
        currentWallTitle = data.title ?? currentWallTitle;

        // Archive with the date stored in the doc, falling back to yesterday.
        const archiveDate = _firestoreTimestampToDateString(data.date) ?? _yesterdayDateString();
        await db.collection("past_picks").doc(archiveDate).set(data);
        logger.info(`Archived wall_of_the_day → past_picks/${archiveDate}`, {
          wallId: currentWallId,
        });
      }
    } catch (err) {
      logger.warn("Could not archive current wall (may not exist yet).", {err});
    }

    // ------------------------------------------------------------------ //
    // 2. Collect recent past_picks (last 30 days) to avoid repeats
    // ------------------------------------------------------------------ //
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

    // ------------------------------------------------------------------ //
    // 3. Pick a new wall — randomly, with up to MAX_RETRIES attempts to
    //    avoid a wall that appeared in the last 30 days.
    //
    //    Strategy:
    //      a) Count all approved walls via Firestore count() aggregate.
    //      b) Pick a random offset and fetch exactly 1 doc at that position,
    //         ordered by document ID (stable, index-free ordering).
    //      c) If that doc is in the exclusion set, retry up to MAX_RETRIES
    //         times with a fresh random offset.
    //      d) Fallback: if every retry hit an excluded wall (very unlikely
    //         with 5,000+ walls), fall back to the first non-excluded wall
    //         from the 100 most-recently-added approved walls.
    // ------------------------------------------------------------------ //
    const MAX_RETRIES = 5;

    let newWall: admin.firestore.DocumentData | null = null;
    let newWallId: string | null = null;

    try {
      // a) Count total approved walls.
      const countSnap = await db
        .collection("walls")
        .where("review", "==", true)
        .count()
        .get();
      const totalCount = countSnap.data().count;
      logger.info(`Total approved walls: ${totalCount}`);

      if (totalCount > 0) {
        // b & c) Random-offset attempts.
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
            if (!excludedWallIds.has(doc.id)) {
              newWall = doc.data();
              newWallId = doc.id;
              logger.info(`Selected wall on attempt ${attempt + 1} at offset ${randomOffset}.`, {
                wallId: newWallId,
              });
              break;
            }
            logger.info(
              `Attempt ${attempt + 1}: wall ${doc.id} is in past_picks — retrying.`,
            );
          }
        }
      }

      // d) Fallback: all retries hit excluded walls — pick the first
      //    non-excluded wall from the 100 most-recently-added approved walls.
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

        for (const doc of fallbackSnap.docs) {
          if (!excludedWallIds.has(doc.id)) {
            newWall = doc.data();
            newWallId = doc.id;
            break;
          }
        }

        // Last-resort: use the absolute latest wall regardless of exclusion.
        if (!newWall && fallbackSnap.size > 0) {
          const lastResortDoc = fallbackSnap.docs[0];
          newWall = lastResortDoc.data();
          newWallId = lastResortDoc.id;
          logger.warn("Last-resort fallback: all 100 newest walls excluded; using latest.", {
            wallId: newWallId,
          });
        }
      }
    } catch (err) {
      logger.error("Failed to query walls collection.", {err});
      return;
    }

    if (!newWall || !newWallId) {
      logger.error("No eligible walls found. Aborting wall_of_the_day update.");
      return;
    }

    // ------------------------------------------------------------------ //
    // 4. Write wall_of_the_day/current
    // ------------------------------------------------------------------ //
    const wotdDoc: Record<string, unknown> = {
      wallId: newWallId,
      url: newWall.wallpaper_url ?? "",
      thumbnailUrl: newWall.wallpaper_thumb ?? "",
      title: newWall.title ?? "",
      photographer: newWall.by ?? "", // `by` is the uploader name field
      photographerId: newWall.email ?? "", // `email` is the uploader identifier
      date: admin.firestore.Timestamp.now(),
      palette: newWall.palette ?? [],
      isPremium: newWall.premium ?? false,
    };

    try {
      await db.collection("wall_of_the_day").doc("current").set(wotdDoc);
      logger.info(`wall_of_the_day/current updated for ${today}`, {
        wallId: newWallId,
        title: wotdDoc.title,
      });
    } catch (err) {
      logger.error("Failed to write wall_of_the_day/current.", {err});
      return;
    }

    // ------------------------------------------------------------------ //
    // 5. Send FCM topic push + write in-app notification doc
    // ------------------------------------------------------------------ //
    const wallTitle = (wotdDoc.title as string).trim() || "Check it out";
    const canonicalWallUrl = _wallShareUrl({
      wallId: newWallId,
      wallpaperUrl: (wotdDoc.url as string) || "",
      thumbnailUrl: (wotdDoc.thumbnailUrl as string) || "",
    });
    await sendNotification({
      title: "Today's Wall of the Day is here",
      body: wallTitle,
      data: {
        route: "wall_of_the_day",
        wall_id: newWallId,
        url: canonicalWallUrl,
      },
      imageUrl: (wotdDoc.thumbnailUrl as string) || undefined,
      modifier: "all",
      channelId: "wall_of_the_day",
      fcmTarget: {topic: "wall_of_the_day"},
    });
    logger.info("WOTD notification sent and in-app doc written.", {wallId: newWallId});
  },
);

// ------------------------------------------------------------------ //
// Helpers
// ------------------------------------------------------------------ //

function _todayDateString(): string {
  return new Date().toISOString().split("T")[0]; // yyyy-MM-dd
}

function _yesterdayDateString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d.toISOString().split("T")[0];
}

function _firestoreTimestampToDateString(
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

function _wallShareUrl({
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
