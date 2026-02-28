"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendNotification = sendNotification;
exports.emailToTopic = emailToTopic;
const admin = require("firebase-admin");
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
    // 1. Write the in-app notification doc
    // ------------------------------------------------------------------ //
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
    // ------------------------------------------------------------------ //
    // 2. Send FCM push (if a target was provided)
    // ------------------------------------------------------------------ //
    if (!payload.fcmTarget) {
        return;
    }
    const message = Object.assign({ notification: {
            title: payload.title,
            body: payload.body,
        }, data: Object.assign(Object.assign({}, payload.data), (payload.imageUrl ? { imageUrl: payload.imageUrl } : {})), android: {
            notification: Object.assign({ channelId: payload.channelId, clickAction: "FLUTTER_NOTIFICATION_CLICK" }, (payload.imageUrl ? { imageUrl: payload.imageUrl } : {})),
            priority: "high",
        }, apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        } }, ("topic" in payload.fcmTarget
        ? { topic: payload.fcmTarget.topic }
        : { token: payload.fcmTarget.token }));
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