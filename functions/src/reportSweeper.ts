import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {sendToUserByEmail} from "./notificationHelper";
import {db, REGION} from "./common";

const ESCALATE_AFTER_MS = 12 * 60 * 60 * 1000;
const MAX_REPORTS_PER_RUN = 200;

/** A report that is still open after 12 hours and has not been escalated yet. */
export function isDueForEscalation(report: admin.firestore.DocumentData, nowMs: number): boolean {
  const createdAt = report.createdAt;
  return report.status === "open" && report.escalatedAt == null && createdAt instanceof admin.firestore.Timestamp &&
    nowMs - createdAt.toMillis() >= ESCALATE_AFTER_MS;
}

/**
 * Every 2 hours: pings the admins once more for each report that is still open after 12 hours, so the 24 hour
 * review promise in the terms holds. The `escalatedAt` field on the report makes the ping happen once.
 */
export const sweepOpenReports = onSchedule(
  {
    schedule: "0 */2 * * *",
    timeZone: "UTC",
    region: REGION,
    retryCount: 1,
  },
  async () => {
    const open = await db.collection("contentReports").where("status", "==", "open").limit(MAX_REPORTS_PER_RUN).get();
    const nowMs = Date.now();
    const due = open.docs.filter((doc) => isDueForEscalation(doc.data(), nowMs));
    if (due.length === 0) return;

    const adminEmails = await getAdminEmails();
    if (adminEmails.length === 0) {
      logger.error("sweepOpenReports: no admin emails configured in config/adminNotifications.", {due: due.length});
      return;
    }
    for (const report of due) {
      const data = report.data();
      const isWall = data.contentType === "wall" && typeof data.targetFirestoreDocId === "string";
      for (const adminEmail of adminEmails) {
        await sendToUserByEmail({
          title: "Report waiting for review",
          body: `${data.contentType ?? "content"} · ${data.reason ?? ""} · open for over 12 hours`,
          data: isWall ?
            {route: "wall", wall_id: data.targetFirestoreDocId, report_id: report.id} :
            {route: "content_report", report_id: report.id},
          modifier: adminEmail,
          channelId: "moderation",
        }, adminEmail);
      }
      await report.ref.update({escalatedAt: admin.firestore.FieldValue.serverTimestamp()});
    }
    logger.info("sweepOpenReports: escalated.", {count: due.length});
  },
);
