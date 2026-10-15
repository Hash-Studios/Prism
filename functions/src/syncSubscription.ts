import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "./common";

const USERS = "usersv2";
const SYNC_STATE = "subscriptionSync";
const SYNC_COOLDOWN_MS = 30_000;
const SYNC_BYPASS_FLOOR_MS = 5_000;
const RECONCILE_PAGE_SIZE = 200;
const RECONCILE_CONCURRENCY = 5;
const RECONCILE_PAGE_DELAY_MS = 1_000;
const revenueCatSecret = defineSecret("REVENUECAT_SECRET_KEY");

// Mirrors PurchaseConstants.paidEntitlementKeys in lib/core/purchases/purchase_constants.dart.
const PAID_ENTITLEMENT_KEYS = ["prism_v3_pro_access", "prism_ultra", "prism_premium", "prism_pro", "prism_collections"];

interface RevenueCatEntitlement {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
}

interface RevenueCatSubscriberResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

/**
 * Mirrors PurchasesService.tierFromCustomerInfo in purchases_service.dart: an entitlement
 * counts if it is null-expiring (lifetime), expires in the future, or is in a billing grace period that has not
 * ended (RevenueCat keeps the past `expires_date` and adds `grace_period_expires_date`).
 */
export function subscriptionFromRevenueCat(json: unknown, nowMs: number): {premium: boolean; subscriptionTier: string} {
  const entitlements = (json as RevenueCatSubscriberResponse)?.subscriber?.entitlements ?? {};
  let paid = false;
  let lifetime = false;
  for (const key of PAID_ENTITLEMENT_KEYS) {
    const entitlement = entitlements[key];
    if (!entitlement) continue;
    const expiresDate = entitlement.expires_date;
    const graceDate = entitlement.grace_period_expires_date;
    const isActive = expiresDate == null || new Date(expiresDate).getTime() > nowMs ||
      (graceDate != null && new Date(graceDate).getTime() > nowMs);
    if (!isActive) continue;
    paid = true;
    if (expiresDate == null) lifetime = true;
  }
  if (!paid) return {premium: false, subscriptionTier: "free"};
  return {premium: true, subscriptionTier: lifetime ? "lifetime" : "pro"};
}

/**
 * Claims the per-user sync slot. False when the last sync was under 30 seconds ago. With `bypassCooldown`
 * (a user stored as Free may have just paid) the wait is 5 seconds, so one account cannot hammer RevenueCat.
 */
export async function claimSyncSlot(callerUid: string, nowMs: number, bypassCooldown = false): Promise<boolean> {
  const ref = db.collection(SYNC_STATE).doc(callerUid);
  return db.runTransaction(async (tx) => {
    const lastAt = (await tx.get(ref)).data()?.lastAt;
    if (typeof lastAt === "number" && nowMs - lastAt < (bypassCooldown ? SYNC_BYPASS_FLOOR_MS : SYNC_COOLDOWN_MS)) {
      return false;
    }
    tx.set(ref, {lastAt: nowMs});
    return true;
  });
}

export async function releaseSyncSlot(callerUid: string, claimedAt: number): Promise<void> {
  const ref = db.collection(SYNC_STATE).doc(callerUid);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).data()?.lastAt === claimedAt) tx.delete(ref);
  });
}

type Doc = Record<string, unknown>;

function storedSubscription(stored: Doc): {premium: boolean; subscriptionTier: string} {
  return {
    premium: stored.premium === true,
    subscriptionTier: typeof stored.subscriptionTier === "string" ? stored.subscriptionTier : "free",
  };
}

/**
 * Reads the user's RevenueCat entitlements and writes `premium` and `subscriptionTier`. The caller holds the sync
 * slot claimed at `claimedAt`; a newer slot wins, and a failed read or write releases it. With `revokeOnly` a user
 * stored as Free is never granted premium: only a paid user is revoked or has the tier refreshed.
 */
async function applySubscription(
  callerUid: string,
  claimedAt: number,
  revokeOnly = false,
): Promise<{premium: boolean; subscriptionTier: string}> {
  let json: unknown;
  try {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(callerUid)}`, {
      headers: {Authorization: `Bearer ${revenueCatSecret.value()}`},
    });
    if (!response.ok) throw new HttpsError("unavailable", `RevenueCat request failed (${response.status}).`);
    json = await response.json();
  } catch (error) {
    await releaseSyncSlot(callerUid, claimedAt);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "RevenueCat request failed.");
  }

  const {premium, subscriptionTier} = subscriptionFromRevenueCat(json, Date.now());
  const userRef = db.collection(USERS).doc(callerUid);
  let persisted: boolean;
  try {
    persisted = await db.runTransaction(async (tx) => {
      const slot = await tx.get(db.collection(SYNC_STATE).doc(callerUid));
      if (slot.data()?.lastAt !== claimedAt) return false;
      if (revokeOnly && (await tx.get(userRef)).data()?.premium !== true) return false;
      tx.update(userRef, {premium, subscriptionTier});
      return true;
    });
  } catch (error) {
    await releaseSyncSlot(callerUid, claimedAt);
    throw error;
  }
  if (!persisted) return storedSubscription((await userRef.get()).data() ?? {});
  return {premium, subscriptionTier};
}

export const syncSubscription = onCall(
  {region: REGION, cors: true, maxInstances: 10, secrets: [revenueCatSecret]},
  async (request: CallableRequest<unknown>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to sync your subscription.");

    const claimedAt = Date.now();
    const storedBefore = (await db.collection(USERS).doc(callerUid).get()).data() ?? {};
    if (!await claimSyncSlot(callerUid, claimedAt, storedBefore.premium !== true)) {
      return storedSubscription(storedBefore);
    }
    return applySubscription(callerUid, claimedAt);
  },
);

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * Daily check of every user stored as premium against RevenueCat. It revokes an expired subscription and refreshes
 * the tier. It never grants premium, and a RevenueCat error leaves the user as stored.
 */
export const reconcileSubscriptions = onSchedule(
  {
    schedule: "30 2 * * *",
    timeZone: "UTC",
    region: REGION,
    timeoutSeconds: 540,
    maxInstances: 1,
    secrets: [revenueCatSecret],
  },
  async () => {
    let checked = 0;
    let failed = 0;
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let query = db.collection(USERS).where("premium", "==", true).limit(RECONCILE_PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const snap = await query.get();
      for (let i = 0; i < snap.docs.length; i += RECONCILE_CONCURRENCY) {
        const results = await Promise.allSettled(snap.docs.slice(i, i + RECONCILE_CONCURRENCY).map(async (doc) => {
          const claimedAt = Date.now();
          // A user who synced in the last 30 seconds is current already.
          if (!await claimSyncSlot(doc.id, claimedAt)) return;
          await applySubscription(doc.id, claimedAt, true);
        }));
        for (const result of results) {
          checked += 1;
          if (result.status === "rejected") {
            failed += 1;
            logger.error("reconcileSubscriptions: user failed.", {err: result.reason});
          }
        }
      }
      if (snap.size < RECONCILE_PAGE_SIZE) break;
      cursor = snap.docs[snap.docs.length - 1];
      await sleep(RECONCILE_PAGE_DELAY_MS);
    }
    logger.info("reconcileSubscriptions: done", {checked, failed});
  },
);
