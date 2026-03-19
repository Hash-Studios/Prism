"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.wallOfTheDay = void 0;
const admin = __importStar(require("firebase-admin"));
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
    let newWall = null;
    let newWallId = null;
    try {
        // a) Count total approved walls.
        const countSnap = await db
            .collection("walls")
            .where("review", "==", true)
            .count()
            .get();
        const totalCount = countSnap.data().count;
        v2_1.logger.info(`Total approved walls: ${totalCount}`);
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
                        v2_1.logger.info(`Selected wall on attempt ${attempt + 1} at offset ${randomOffset}.`, {
                            wallId: newWallId,
                        });
                        break;
                    }
                    v2_1.logger.info(`Attempt ${attempt + 1}: wall ${doc.id} is in past_picks — retrying.`);
                }
            }
        }
        // d) Fallback: all retries hit excluded walls — pick the first
        //    non-excluded wall from the 100 most-recently-added approved walls.
        if (!newWall) {
            v2_1.logger.warn(`All ${MAX_RETRIES} random attempts hit excluded walls; falling back to newest-first scan.`);
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
                v2_1.logger.warn("Last-resort fallback: all 100 newest walls excluded; using latest.", {
                    wallId: newWallId,
                });
            }
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
    const canonicalWallUrl = _wallShareUrl({
        wallId: newWallId,
        wallpaperUrl: wotdDoc.url || "",
        thumbnailUrl: wotdDoc.thumbnailUrl || "",
    });
    await (0, notificationHelper_1.sendNotification)({
        title: "Today's Wall of the Day is here",
        body: wallTitle,
        data: {
            route: "wall_of_the_day",
            wall_id: newWallId,
            url: canonicalWallUrl,
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
function _wallShareUrl({ wallId, wallpaperUrl, thumbnailUrl, }) {
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
//# sourceMappingURL=wallOfTheDay.js.map