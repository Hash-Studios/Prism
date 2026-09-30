import {createHash} from "node:crypto";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {
  emailToTopic,
  isLoggedOut,
  sendNotification,
  sendToUidAndEmailTopics,
  userIdToTopic,
} from "./notificationHelper";
import {usernameLowerOf} from "./usernameLower";
import {db, findUserByEmail, REGION, str} from "./common";

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
 *   2. Unless they muted Followers alerts, send an FCM push to the followed user.
 *   3. Write a per-user in-app notification doc (modifier = followed user's email).
 */
export const onFollowCreated = onDocumentUpdated(
  {
    document: "usersv2/{userId}",
    region: REGION,
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

    const followedUserEmail = str(after.email);
    if (!followedUserEmail) {
      return;
    }

    const followedUid = event.params.userId;
    const pushEnabled = !isLoggedOut(after) && !(await followerAlertsMuted(followedUid));

    for (const followerEmail of newFollowerEmailsRaw) {
      const followerUid = await resolveUserIdByEmail(followerEmail);
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

      const followerUsername = await resolveUsername(followerEmail);
      const payload = {
        title: "You have a new follower! 🎉",
        body: `${followerUsername} is now following you.`,
        data: {
          route: "follower",
          follower_email: followerEmail.trim(),
          url: profileUrl(followerEmail),
        },
        modifier: followedUserEmail,
        channelId: "followers",
        collapseKey: followCollapseKey(followerEmail),
      };
      if (pushEnabled) {
        await sendToUidAndEmailTopics(payload, userIdToTopic(followedUid), emailToTopic(followedUserEmail));
      } else {
        await sendNotification(payload);
      }

      logger.info("onFollowCreated: follow notification sent.", {
        followedUserEmail,
        followerEmail: followerEmail.toLowerCase(),
      });
    }
  },
);

/** Same key for both follow pushes, short enough for apns-collapse-id (64 bytes). */
export function followCollapseKey(followerEmail: string): string {
  const hash = createHash("sha1").update(followerEmail.trim().toLowerCase()).digest("hex").slice(0, 16);
  return `follow_${hash}`;
}

/** True only when the user explicitly turned Followers alerts off. */
export function isFollowerAlertsOff(session: Record<string, unknown> | undefined): boolean {
  return session?.followerAlerts === false;
}

async function followerAlertsMuted(uid: string): Promise<boolean> {
  try {
    const snap = await db.doc(`usersv2/${uid}/private/session`).get();
    return isFollowerAlertsOff(snap.data());
  } catch (err) {
    logger.warn("onFollowCreated: could not read follower alert pref.", {uid, err});
    return false;
  }
}

/** Returns usersv2 document id (Firebase uid) for an email, or null. */
async function resolveUserIdByEmail(email: string): Promise<string | null> {
  const trimmed = email.trim();
  if (!trimmed) {
    return null;
  }
  try {
    return (await findUserByEmail(trimmed))?.id ?? null;
  } catch (err) {
    logger.warn("onFollowCreated: could not resolve follower uid.", {email: trimmed, err});
    return null;
  }
}

/** Resolves a display username for a given email address.
 *  Falls back to the email prefix if the user doc cannot be found. */
async function resolveUsername(email: string): Promise<string> {
  try {
    const data = (await findUserByEmail(email))?.data();
    const name = str(data?.username) || str(data?.name);
    if (name) return name;
  } catch (err) {
    logger.warn("onFollowCreated: could not resolve follower username.", {email, err});
  }
  return email.split("@")[0];
}

function profileUrl(identifier: string): string {
  const cleaned = identifier.trim();
  if (!cleaned) return "";
  return `https://prismwalls.com/user/${encodeURIComponent(cleaned)}`;
}
