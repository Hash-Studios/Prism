import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {REGION, str} from "./common";
import {emailToTopic, sendNotification} from "./notificationHelper";

/** Topic the audience of an inbox entry subscribes to, or undefined when none does. */
export function topicForModifier(modifier: string): string | undefined {
  if (modifier === "all") return "recommendations";
  if (modifier === "premium" || modifier === "free") return modifier;
  if (modifier.includes("@")) return emailToTopic(modifier) || undefined;
  // ponytail: app-version audiences have no topic. Add v_<version> topics if campaigns start using them.
  return undefined;
}

/**
 * Pushes inbox entries that admins write straight to `notifications` (for
 * example wall rejections), so every in-app notification also arrives as a
 * push. sendNotification marks its own entries pushHandled, so they are skipped.
 */
export const onNotificationCreated = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    const doc = event.data?.data();
    if (!doc || doc.pushHandled === true) return;
    const modifier = str(doc.modifier);
    const topic = topicForModifier(modifier);
    const title = str(doc.notification?.title);
    const body = str(doc.notification?.body);
    if (!topic || !title || !body) return;

    const data: Record<string, string> = {};
    for (const [key, value] of Object.entries(doc.data ?? {})) {
      if (typeof value === "string" && value) data[key] = value;
    }
    await sendNotification({
      title,
      body,
      data: {...data, route: data.route ?? "announcement"},
      imageUrl: data.imageUrl,
      modifier,
      channelId: "posts",
      fcmTarget: {topic},
      pushOnly: true,
    });
  },
);
