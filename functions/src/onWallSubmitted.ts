import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {defineSecret} from "firebase-functions/params";
import {parseAiSource, saveAiGenerationReceipt} from "./aiWallSource";
import {getAdminEmails} from "./adminConfig";
import {emailHash, sendToUserByEmail} from "./notificationHelper";
import {db, findUserByEmail, REGION, str} from "./common";
import {isStudioWall} from "./studio/isStudioWall";
import {notificationCopyPayload} from "./notificationCatalog";
import {authorOf, authorUpdate} from "./wallAuthor";
import {keepRemixOf, removeRemixOfIfUnchanged} from "./wallRemix";
import {sanitizeResubmitOf} from "./wallResubmissions";
import {sanitizeSubmissionText} from "./wallSubmissionSafety";
import {checkSubmittedVariantOf} from "./wallVariants";
import {isLiveWall, verifyLiveWall} from "./wallLive";
import {parseFileReference, proveStillWallUpload, type FileReference} from "./completedWallUpload";
import {r2Secrets} from "./r2Storage";
import {verifiedUidForEmail} from "./authoredContentUid";
import {HttpsError} from "firebase-functions/v2/https";

const GITHUB_RAW_HOST = "raw.githubusercontent.com";
const studioSecret = defineSecret("STUDIO_SECRET");

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
 * not reject, an image link outside the GitHub raw host. Copies the Worker record of a user AI wall to a server-only
 * receipt, so the approval trigger can prove its owner after the record expires. Removes a `remixOf` that does not name
 * an approved AI original (see keepRemixOf), and a `variantOf` that fails a colourway check
 * (see checkSubmittedVariantOf). Then notifies the admins in `config/adminNotifications` when a premium
 * user submits a wall (walls start with review=false).
 */
export const onWallSubmitted = onDocumentCreated(
  {
    document: "walls/{wallId}",
    region: REGION,
    secrets: [studioSecret, ...r2Secrets],
    timeoutSeconds: 120,
    memory: "512MiB",
    concurrency: 1,
    retry: true,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    const wallId = event.params.wallId;
    if (event.data) {
      await sanitizeResubmitOf(event.data);
      if (await sanitizeSubmissionText(event.data)) logger.warn("onWallSubmitted: cleared rejected metadata text.", {wallId});
    }
    if (data.remixOf !== undefined && event.data) {
      try {
        if (!(await keepRemixOf(wallId, data)) && await removeRemixOfIfUnchanged(event.data, data.remixOf)) {
          logger.info("onWallSubmitted: removed an unverified remixOf.", {wallId});
        }
      } catch (err) {
        // onWallRemixWritten checks the link again before it credits anything.
        logger.warn("onWallSubmitted: remixOf check failed.", {wallId, err});
      }
    }
    if (data.variantOf !== undefined && event.data) {
      try {
        const dropped = await checkSubmittedVariantOf(event.data);
        if (dropped) logger.info("onWallSubmitted: removed a variantOf that failed a check.", {wallId, reason: dropped});
      } catch (err) {
        // onWallVariantWritten checks the link again on approval.
        logger.warn("onWallSubmitted: variantOf check failed.", {wallId, err});
      }
    }
    if (await isStudioWall(wallId, data)) {
      logger.info(
        "onWallSubmitted: Prism Studio wall, no owner sync or admin push.",
        {wallId},
      );
      return;
    }
    const artistEmail = str(data.email);
    if (isLiveWall(data) && event.data) {
      try {
        const ownerUid = artistEmail ? await verifiedUidForEmail(artistEmail) : null;
        await verifyLiveWall(event.data, ownerUid);
      } catch (err) {
        logger.warn("onWallSubmitted: live wall check failed.", {wallId, err});
        throw err;
      }
    }
    const wallTitle = str(data.title) || "Untitled";
    const wallThumb = str(data.wallpaper_thumb);

    const aiSource = parseAiSource(data);
    if (aiSource) {
      try {
        if (!(await saveAiGenerationReceipt(db, aiSource.generationId))) {
          logger.warn("onWallSubmitted: AI wall has no Worker record; no receipt.", {wallId});
        }
      } catch (err) {
        logger.warn("onWallSubmitted: AI generation receipt failed.", {wallId, err});
      }
    }

    if (!isLiveWall(data) && !aiSource && event.data) {
      try {
        await bindStillWallImages(event.data, artistEmail);
      } catch (err) {
        logger.warn("onWallSubmitted: still wall proof failed.", {wallId, err});
        throw err;
      }
    }

    let artistName = str(data.by) || "A user";
    let isPremium = true;
    if (artistEmail) {
      try {
        const user = await findUserByEmail(artistEmail);
        if (user) {
          isPremium = user.data().premium === true;
          artistName =
            (await syncOwnerFields(event.data?.ref, data, user.data())) ||
            artistName;
        }
      } catch (err) {
        logger.warn(
          "onWallSubmitted: owner lookup failed; notifying for review.",
          {
            wallId,
            artistHash: emailHash(artistEmail),
            err,
          },
        );
      }
    }
    if (!isPremium) return;

    const adminEmails = await getAdminEmails();
    if (adminEmails.length === 0) {
      logger.warn(
        "onWallSubmitted: no admin emails configured in config/adminNotifications.",
      );
      return;
    }

    for (const adminEmail of adminEmails) {
      await sendToUserByEmail(
        {
          ...notificationCopyPayload({
            kind: "wallSubmittedForReview",
            artistName,
            artistEmail,
          }),
          data: {route: "wall", wall_id: wallId},
          imageUrl: wallThumb || undefined,
          modifier: adminEmail,
          channelId: "posts",
          scoreKind: "moderation",
          // This trigger retries, so each wall keeps one inbox entry per admin.
          docId: `wall_submitted_${wallId}`,
        },
        adminEmail,
      );
    }

    logger.info("onWallSubmitted: admin notifications sent.", {
      wallId,
      artistHash: emailHash(artistEmail),
      wallTitle,
      adminCount: adminEmails.length,
    });
  },
);

function stillFile(data: admin.firestore.DocumentData, role: "original" | "thumbnail"):
  {file: FileReference; url: string} | null {
  const original = role === "original";
  const path = str(data[original ? "wallpaper_path" : "thumb_path"]);
  const sha = str(data[original ? "wallpaper_sha" : "thumb_sha"]);
  const url = str(data[original ? "wallpaper_url" : "wallpaper_thumb"]);
  const rawKind = data[original ? "wallpaper_source_kind" : "thumb_source_kind"];
  const sourceKind = rawKind === "owned" || rawKind === "github" ? rawKind : url === "" ? "owned" : "github";
  if (!path || !sha) return null;
  try {
    return {file: parseFileReference({path, sha, sourceKind}), url};
  } catch {
    return null;
  }
}

function clearStillRole(role: "original" | "thumbnail"): Record<string, unknown> {
  return role === "original" ?
    {wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "",
      wallpaper_source_kind: admin.firestore.FieldValue.delete()} :
    {wallpaper_thumb: "", thumb_path: "", thumb_sha: "",
      thumb_source_kind: admin.firestore.FieldValue.delete()};
}

/** Strips still-wall image fields that are not a caller-owned completed upload. */
async function bindStillWallImages(snapshot: admin.firestore.QueryDocumentSnapshot, artistEmail: string): Promise<void> {
  const repo = process.env.GH_REPO_WALLS?.trim();
  const owner = process.env.GH_USERNAME?.trim();
  if (!repo || !owner) {
    logger.warn("onWallSubmitted: still upload proof is not configured; unproven images stripped.",
      {wallId: snapshot.id});
    await snapshot.ref.update({...clearStillRole("original"), ...clearStillRole("thumbnail")});
    return;
  }
  const ownerUid = artistEmail ? await verifiedUidForEmail(artistEmail) : null;
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(snapshot.ref)).data();
    if (!current) return;
    const updates: Record<string, unknown> = {};
    for (const role of ["original", "thumbnail"] as const) {
      const parsed = stillFile(current, role);
      const urlField = role === "original" ? "wallpaper_url" : "wallpaper_thumb";
      try {
        if (!ownerUid || !parsed) throw new HttpsError("failed-precondition", "Completed upload proof is unavailable.");
        const proven = await proveStillWallUpload(tx, ownerUid, parsed.file, role);
        if (proven.url !== parsed.url) {
          throw new HttpsError("failed-precondition", "Completed upload proof is unavailable.");
        }
      } catch (error) {
        if (error instanceof HttpsError && error.code === "failed-precondition") {
          logger.warn("onWallSubmitted: unproven still image stripped.", {wallId: snapshot.id, field: urlField});
          Object.assign(updates, clearStillRole(role));
          continue;
        }
        throw error;
      }
    }
    if (Object.keys(updates).length > 0) tx.update(snapshot.ref, updates);
  });
}

/** Writes the owner's name and photo to the wall. Returns the name to show. */
async function syncOwnerFields(
  ref: admin.firestore.DocumentReference | undefined,
  wall: admin.firestore.DocumentData,
  owner: admin.firestore.DocumentData,
): Promise<string> {
  const update = authorUpdate(wall, owner);
  if (ref && Object.keys(update).length > 0) await ref.update(update);
  return authorOf(owner).by;
}
