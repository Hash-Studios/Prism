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
exports.onWallSubmitted = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const adminConfig_1 = require("./adminConfig");
const notificationHelper_1 = require("./notificationHelper");
if (!admin.apps.length) {
    admin.initializeApp();
}
/**
 * Fires when a new wall document is created in the `walls` collection.
 *
 * Walls start with review=false (pending review).  This function notifies
 * admins so they can review the submission promptly.
 *
 * Admin recipient emails are read from `config/adminNotifications` in
 * Firestore (field: `emails: string[]`).  This replaces the old pattern of
 * hardcoded admin email prefixes in wallfirestore.dart.
 *
 * To configure admins, create or update this document in the Firebase console:
 *   Collection: config
 *   Document:   adminNotifications
 *   Field:      emails  (array of admin email addresses)
 */
exports.onWallSubmitted = (0, firestore_1.onDocumentCreated)({
    document: "walls/{wallId}",
    region: "asia-south1",
}, async (event) => {
    var _a, _b, _c, _d, _e;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data) {
        return;
    }
    // Only notify for premium users' walls (matching old client behaviour).
    const isPremium = data.premium === true;
    if (!isPremium) {
        return;
    }
    const wallId = event.params.wallId;
    const artistName = ((_b = data.by) !== null && _b !== void 0 ? _b : "").toString().trim() || "A user";
    const artistEmail = ((_c = data.email) !== null && _c !== void 0 ? _c : "").toString().trim();
    const wallTitle = ((_d = data.title) !== null && _d !== void 0 ? _d : "").toString().trim() || "Untitled";
    const wallThumb = ((_e = data.wallpaper_thumb) !== null && _e !== void 0 ? _e : "").toString().trim();
    const adminEmails = await (0, adminConfig_1.getAdminEmails)();
    if (adminEmails.length === 0) {
        v2_1.logger.warn("onWallSubmitted: no admin emails configured in config/adminNotifications.");
        return;
    }
    for (const adminEmail of adminEmails) {
        const adminTopic = (0, notificationHelper_1.emailToTopic)(adminEmail);
        await (0, notificationHelper_1.sendNotification)({
            title: "New Premium Wall for review! 🎉",
            body: `New post by ${artistName} (${artistEmail}) is up for review.`,
            data: {
                route: "wall",
                wall_id: wallId,
                pageName: "",
                url: "",
            },
            imageUrl: wallThumb || undefined,
            modifier: adminEmail,
            channelId: "posts",
            fcmTarget: { topic: adminTopic },
        });
    }
    v2_1.logger.info("onWallSubmitted: admin notifications sent.", {
        wallId,
        artistEmail,
        wallTitle,
        adminCount: adminEmails.length,
    });
});
//# sourceMappingURL=onWallSubmitted.js.map