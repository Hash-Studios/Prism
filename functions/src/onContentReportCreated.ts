import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {sendToUserByEmail} from "./notificationHelper";
import {db, REGION} from "./common";
import {hideFolder} from "./publicFolders";

interface ReportDoc {
  contentType?: string;
  targetFirestoreDocId?: string;
  reason?: string;
  details?: string;
  reporterUid?: string;
}

const HOLD_REPORTER_COUNT = 3;
const MIN_REPORTER_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Counts distinct reporters older than 7 days. Missing accounts do not count; transient lookup errors retry. */
async function countTrustedReporters(
  reporterUids: Set<string>,
  nowMs: number,
): Promise<number> {
  let trusted = 0;
  for (const uid of reporterUids) {
    try {
      const created = Date.parse(
        (await admin.auth().getUser(uid)).metadata.creationTime,
      );
      if (Number.isFinite(created) && nowMs - created > MIN_REPORTER_AGE_MS) {
        trusted += 1;
      }
    } catch (err) {
      if ((err as {code?: string}).code !== "auth/user-not-found" &&
        (err as Error).message !== "auth/user-not-found") throw err;
      logger.warn(
        "onContentReportCreated: could not read a reporter account.",
        {reporterUid: uid, err},
      );
    }
  }
  return trusted;
}

/** True when 3 different reporters, with accounts older than 7 days, reported the target. */
async function reportedByTrustedUsers(contentType: string, targetId: string): Promise<boolean> {
  const reports = await db
    .collection("contentReports")
    .where("contentType", "==", contentType)
    .where("targetFirestoreDocId", "==", targetId)
    .get();
  const reporters = new Set<string>();
  for (const report of reports.docs) {
    const uid = (report.data().reporterUid ?? "").toString();
    if (uid) reporters.add(uid);
  }
  if (reporters.size < HOLD_REPORTER_COUNT) return false;
  return (await countTrustedReporters(reporters, Date.now())) >= HOLD_REPORTER_COUNT;
}

/**
 * Takes an approved wall back to review when trusted users reported it.
 * An admin re-approves it from the review screen. Returns true when this call held the wall.
 */
async function holdWallAfterReports(wallId: string): Promise<boolean> {
  if (!(await reportedByTrustedUsers("wall", wallId))) return false;
  const wallRef = db.collection("walls").doc(wallId);
  return db.runTransaction(async (tx) => {
    const wall = await tx.get(wallRef);
    if (wall.data()?.review !== true) return false;
    tx.update(wallRef, {
      review: false,
      heldForReview: true,
      heldAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

/**
 * Holds a wall that several trusted users reported, then notifies the configured admins of the new UGC report.
 */
export const onContentReportCreated = onDocumentCreated(
  {
    document: "contentReports/{reportId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const data = event.data?.data() as ReportDoc | undefined;
    if (!data) {
      return;
    }

    const reportId = event.params.reportId;
    const contentType = (data.contentType ?? "unknown").toString();
    const targetId = (data.targetFirestoreDocId ?? "").toString();
    const reason = (data.reason ?? "").toString();
    const reporterUid = (data.reporterUid ?? "").toString();

    if (contentType === "wall" && targetId.length > 0) {
      try {
        if (await holdWallAfterReports(targetId)) {
          logger.warn(
            "onContentReportCreated: wall held for review after reports.",
            {reportId, targetId},
          );
        }
      } catch (err) {
        logger.error(
          "onContentReportCreated: could not check the report count.",
          {reportId, targetId, err},
        );
        // The trigger retries; holdWallAfterReports holds a wall once, so a retry is safe.
        throw err;
      }
    }

    // A reported public folder is hidden the same way. An admin shows it again with setFolderHidden.
    if (contentType === "folder" && targetId.length > 0) {
      try {
        if (await reportedByTrustedUsers("folder", targetId)) {
          await hideFolder(targetId, true);
          logger.warn("onContentReportCreated: public folder hidden after reports.", {reportId, targetId});
        }
      } catch (err) {
        const code = (err as {code?: string | number}).code;
        if (code !== "not-found" && code !== "NOT_FOUND" && code !== 5) {
          logger.error("onContentReportCreated: could not check the folder reports.", {reportId, targetId, err});
          throw err;
        }
      }
    }

    // A block files a report so it is on record. It needs no admin push.
    if (reason === "blocked") return;

    const adminEmails = await getAdminEmails();
    if (adminEmails.length === 0) {
      logger.error(
        "onContentReportCreated: no admin emails configured in config/adminNotifications.",
        {
          reportId,
          contentType,
        },
      );
      return;
    }

    const copy = {
      title: "New content report",
      body: "A user submitted content for review.",
    };
    const notificationData = {route: "content_report", report_id: reportId};

    for (const adminEmail of adminEmails) {
      await sendToUserByEmail(
        {
          ...copy,
          data: notificationData,
          modifier: adminEmail,
          channelId: "moderation",
          scoreKind: "moderation",
        },
        adminEmail,
      );
    }

    const webhookUrl = process.env.CONTENT_REPORT_WEBHOOK_URL?.trim();
    if (webhookUrl) {
      try {
        const res = await fetch(webhookUrl, {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify({
            text: `[Prism] ${copy.title}: ${copy.body} (reportId=${reportId})`,
            reportId,
            contentType,
            targetId,
            reason,
            reporterUid,
          }),
        });
        if (!res.ok) {
          logger.warn("onContentReportCreated: webhook non-OK", {
            status: res.status,
          });
        }
      } catch (err) {
        logger.error("onContentReportCreated: webhook failed", {err});
      }
    }

    logger.info("onContentReportCreated: notifications sent", {
      reportId,
      adminCount: adminEmails.length,
    });
  },
);
