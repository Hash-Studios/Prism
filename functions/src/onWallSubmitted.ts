import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {emailHash, sendToUserByEmail} from "./notificationHelper";
import {findUserByEmail, REGION, str} from "./common";

const GITHUB_RAW_HOST = "raw.githubusercontent.com";

/** True when `url` is a https link on the GitHub raw host, where every upload of the app is served. */
export function isGithubRawUrl(url: unknown): boolean {
  try {
    const parsed = new URL(String(url));
    return parsed.protocol === "https:" && parsed.hostname === GITHUB_RAW_HOST;
  } catch {
    return false;
  }
}

/**
 * Fills `by` and `userPhoto` of a new wall from the owner's profile, because the client writes both. Logs, but does
 * not reject, an image link outside the GitHub raw host. Then notifies the admins in `config/adminNotifications`
 * when a premium user submits a wall (walls start with review=false).
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
    const artistEmail = str(data.email);
    const wallTitle = str(data.title) || "Untitled";
    const wallThumb = str(data.wallpaper_thumb);

    if (data.isAiGenerated !== true) {
      for (const field of ["wallpaper_url", "wallpaper_thumb"]) {
        if (str(data[field]) !== "" && !isGithubRawUrl(data[field])) {
          logger.warn("onWallSubmitted: image link is not on the GitHub raw host.", {wallId, field});
        }
      }
    }

    let artistName = str(data.by) || "A user";
    let isPremium = true;
    if (artistEmail) {
      try {
        const user = await findUserByEmail(artistEmail);
        if (user) {
          isPremium = user.data().premium === true;
          artistName = await syncOwnerFields(event.data?.ref, data, user.data()) || artistName;
        }
      } catch (err) {
        logger.warn("onWallSubmitted: owner lookup failed; notifying for review.", {
          wallId,
          artistHash: emailHash(artistEmail),
          err,
        });
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
      artistHash: emailHash(artistEmail),
      wallTitle,
      adminCount: adminEmails.length,
    });
  },
);

/** Writes the owner's name and photo to the wall. Returns the name to show. */
async function syncOwnerFields(
  ref: admin.firestore.DocumentReference | undefined,
  wall: admin.firestore.DocumentData,
  owner: admin.firestore.DocumentData,
): Promise<string> {
  const by = str(owner.name) || str(owner.username);
  const userPhoto = str(owner.profilePhoto);
  const update: Record<string, string> = {};
  if (by && by !== wall.by) update.by = by;
  if (userPhoto && userPhoto !== wall.userPhoto) update.userPhoto = userPhoto;
  if (ref && Object.keys(update).length > 0) await ref.update(update);
  return by;
}
