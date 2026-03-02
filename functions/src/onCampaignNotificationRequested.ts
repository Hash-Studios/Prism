import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { sendNotification, emailToTopic } from "./notificationHelper";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Triggered when an admin writes a document to the `notificationRequests`
 * collection.  This is the campaign / broadcast notification system.
 *
 * A request document should have:
 *   title:      string   — notification headline
 *   body:       string   — notification body text
 *   modifier:   string   — audience: "all" | "premium" | "free" | userEmail
 *   route:      string   — client-side route: "announcement" | "wall_of_the_day" | "wall" | "follower"
 *   imageUrl?:  string   — optional thumbnail image URL
 *   channelId?: string   — Android channel (default: "recommendations")
 *
 * To trigger from the Flutter admin app, write to `notificationRequests`:
 *
 *   firestoreClient.addDoc('notificationRequests', {
 *     'title': 'Hello World',
 *     'body': 'New update available!',
 *     'modifier': 'all',
 *     'route': 'announcement',
 *   })
 *
 * FCM topic mapping (all users subscribe to these in home_screen.dart):
 *   modifier = "all"       → topic: "recommendations"  (all users are subscribed)
 *   modifier = "premium"   → topic: "premium"
 *   modifier = "free"      → topic: "free"
 *   modifier = {email}     → topic: emailToTopic(email)  (user's own topic)
 */
export const onCampaignNotificationRequested = onDocumentCreated(
  {
    document: "notificationRequests/{requestId}",
    region: "asia-south1",
  },
  async (event) => {
    const requestId = event.params.requestId;
    const data = event.data?.data();

    if (!data) {
      logger.warn("onCampaignNotificationRequested: empty document, skipping.", { requestId });
      return;
    }

    const title: string = (data.title ?? "").toString().trim();
    const body: string = (data.body ?? "").toString().trim();
    const modifier: string = (data.modifier ?? "all").toString().trim();
    const route: string = (data.route ?? "announcement").toString().trim();
    const imageUrl: string = (data.imageUrl ?? "").toString().trim();
    const channelId: string = (data.channelId ?? "recommendations").toString().trim();

    if (!title || !body) {
      await _markProcessed(requestId, { error: "title and body are required" });
      return;
    }

    // Determine the FCM topic from the modifier value.
    let fcmTopic: string;
    if (modifier === "all") {
      // All users subscribe to the "recommendations" topic on first app open.
      fcmTopic = "recommendations";
    } else if (modifier === "premium" || modifier === "free") {
      fcmTopic = modifier;
    } else {
      // Treat as a user email — send to their own email-prefix topic.
      fcmTopic = emailToTopic(modifier);
    }

    await sendNotification({
      title,
      body,
      data: {
        route,
        pageName: "",
        url: "",
      },
      imageUrl: imageUrl || undefined,
      modifier,
      channelId,
      fcmTarget: { topic: fcmTopic },
    });

    await _markProcessed(requestId, { fcmTopic });

    logger.info("onCampaignNotificationRequested: notification sent.", {
      requestId,
      modifier,
      fcmTopic,
      route,
    });
  },
);

async function _markProcessed(
  requestId: string,
  meta: Record<string, unknown>,
): Promise<void> {
  try {
    await db.collection("notificationRequests").doc(requestId).update({
      processed: true,
      processedAt: admin.firestore.Timestamp.now(),
      ...meta,
    });
  } catch (err) {
    logger.warn("onCampaignNotificationRequested: failed to mark request processed.", { requestId, err });
  }
}
