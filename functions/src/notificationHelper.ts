import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

export interface NotificationData extends Record<string, string> {
  route: string;
}

export interface NotificationPayload {
  title: string;
  body: string;
  data: NotificationData;
  imageUrl?: string;
  /** Determines which users see this notification in their in-app inbox.
   *  Values: "all" | "premium" | "free" | appVersion | userEmail */
  modifier: string;
  channelId: string;
  /** FCM delivery target. Omit for in-app-only (no push). */
  fcmTarget?: { topic: string } | { token: string };
  /** If true, only send FCM push; do not write an in-app notification doc.
   *  Use for e.g. follower broadcasts where one doc per recipient would not scale. */
  pushOnly?: boolean;
}

/**
 * Core notification helper — used by every Cloud Function that needs to
 * send a notification.  It does two things atomically:
 *   1. Writes a document to the `notifications` Firestore collection so the
 *      notification appears in the user's in-app inbox.
 *   2. Sends an FCM push via the Admin SDK (unless fcmTarget is omitted).
 *
 * The Firestore document schema matches what InAppNotif.fromSnapshot()
 * expects in the Flutter client.
 */
export async function sendNotification(payload: NotificationPayload): Promise<void> {
  const db = admin.firestore();
  const messaging = admin.messaging();

  // ------------------------------------------------------------------ //
  // 1. Write the in-app notification doc (unless pushOnly)
  // ------------------------------------------------------------------ //
  if (!payload.pushOnly) {
    try {
      await db.collection("notifications").add({
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          route: payload.data.route ?? "",
          imageUrl: payload.imageUrl ?? "",
          url: payload.data.url ?? "",
          pageName: payload.data.pageName ?? "",
          arguments: [],
          // Forward any extra fields (e.g. wall_id, follower_email)
          ...Object.fromEntries(
            Object.entries(payload.data).filter(
              ([k]) => !["route", "url", "pageName"].includes(k),
            ),
          ),
        },
        modifier: payload.modifier,
        createdAt: admin.firestore.Timestamp.now(),
      });
    } catch (err) {
      logger.error("Failed to write notification doc to Firestore.", {err, payload});
    // Do not throw — attempt FCM push even if Firestore write fails.
    }
  }

  // ------------------------------------------------------------------ //
  // 2. Send FCM push (if a target was provided)
  // ------------------------------------------------------------------ //
  if (!payload.fcmTarget) {
    return;
  }

  const message: admin.messaging.Message = {
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      ...payload.data,
      channel_id: payload.channelId,
      ...(payload.imageUrl ? {imageUrl: payload.imageUrl} : {}),
    },
    android: {
      notification: {
        channelId: payload.channelId,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        ...(payload.imageUrl ? {imageUrl: payload.imageUrl} : {}),
      },
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    ...("topic" in payload.fcmTarget ?
      {topic: payload.fcmTarget.topic} :
      {token: payload.fcmTarget.token}),
  };

  try {
    const messageId = await messaging.send(message);
    logger.info("FCM push sent.", {
      messageId,
      route: payload.data.route,
      target: payload.fcmTarget,
    });
  } catch (err) {
    logger.error("Failed to send FCM push.", {err, route: payload.data.route});
  }
}

/**
 * Extracts the FCM-safe topic name from an email address.
 * FCM topics must match [a-zA-Z0-9-_.~%]+
 * We use the portion before "@" and replace unsafe chars with "_".
 */
export function emailToTopic(email: string): string {
  return email.split("@")[0].replace(/[^a-zA-Z0-9\-_.~%]/g, "_");
}
