import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {db, findUserByEmail, REGION, str} from "./common";
import {
  emailHash,
  emailToTopic,
  isLoggedOut,
  postsTopic,
  sendNotification,
  sendToUser,
  sendToUserByEmail,
} from "./notificationHelper";

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

    if (!(await claimApprovalNotice(event.data?.after.ref))) {
      logger.info("onWallApproved: approval already announced, skipping.", {wallId});
      return;
    }

    const artist = await resolveUserByEmail(artistEmail);
    const artistPayload = {
      title: "Your wallpaper is live! 🎉",
      body: `"${wallTitle}" has been approved and is now visible to everyone.`,
      data: {route: "wall", wall_id: wallId},
      imageUrl: wallThumb || undefined,
      modifier: artistEmail,
      channelId: "posts",
      collapseKey: `wall_${wallId}`,
    };
    const artistData = artist?.data();
    await sendToUser(artistPayload, {
      uid: artist?.id,
      email: artistEmail,
      loggedOut: isLoggedOut(artistData),
      legacyToken: artistData?.fcmToken,
    });

    logger.info("onWallApproved: artist notification sent.", {wallId, artistHash: emailHash(artistEmail)});

    // Followers subscribe to <email prefix>_posts (followersTopicFromEmail). Newer builds subscribe to posts_<uid>,
    // which cannot collide across creators. Both topics get the push, with one collapse key.
    // Push only: an in-app doc would show the artist a duplicate.
    const followersTopics = [`${emailToTopic(artistEmail)}_posts`, ...(artist ? [postsTopic(artist.id)] : [])];
    const collapseKey = postsCollapseKey(artistEmail);
    for (const topic of followersTopics) {
      await sendNotification({
        title: `New wall by ${artistName}`,
        body: `"${wallTitle}" is now live on Prism.`,
        data: {route: "wall", wall_id: wallId, artist_email: artistEmail},
        imageUrl: wallThumb || undefined,
        modifier: artistEmail,
        channelId: "posts",
        fcmTarget: {topic},
        pushOnly: true,
        collapseKey,
      });
    }

    logger.info("onWallApproved: followers notification sent.", {
      wallId,
      followersTopics,
    });

    for (const email of await getAdminEmails()) {
      await sendToUserByEmail({
        title: "Wall approved ✅",
        body: `"${wallTitle}" by ${artistName} is now live.`,
        data: {route: "wall", wall_id: wallId},
        imageUrl: wallThumb || undefined,
        modifier: email,
        channelId: "posts",
      }, email);
    }
  },
);

/** Same key on every followers push of one creator, short enough for apns-collapse-id (64 bytes). */
export function postsCollapseKey(artistEmail: string): string {
  const hash = createHash("sha1").update(artistEmail.trim().toLowerCase()).digest("hex").slice(0, 16);
  return `posts_${hash}`;
}

/** Stamps the wall once, so a retried or repeated approval event sends no second set of pushes. */
async function claimApprovalNotice(ref: admin.firestore.DocumentReference | undefined): Promise<boolean> {
  if (!ref) return true;
  try {
    return await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (current.data()?.approvedNotifiedAt != null) return false;
      tx.update(ref, {approvedNotifiedAt: admin.firestore.FieldValue.serverTimestamp()});
      return true;
    });
  } catch (err) {
    logger.warn("onWallApproved: could not stamp the approval, sending anyway.", {err});
    return true;
  }
}

async function resolveUserByEmail(email: string): ReturnType<typeof findUserByEmail> {
  try {
    return await findUserByEmail(email);
  } catch (err) {
    logger.warn("onWallApproved: could not resolve artist uid.", {emailHash: emailHash(email), err});
    return null;
  }
}
