import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REENGAGEMENT_STATE_COLLECTION = "reengagementState";
const USERS_COLLECTION = "usersv2";
const REGION = "asia-south1";

/**
 * Tracks re-engagement open/click events written by the Flutter app.
 *
 * The app writes a document to `reengagementEvents/{eventId}` when the user
 * taps a re-engagement push notification or email CTA deep link.
 *
 * Event document schema:
 *   userId:   string    — the user's UID (from FirebaseAuth)
 *   sequence: number    — 1 | 2 | 3
 *   source:   string    — "push" | "email"
 *   action:   string    — "open" | "unsubscribe"
 *
 * On "open":
 *   - Sets seqNOpenedAt on the reengagementState doc
 *   - Clears suppressed flag if this was a seq3 open (user re-engaged)
 *
 * On "unsubscribe":
 *   - Sets suppressed = true on reengagementState doc
 *   - Sets emailOptOut = true and pushSuppressed = true on the user doc
 */
export const onReengagementEventCreated = onDocumentCreated(
  {
    document: "reengagementEvents/{eventId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = _asString(data.userId);
    const sequence = Number(data.sequence ?? 0);
    const action = _asString(data.action);

    if (!userId || !sequence) {
      logger.warn("onReengagementEventCreated: missing userId or sequence.", {eventId: event.params.eventId});
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const stateRef = db.collection(REENGAGEMENT_STATE_COLLECTION).doc(userId);
    const stateUpdate: Record<string, unknown> = {};

    // sequence === 0 is a sentinel from cold-start push taps where the
    // sequence wasn't encoded in the payload.  Infer it from the current state.
    let resolvedSequence = sequence;
    if (action === "open" && resolvedSequence === 0) {
      try {
        const stateSnap = await stateRef.get();
        if (stateSnap.exists) {
          const s = stateSnap.data() as Record<string, unknown>;
          if (s.seq3SentAt && !s.seq3OpenedAt) resolvedSequence = 3;
          else if (s.seq2SentAt && !s.seq2OpenedAt) resolvedSequence = 2;
          else if (s.seq1SentAt && !s.seq1OpenedAt) resolvedSequence = 1;
        }
      } catch (err) {
        logger.warn("onReengagementEventCreated: could not infer sequence from state.", {userId, err});
      }
    }

    if (action === "open") {
      if (resolvedSequence === 1) stateUpdate.seq1OpenedAt = now;
      else if (resolvedSequence === 2) stateUpdate.seq2OpenedAt = now;
      else if (resolvedSequence === 3) {
        stateUpdate.seq3OpenedAt = now;
        // User re-engaged via seq3 — clear suppression so future campaigns can reach them.
        stateUpdate.suppressed = false;
      }

      logger.info("onReengagementEventCreated: open recorded.", {userId, sequence});
    } else if (action === "unsubscribe") {
      stateUpdate.suppressed = true;
      stateUpdate.emailOptOut = true;

      // Mirror suppression onto the user doc so all campaign senders respect it.
      try {
        await db.collection(USERS_COLLECTION).doc(userId).update({
          emailOptOut: true,
          pushSuppressed: true,
        });
      } catch (err) {
        logger.warn("onReengagementEventCreated: could not update user suppression flags.", {userId, err});
      }

      logger.info("onReengagementEventCreated: user suppressed.", {userId});
    } else {
      logger.warn("onReengagementEventCreated: unknown action.", {userId, action});
      return;
    }

    await stateRef.set(stateUpdate, {merge: true});
  },
);

/**
 * Processes email unsubscribe requests submitted via the web unsubscribe page.
 *
 * The web page at prismwalls.com/unsubscribe writes to
 * `emailUnsubscribeRequests/{requestId}` after validating the token.
 *
 * Request doc schema:
 *   userId: string — the UID extracted from the unsubscribe token
 */
export const onEmailUnsubscribeRequested = onDocumentCreated(
  {
    document: "emailUnsubscribeRequests/{requestId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = _asString(data.userId);
    if (!userId) {
      logger.warn("onEmailUnsubscribeRequested: missing userId.", {requestId: event.params.requestId});
      return;
    }

    try {
      const batch = db.batch();
      batch.update(db.collection(USERS_COLLECTION).doc(userId), {emailOptOut: true});
      batch.set(
        db.collection(REENGAGEMENT_STATE_COLLECTION).doc(userId),
        {suppressed: true, emailOptOut: true},
        {merge: true},
      );
      await batch.commit();
      logger.info("onEmailUnsubscribeRequested: unsubscribed.", {userId});
    } catch (err) {
      logger.error("onEmailUnsubscribeRequested: failed.", {userId, err});
    }
  },
);

function _asString(value: unknown): string {
  return value == null ? "" : String(value).trim();
}
