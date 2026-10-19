import type {ImageAnnotatorClient} from "@google-cloud/vision";

export const DEFAULT_CATEGORY = "General";
export const DEFAULT_COLLECTION = "community";

// First matching category wins, so keywords already covered by an earlier row are left out. A keyword matches whole
// words only, so "car" does not match "Cartoon" or "Playing card".
const CATEGORY_MAPPINGS: Record<string, string[]> = {
  "Nature": ["mountain", "landscape", "sunset", "sky", "tree", "forest", "beach", "ocean", "sea", "river", "lake", "flower", "garden", "plant", "leaf", "grass", "cloud", "rain", "snow", "winter", "autumn"],
  "Architecture": ["city", "building", "architecture", "house", "home", "interior", "room", "office", "tower", "bridge", "urban", "modern"],
  "Cars": ["car", "vehicle", "automobile", "sports car", "motorcycle", "truck", "jeep", "luxury car", "race car", "vintage car"],
  "Anime": ["anime", "manga", "character", "anime girl", "anime boy", "illustration", "cartoon"],
  "Space": ["space", "galaxy", "stars", "universe", "planet", "nebula", "astronaut", "rocket", "moon", "cosmos", "stellar"],
  "Ocean": ["underwater", "marine", "coral", "fish", "jellyfish", "dolphin", "whale", "tropical"],
  "Flowers": ["rose", "lotus", "tulip", "blossom", "floral", "bouquet"],
  "Neon": ["neon", "light", "night lights", "led", "glow", "cyberpunk", "laser", "sign"],
  "Dark": ["dark", "darkness", "night", "black", "shadow", "moody", "mysterious", "horror", "creepy", "mystery"],
  "Abstract": ["abstract", "pattern", "art", "geometric", "texture", "minimal", "colorful", "artistic"],
  "3D Render": ["3d", "render", "cgi", "surreal"],
  "Minimal": ["simple", "clean", "white", "plain", "elegant"],
  "Gradient": ["gradient", "color gradient", "blend", "mesh gradient", "gradient background"],
  "AI Art": ["ai", "generated"],
  "Cyberpunk": ["future", "tech", "technology", "robot", "android", "cyborg", "digital"],
  "Vintage": ["vintage", "retro", "old", "classic", "nostalgic", "vintage style", "antique"],
  "Landscape": ["scenery", "panorama", "vista", "horizon", "valley", "desert", "countryside"],
  "Galaxy": ["star", "cosmic", "milky way", "astronomy"],
};

const wordsOf = (text: string): string[] => text.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 0);

/** True when the keyword's words come in order in the label, each one as is or with a plural "s" or "es". */
function labelHas(label: string[], keyword: string[]): boolean {
  return label.some((_, start) => keyword.every((word, i) => {
    const found = label[start + i];
    return found === word || found === `${word}s` || found === `${word}es`;
  }));
}

export function mapLabelsToCategory(labels: string[]): string {
  const labelWords = labels.map(wordsOf);

  for (const [category, keywords] of Object.entries(CATEGORY_MAPPINGS)) {
    for (const keyword of keywords) {
      if (labelWords.some((label) => labelHas(label, wordsOf(keyword)))) {
        return category;
      }
    }
  }

  return DEFAULT_CATEGORY;
}

let visionClient: ImageAnnotatorClient | undefined;

export async function detectLabels(imageUrl: string): Promise<string[]> {
  const {ImageAnnotatorClient} = await import("@google-cloud/vision");
  visionClient ??= new ImageAnnotatorClient();

  const [result] = await visionClient.annotateImage({
    image: {source: {imageUri: imageUrl}},
    features: [{type: "LABEL_DETECTION", maxResults: 10}],
  });

  const labels = result.labelAnnotations || [];
  return labels
    .filter((label) => label.score && label.score > 0.7)
    .map((label) => label.description || "")
    .filter((desc) => desc.length > 0);
}
