import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const REGION = "asia-south1";
const USERS = "usersv2";
const revenueCatSecret = defineSecret("REVENUECAT_SECRET_KEY");

// Mirrors PurchaseConstants.paidEntitlementKeys in lib/core/purchases/purchase_constants.dart.
const PAID_ENTITLEMENT_KEYS = ["prism_v3_pro_access", "prism_ultra", "prism_premium", "prism_pro", "prism_collections"];

interface RevenueCatEntitlement {
  expires_date?: string | null;
}

interface RevenueCatSubscriberResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

/**
 * Mirrors PurchasesService.tierFromCustomerInfo in purchases_service.dart: an entitlement
 * counts if it is null-expiring (lifetime) or expires in the future.
 */
export function subscriptionFromRevenueCat(json: unknown, nowMs: number): {premium: boolean; subscriptionTier: string} {
  const entitlements = (json as RevenueCatSubscriberResponse)?.subscriber?.entitlements ?? {};
  let paid = false;
  let lifetime = false;
  for (const key of PAID_ENTITLEMENT_KEYS) {
    const entitlement = entitlements[key];
    if (!entitlement) continue;
    const expiresDate = entitlement.expires_date;
    const isActive = expiresDate == null || new Date(expiresDate).getTime() > nowMs;
    if (!isActive) continue;
    paid = true;
    if (expiresDate == null) lifetime = true;
  }
  if (!paid) return {premium: false, subscriptionTier: "free"};
  return {premium: true, subscriptionTier: lifetime ? "lifetime" : "pro"};
}

export const syncSubscription = onCall(
  {region: REGION, cors: true, secrets: [revenueCatSecret]},
  async (request: CallableRequest<unknown>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to sync your subscription.");

    let json: unknown;
    try {
      const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(callerUid)}`, {
        headers: {Authorization: `Bearer ${revenueCatSecret.value()}`},
      });
      if (!response.ok) throw new HttpsError("unavailable", `RevenueCat request failed (${response.status}).`);
      json = await response.json();
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("unavailable", "RevenueCat request failed.");
    }

    const {premium, subscriptionTier} = subscriptionFromRevenueCat(json, Date.now());
    await db.collection(USERS).doc(callerUid).update({premium, subscriptionTier});
    return {premium, subscriptionTier};
  },
);
