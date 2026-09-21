import * as admin from "firebase-admin";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {sendNotification, emailToTopic, userIdToTopic} from "./notificationHelper";
import {usernameLowerOf} from "./usernameLower";

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
 * It also keeps `usernameLower` equal to the lowercased username.
 *
 * For each newly added follower email:
 *   1. Look up the follower's display name from their user doc.
 *   2. Send an FCM push to the followed user (via their own email-prefix topic).
 *   3. Write a per-user in-app notification doc (modifier = followed user's email).
 */
export const onFollowCreated = onDocumentUpdated(
  {
    document: "usersv2/{userId}",
    region: "asia-south1",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      return;
    }

    // Keep usernameLower in sync for follower/following search. The write
    // re-fires this trigger once, and that run finds nothing to change.
    const usernameLower = usernameLowerOf(after.username);
    if (after.usernameLower !== usernameLower) {
      try {
        await event.data?.after.ref.update({usernameLower});
      } catch (err) {
        logger.warn("onFollowCreated: usernameLower sync failed.", {err});
      }
    }

    const beforeList = (before.followers as string[] | undefined ?? [])
      .map((e) => e.toString().trim())
      .filter((e) => e.length > 0);
    const afterList = (after.followers as string[] | undefined ?? [])
      .map((e) => e.toString().trim())
      .filter((e) => e.length > 0);

    const beforeNorm = new Set<string>(beforeList.map((e) => e.toLowerCase()));

    // Preserve original casing for Firestore email lookups; diff using normalized form.
    const newFollowerEmailsRaw = afterList.filter((e) => !beforeNorm.has(e.toLowerCase()));
    if (newFollowerEmailsRaw.length === 0) {
      return;
    }

    const followedUserEmail: string = (after.email ?? "").toString().trim();
    if (!followedUserEmail) {
      return;
    }

    const followedUid = event.params.userId;

    for (const followerEmail of newFollowerEmailsRaw) {
      const followerUid = await _resolveUserIdByEmail(followerEmail);
      if (followerUid) {
        const blockSnap = await db
          .collection("usersv2")
          .doc(followedUid)
          .collection("blockedUsers")
          .doc(followerUid)
          .get();
        if (blockSnap.exists) {
          logger.info("onFollowCreated: skipped — follower is blocked by followed user.", {
            followedUid,
            followerUid,
          });
          continue;
        }
      }

      // Look up the follower's display name for a personalised message.
      const followerUsername = await _resolveUsername(followerEmail);

      const followedTopic = userIdToTopic(followedUid);

      await sendNotification({
        title: "You have a new follower! 🎉",
        body: `${followerUsername} is now following you.`,
        data: {
          route: "follower",
          follower_email: followerEmail.trim(),
          pageName: "",
          url: _profileUrl(followerEmail),
        },
        modifier: followedUserEmail,
        channelId: "followers",
        // Send push to the followed user's own topic (they subscribe on login).
        fcmTarget: {topic: followedTopic},
      });
      await sendNotification({
        title: "You have a new follower! 🎉",
        body: `${followerUsername} is now following you.`,
        data: {
          route: "follower",
          follower_email: followerEmail.trim(),
          pageName: "",
          url: _profileUrl(followerEmail),
        },
        modifier: followedUserEmail,
        channelId: "followers",
        fcmTarget: {topic: emailToTopic(followedUserEmail)},
        pushOnly: true,
      });

      logger.info("onFollowCreated: follow notification sent.", {
        followedUserEmail,
        followerEmail: followerEmail.toLowerCase(),
      });
    }
  },
);

/** Returns usersv2 document id (Firebase uid) for an email, or null. */
async function _resolveUserIdByEmail(email: string): Promise<string | null> {
  const trimmed = email.trim();
  if (!trimmed) {
    return null;
  }
  try {
    const snap = await db.collection("usersv2").where("email", "==", trimmed).limit(1).get();
    if (!snap.empty) {
      return snap.docs[0].id;
    }
    const lower = trimmed.toLowerCase();
    if (lower !== trimmed) {
      const snapLo = await db.collection("usersv2").where("email", "==", lower).limit(1).get();
      if (!snapLo.empty) {
        return snapLo.docs[0].id;
      }
    }
  } catch (err) {
    logger.warn("onFollowCreated: could not resolve follower uid.", {email: trimmed, err});
  }
  return null;
}

/** Resolves a display username for a given email address.
 *  Falls back to the email prefix if the user doc cannot be found. */
async function _resolveUsername(email: string): Promise<string> {
  try {
    const snap = await db
      .collection("usersv2")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (!snap.empty) {
      const data = snap.docs[0].data();
      const name =
        (data.username as string | undefined)?.trim() ||
        (data.name as string | undefined)?.trim();
      if (name) return name;
    }
  } catch (err) {
    logger.warn("onFollowCreated: could not resolve follower username.", {email, err});
  }
  return email.split("@")[0];
}

function _profileUrl(identifier: string): string {
  const cleaned = identifier.trim();
  if (!cleaned) return "";
  return `https://prismwalls.com/user/${encodeURIComponent(cleaned)}`;
}
