import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {sendNotification} from "./notificationHelper";
import {queueReengagementEmail} from "./emailReengagement";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const USERS_COLLECTION = "usersv2";
const REENGAGEMENT_STATE_COLLECTION = "reengagementState";
const COIN_TX_COLLECTION = "coinTransactions";
const REGION = "asia-south1";
const REACTIVATION_COINS = 50;
const PAGE_SIZE = 200;

type Segment = "hot" | "warm" | "cold" | "frozen";

interface SegmentCutoffs {
  hotStart: Date;
  hotEnd: Date;
  warmStart: Date;
  warmEnd: Date;
  coldStart: Date;
  coldEnd: Date;
}

interface UserReengagementState {
  seq1SentAt?: admin.firestore.Timestamp;
  seq1OpenedAt?: admin.firestore.Timestamp;
  seq2SentAt?: admin.firestore.Timestamp;
  seq2OpenedAt?: admin.firestore.Timestamp;
  seq3SentAt?: admin.firestore.Timestamp;
  seq3OpenedAt?: admin.firestore.Timestamp;
  suppressed?: boolean;
  coinsGranted?: boolean;
}

/**
 * Triggered when an admin writes to `reengagementCampaigns/{campaignId}`.
 *
 * Campaign document schema:
 *   sequence:    number    — 1 | 2 | 3
 *   segments:    string[]  — ["hot","warm","cold","frozen"] or any subset
 *   scheduledAt?: Timestamp
 *
 * Segment definitions (by last active date):
 *   hot    → 30–90 days ago  (push + email)
 *   warm   → 90–365 days ago (push + email)
 *   cold   → 1–3 years ago   (email only — push tokens likely stale)
 *   frozen → 3+ years / never returned (email only)
 *
 * Sequence rules:
 *   1 → Launch announcement, sent to everyone in the given segments
 *   2 → Coins reminder, sent only to seq1 non-openers; credits 50 coins first
 *   3 → Final farewell, sent only to seq2 non-openers; marks users suppressed after
 */
export const onReengagementCampaignRequested = onDocumentCreated(
  {
    document: "reengagementCampaigns/{campaignId}",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const campaignId = event.params.campaignId;
    const data = event.data?.data();

    if (!data) {
      logger.warn("onReengagementCampaignRequested: empty document.", {campaignId});
      return;
    }

    const sequence = Number(data.sequence ?? 1);
    const segments: Segment[] = Array.isArray(data.segments)
      ? (data.segments as Segment[])
      : ["hot", "warm", "cold", "frozen"];

    if (sequence < 1 || sequence > 3) {
      await _markCampaignProcessed(campaignId, {error: `Invalid sequence: ${sequence}`});
      return;
    }

    logger.info("onReengagementCampaignRequested: starting.", {campaignId, sequence, segments});

    const segmentCutoffs = _buildSegmentCutoffs();
    let totalProcessed = 0;
    let totalPushSent = 0;
    let totalEmailQueued = 0;
    let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

    while (true) {
      let query = db
        .collection(USERS_COLLECTION)
        .select("email", "fcmToken", "lastLoginAt", "coins", "premium", "emailOptOut", "pushSuppressed")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      lastDoc = snapshot.docs[snapshot.docs.length - 1];

      for (const userDoc of snapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const email = _asString(userData.email).toLowerCase();
        const fcmToken = _asString(userData.fcmToken);
        const emailOptOut = _asBool(userData.emailOptOut, false);
        const pushSuppressed = _asBool(userData.pushSuppressed, false);

        if (!email) continue;

        const lastLoginAt = _asDate(userData.lastLoginAt);
        const userSegment = _classifyUser(lastLoginAt, segmentCutoffs);
        if (!segments.includes(userSegment)) continue;

        // Load per-user campaign state.
        const stateRef = db.collection(REENGAGEMENT_STATE_COLLECTION).doc(userId);
        const stateSnap = await stateRef.get();
        const state: UserReengagementState = stateSnap.exists
          ? (stateSnap.data() as UserReengagementState)
          : {};

        if (state.suppressed) continue;

        // Sequence-specific eligibility.
        if (sequence === 2) {
          if (!state.seq1SentAt || state.seq1OpenedAt) continue;
        } else if (sequence === 3) {
          if (!state.seq2SentAt || state.seq2OpenedAt) continue;
        }

        const now = admin.firestore.Timestamp.now();
        const stateUpdate: Record<string, unknown> = {};

        // Seq 2: credit 50 coins if not already done.
        if (sequence === 2 && !state.coinsGranted) {
          await _creditReactivationCoins(userId, _asInt(userData.coins, 0), now);
          stateUpdate.coinsGranted = true;
        }

        // Push — only for hot/warm segments where tokens are likely valid.
        if (fcmToken && !pushSuppressed && _isPushEligible(userSegment)) {
          const push = _buildPushPayload(sequence);
          try {
            await sendNotification({
              title: push.title,
              body: push.body,
              data: {route: "reengagement", seq: sequence.toString(), source: "push"},
              modifier: email,
              channelId: "recommendations",
              fcmTarget: {token: fcmToken},
              pushOnly: true,
            });
            totalPushSent++;
          } catch (err) {
            logger.warn("Push send failed.", {userId, sequence, err});
          }
        }

        // Email — all segments, unless opted out.
        if (!emailOptOut) {
          await queueReengagementEmail({userId, email, sequence, segment: userSegment});
          totalEmailQueued++;
        }

        // Update per-user campaign state.
        if (sequence === 1) stateUpdate.seq1SentAt = now;
        else if (sequence === 2) stateUpdate.seq2SentAt = now;
        else if (sequence === 3) stateUpdate.seq3SentAt = now;

        await stateRef.set(stateUpdate, {merge: true});
        totalProcessed++;
      }

      logger.info("onReengagementCampaignRequested: page done.", {
        pageSize: snapshot.size,
        totalProcessed,
      });

      if (snapshot.size < PAGE_SIZE) break;
    }

    await _markCampaignProcessed(campaignId, {
      totalProcessed,
      totalPushSent,
      totalEmailQueued,
      sequence,
    });

    logger.info("onReengagementCampaignRequested: complete.", {
      campaignId,
      sequence,
      totalProcessed,
      totalPushSent,
      totalEmailQueued,
    });
  },
);

// ── Segment helpers ───────────────────────────────────────────────────────────

function _buildSegmentCutoffs(): SegmentCutoffs {
  const now = new Date();
  const daysAgo = (d: number) => new Date(now.getTime() - d * 24 * 60 * 60 * 1000);
  return {
    hotEnd: daysAgo(30),
    hotStart: daysAgo(90),
    warmEnd: daysAgo(90),
    warmStart: daysAgo(365),
    coldEnd: daysAgo(365),
    coldStart: daysAgo(3 * 365),
  };
}

function _classifyUser(lastLoginAt: Date | null, c: SegmentCutoffs): Segment {
  if (!lastLoginAt) return "frozen";
  const t = lastLoginAt.getTime();
  if (t >= c.hotStart.getTime() && t < c.hotEnd.getTime()) return "hot";
  if (t >= c.warmStart.getTime() && t < c.warmEnd.getTime()) return "warm";
  if (t >= c.coldStart.getTime() && t < c.coldEnd.getTime()) return "cold";
  return "frozen";
}

function _isPushEligible(segment: Segment): boolean {
  return segment === "hot" || segment === "warm";
}

function _buildPushPayload(sequence: number): {title: string; body: string} {
  switch (sequence) {
    case 1:
      return {
        title: "Prism just got a massive upgrade 🎨",
        body: "AI wallpaper generation is here. Your first 3 are free.",
      };
    case 2:
      return {
        title: "You have 50 Prism Coins waiting — unclaimed",
        body: "Tap to claim your coins and try the new AI wallpaper generator.",
      };
    case 3:
      return {
        title: "Last chance — we're saying goodbye 👋",
        body: "We're removing inactive accounts from our list. Tap to stay.",
      };
    default:
      return {title: "Check out Prism", body: "Something new is waiting for you."};
  }
}

// ── Coins helper ──────────────────────────────────────────────────────────────

async function _creditReactivationCoins(
  userId: string,
  currentCoins: number,
  now: admin.firestore.Timestamp,
): Promise<void> {
  const txId = `ctx_reactivation_${userId}_${now.toMillis()}`;
  const newBalance = currentCoins + REACTIVATION_COINS;
  const batch = db.batch();

  batch.update(db.collection(USERS_COLLECTION).doc(userId), {coins: newBalance});
  batch.set(db.collection(COIN_TX_COLLECTION).doc(txId), {
    id: txId,
    userId,
    createdAt: now,
    updatedAt: now,
    delta: REACTIVATION_COINS,
    balanceBefore: currentCoins,
    balanceAfter: newBalance,
    action: "reactivationBonus",
    description: `Re-engagement bonus (+${REACTIVATION_COINS} coins)`,
    sourceTag: "reengagement.campaign.sequence_2",
    status: "completed",
    type: "credit",
    reason: "reactivation_bonus",
  });

  await batch.commit();
  logger.info("_creditReactivationCoins: credited.", {userId, newBalance});
}

// ── Campaign doc helpers ──────────────────────────────────────────────────────

async function _markCampaignProcessed(
  campaignId: string,
  meta: Record<string, unknown>,
): Promise<void> {
  try {
    await db.collection("reengagementCampaigns").doc(campaignId).update({
      processed: true,
      processedAt: admin.firestore.Timestamp.now(),
      ...meta,
    });
  } catch (err) {
    logger.warn("Failed to mark campaign processed.", {campaignId, err});
  }
}

// ── Type coercion ─────────────────────────────────────────────────────────────

function _asString(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

function _asInt(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

function _asBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const n = value.trim().toLowerCase();
    if (n === "true" || n === "1") return true;
    if (n === "false" || n === "0") return false;
  }
  return fallback;
}

function _asDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}
