import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {getAdminEmails} from "./adminConfig";
import {sendToUserByEmail} from "./notificationHelper";
import {notificationCopyPayload} from "./notificationCatalog";
import {db, REGION} from "./common";

const ESCALATE_AFTER_MS = 12 * 60 * 60 * 1000;
const MAX_REPORTS_PER_RUN = 200;

/** A report that is still open after 12 hours and has not been escalated yet. */
export function isDueForEscalation(
  report: admin.firestore.DocumentData,
  nowMs: number,
): boolean {
  const createdAt = report.createdAt;
  return (
    report.status === "open" &&
    report.escalatedAt == null &&
    createdAt instanceof admin.firestore.Timestamp &&
    nowMs - createdAt.toMillis() >= ESCALATE_AFTER_MS
  );
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
    const nowMs = Date.now();
    const query = db
      .collection("contentReports")
      .where("status", "==", "open")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(MAX_REPORTS_PER_RUN);
    const due: admin.firestore.QueryDocumentSnapshot[] = [];
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    while (due.length < MAX_REPORTS_PER_RUN) {
      const page = await (cursor ? query.startAfter(cursor) : query).get();
      for (const doc of page.docs) {
        if (isDueForEscalation(doc.data(), nowMs)) due.push(doc);
        if (due.length === MAX_REPORTS_PER_RUN) break;
      }
      if (page.size < MAX_REPORTS_PER_RUN) break;
      cursor = page.docs[page.docs.length - 1];
    }
    if (due.length === 0) return;

    const adminEmails = await getAdminEmails();
    if (adminEmails.length === 0) {
      logger.error(
        "sweepOpenReports: no admin emails configured in config/adminNotifications.",
        {due: due.length},
      );
      return;
    }
    for (const report of due) {
      const data = report.data();
      const isWall =
        data.contentType === "wall" &&
        typeof data.targetFirestoreDocId === "string";
      for (const adminEmail of adminEmails) {
        await sendToUserByEmail(
          {
            ...notificationCopyPayload({
              kind: "reportNeedsReview",
              contentType:
                typeof data.contentType === "string" ?
                  data.contentType :
                  "content",
              reason: typeof data.reason === "string" ? data.reason : "",
            }),
            data: isWall ?
              {
                route: "wall",
                wall_id: data.targetFirestoreDocId,
                report_id: report.id,
              } :
              {route: "content_report", report_id: report.id},
            modifier: adminEmail,
            channelId: "moderation",
            scoreKind: "moderation",
          },
          adminEmail,
        );
      }
      await report.ref.update({
        escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    logger.info("sweepOpenReports: escalated.", {count: due.length});
  },
);
