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
exports.onFollowCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const notificationHelper_1 = require("./notificationHelper");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Fires whenever a document in `usersv2` is updated.
 *
 * The follow system stores follower/following relationships as arrays inside
 * user documents (not as a subcollection), so we detect new follows by
 * diffing `before.followers` vs `after.followers`.
 *
 * For each newly added follower email:
 *   1. Look up the follower's display name from their user doc.
 *   2. Send an FCM push to the followed user (via their own email-prefix topic).
 *   3. Write a per-user in-app notification doc (modifier = followed user's email).
 */
exports.onFollowCreated = (0, firestore_1.onDocumentUpdated)({
    document: "usersv2/{userId}",
    region: "asia-south1",
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    if (!before || !after) {
        return;
    }
    const beforeFollowers = new Set(((_e = before.followers) !== null && _e !== void 0 ? _e : []).map((e) => e.toString().trim().toLowerCase()));
    const afterFollowers = new Set(((_f = after.followers) !== null && _f !== void 0 ? _f : []).map((e) => e.toString().trim().toLowerCase()));
    // Find emails that were added in this update.
    const newFollowerEmails = [...afterFollowers].filter((e) => !beforeFollowers.has(e));
    if (newFollowerEmails.length === 0) {
        return;
    }
    const followedUserEmail = ((_g = after.email) !== null && _g !== void 0 ? _g : "").toString().trim();
    if (!followedUserEmail) {
        return;
    }
    for (const followerEmail of newFollowerEmails) {
        // Look up the follower's display name for a personalised message.
        const followerUsername = await _resolveUsername(followerEmail);
        const followedTopic = (0, notificationHelper_1.emailToTopic)(followedUserEmail);
        await (0, notificationHelper_1.sendNotification)({
            title: "You have a new follower! 🎉",
            body: `${followerUsername} is now following you.`,
            data: {
                route: "follower",
                follower_email: followerEmail,
                pageName: "",
                url: _profileUrl(followerEmail),
            },
            modifier: followedUserEmail,
            channelId: "followers",
            // Send push to the followed user's own topic (they subscribe on login).
            fcmTarget: { topic: followedTopic },
        });
        v2_1.logger.info("onFollowCreated: follow notification sent.", {
            followedUserEmail,
            followerEmail,
        });
    }
});
/** Resolves a display username for a given email address.
 *  Falls back to the email prefix if the user doc cannot be found. */
async function _resolveUsername(email) {
    var _a, _b;
    try {
        const snap = await db
            .collection("usersv2")
            .where("email", "==", email)
            .limit(1)
            .get();
        if (!snap.empty) {
            const data = snap.docs[0].data();
            const name = ((_a = data.username) === null || _a === void 0 ? void 0 : _a.trim()) ||
                ((_b = data.name) === null || _b === void 0 ? void 0 : _b.trim());
            if (name)
                return name;
        }
    }
    catch (err) {
        v2_1.logger.warn("onFollowCreated: could not resolve follower username.", { email, err });
    }
    return email.split("@")[0];
}
function _profileUrl(identifier) {
    const cleaned = identifier.trim();
    if (!cleaned)
        return "";
    return `https://prismwalls.com/user/${encodeURIComponent(cleaned)}`;
}
//# sourceMappingURL=onFollowCreated.js.map