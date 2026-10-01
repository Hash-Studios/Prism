import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {findUserByEmail} from "./common";

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
  fcmTarget?: { topic: string } | { token: string } | { condition: string };
  /** If true, only send FCM push; do not write an in-app notification doc.
   *  Use for e.g. follower broadcasts where one doc per recipient would not scale. */
  pushOnly?: boolean;
  /** Pushes with the same key replace each other on the device, so one event
   *  sent to both the uid topic and the legacy email topic shows once. */
  collapseKey?: string;
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

  if (!payload.pushOnly) {
    try {
      await db.collection("notifications").add({
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          route: payload.data.route,
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
        // onNotificationCreated pushes entries without this flag.
        pushHandled: true,
        createdAt: admin.firestore.Timestamp.now(),
      });
    } catch (err) {
      logger.error("Failed to write notification doc to Firestore.", {err, payload});
      // Do not throw: still attempt the FCM push.
    }
  }

  if (!payload.fcmTarget) {
    return;
  }

  const message = fcmMessage({...payload, fcmTarget: payload.fcmTarget});

  try {
    if ("topic" in payload.fcmTarget && payload.modifier.includes("@")) {
      const personalEmailTopic = payload.fcmTarget.topic === emailToTopic(payload.modifier);
      if (!payload.pushOnly || personalEmailTopic) {
        const user = await findUserByEmail(payload.modifier);
        if (isLoggedOut(user?.data())) return;
      }
    }

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

/** Builds the FCM message for a payload that has a delivery target. */
export function fcmMessage(
  payload: NotificationPayload & {fcmTarget: NonNullable<NotificationPayload["fcmTarget"]>},
): admin.messaging.Message {
  return {
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
        ...(payload.collapseKey ? {tag: payload.collapseKey} : {}),
      },
      priority: "high",
    },
    apns: {
      ...(payload.collapseKey ? {headers: {"apns-collapse-id": payload.collapseKey}} : {}),
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    ...payload.fcmTarget,
  };
}

/**
 * Sends to the user's uid topic (with an in-app doc), then to the legacy email
 * topic as push only. The shared collapseKey shows the push once on a device
 * subscribed to both. Without a uid topic, sends only to the email topic.
 */
export async function sendToUidAndEmailTopics(
  payload: Omit<NotificationPayload, "fcmTarget" | "pushOnly">,
  uidTopic: string | undefined,
  emailTopic: string,
): Promise<void> {
  await sendNotification({...payload, fcmTarget: {topic: uidTopic ?? emailTopic}});
  if (uidTopic) {
    await sendNotification({...payload, fcmTarget: {topic: emailTopic}, pushOnly: true});
  }
}

export function isLoggedOut(user: {loggedIn?: unknown} | undefined): boolean {
  return user?.loggedIn === false;
}

const INVALID_TOPIC_CHARS = /[^a-zA-Z0-9\-_.~%]/g;

/**
 * Extracts the FCM-safe topic name from an email address.
 * FCM topics must match [a-zA-Z0-9-_.~%]+. Unsafe chars are stripped, not
 * replaced, to match what the app subscribes to (followersTopicFromEmail).
 */
export function emailToTopic(email: string): string {
  return email.split("@")[0].replace(INVALID_TOPIC_CHARS, "");
}

export function userIdToTopic(uid: string): string {
  return `u_${uid.replace(INVALID_TOPIC_CHARS, "")}`;
}
