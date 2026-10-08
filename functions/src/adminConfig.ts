import {logger} from "firebase-functions/v2";
import {db} from "./common";

/**
 * Admin recipient emails from `config/adminNotifications` (field `emails: string[]`).
 */
export async function getAdminEmails(): Promise<string[]> {
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

/** The part of a callable's `auth` that decides admin rights. */
export interface AdminCaller {
  token?: {admin?: unknown; email?: unknown; email_verified?: unknown};
}

/**
 * One answer to "is this caller an admin" for every callable. True for the `admin` claim, for a verified email with
 * a doc in `admin_users` (what the Firestore rules use), or for an email in `config/adminNotifications`.
 */
export async function isAdminCaller(auth: AdminCaller | undefined): Promise<boolean> {
  const token = auth?.token;
  if (token?.admin === true) return true;
  const email = typeof token?.email === "string" ? token.email.trim() : "";
  if (email === "") return false;
  if (token?.email_verified === true) {
    try {
      if ((await db.collection("admin_users").doc(email).get()).exists) return true;
    } catch (err) {
      logger.error("isAdminCaller: failed to read admin_users.", {err});
    }
  }
  const lower = email.toLowerCase();
  return (await getAdminEmails()).some((e) => e.toLowerCase() === lower);
}
