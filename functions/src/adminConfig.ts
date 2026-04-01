import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

/**
 * Admin recipient emails from `config/adminNotifications` (field `emails: string[]`).
 */
export async function getAdminEmails(): Promise<string[]> {
  const db = admin.firestore();
  try {
    const snap = await db.collection("config").doc("adminNotifications").get();
    if (!snap.exists) {
      return [];
    }
    const emails = snap.data()?.emails;
    if (!Array.isArray(emails)) {
      return [];
    }
    return emails.map((e) => e.toString().trim()).filter((e) => e.length > 0);
  } catch (err) {
    logger.error("getAdminEmails: failed to fetch admin config.", {err});
    return [];
  }
}
