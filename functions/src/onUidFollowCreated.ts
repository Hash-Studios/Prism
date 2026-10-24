import {createHash} from "node:crypto";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION, str} from "./common";
import {isLoggedOut, sendToUser} from "./notificationHelper";
import {notificationCopyPayload} from "./notificationCatalog";

export const onUidFollowCreated = onDocumentCreated(
  {document: "profiles/{targetUid}/followers/{followerUid}", region: REGION},
  async (event) => {
    const {targetUid, followerUid} = event.params;
    if (!targetUid || !followerUid || targetUid === followerUid) return;
    const edgeRef = db.doc(`profiles/${targetUid}/followers/${followerUid}`);
    const [edgeSnap, targetSnap, followerSnap, targetBlock, followerBlock, targetBarrier, followerBarrier] = await Promise.all([
      edgeRef.get(),
      db.doc(`usersv2/${targetUid}`).get(),
      db.doc(`profiles/${followerUid}`).get(),
      db.doc(`usersv2/${targetUid}/blockedUsers/${followerUid}`).get(),
      db.doc(`usersv2/${followerUid}/blockedUsers/${targetUid}`).get(),
      db.doc(`creatorDeletionState/${targetUid}`).get(),
      db.doc(`creatorDeletionState/${followerUid}`).get(),
    ]);
    if (!edgeSnap.exists || edgeSnap.data()?.notify !== true) return;
    const target = targetSnap.data();
    const follower = followerSnap.data();
    const recipientEmail = str(target?.email);
    const followerName = str(follower?.username) || str(follower?.name);
    if (!target || target.deleted === true || !recipientEmail || !followerName ||
      targetBarrier.data()?.closed === true || followerBarrier.data()?.closed === true) return;
    if (targetBlock.exists || followerBlock.exists) {
      logger.info("onUidFollowCreated: blocked edge ignored.", {targetUid, followerUid});
      return;
    }

    const session = await db.doc(`usersv2/${targetUid}/private/session`).get();
    const hash = createHash("sha1").update(followerUid).digest("hex").slice(0, 16);
    await sendToUser({
      ...notificationCopyPayload({kind: "newFollower", followerName}),
      data: {
        route: "follower", notification_kind: "follower", follower_uid: followerUid,
        ...(str(follower?.username) ? {username: str(follower?.username)} : {}),
        url: `https://prismwalls.com/user/${encodeURIComponent(str(follower?.username) || followerUid)}`,
      },
      modifier: recipientEmail,
      channelId: "followers",
      scoreKind: "follower",
      collapseKey: `follow_${hash}`,
      docId: `follow_${hash}_${targetUid}`,
    }, {
      uid: targetUid,
      email: recipientEmail,
      loggedOut: isLoggedOut(target),
      legacyToken: target.fcmToken,
    }, session.data()?.followerAlerts !== false);
  },
);
