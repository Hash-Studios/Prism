import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db as database, findUserByEmail} from "./common";
import {recordPushOutcome, scoreKindFor} from "./notificationScoreboard";
import {
  isNativeLocalizationTopic,
  nativeLocalizationTopic,
  nativeNotificationLocalization,
  type RenderedNotificationCopy,
} from "./notificationCatalog";

export interface NotificationData extends Record<string, string> {
  route: string;
}

export interface NotificationPayload {
  title: string;
  body: string;
  message?: RenderedNotificationCopy;
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
  /** Pushes with the same key replace each other on the device during retry or duplicate delivery. */
  collapseKey?: string;
  /** Fixed inbox doc id, so a retried or repeated event rewrites one doc instead of adding another. */
  docId?: string;
  /** Scoreboard kind. When omitted, the route is used. Unknown routes are not counted. */
  scoreKind?: string;
  /** Sends localized resource keys without common English strings for capable native clients. */
  nativeLocalization?: boolean;
}

/**
 * Core notification helper — used by every Cloud Function that needs to
 * send a notification. It attempts two independent operations:
 *   1. Writes a document to the `notifications` Firestore collection so the
 *      notification appears in the user's in-app inbox.
 *   2. Sends an FCM push via the Admin SDK (unless fcmTarget is omitted).
 *
 * The Firestore document schema matches what InAppNotif.fromSnapshot()
 * expects in the Flutter client.
 */
export async function sendNotification(
  payload: NotificationPayload,
): Promise<boolean> {
  const db = admin.firestore();

  if (!payload.pushOnly) {
    try {
      const inbox = db.collection("notifications");
      const doc = {
        notification: {
          title: payload.title,
          body: payload.body,
        },
        ...(payload.message ?
          {
            message: {
              kind: payload.message.kind,
              args: payload.message.args,
            },
          } :
          {}),
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
      logger.error("Failed to write notification doc to Firestore.", {
        err,
        route: payload.data.route,
      });
      // Do not throw: still attempt the FCM push.
    }
  }

  if (!payload.fcmTarget) {
    return true;
  }

  if (
    "topic" in payload.fcmTarget &&
    !isNativeLocalizationTopic(payload.fcmTarget.topic)
  ) {
    const legacy = sendPush(payload, payload.fcmTarget);
    const localized = sendPush(
      {...payload, nativeLocalization: true},
      {topic: nativeLocalizationTopic(payload.fcmTarget.topic)},
    );
    const results = await Promise.all([legacy, localized]);
    return results.some(Boolean);
  }
  return sendPush(payload, payload.fcmTarget);
}

async function sendPush(
  payload: NotificationPayload,
  fcmTarget: NonNullable<NotificationPayload["fcmTarget"]>,
): Promise<boolean> {
  const messaging = admin.messaging();
  if ("topic" in fcmTarget && fcmTarget.topic.startsWith("u_")) {
    logger.warn("Refusing to send a personal notification to a UID topic.", {
      route: payload.data.route,
    });
    return false;
  }
  if (
    "condition" in fcmTarget &&
    (payload.modifier.includes("@") || /['"]u_[^'"]*['"]\s+in\s+topics/.test(fcmTarget.condition))
  ) {
    logger.warn("Refusing a personal or UID-topic condition target.", {
      route: payload.data.route,
    });
    return false;
  }
  if ("topic" in fcmTarget && payload.modifier.includes("@")) {
    const legacyTopic = isNativeLocalizationTopic(fcmTarget.topic) ?
      fcmTarget.topic.slice(0, -"_loc_v1".length) :
      fcmTarget.topic;
    const isFollowerTopic = legacyTopic.endsWith("_posts") || legacyTopic.startsWith("posts_");
    if (legacyTopic === emailToTopic(payload.modifier) || !isFollowerTopic) {
      logger.warn(
        "Refusing to push a personal notification to an audience topic.",
        {route: payload.data.route},
      );
      return true;
    }
    if (!payload.pushOnly) {
      try {
        const user = await findUserByEmail(payload.modifier);
        if (isLoggedOut(user?.data())) return true;
      } catch (err) {
        logger.error("Failed to resolve the personal notification recipient.", {
          err,
          route: payload.data.route,
        });
        return false;
      }
    }
  }

  const message = fcmMessage({...payload, fcmTarget});
  const kind = scoreKindFor(payload);
  try {
    if (kind) await recordPushOutcome(kind, "sends");
    const messageId = await messaging.send(message);
    if (kind) await recordPushOutcome(kind, "accepts");
    logger.info("FCM push sent.", {
      messageId,
      route: payload.data.route,
      kind,
      targetType: "token" in fcmTarget ? "token" : "topic" in fcmTarget ? "topic" : "condition",
    });
    return true;
  } catch (err) {
    if (kind) await recordPushOutcome(kind, "fails");
    logger.error("Failed to send FCM push.", {err, route: payload.data.route, kind});
    return false;
  }
}

/** Builds the FCM message for a payload that has a delivery target. */
export function fcmMessage(
  payload: NotificationPayload & {
    fcmTarget: NonNullable<NotificationPayload["fcmTarget"]>;
  },
): admin.messaging.Message {
  const kind = scoreKindFor(payload);
  const nativeCopy = payload.message ?
    nativeNotificationLocalization(payload.message) :
    null;
  const targetIsLocalized =
    "topic" in payload.fcmTarget &&
    isNativeLocalizationTopic(payload.fcmTarget.topic);
  const nativeLocalization =
    Boolean(payload.nativeLocalization || targetIsLocalized) && Boolean(nativeCopy);
  return {
    ...(nativeLocalization ?
      {} :
      {notification: {title: payload.title, body: payload.body}}),
    data: {
      ...payload.data,
      ...(payload.message ?
        {
          notification_kind: payload.data.notification_kind ?? "generic",
          notification_copy_kind: payload.message.kind,
          notification_args: JSON.stringify(payload.message.args),
        } :
        {}),
      ...(kind ? {push_kind: kind} : {}),
      channel_id: payload.channelId,
      ...(payload.imageUrl ? {imageUrl: payload.imageUrl} : {}),
    },
    android: {
      notification: {
        channelId: payload.channelId,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        ...(payload.imageUrl ? {imageUrl: payload.imageUrl} : {}),
        ...(payload.collapseKey ? {tag: payload.collapseKey} : {}),
        ...(nativeLocalization && nativeCopy ?
          {
            titleLocKey: nativeCopy.titleKey,
            ...(nativeCopy.titleArgs.length > 0 ?
              {titleLocArgs: nativeCopy.titleArgs} :
              {}),
            bodyLocKey: nativeCopy.bodyKey,
            ...(nativeCopy.bodyArgs.length > 0 ?
              {bodyLocArgs: nativeCopy.bodyArgs} :
              {}),
          } :
          {}),
      },
      priority: "high",
    },
    apns: {
      ...(payload.collapseKey ?
        {headers: {"apns-collapse-id": payload.collapseKey}} :
        {}),
      payload: {
        aps: {
          sound: "default",
          ...(nativeLocalization && nativeCopy ?
            {
              alert: {
                titleLocKey: nativeCopy.titleKey,
                ...(nativeCopy.titleArgs.length > 0 ?
                  {titleLocArgs: nativeCopy.titleArgs} :
                  {}),
                locKey: nativeCopy.bodyKey,
                ...(nativeCopy.bodyArgs.length > 0 ?
                  {locArgs: nativeCopy.bodyArgs} :
                  {}),
              },
            } :
            {}),
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
  /** Deprecated legacy token input. Kept for caller compatibility; never used for delivery. */
  legacyToken?: unknown;
}

export interface UserPushToken {
  token: string;
  nativeLocalization: boolean;
}

export const FCM_TOKEN_BINDING_VERSION = 1;

/** Reads only string tokens from private/session. */
export function pickFcmToken(
  sessionToken: unknown,
  legacyToken: unknown,
): string {
  void legacyToken;
  return typeof sessionToken === "string" ? sessionToken.trim() : "";
}

export async function userPushTokens(
  uid: string,
  legacyToken: unknown,
): Promise<UserPushToken[]> {
  let session: Record<string, unknown> | undefined;
  try {
    session = (
      await database.doc(`usersv2/${uid}/private/session`).get()
    ).data();
  } catch (err) {
    logger.warn("Could not read the session FCM token.", {uid, err});
  }
  const sessionToken = pickFcmToken(session?.fcmToken, legacyToken);
  if (sessionToken) {
    if (
      session?.fcmTokenBindingVersion !== FCM_TOKEN_BINDING_VERSION ||
      session?.fcmTokenBindingToken !== sessionToken
    ) return [];
    return [
      {
        token: sessionToken,
        nativeLocalization:
          session?.notificationLocalizationVersion === 1 &&
          session?.notificationLocalizationToken === sessionToken,
      },
    ];
  }
  return [];
}

async function userCanReceivePersonalPush(uid: string): Promise<boolean> {
  try {
    const user = (await database.doc(`usersv2/${uid}`).get()).data();
    return Boolean(user) && user?.loggedIn !== false;
  } catch (err) {
    logger.warn("Could not confirm the personal push recipient account.", {uid, err});
    return false;
  }
}

/** Same key on every push of one event, so a retry replaces the existing device notification. */
function personalCollapseKey(payload: PersonalPayload): string {
  const hash = createHash("sha1")
    .update(JSON.stringify([payload.title, payload.body, payload.data]))
    .digest("hex")
    .slice(0, 16);
  return `p_${hash}`;
}

/**
 * Writes the in-app doc (unless pushOnly), then pushes only to the user's private session FCM token. The email-prefix
 * topic is shared by every address with the same prefix, so personal payloads never go there. Returns false when a
 * push failed; an account without a private session token keeps its inbox entry and receives no push.
 */
export async function sendToUser(
  payload: PersonalPayload,
  recipient: PushRecipient,
  pushEnabled = true,
): Promise<boolean> {
  const inboxPayload = {...payload, fcmTarget: undefined};
  await sendNotification(inboxPayload);
  if (!pushEnabled || recipient.loggedOut) return true;

  let pushPayload: PersonalPayload = inboxPayload;
  if (scoreKindFor(payload) === "moderation") {
    const reportId = typeof payload.data.report_id === "string" ? payload.data.report_id : "";
    pushPayload = {
      ...inboxPayload,
      title: reportId ? "Content report needs review" : "Moderation update",
      body: reportId ? "A content report is waiting for review." : "Open Prism to review.",
      message: undefined,
      imageUrl: undefined,
      data: {route: "content_report", ...(reportId ? {report_id: reportId} : {})},
      nativeLocalization: false,
    };
  }

  if (!recipient.uid) {
    logger.warn("No uid for the recipient, skipping the personal push.", {
      route: payload.data.route,
    });
    return true;
  }
  if (!(await userCanReceivePersonalPush(recipient.uid))) return true;
  const collapseKey = payload.collapseKey ?? personalCollapseKey(payload);
  const targets: Array<{
    fcmTarget: NonNullable<NotificationPayload["fcmTarget"]>;
    nativeLocalization?: boolean;
  }> = [
    ...(await userPushTokens(recipient.uid, recipient.legacyToken)).map(
      ({token, nativeLocalization}) => ({
        fcmTarget: {token},
        nativeLocalization,
      }),
    ),
  ];
  const results = await Promise.all(
    targets.map(({fcmTarget, nativeLocalization}) =>
      sendNotification({
        ...pushPayload,
        collapseKey,
        fcmTarget,
        nativeLocalization,
        pushOnly: true,
      }),
    ),
  );
  if (targets.length === 0) return true;
  return results.some(Boolean);
}

/** Like sendToUser, for a recipient known only by email (admins, campaign and inbox audiences). */
export async function sendToUserByEmail(
  payload: PersonalPayload,
  email: string,
  pushEnabled = true,
): Promise<boolean> {
  let user: admin.firestore.QueryDocumentSnapshot | null = null;
  try {
    user = await findUserByEmail(email);
  } catch (err) {
    logger.warn(
      "Could not resolve the recipient; skipping the personal push.",
      {emailHash: emailHash(email), err},
    );
  }
  const data = user?.data();
  return sendToUser(
    payload,
    {
      uid: user?.id,
      email,
      loggedOut: isLoggedOut(data),
      legacyToken: data?.fcmToken,
    },
    pushEnabled,
  );
}

export function isLoggedOut(user: { loggedIn?: unknown } | undefined): boolean {
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

/** Topic of the followers of one creator. Unlike the email prefix topic it cannot collide across creators. */
export function postsTopic(uid: string): string {
  return `posts_${uid.replace(INVALID_TOPIC_CHARS, "")}`;
}

/** Short stable id of an email for logs, so a log line never holds the address. */
export function emailHash(email: string): string {
  return createHash("sha1")
    .update(email.trim().toLowerCase())
    .digest("hex")
    .slice(0, 16);
}
