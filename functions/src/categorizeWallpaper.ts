import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {DEFAULT_CATEGORY, DEFAULT_COLLECTION, detectLabels, mapLabelsToCategory} from "./wallCategory";
import {db, REGION} from "./common";

/** A wall doc id: a non-empty string without a slash, at most 128 characters. */
export function parseWallId(raw: unknown): string {
  const wallId = typeof raw === "string" ? raw.trim() : "";
  if (!wallId || wallId.length > 128 || wallId.includes("/") || wallId === "." || wallId === ".." ||
      /^__.*__$/.test(wallId)) {
    throw new HttpsError("invalid-argument", "wallId must be a valid wallpaper id.");
  }
  return wallId;
}

export const categorizeWallpaper = onCall(
  {
    region: REGION,
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to categorize wallpapers.");
    }

    const wallId = parseWallId(request.data?.wallId);

    const wallDoc = await db.collection("walls").doc(wallId).get();

    if (!wallDoc.exists) {
      throw new HttpsError("not-found", "Wallpaper not found.");
    }

    const data = wallDoc.data();
    if (!data) {
      throw new HttpsError("not-found", "Wallpaper data not found.");
    }

    const callerEmail = (request.auth.token.email ?? "").toString().trim().toLowerCase();
    const wallEmail = (data.email ?? "").toString().trim().toLowerCase();
    const isAdmin = await isAdminCaller(request.auth);
    if (!isAdmin && callerEmail !== wallEmail) {
      throw new HttpsError("permission-denied", "You cannot categorize this wallpaper.");
    }
    if (data.aiCategorized === true && !isAdmin) {
      return {success: true, category: data.category ?? DEFAULT_CATEGORY, labels: []};
    }

    const wallpaperUrl = (data.wallpaper_url || data.wallpaper_thumb || "").toString().trim();

    if (!wallpaperUrl) {
      throw new HttpsError("failed-precondition", "No wallpaper URL found.");
    }

    const labels = await detectLabels(wallpaperUrl);
    const category = mapLabelsToCategory(labels);

    await db.collection("walls").doc(wallId).update({
      category: category,
      collections: [DEFAULT_COLLECTION],
      categorizedAt: admin.firestore.FieldValue.serverTimestamp(),
      aiCategorized: true,
    });

    logger.info("categorizeWallpaper: categorized", {wallId, category, labels: labels.slice(0, 5)});

    return {success: true, category, labels: labels.slice(0, 5)};
  },
);
