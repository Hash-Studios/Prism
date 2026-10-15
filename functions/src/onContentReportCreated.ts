import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {type NotificationData, sendToUserByEmail} from "./notificationHelper";
import {db, REGION} from "./common";

interface ReportDoc {
  contentType?: string;
  targetFirestoreDocId?: string;
  reason?: string;
  details?: string;
  reporterUid?: string;
}

const HOLD_REPORTER_COUNT = 3;
const MIN_REPORTER_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Number of reporters, each counted once, whose account is older than 7 days. A failed lookup does not count. */
async function countTrustedReporters(reporterUids: Set<string>, nowMs: number): Promise<number> {
  let trusted = 0;
  for (const uid of reporterUids) {
    try {
      const created = Date.parse((await admin.auth().getUser(uid)).metadata.creationTime);
      if (Number.isFinite(created) && nowMs - created > MIN_REPORTER_AGE_MS) trusted += 1;
    } catch (err) {
      logger.warn("onContentReportCreated: could not read a reporter account.", {reporterUid: uid, err});
    }
  }
  return trusted;
}

/**
 * Takes an approved wall back to review when 3 different reporters, with accounts older than 7 days, reported it.
 * An admin re-approves it from the review screen. Returns true when this call held the wall.
 */
async function holdWallAfterReports(wallId: string): Promise<boolean> {
  const reports = await db.collection("contentReports")
    .where("contentType", "==", "wall")
    .where("targetFirestoreDocId", "==", wallId)
    .get();
  const reporters = new Set<string>();
  for (const report of reports.docs) {
    const uid = (report.data().reporterUid ?? "").toString();
    if (uid) reporters.add(uid);
  }
  if (reporters.size < HOLD_REPORTER_COUNT) return false;
  if ((await countTrustedReporters(reporters, Date.now())) < HOLD_REPORTER_COUNT) return false;

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
          logger.warn("onContentReportCreated: wall held for review after reports.", {reportId, targetId});
        }
      } catch (err) {
        logger.error("onContentReportCreated: could not check the report count.", {reportId, targetId, err});
      }
    }

    // A block files a report so it is on record. It needs no admin push.
    if (reason === "blocked") return;

    const adminEmails = await getAdminEmails();
    if (adminEmails.length === 0) {
      logger.error("onContentReportCreated: no admin emails configured in config/adminNotifications.", {
        reportId,
        contentType,
      });
      return;
    }

    const title = "New content report";
    const body = `${contentType} · ${reason} · doc ${targetId.slice(0, 32)}${targetId.length > 32 ? "…" : ""}`;

    let wallThumbUrl = "";
    if (contentType === "wall" && targetId.length > 0) {
      try {
        const wallSnap = await db.collection("walls").doc(targetId).get();
        const w = wallSnap.data();
        wallThumbUrl = (w?.wallpaper_thumb ?? w?.wallpaper_url ?? "").toString().trim();
      } catch (err) {
        logger.warn("onContentReportCreated: could not load wall for thumbnail.", {err, targetId});
      }
    }

    const isWallReport = contentType === "wall" && targetId.length > 0;
    const notificationData: NotificationData = isWallReport ?
      {
        route: "wall",
        wall_id: targetId,
        report_id: reportId,
        content_type: contentType,
        target_doc_id: targetId,
        reason,
        reporter_uid: reporterUid,
      } :
      {
        route: "content_report",
        report_id: reportId,
        content_type: contentType,
        target_doc_id: targetId,
        reason,
        reporter_uid: reporterUid,
      };

    for (const adminEmail of adminEmails) {
      await sendToUserByEmail({
        title,
        body,
        data: notificationData,
        ...(wallThumbUrl ? {imageUrl: wallThumbUrl} : {}),
        modifier: adminEmail,
        channelId: "moderation",
      }, adminEmail);
    }

    const webhookUrl = process.env.CONTENT_REPORT_WEBHOOK_URL?.trim();
    if (webhookUrl) {
      try {
        const res = await fetch(webhookUrl, {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify({
            text: `[Prism] ${title}: ${body} (reportId=${reportId})`,
            reportId,
            contentType,
            targetId,
            reason,
            reporterUid,
          }),
        });
        if (!res.ok) {
          logger.warn("onContentReportCreated: webhook non-OK", {status: res.status});
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
