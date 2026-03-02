"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.wallOfTheDay = void 0;
const admin = require("firebase-admin");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const v2_1 = require("firebase-functions/v2");
const notificationHelper_1 = require("./notificationHelper");
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
exports.wallOfTheDay = (0, scheduler_1.onSchedule)({
    schedule: "30 3 * * *", // 03:30 UTC = 09:00 AM IST
    timeZone: "UTC",
    region: "asia-south1", // Mumbai — lowest latency for India-first app
}, async () => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const today = _todayDateString();
    // ------------------------------------------------------------------ //
    // 1. Archive yesterday's wall
    // ------------------------------------------------------------------ //
    let currentWallId = null;
    let currentWallTitle = "Today's Wall";
    try {
        const currentSnap = await db
            .collection("wall_of_the_day")
            .doc("current")
            .get();
        if (currentSnap.exists) {
            const data = currentSnap.data();
            currentWallId = (_a = data.wallId) !== null && _a !== void 0 ? _a : null;
            currentWallTitle = (_b = data.title) !== null && _b !== void 0 ? _b : currentWallTitle;
            // Archive with the date stored in the doc, falling back to yesterday.
            const archiveDate = (_c = _firestoreTimestampToDateString(data.date)) !== null && _c !== void 0 ? _c : _yesterdayDateString();
            await db.collection("past_picks").doc(archiveDate).set(data);
            v2_1.logger.info(`Archived wall_of_the_day → past_picks/${archiveDate}`, {
                wallId: currentWallId,
            });
        }
    }
    catch (err) {
        v2_1.logger.warn("Could not archive current wall (may not exist yet).", { err });
    }
    // ------------------------------------------------------------------ //
    // 2. Collect recent past_picks (last 30 days) to avoid repeats
    // ------------------------------------------------------------------ //
    const excludedWallIds = new Set();
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
            if (wid)
                excludedWallIds.add(wid);
        });
    }
    catch (err) {
        v2_1.logger.warn("Could not fetch past_picks for dedup; proceeding without exclusion.", { err });
    }
    // ------------------------------------------------------------------ //
    // 3. Pick a new wall
    // ------------------------------------------------------------------ //
    let newWall = null;
    let newWallId = null;
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
            v2_1.logger.warn("All candidate walls were in past_picks; using latest as fallback.", {
                wallId: newWallId,
            });
        }
    }
    catch (err) {
        v2_1.logger.error("Failed to query walls collection.", { err });
        return;
    }
    if (!newWall || !newWallId) {
        v2_1.logger.error("No eligible walls found. Aborting wall_of_the_day update.");
        return;
    }
    // ------------------------------------------------------------------ //
    // 4. Write wall_of_the_day/current
    // ------------------------------------------------------------------ //
    const wotdDoc = {
        wallId: newWallId,
        url: (_d = newWall.wallpaper_url) !== null && _d !== void 0 ? _d : "",
        thumbnailUrl: (_e = newWall.wallpaper_thumb) !== null && _e !== void 0 ? _e : "",
        title: (_f = newWall.title) !== null && _f !== void 0 ? _f : "",
        photographer: (_g = newWall.by) !== null && _g !== void 0 ? _g : "", // `by` is the uploader name field
        photographerId: (_h = newWall.email) !== null && _h !== void 0 ? _h : "", // `email` is the uploader identifier
        date: admin.firestore.Timestamp.now(),
        palette: (_j = newWall.palette) !== null && _j !== void 0 ? _j : [],
        isPremium: (_k = newWall.premium) !== null && _k !== void 0 ? _k : false,
    };
    try {
        await db.collection("wall_of_the_day").doc("current").set(wotdDoc);
        v2_1.logger.info(`wall_of_the_day/current updated for ${today}`, {
            wallId: newWallId,
            title: wotdDoc.title,
        });
    }
    catch (err) {
        v2_1.logger.error("Failed to write wall_of_the_day/current.", { err });
        return;
    }
    // ------------------------------------------------------------------ //
    // 5. Send FCM topic push + write in-app notification doc
    // ------------------------------------------------------------------ //
    const wallTitle = wotdDoc.title.trim() || "Check it out";
    await (0, notificationHelper_1.sendNotification)({
        title: "Today's Wall of the Day is here",
        body: wallTitle,
        data: {
            route: "wall_of_the_day",
            wall_id: newWallId,
        },
        imageUrl: wotdDoc.thumbnailUrl || undefined,
        modifier: "all",
        channelId: "wall_of_the_day",
        fcmTarget: { topic: "wall_of_the_day" },
    });
    v2_1.logger.info("WOTD notification sent and in-app doc written.", { wallId: newWallId });
});
// ------------------------------------------------------------------ //
// Helpers
// ------------------------------------------------------------------ //
function _todayDateString() {
    return new Date().toISOString().split("T")[0]; // yyyy-MM-dd
}
function _yesterdayDateString() {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return d.toISOString().split("T")[0];
}
function _firestoreTimestampToDateString(value) {
    if (!value)
        return null;
    try {
        const date = value instanceof Date ? value : value.toDate();
        return date.toISOString().split("T")[0];
    }
    catch (_a) {
        return null;
    }
}
//# sourceMappingURL=wallOfTheDay.js.map