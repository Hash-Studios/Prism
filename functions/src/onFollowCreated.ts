import * as admin from "firebase-admin";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION, str} from "./common";
import {usernameLowerOf} from "./usernameLower";
import {authorOf, syncAuthorFields} from "./wallAuthor";
import {verifiedUidForEmail} from "./authoredContentUid";
import {applyFollowEdge} from "./profiles";

function emails(list: unknown): Map<string, string> {
  const out = new Map<string, string>();
  for (const entry of Array.isArray(list) ? list : []) {
    const email = str(entry);
    if (email) out.set(email.toLowerCase(), email);
  }
  return out;
}

/**
 * Keeps legacy upload author fields current and bridges the email follow arrays that shipped clients
 * still write into UID edges. The follow push comes from onUidFollowCreated.
 */
export const onFollowCreated = onDocumentUpdated(
  {document: "usersv2/{userId}", region: REGION},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    const uid = event.params.userId;

    const nameLower = usernameLowerOf(after.name);
    if (typeof after.name === "string" && after.nameLower !== nameLower) {
      try {
        await event.data?.after.ref.update({nameLower});
      } catch (err) {
        logger.warn("onFollowCreated: lowercase name sync failed.", {err});
      }
    }

    const beforeAuthor = authorOf(before);
    const afterAuthor = authorOf(after);
    if (beforeAuthor.by !== afterAuthor.by || beforeAuthor.userPhoto !== afterAuthor.userPhoto) {
      try {
        await syncAuthorFields(uid, after);
      } catch (err) {
        logger.warn("onFollowCreated: author sync failed.", {err});
      }
    }

    const was = emails(before.followers);
    const now = emails(after.followers);
    const added = [...now].filter(([key]) => !was.has(key)).map(([, email]) => email);
    const removed = [...was].filter(([key]) => !now.has(key)).map(([, email]) => email);
    const followedEmail = str(after.email);

    for (const [list, follow] of [[added, true], [removed, false]] as const) {
      for (const email of list) {
        try {
          const followerUid = await verifiedUidForEmail(email);
          if (!followerUid || followerUid === uid) continue;
          if (follow && followedEmail &&
            (await db.doc(`usersv2/${uid}/blockedUsers/${followerUid}`).get()).exists) {
            await removeFollow(uid, followedEmail, followerUid, email);
            continue;
          }
          await applyFollowEdge({followerUid, targetUid: uid, follow, notify: true});
        } catch (err) {
          logger.warn("onFollowCreated: could not bridge a legacy follow.", {uid, follow, err});
        }
      }
    }
  },
);

/** Takes the follow out of both arrays. A blocked user cannot stay a follower. */
async function removeFollow(
  followedUid: string,
  followedEmail: string,
  followerUid: string,
  followerEmail: string,
): Promise<void> {
  const users = db.collection("usersv2");
  await users.doc(followedUid).update({
    followers: admin.firestore.FieldValue.arrayRemove(followerEmail),
  });
  await users.doc(followerUid).update({
    following: admin.firestore.FieldValue.arrayRemove(
      ...new Set([followedEmail, followedEmail.toLowerCase()]),
    ),
  });
}
