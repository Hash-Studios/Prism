import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { sendNotification } from "./notificationHelper";

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
    let currentWallTitle: string = "Today's Wall";

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
      logger.warn("Could not archive current wall (may not exist yet).", { err });
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
      logger.warn("Could not fetch past_picks for dedup; proceeding without exclusion.", { err });
    }

    // ------------------------------------------------------------------ //
    // 3. Pick a new wall
    // ------------------------------------------------------------------ //
    let newWall: admin.firestore.DocumentData | null = null;
    let newWallId: string | null = null;

    try {
      // Try to pick a wall not in past_picks (last 30 days).
      // We fetch a batch and skip any excluded ones.
      const candidatesSnap = await db
        .collection("walls")
        .where("review", "==", true) // matches the app's own query filter
        .orderBy("createdAt", "desc")
        .limit(100)
        .get();

      for (const doc of candidatesSnap.docs) {
        if (!excludedWallIds.has(doc.id)) {
          newWall = doc.data();
          newWallId = doc.id;
          break;
        }
      }

      // Fallback: if all recent walls are excluded, just take the latest one.
      if (!newWall && candidatesSnap.size > 0) {
        const fallbackDoc = candidatesSnap.docs[0];
        newWall = fallbackDoc.data();
        newWallId = fallbackDoc.id;
        logger.warn("All candidate walls were in past_picks; using latest as fallback.", {
          wallId: newWallId,
        });
      }
    } catch (err) {
      logger.error("Failed to query walls collection.", { err });
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
      photographer: newWall.by ?? "",       // `by` is the uploader name field
      photographerId: newWall.email ?? "",  // `email` is the uploader identifier
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
      logger.error("Failed to write wall_of_the_day/current.", { err });
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
      fcmTarget: { topic: "wall_of_the_day" },
    });
    logger.info("WOTD notification sent and in-app doc written.", { wallId: newWallId });
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
