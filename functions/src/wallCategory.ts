import type {ImageAnnotatorClient} from "@google-cloud/vision";

export const DEFAULT_CATEGORY = "General";
export const DEFAULT_COLLECTION = "community";

// First matching rule wins, so keywords already covered by an earlier rule are left out. A keyword matches whole
// words only, so "car" does not match "Cartoon" or "Playing card". Anime has two rules: a label that names anime beats
// a game label, and a game label beats a plain "character". Pastel is last, so it only takes walls that no other
// category matches.
const CATEGORY_RULES: ReadonlyArray<readonly [string, readonly string[]]> = [
  ["Nature", ["mountain", "landscape", "sunset", "sky", "tree", "forest", "beach", "ocean", "sea", "river", "lake", "flower", "garden", "plant", "leaf", "grass", "cloud", "rain", "snow", "winter", "autumn"]],
  ["Architecture", ["city", "building", "architecture", "house", "home", "interior", "room", "office", "tower", "bridge", "urban", "modern"]],
  ["Cars", ["car", "vehicle", "automobile", "sports car", "motorcycle", "truck", "jeep", "luxury car", "race car", "vintage car"]],
  ["Anime", ["anime", "manga", "anime girl", "anime boy"]],
  ["Gaming", ["video game", "pc game", "action-adventure game", "shooter game", "gaming", "esports", "game controller", "joystick"]],
  ["Anime", ["character", "illustration", "cartoon"]],
  ["Space", ["space", "galaxy", "stars", "universe", "planet", "nebula", "astronaut", "rocket", "moon", "cosmos", "stellar"]],
  ["Ocean", ["underwater", "marine", "coral", "fish", "jellyfish", "dolphin", "whale", "tropical"]],
  ["Flowers", ["rose", "lotus", "tulip", "blossom", "floral", "bouquet"]],
  ["Neon", ["neon", "light", "night lights", "led", "glow", "cyberpunk", "laser", "sign"]],
  ["Dark", ["dark", "darkness", "night", "black", "shadow", "moody", "mysterious", "horror", "creepy", "mystery"]],
  ["Abstract", ["abstract", "pattern", "art", "geometric", "texture", "minimal", "colorful", "artistic"]],
  ["3D Render", ["3d", "render", "cgi", "surreal"]],
  ["Minimal", ["simple", "clean", "white", "plain", "elegant"]],
  ["Gradient", ["gradient", "color gradient", "blend", "mesh gradient", "gradient background"]],
  ["AI Art", ["ai", "generated"]],
  ["Cyberpunk", ["future", "tech", "technology", "robot", "android", "cyborg", "digital"]],
  ["Vintage", ["vintage", "retro", "old", "classic", "nostalgic", "vintage style", "antique"]],
  ["Landscape", ["scenery", "panorama", "vista", "horizon", "valley", "desert", "countryside"]],
  ["Galaxy", ["star", "cosmic", "milky way", "astronomy"]],
  ["Pastel", ["pastel"]],
];

/** Every name the classifier can write to `walls.category`, in rule order. */
export const CATEGORY_NAMES: readonly string[] = [...new Set(CATEGORY_RULES.map(([name]) => name))];

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

  for (const [category, keywords] of CATEGORY_RULES) {
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
  return labelsFor({source: {imageUri: imageUrl}});
}

/** Labels for image bytes sent inline. Vision reads the bytes for this request only. */
export async function detectLabelsInImage(content: Buffer): Promise<string[]> {
  return labelsFor({content});
}

async function labelsFor(image: {source: {imageUri: string}} | {content: Buffer}): Promise<string[]> {
  const {ImageAnnotatorClient} = await import("@google-cloud/vision");
  visionClient ??= new ImageAnnotatorClient();
  const features = [{type: "LABEL_DETECTION" as const, maxResults: 10}];
  if (!("content" in image)) {
    const [result] = await visionClient.annotateImage({image, features});
    return labelsFrom(result.labelAnnotations || []);
  }
  const [response] = await visionClient.batchAnnotateImages({
    requests: [{image, features}],
  }, {retry: null, timeout: 20_000});
  const result = response.responses?.[0];
  if (result?.error?.code) throw new Error("Vision label detection failed.");
  return labelsFrom(result?.labelAnnotations || []);
}

function labelsFrom(labels: Array<{score?: number | null; description?: string | null}>): string[] {
  return labels
    .filter((label) => label.score && label.score > 0.7)
    .map((label) => label.description || "")
    .filter((desc) => desc.length > 0);
}
