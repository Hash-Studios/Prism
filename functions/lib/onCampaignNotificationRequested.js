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
exports.onCampaignNotificationRequested = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const notificationHelper_1 = require("./notificationHelper");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Triggered when an admin writes a document to the `notificationRequests`
 * collection.  This is the campaign / broadcast notification system.
 *
 * A request document should have:
 *   title:      string   — notification headline
 *   body:       string   — notification body text
 *   modifier:   string   — audience: "all" | "premium" | "free" | userEmail
 *   route:      string   — client-side route: "announcement" | "wall_of_the_day" | "wall" | "follower"
 *   imageUrl?:  string   — optional thumbnail image URL
 *   channelId?: string   — Android channel (default: "recommendations")
 *
 * To trigger from the Flutter admin app, write to `notificationRequests`:
 *
 *   firestoreClient.addDoc('notificationRequests', {
 *     'title': 'Hello World',
 *     'body': 'New update available!',
 *     'modifier': 'all',
 *     'route': 'announcement',
 *   })
 *
 * FCM topic mapping (all users subscribe to these in home_screen.dart):
 *   modifier = "all"       → topic: "recommendations"  (all users are subscribed)
 *   modifier = "premium"   → topic: "premium"
 *   modifier = "free"      → topic: "free"
 *   modifier = {email}     → topic: emailToTopic(email)  (user's own topic)
 */
exports.onCampaignNotificationRequested = (0, firestore_1.onDocumentCreated)({
    document: "notificationRequests/{requestId}",
    region: "asia-south1",
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const requestId = event.params.requestId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data) {
        v2_1.logger.warn("onCampaignNotificationRequested: empty document, skipping.", { requestId });
        return;
    }
    const title = ((_b = data.title) !== null && _b !== void 0 ? _b : "").toString().trim();
    const body = ((_c = data.body) !== null && _c !== void 0 ? _c : "").toString().trim();
    const modifier = ((_d = data.modifier) !== null && _d !== void 0 ? _d : "all").toString().trim();
    const route = ((_e = data.route) !== null && _e !== void 0 ? _e : "announcement").toString().trim();
    const imageUrl = ((_f = data.imageUrl) !== null && _f !== void 0 ? _f : "").toString().trim();
    const channelId = ((_g = data.channelId) !== null && _g !== void 0 ? _g : "recommendations").toString().trim();
    if (!title || !body) {
        await _markProcessed(requestId, { error: "title and body are required" });
        return;
    }
    // Determine the FCM topic from the modifier value.
    let fcmTopic;
    if (modifier === "all") {
        // All users subscribe to the "recommendations" topic on first app open.
        fcmTopic = "recommendations";
    }
    else if (modifier === "premium" || modifier === "free") {
        fcmTopic = modifier;
    }
    else {
        // Treat as a user email — send to their own email-prefix topic.
        fcmTopic = (0, notificationHelper_1.emailToTopic)(modifier);
    }
    await (0, notificationHelper_1.sendNotification)({
        title,
        body,
        data: {
            route,
            pageName: "",
            url: "",
        },
        imageUrl: imageUrl || undefined,
        modifier,
        channelId,
        fcmTarget: { topic: fcmTopic },
    });
    await _markProcessed(requestId, { fcmTopic });
    v2_1.logger.info("onCampaignNotificationRequested: notification sent.", {
        requestId,
        modifier,
        fcmTopic,
        route,
    });
});
async function _markProcessed(requestId, meta) {
    try {
        await db.collection("notificationRequests").doc(requestId).update(Object.assign({ processed: true, processedAt: admin.firestore.Timestamp.now() }, meta));
    }
    catch (err) {
        v2_1.logger.warn("onCampaignNotificationRequested: failed to mark request processed.", { requestId, err });
    }
}
//# sourceMappingURL=onCampaignNotificationRequested.js.map