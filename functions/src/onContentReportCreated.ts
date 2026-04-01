import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {emailToTopic, sendNotification} from "./notificationHelper";

if (!admin.apps.length) {
  admin.initializeApp();
}

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
    region: "asia-south1",
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
      logger.warn("onContentReportCreated: no admin emails configured in config/adminNotifications.");
      return;
    }

    const title = "New content report";
    const body = `${contentType} · ${reason} · doc ${targetId.slice(0, 32)}${targetId.length > 32 ? "…" : ""}`;

    for (const adminEmail of adminEmails) {
      const adminTopic = emailToTopic(adminEmail);
      await sendNotification({
        title,
        body,
        data: {
          route: "content_report",
          pageName: "",
          url: "",
          report_id: reportId,
          content_type: contentType,
          target_doc_id: targetId,
          reason,
          reporter_uid: reporterUid,
        },
        modifier: adminEmail,
        channelId: "moderation",
        fcmTarget: {topic: adminTopic},
      });
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
