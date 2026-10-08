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

/**
 * Notifies configured admins when a new UGC report is filed.
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
