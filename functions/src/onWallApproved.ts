import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {db, findUserByEmail, REGION, str} from "./common";
import {isStudioWall} from "./studio/isStudioWall";
import {notificationCopyPayload} from "./notificationCatalog";
import {getOwnedWallDelivery, ownedAssetStorageEnabled, ownedThumbnailUrl} from "./ownedAssetDelivery";
import {fileWallInCollection} from "./wallCollections";
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
 * Files approved walls into their category collection and announces them once their delivery is ready.
 */
export const onWallApproved = onDocumentUpdated(
  {
    document: "walls/{wallId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      return;
    }

    const wasApproved = before.review === true;
    const isApproved = after.review === true;
    const owned = ownedAssetStorageEnabled();
    const becameProtected = before.originalProtected !== true && after.originalProtected === true;
    if (!isApproved || (wasApproved && !(owned && becameProtected))) {
      return;
    }

    const wallId = event.params.wallId;
    const expected = event.data?.after;
    if (!expected) return;
    let current: admin.firestore.DocumentSnapshot;
    try {
      current = await expected.ref.get();
    } catch (err) {
      logger.warn("onWallApproved: could not read the current wall.", {wallId, err});
      throw err;
    }
    if (!sameWallIncarnation(expected, current) || current.data()?.review !== true) return;
    // Approval sets collections to community, so the category collection is added after it.
    if (!wasApproved) await fileWallInCollection(expected.ref);
    if (await isStudioWall(wallId, current.data() ?? {})) {
      logger.info("onWallApproved: Prism Studio wall, no pushes.", {wallId});
      return;
    }
    if (!str(current.data()?.email)) return;
    const announced = await claimApprovalNotice(expected, owned);
    if (!announced) {
      logger.info("onWallApproved: wall is unavailable or already announced, skipping.", {wallId});
      return;
    }
    const artistEmail = str(announced.email);
    const artistName = str(announced.by) || "An artist";
    const wallTitle = str(announced.title) || "Untitled";
    const wallThumb = str(announced.wallpaper_thumb);

    if (!artistEmail) {
      logger.warn("onWallApproved: wall has no artist email, skipping.", {
        wallId,
      });
      return;
    }

    const artist = await resolveUserByEmail(artistEmail);
    const artistPayload = {
      ...notificationCopyPayload({kind: "wallApprovedForArtist", wallTitle}),
      data: {
        route: "wall",
        wall_id: wallId,
        notification_kind: "wall_approved",
      },
      imageUrl: wallThumb || undefined,
      modifier: artistEmail,
      channelId: "posts",
      scoreKind: "post",
      collapseKey: `wall_${wallId}`,
    };
    const artistData = artist?.data();
    await sendToUser(artistPayload, {
      uid: artist?.id,
      email: artistEmail,
      loggedOut: isLoggedOut(artistData),
      legacyToken: artistData?.fcmToken,
    });

    logger.info("onWallApproved: artist notification sent.", {
      wallId,
      artistHash: emailHash(artistEmail),
    });

    // Followers subscribe to <email prefix>_posts (followersTopicFromEmail). Newer builds subscribe to posts_<uid>,
    // which cannot collide across creators. Both topics get the push, with one collapse key.
    // Push only: an in-app doc would show the artist a duplicate.
    const followersTopics = [
      `${emailToTopic(artistEmail)}_posts`,
      ...(artist ? [postsTopic(artist.id)] : []),
    ];
    const collapseKey = postsCollapseKey(artistEmail);
    for (const topic of followersTopics) {
      await sendNotification({
        ...notificationCopyPayload({
          kind: "wallLiveForFollowers",
          artistName,
          wallTitle,
        }),
        data: {
          route: "wall",
          wall_id: wallId,
          artist_email: artistEmail,
          notification_kind: "wall_live",
        },
        imageUrl: wallThumb || undefined,
        modifier: artistEmail,
        channelId: "posts",
        scoreKind: "post",
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
      await sendToUserByEmail(
        {
          ...notificationCopyPayload({
            kind: "wallApprovedForAdmin",
            wallTitle,
            artistName,
          }),
          data: {
            route: "wall",
            wall_id: wallId,
            notification_kind: "wall_approved",
          },
          imageUrl: wallThumb || undefined,
          modifier: email,
          channelId: "posts",
          scoreKind: "moderation",
        },
        email,
      );
    }
  },
);

/** Same key on every followers push of one creator, short enough for apns-collapse-id (64 bytes). */
export function postsCollapseKey(artistEmail: string): string {
  const hash = createHash("sha1")
    .update(artistEmail.trim().toLowerCase())
    .digest("hex")
    .slice(0, 16);
  return `posts_${hash}`;
}

/** Stamps the wall once, so a retried or repeated approval event sends no second set of pushes. */
async function claimApprovalNotice(
  expected: admin.firestore.DocumentSnapshot,
  owned: boolean,
): Promise<admin.firestore.DocumentData | null> {
  try {
    const ready = owned ? await getOwnedWallDelivery(str(expected.data()?.id)) : undefined;
    return await db.runTransaction(async (tx) => {
      const current = await tx.get(expected.ref);
      const data = current.data();
      if (!sameWallIncarnation(expected, current) || !current.createTime || data?.review !== true || !str(data.email) ||
        data.approvedNotifiedAt != null) return null;
      if (ready) {
        const manifest = (await tx.get(db.collection("ownedAssets").doc(str(data.id)))).data();
        if (manifest?.status !== "ready" || manifest.canonicalPath !== current.ref.path ||
          manifest.incarnation !== current.createTime.toMillis() ||
          manifest.incarnationNanos !== current.createTime.nanoseconds ||
          manifest.original?.objectId !== ready.original.objectId || manifest.thumb?.objectId !== ready.thumb.objectId ||
          data.originalProtected !== true || data.originalObjectId !== ready.original.objectId ||
          data.wallpaper_url !== "" || data.wallpaper_path !== "" || data.wallpaper_sha !== "" ||
          data.thumb_path !== "" || data.thumb_sha !== "" || data.wallpaper_thumb !== ownedThumbnailUrl(ready.thumb)) return null;
      }
      tx.update(expected.ref, {
        approvedNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return data;
    });
  } catch (err) {
    if (err instanceof Error && ["Owned wall unavailable", "Invalid wall identity"].includes(err.message)) return null;
    logger.warn(
      "onWallApproved: could not claim a ready approval notice, retrying.",
      {err},
    );
    throw err;
  }
}

function sameWallIncarnation(expected: admin.firestore.DocumentSnapshot,
  current: admin.firestore.DocumentSnapshot): boolean {
  return Boolean(expected.createTime && current.createTime?.isEqual(expected.createTime) &&
    expected.ref.path === current.ref.path && expected.data()?.id === current.data()?.id);
}

async function resolveUserByEmail(
  email: string,
): ReturnType<typeof findUserByEmail> {
  try {
    return await findUserByEmail(email);
  } catch (err) {
    logger.warn("onWallApproved: could not resolve artist uid.", {
      emailHash: emailHash(email),
      err,
    });
    return null;
  }
}
