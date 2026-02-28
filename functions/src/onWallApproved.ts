import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { sendNotification, emailToTopic } from "./notificationHelper";

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
export const onWallApproved = onDocumentUpdated(
  {
    document: "walls/{wallId}",
    region: "asia-south1",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

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
    const artistEmail: string = (after.email ?? "").toString().trim();
    const artistName: string = (after.by ?? "").toString().trim() || "An artist";
    const wallTitle: string = (after.title ?? "").toString().trim() || "Untitled";
    const wallThumb: string = (after.wallpaper_thumb ?? "").toString().trim();

    if (!artistEmail) {
      logger.warn("onWallApproved: wall has no artist email, skipping.", { wallId });
      return;
    }

    // ------------------------------------------------------------------ //
    // 1. Notify the artist that their wall was approved
    //    - In-app doc (modifier = artistEmail)  +  FCM push to their own topic
    // ------------------------------------------------------------------ //
    const artistTopic = emailToTopic(artistEmail);
    await sendNotification({
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

    logger.info("onWallApproved: artist notification sent.", { wallId, artistEmail });

    // ------------------------------------------------------------------ //
    // 2. Notify the artist's followers that a new wall is available
    //    - Push only (no in-app doc — one doc per follower would not scale)
    //    - Topic: {artistEmailPrefix}_posts  (followers subscribe to this)
    // ------------------------------------------------------------------ //
    const followersTopic = `${artistTopic}_posts`;

    // Push only — no in-app doc. Otherwise we'd write one doc with modifier=
    // artistEmail and the artist would see a duplicate; followers get the
    // push and can open the wall from the notification.
    await sendNotification({
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

    logger.info("onWallApproved: followers notification sent.", {
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
  },
);

async function _notifyAdmins(params: {
  title: string;
  body: string;
  wallId: string;
  wallThumb: string;
}): Promise<void> {
  try {
    const configSnap = await db.collection("config").doc("adminNotifications").get();
    if (!configSnap.exists) {
      return;
    }
    const adminEmails: string[] = (configSnap.data()?.emails ?? []) as string[];
    for (const email of adminEmails) {
      const topic = emailToTopic(email);
      await sendNotification({
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
  } catch (err) {
    logger.warn("onWallApproved: admin notification failed (non-fatal).", { err });
  }
}
