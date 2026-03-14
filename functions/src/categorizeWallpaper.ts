import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onCall} from "firebase-functions/v2/https";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const CATEGORY_MAPPINGS: Record<string, string[]> = {
  "Nature": ["mountain", "landscape", "sunset", "sky", "tree", "forest", "beach", "ocean", "sea", "river", "lake", "flower", "garden", "plant", "leaf", "grass", "cloud", "rain", "snow", "winter", "autumn"],
  "Architecture": ["city", "building", "architecture", "skyscraper", "house", "home", "interior", "room", "office", "tower", "bridge", "street", "urban", "modern"],
  "Cars": ["car", "vehicle", "automobile", "sports car", "motorcycle", "truck", "jeep", "luxury car", "race car", "vintage car"],
  "Anime": ["anime", "cartoon", "manga", "character", "anime girl", "anime boy", "illustration"],
  "Space": ["space", "galaxy", "stars", "universe", "planet", "nebula", "astronaut", "rocket", "moon", "cosmos", "stellar"],
  "Ocean": ["ocean", "sea", "beach", "underwater", "marine", "coral", "fish", "jellyfish", "dolphin", "whale", "tropical"],
  "Flowers": ["flower", "rose", "lotus", "tulip", "sunflower", "blossom", "floral", "bouquet", "garden"],
  "Neon": ["neon", "light", "night lights", "led", "glow", "cyberpunk", "laser", "sign", "city lights"],
  "Dark": ["dark", "night", "black", "shadow", "moody", "mysterious", "horror", "creepy", "mystery"],
  "Abstract": ["abstract", "pattern", "art", "design", "geometric", "texture", "minimal", "colorful", "artistic"],
  "3D Render": ["3d", "render", "cgi", "digital art", "3d illustration", "surreal", "cg artwork"],
  "Minimal": ["minimal", "simple", "clean", "white", "minimalist", "plain", "elegant", "simple design"],
  "Gradient": ["gradient", "color gradient", "colorful", "blend", "mesh gradient", "gradient background"],
  "AI Art": ["ai", "artificial intelligence", "generated", "digital art", "ai art"],
  "Cyberpunk": ["cyberpunk", "future", "tech", "technology", "robot", "android", "cyborg", "digital"],
  "Vintage": ["vintage", "retro", "old", "classic", "nostalgic", "vintage style", "antique"],
  "Landscape": ["landscape", "scenery", "panorama", "vista", "horizon", "mountains", "valley", "desert", "countryside"],
  "Galaxy": ["galaxy", "nebula", "star", "cosmic", "deep space", "milky way", "astronomy"],
};

const DEFAULT_CATEGORY = "General";
const DEFAULT_COLLECTION = "community";

function mapLabelsToCategory(labels: string[]): string {
  const lowerLabels = labels.map((l) => l.toLowerCase());

  for (const [category, keywords] of Object.entries(CATEGORY_MAPPINGS)) {
    for (const keyword of keywords) {
      if (lowerLabels.some((label) => label.includes(keyword))) {
        return category;
      }
    }
  }

  return DEFAULT_CATEGORY;
}

async function detectLabels(imageUrl: string): Promise<string[]> {
  const client = new ImageAnnotatorClient();

  const [result] = await client.annotateImage({
    image: {source: {imageUri: imageUrl}},
    features: [{type: "LABEL_DETECTION", maxResults: 10}],
  });

  const labels = result.labelAnnotations || [];
  return labels
    .filter((label) => label.score && label.score > 0.7)
    .map((label) => label.description || "")
    .filter((desc) => desc.length > 0);
}

export const categorizeWallpaper = onCall(
  {
    region: "asia-south1",
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthorized");
    }

    const {wallId} = request.data;

    if (!wallId) {
      throw new Error("wallId is required");
    }

    const wallDoc = await db.collection("walls").doc(wallId).get();

    if (!wallDoc.exists) {
      throw new Error("Wallpaper not found");
    }

    const data = wallDoc.data();
    if (!data) {
      throw new Error("Wallpaper data not found");
    }

    const wallpaperUrl = (data.wallpaper_url || data.wallpaper_thumb || "").toString().trim();

    if (!wallpaperUrl) {
      throw new Error("No wallpaper URL found");
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
