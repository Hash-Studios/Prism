import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {findUserByEmail, REGION, str} from "./common";
import {sendNotification, sendToUidAndEmailTopics, emailToTopic, userIdToTopic} from "./notificationHelper";

/**
 * When a wall goes from review=false to review=true (approved), notifies the
 * artist, the artist's followers and the admins.
 */
export const onWallApproved = onDocumentUpdated(
  {
    document: "walls/{wallId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      return;
    }

    const wasApproved = before.review === true;
    const isApproved = after.review === true;
    if (wasApproved || !isApproved) {
      return;
    }

    const wallId = event.params.wallId;
    const artistEmail = str(after.email);
    const artistName = str(after.by) || "An artist";
    const wallTitle = str(after.title) || "Untitled";
    const wallThumb = str(after.wallpaper_thumb);

    if (!artistEmail) {
      logger.warn("onWallApproved: wall has no artist email, skipping.", {wallId});
      return;
    }

    const artistUid = await resolveUserIdByEmail(artistEmail);
    await sendToUidAndEmailTopics(
      {
        title: "Your wallpaper is live! 🎉",
        body: `"${wallTitle}" has been approved and is now visible to everyone.`,
        data: {route: "wall", wall_id: wallId},
        imageUrl: wallThumb || undefined,
        modifier: artistEmail,
        channelId: "posts",
        collapseKey: `wall_${wallId}`,
      },
      artistUid ? userIdToTopic(artistUid) : undefined,
      emailToTopic(artistEmail),
    );

    logger.info("onWallApproved: artist notification sent.", {wallId, artistEmail});

    // Followers subscribe to <email prefix>_posts (followersTopicFromEmail).
    // Push only: an in-app doc would show the artist a duplicate.
    const followersTopic = `${emailToTopic(artistEmail)}_posts`;
    await sendNotification({
      title: `New wall by ${artistName}`,
      body: `"${wallTitle}" is now live on Prism.`,
      data: {route: "wall", wall_id: wallId, artist_email: artistEmail},
      imageUrl: wallThumb || undefined,
      modifier: artistEmail,
      channelId: "posts",
      fcmTarget: {topic: followersTopic},
      pushOnly: true,
    });

    logger.info("onWallApproved: followers notification sent.", {
      wallId,
      followersTopic,
    });

    for (const email of await getAdminEmails()) {
      await sendNotification({
        title: "Wall approved ✅",
        body: `"${wallTitle}" by ${artistName} is now live.`,
        data: {route: "wall", wall_id: wallId},
        imageUrl: wallThumb || undefined,
        modifier: email,
        channelId: "posts",
        fcmTarget: {topic: emailToTopic(email)},
      });
    }
  },
);

async function resolveUserIdByEmail(email: string): Promise<string | null> {
  try {
    return (await findUserByEmail(email))?.id ?? null;
  } catch (err) {
    logger.warn("onWallApproved: could not resolve artist uid.", {email, err});
    return null;
  }
}
