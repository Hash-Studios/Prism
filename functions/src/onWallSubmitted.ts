import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {sendNotification, emailToTopic} from "./notificationHelper";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

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
export const onWallSubmitted = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: "asia-south1",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    // Only notify for premium users' walls (matching old client behaviour).
    const isPremium = data.premium === true;
    if (!isPremium) {
      return;
    }

    const wallId = event.params.wallId;
    const artistName: string = (data.by ?? "").toString().trim() || "A user";
    const artistEmail: string = (data.email ?? "").toString().trim();
    const wallTitle: string = (data.title ?? "").toString().trim() || "Untitled";
    const wallThumb: string = (data.wallpaper_thumb ?? "").toString().trim();

    const adminEmails = await _getAdminEmails();
    if (adminEmails.length === 0) {
      logger.warn("onWallSubmitted: no admin emails configured in config/adminNotifications.");
      return;
    }

    for (const adminEmail of adminEmails) {
      const adminTopic = emailToTopic(adminEmail);
      await sendNotification({
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
        fcmTarget: {topic: adminTopic},
      });
    }

    logger.info("onWallSubmitted: admin notifications sent.", {
      wallId,
      artistEmail,
      wallTitle,
      adminCount: adminEmails.length,
    });
  },
);

async function _getAdminEmails(): Promise<string[]> {
  try {
    const snap = await db.collection("config").doc("adminNotifications").get();
    if (!snap.exists) {
      return [];
    }
    const emails = snap.data()?.emails;
    if (!Array.isArray(emails)) {
      return [];
    }
    return emails.map((e) => e.toString().trim()).filter((e) => e.length > 0);
  } catch (err) {
    logger.error("onWallSubmitted: failed to fetch admin config.", {err});
    return [];
  }
}
