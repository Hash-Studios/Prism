import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {sendNotification} from "./notificationHelper";
import {db, REGION} from "./common";

/**
 * Scheduled Cloud Function — runs daily at 9:00 AM IST (03:30 UTC).
 *
 * What it does:
 *   1. Reads the current wall_of_the_day/current doc.
 *   2. Archives { wallId, date } to past_picks/{yyyy-MM-dd} for dedup.
 *   3. Picks a new wall from the `walls` collection that hasn't appeared
 *      in past_picks within the last 30 days.
 *   4. Writes the new wall to wall_of_the_day/current.
 *   5. Sends an FCM topic push to the `wall_of_the_day` topic.
 */
export const wallOfTheDay = onSchedule(
  {
    schedule: "30 3 * * *", // 03:30 UTC = 09:00 AM IST
    timeZone: "UTC",
    region: REGION,
  },
  async () => {
    let currentWallId: string | null = null;

    try {
      const currentSnap = await db
        .collection("wall_of_the_day")
        .doc("current")
        .get();

      const data = currentSnap.data();
      if (data) {
        currentWallId = data.wallId ?? null;

        // Archive pointer only: `past_picks/{yyyy-MM-dd}` holds wallId + date for dedup queries.
        const archiveDate = firestoreTimestampToDateString(data.date) ?? yesterdayDateString();
        const archivePayload = {
          wallId: data.wallId ?? "",
          date: data.date ?? admin.firestore.Timestamp.now(),
        };
        await db.collection("past_picks").doc(archiveDate).set(archivePayload);
        logger.info(`Archived wall_of_the_day → past_picks/${archiveDate}`, {
          wallId: currentWallId,
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
    //   c) If it was picked recently, retry with a fresh offset.
    //   d) If every retry hit an excluded wall, take the first non-excluded wall from the 100 newest.
    const MAX_RETRIES = 5;

    let newWall: admin.firestore.DocumentData | null = null;
    let newWallId: string | null = null;

    try {
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

    const wotdDoc = {
      wallId: newWallId,
      date: admin.firestore.Timestamp.now(),
    };

    try {
      await db.collection("wall_of_the_day").doc("current").set(wotdDoc);
      logger.info("wall_of_the_day/current updated", {
        wallId: newWallId,
      });
    } catch (err) {
      logger.error("Failed to write wall_of_the_day/current.", {err});
      return;
    }

    const wallTitle = (newWall.title as string | undefined)?.trim() || "Check it out";
    const wallpaperUrl = String(newWall.wallpaper_url ?? "");
    const thumbnailUrl = String(newWall.wallpaper_thumb ?? "");
    // Share links resolve walls by their `id` field, which is not the doc id.
    const shareId = typeof newWall.id === "string" && newWall.id.trim() ? newWall.id.trim() : newWallId;
    const canonicalWallUrl = wallShareUrl({
      wallId: shareId,
      wallpaperUrl,
      thumbnailUrl,
    });
    await sendNotification({
      title: "Today's Wall of the Day is here",
      body: wallTitle,
      data: {
        route: "wall_of_the_day",
        wall_id: newWallId,
        url: canonicalWallUrl,
      },
      imageUrl: thumbnailUrl || undefined,
      modifier: "all",
      channelId: "wall_of_the_day",
      fcmTarget: {topic: "wall_of_the_day"},
    });
    logger.info("WOTD notification sent and in-app doc written.", {wallId: newWallId});
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
