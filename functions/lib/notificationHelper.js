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
exports.sendNotification = sendNotification;
exports.emailToTopic = emailToTopic;
const admin = __importStar(require("firebase-admin"));
const v2_1 = require("firebase-functions/v2");
/**
 * Core notification helper — used by every Cloud Function that needs to
 * send a notification.  It does two things atomically:
 *   1. Writes a document to the `notifications` Firestore collection so the
 *      notification appears in the user's in-app inbox.
 *   2. Sends an FCM push via the Admin SDK (unless fcmTarget is omitted).
 *
 * The Firestore document schema matches what InAppNotif.fromSnapshot()
 * expects in the Flutter client.
 */
async function sendNotification(payload) {
    var _a, _b, _c, _d;
    const db = admin.firestore();
    const messaging = admin.messaging();
    // ------------------------------------------------------------------ //
    // 1. Write the in-app notification doc (unless pushOnly)
    // ------------------------------------------------------------------ //
    if (!payload.pushOnly) {
        try {
            await db.collection("notifications").add({
                notification: {
                    title: payload.title,
                    body: payload.body,
                },
                data: Object.assign({ route: (_a = payload.data.route) !== null && _a !== void 0 ? _a : "", imageUrl: (_b = payload.imageUrl) !== null && _b !== void 0 ? _b : "", url: (_c = payload.data.url) !== null && _c !== void 0 ? _c : "", pageName: (_d = payload.data.pageName) !== null && _d !== void 0 ? _d : "", arguments: [] }, Object.fromEntries(Object.entries(payload.data).filter(([k]) => !["route", "url", "pageName"].includes(k)))),
                modifier: payload.modifier,
                createdAt: admin.firestore.Timestamp.now(),
            });
        }
        catch (err) {
            v2_1.logger.error("Failed to write notification doc to Firestore.", { err, payload });
            // Do not throw — attempt FCM push even if Firestore write fails.
        }
    }
    // ------------------------------------------------------------------ //
    // 2. Send FCM push (if a target was provided)
    // ------------------------------------------------------------------ //
    if (!payload.fcmTarget) {
        return;
    }
    const message = Object.assign({ notification: {
            title: payload.title,
            body: payload.body,
        }, data: Object.assign(Object.assign(Object.assign({}, payload.data), { channel_id: payload.channelId }), (payload.imageUrl ? { imageUrl: payload.imageUrl } : {})), android: {
            notification: Object.assign({ channelId: payload.channelId, clickAction: "FLUTTER_NOTIFICATION_CLICK" }, (payload.imageUrl ? { imageUrl: payload.imageUrl } : {})),
            priority: "high",
        }, apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        } }, ("topic" in payload.fcmTarget ?
        { topic: payload.fcmTarget.topic } :
        { token: payload.fcmTarget.token }));
    try {
        const messageId = await messaging.send(message);
        v2_1.logger.info("FCM push sent.", {
            messageId,
            route: payload.data.route,
            target: payload.fcmTarget,
        });
    }
    catch (err) {
        v2_1.logger.error("Failed to send FCM push.", { err, route: payload.data.route });
    }
}
/**
 * Extracts the FCM-safe topic name from an email address.
 * FCM topics must match [a-zA-Z0-9-_.~%]+
 * We use the portion before "@" and replace unsafe chars with "_".
 */
function emailToTopic(email) {
    return email.split("@")[0].replace(/[^a-zA-Z0-9\-_.~%]/g, "_");
}
//# sourceMappingURL=notificationHelper.js.map