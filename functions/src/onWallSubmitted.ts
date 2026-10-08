import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {sendToUserByEmail} from "./notificationHelper";
import {findUserByEmail, REGION, str} from "./common";

/**
 * Notifies the admins in `config/adminNotifications` when a premium user
 * submits a wall (walls start with review=false).
 */
export const onWallSubmitted = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    const wallId = event.params.wallId;
    const artistName = str(data.by) || "A user";
    const artistEmail = str(data.email);
    const wallTitle = str(data.title) || "Untitled";
    const wallThumb = str(data.wallpaper_thumb);

    let isPremium = true;
    if (artistEmail) {
      try {
        const user = await findUserByEmail(artistEmail);
        if (user) {
          isPremium = user.data().premium === true;
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
      await sendToUserByEmail({
        title: "New Premium Wall for review! 🎉",
        body: `New post by ${artistName} (${artistEmail}) is up for review.`,
        data: {route: "wall", wall_id: wallId},
        imageUrl: wallThumb || undefined,
        modifier: adminEmail,
        channelId: "posts",
      }, adminEmail);
    }

    logger.info("onWallSubmitted: admin notifications sent.", {
      wallId,
      artistEmail,
      wallTitle,
      adminCount: adminEmails.length,
    });
  },
);
