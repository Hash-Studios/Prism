import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {emailToTopic, sendNotification, sendToUserByEmail} from "./notificationHelper";
import {db, REGION, str} from "./common";

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
 *   modifier = {email}     → the user's uid topic and FCM token
 */
export const onCampaignNotificationRequested = onDocumentCreated(
  {
    document: "notificationRequests/{requestId}",
    region: REGION,
  },
  async (event) => {
    const requestId = event.params.requestId;
    const data = event.data?.data();

    if (!data) {
      logger.warn("onCampaignNotificationRequested: empty document, skipping.", {requestId});
      return;
    }

    const title = str(data.title);
    const body = str(data.body);
    const modifier = str(data.modifier ?? "all");
    const route = str(data.route ?? "announcement");
    const imageUrl = str(data.imageUrl);
    const channelId = str(data.channelId ?? "recommendations");

    if (!title || !body) {
      await markProcessed(requestId, {error: "title and body are required"});
      return;
    }

    if (modifier.includes("@")) {
      await sendToUserByEmail(
        {title, body, data: {route}, imageUrl: imageUrl || undefined, modifier, channelId},
        modifier,
      );
      await markProcessed(requestId, {fcmTopic: "user"});
      logger.info("onCampaignNotificationRequested: personal notification sent.", {requestId, modifier, route});
      return;
    }

    let fcmTopic: string;
    if (modifier === "all") {
      // All users subscribe to the "recommendations" topic on first app open.
      fcmTopic = "recommendations";
    } else if (modifier === "premium" || modifier === "free") {
      fcmTopic = modifier;
    } else {
      fcmTopic = emailToTopic(modifier);
    }

    await sendNotification({
      title,
      body,
      data: {route},
      imageUrl: imageUrl || undefined,
      modifier,
      channelId,
      fcmTarget: {topic: fcmTopic},
    });

    await markProcessed(requestId, {fcmTopic});

    logger.info("onCampaignNotificationRequested: notification sent.", {
      requestId,
      modifier,
      fcmTopic,
      route,
    });
  },
);

async function markProcessed(
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
    logger.warn("onCampaignNotificationRequested: failed to mark request processed.", {requestId, err});
  }
}
