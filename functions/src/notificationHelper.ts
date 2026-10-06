import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db as database, findUserByEmail, str} from "./common";

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
  /** Fixed inbox doc id, so a retried or repeated event rewrites one doc instead of adding another. */
  docId?: string;
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
export async function sendNotification(payload: NotificationPayload): Promise<boolean> {
  const db = admin.firestore();
  const messaging = admin.messaging();

  if (!payload.pushOnly) {
    try {
      const inbox = db.collection("notifications");
      const doc = {
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
      };
      if (payload.docId) {
        await inbox.doc(payload.docId).set(doc);
      } else {
        await inbox.add(doc);
      }
    } catch (err) {
      logger.error("Failed to write notification doc to Firestore.", {err, payload});
      // Do not throw: still attempt the FCM push.
    }
  }

  if (!payload.fcmTarget) {
    return true;
  }

  const message = fcmMessage({...payload, fcmTarget: payload.fcmTarget});

  try {
    if ("topic" in payload.fcmTarget && payload.modifier.includes("@")) {
      const personalEmailTopic = payload.fcmTarget.topic === emailToTopic(payload.modifier);
      if (!payload.pushOnly || personalEmailTopic) {
        const user = await findUserByEmail(payload.modifier);
        if (isLoggedOut(user?.data())) return true;
      }
    }

    const messageId = await messaging.send(message);
    logger.info("FCM push sent.", {
      messageId,
      route: payload.data.route,
      target: payload.fcmTarget,
    });
    return true;
  } catch (err) {
    logger.error("Failed to send FCM push.", {err, route: payload.data.route});
    return false;
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
        },
      },
    },
    ...payload.fcmTarget,
  };
}

export type PersonalPayload = Omit<NotificationPayload, "fcmTarget">;

export interface PushRecipient {
  uid?: string;
  email: string;
  loggedOut?: boolean;
  /** `usersv2.fcmToken`, which builds before the private session doc wrote. */
  legacyToken?: unknown;
}

/** The app stores the token in private/session; older builds wrote usersv2.fcmToken. */
export function pickFcmToken(sessionToken: unknown, legacyToken: unknown): string {
  return str(sessionToken) || str(legacyToken);
}

export async function userPushTokens(uid: string, legacyToken: unknown): Promise<string[]> {
  let sessionToken: unknown;
  try {
    sessionToken = (await database.doc(`usersv2/${uid}/private/session`).get()).data()?.fcmToken;
  } catch (err) {
    logger.warn("Could not read the session FCM token.", {uid, err});
  }
  const token = pickFcmToken(sessionToken, legacyToken);
  return token ? [token] : [];
}

/** Same key on every push of one event, so a device that gets the topic and the token push shows it once. */
function personalCollapseKey(payload: PersonalPayload): string {
  const hash = createHash("sha1")
    .update(JSON.stringify([payload.title, payload.body, payload.data]))
    .digest("hex")
    .slice(0, 16);
  return `p_${hash}`;
}

/**
 * Writes the in-app doc (unless pushOnly), then pushes to the user's uid topic and FCM token. The email-prefix
 * topic is shared by every address with the same prefix, so it is used only when no user doc matches the email.
 * Returns false when every push failed.
 */
export async function sendToUser(
  payload: PersonalPayload,
  recipient: PushRecipient,
  pushEnabled = true,
): Promise<boolean> {
  await sendNotification(payload);
  if (!pushEnabled || recipient.loggedOut) return true;

  if (!recipient.uid) {
    const emailTopic = emailToTopic(recipient.email);
    return emailTopic ?
      sendNotification({...payload, fcmTarget: {topic: emailTopic}, pushOnly: true}) :
      true;
  }
  const collapseKey = payload.collapseKey ?? personalCollapseKey(payload);
  const targets = [
    {topic: userIdToTopic(recipient.uid)},
    ...(await userPushTokens(recipient.uid, recipient.legacyToken)).map((token) => ({token})),
  ];
  const results = await Promise.all(
    targets.map((fcmTarget) => sendNotification({...payload, collapseKey, fcmTarget, pushOnly: true})),
  );
  return results.some(Boolean);
}

/** Like sendToUser, for a recipient known only by email (admins, campaign and inbox audiences). */
export async function sendToUserByEmail(payload: PersonalPayload, email: string, pushEnabled = true): Promise<boolean> {
  let user: admin.firestore.QueryDocumentSnapshot | null = null;
  try {
    user = await findUserByEmail(email);
  } catch (err) {
    logger.warn("Could not resolve the recipient; using the email topic.", {email, err});
  }
  const data = user?.data();
  return sendToUser(payload, {
    uid: user?.id,
    email,
    loggedOut: isLoggedOut(data),
    legacyToken: data?.fcmToken,
  }, pushEnabled);
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
