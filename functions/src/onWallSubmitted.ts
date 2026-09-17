import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
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

    const wallId = event.params.wallId;
    const artistName: string = (data.by ?? "").toString().trim() || "A user";
    const artistEmail: string = (data.email ?? "").toString().trim();
    const wallTitle: string = (data.title ?? "").toString().trim() || "Untitled";
    const wallThumb: string = (data.wallpaper_thumb ?? "").toString().trim();

    let isPremium = true;
    if (artistEmail) {
      try {
        const snap = await db.collection("usersv2").where("email", "==", artistEmail).limit(1).get();
        const userSnap = snap.empty ? await db.collection("usersv2").where("email", "==", artistEmail.toLowerCase()).limit(1).get() : snap;
        if (!userSnap.empty) {
          isPremium = userSnap.docs[0].data().premium === true;
        }
      } catch (err) {
        logger.warn("onWallSubmitted: premium lookup failed; notifying for review.", {wallId, artistEmail, err});
      }
    }
    if (!isPremium) return;

    const adminEmails = await getAdminEmails();
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
