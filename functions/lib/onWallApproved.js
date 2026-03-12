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
exports.onWallApproved = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const notificationHelper_1 = require("./notificationHelper");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Fires whenever a document in the `walls` collection is updated.
 *
 * Responsibilities:
 *   1. When a wall transitions from review=false → review=true (approved):
 *      a. Send push + write in-app notification for the artist ("your wall is live").
 *      b. Send push to the artist's followers topic ("new wall from artist you follow").
 *
 * Note: `admin_review_repository.dart` previously wrote the in-app notification doc
 * from the client.  That call has been removed; this CF is the sole writer.
 */
exports.onWallApproved = (0, firestore_1.onDocumentUpdated)({
    document: "walls/{wallId}",
    region: "asia-south1",
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    if (!before || !after) {
        return;
    }
    // Only act on the false → true transition.
    const wasApproved = before.review === true;
    const isApproved = after.review === true;
    if (wasApproved || !isApproved) {
        return;
    }
    const wallId = event.params.wallId;
    const artistEmail = ((_e = after.email) !== null && _e !== void 0 ? _e : "").toString().trim();
    const artistName = ((_f = after.by) !== null && _f !== void 0 ? _f : "").toString().trim() || "An artist";
    const wallTitle = ((_g = after.title) !== null && _g !== void 0 ? _g : "").toString().trim() || "Untitled";
    const wallThumb = ((_h = after.wallpaper_thumb) !== null && _h !== void 0 ? _h : "").toString().trim();
    if (!artistEmail) {
        v2_1.logger.warn("onWallApproved: wall has no artist email, skipping.", { wallId });
        return;
    }
    // ------------------------------------------------------------------ //
    // 1. Notify the artist that their wall was approved
    //    - In-app doc (modifier = artistEmail)  +  FCM push to their own topic
    // ------------------------------------------------------------------ //
    const artistTopic = (0, notificationHelper_1.emailToTopic)(artistEmail);
    await (0, notificationHelper_1.sendNotification)({
        title: "Your wallpaper is live! 🎉",
        body: `"${wallTitle}" has been approved and is now visible to everyone.`,
        data: {
            route: "wall",
            wall_id: wallId,
            pageName: "",
            url: "",
        },
        imageUrl: wallThumb || undefined,
        modifier: artistEmail,
        channelId: "posts",
        fcmTarget: { topic: artistTopic },
    });
    v2_1.logger.info("onWallApproved: artist notification sent.", { wallId, artistEmail });
    // ------------------------------------------------------------------ //
    // 2. Notify the artist's followers that a new wall is available
    //    - Push only (no in-app doc — one doc per follower would not scale)
    //    - Topic: {artistEmailPrefix}_posts  (followers subscribe to this)
    // ------------------------------------------------------------------ //
    const followersTopic = `${artistTopic}_posts`;
    // Push only — no in-app doc. Otherwise we'd write one doc with modifier=
    // artistEmail and the artist would see a duplicate; followers get the
    // push and can open the wall from the notification.
    await (0, notificationHelper_1.sendNotification)({
        title: `New wall by ${artistName}`,
        body: `"${wallTitle}" is now live on Prism.`,
        data: {
            route: "wall",
            wall_id: wallId,
            artist_email: artistEmail,
            pageName: "",
            url: "",
        },
        imageUrl: wallThumb || undefined,
        modifier: artistEmail,
        channelId: "posts",
        fcmTarget: { topic: followersTopic },
        pushOnly: true,
    });
    v2_1.logger.info("onWallApproved: followers notification sent.", {
        wallId,
        followersTopic,
    });
    // ------------------------------------------------------------------ //
    // 3. Notify admins that a new wall has been approved
    //    (reads target emails from config/adminNotifications)
    // ------------------------------------------------------------------ //
    await _notifyAdmins({
        title: "Wall approved ✅",
        body: `"${wallTitle}" by ${artistName} is now live.`,
        wallId,
        wallThumb,
    });
});
async function _notifyAdmins(params) {
    var _a, _b;
    try {
        const configSnap = await db.collection("config").doc("adminNotifications").get();
        if (!configSnap.exists) {
            return;
        }
        const adminEmails = ((_b = (_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.emails) !== null && _b !== void 0 ? _b : []);
        for (const email of adminEmails) {
            const topic = (0, notificationHelper_1.emailToTopic)(email);
            await (0, notificationHelper_1.sendNotification)({
                title: params.title,
                body: params.body,
                data: {
                    route: "wall",
                    wall_id: params.wallId,
                    pageName: "",
                    url: "",
                },
                imageUrl: params.wallThumb || undefined,
                modifier: email,
                channelId: "posts",
                fcmTarget: { topic },
            });
        }
    }
    catch (err) {
        v2_1.logger.warn("onWallApproved: admin notification failed (non-fatal).", { err });
    }
}
//# sourceMappingURL=onWallApproved.js.map