import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";
import {emailToTopic, sendNotification, sendToUserByEmail} from "./notificationHelper";

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
    const snapshot = event.data;
    const doc = snapshot?.data();
    if (!snapshot || !doc || doc.pushHandled === true) return;
    const modifier = str(doc.modifier);
    const personal = modifier.includes("@");
    const topic = topicForModifier(modifier);
    const title = str(doc.notification?.title);
    const body = str(doc.notification?.body);
    if ((!personal && !topic) || !title || !body) return;

    const data: Record<string, string> = {};
    for (const [key, value] of Object.entries(doc.data ?? {})) {
      if (typeof value === "string" && value) data[key] = value;
    }
    // ponytail: one attempt, like sendNotification; a crash after claiming can lose
    // the push. Guaranteed delivery would need durable delivery tracking.
    const claimed = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(snapshot.ref);
      if (!current.exists || current.data()?.pushHandled === true) return false;
      transaction.update(snapshot.ref, {pushHandled: true});
      return true;
    });
    if (!claimed) return;

    const payload = {
      title,
      body,
      data: {...data, route: data.route ?? "announcement"},
      imageUrl: data.imageUrl,
      modifier,
      channelId: "posts",
      pushOnly: true,
    };
    if (personal) {
      await sendToUserByEmail(payload, modifier);
    } else if (topic) {
      await sendNotification({...payload, fcmTarget: {topic}});
    }
  },
);
