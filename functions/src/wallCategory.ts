import type {ImageAnnotatorClient} from "@google-cloud/vision";

export const DEFAULT_CATEGORY = "General";
export const DEFAULT_COLLECTION = "community";

// A keyword matches whole words only, so "car" does not match "Cartoon" or "Playing card". Each rule has a tier.
// SUBJECT names what the wall shows. STYLE names a look, a mood or a backdrop that many walls share (sky, night,
// light, art). LAST is Pastel, which takes only walls that no other rule matches. The most specific tier that any label
// matches wins. In that tier, the label with the best Vision rank wins. In one label, the rule order breaks the tie.
const SUBJECT = 0;
const STYLE = 1;
const LAST = 2;
type Tier = typeof SUBJECT | typeof STYLE | typeof LAST;

const CATEGORY_RULES: ReadonlyArray<readonly [string, Tier, readonly string[]]> = [
  ["Anime", SUBJECT, ["anime", "manga", "anime girl", "anime boy"]],
  ["Flowers", SUBJECT, ["petal", "rose", "bouquet", "floristry", "cut flowers", "lotus", "tulip", "blossom", "floral"]],
  ["Nature", SUBJECT, ["mountain", "landscape", "sunset", "tree", "forest", "beach", "ocean", "sea", "river", "lake",
    "garden", "grass", "rain", "snow", "winter", "autumn"]],
  ["Nature", STYLE, ["sky", "cloud", "flower", "plant", "leaf"]],
  ["Architecture", SUBJECT, ["city", "building", "architecture", "house", "interior", "room", "tower", "bridge", "urban"]],
  ["Cars", SUBJECT, ["car", "vehicle", "automobile", "sports car", "motorcycle", "truck", "jeep", "luxury car", "race car",
    "vintage car"]],
  ["Gaming", SUBJECT, ["video game", "pc game", "action-adventure game", "shooter game", "gaming", "esports",
    "game controller", "joystick"]],
  ["Space", SUBJECT, ["space", "galaxy", "stars", "universe", "planet", "nebula", "astronaut", "rocket", "moon", "cosmos",
    "stellar"]],
  ["Ocean", SUBJECT, ["underwater", "marine", "coral", "fish", "jellyfish", "dolphin", "whale"]],
  ["Ocean", STYLE, ["tropical"]],
  ["Anime", STYLE, ["character", "illustration", "cartoon"]],
  ["Neon", SUBJECT, ["neon", "night lights", "cyberpunk", "laser"]],
  ["Neon", STYLE, ["light", "led", "glow", "sign"]],
  ["Dark", STYLE, ["dark", "darkness", "night", "black", "shadow", "moody", "mysterious", "horror", "creepy", "mystery"]],
  ["Abstract", STYLE, ["abstract", "pattern", "art", "geometric", "texture", "minimal", "colorful", "artistic"]],
  ["Architecture", STYLE, ["home", "office", "modern"]],
  ["3D Render", STYLE, ["3d", "render", "cgi", "surreal"]],
  ["Minimal", STYLE, ["simple", "clean", "white", "plain", "elegant"]],
  ["Gradient", STYLE, ["gradient", "color gradient", "blend", "mesh gradient", "gradient background"]],
  ["AI Art", STYLE, ["ai", "generated"]],
  ["Cyberpunk", STYLE, ["future", "tech", "technology", "robot", "android", "cyborg", "digital"]],
  ["Vintage", STYLE, ["vintage", "retro", "old", "classic", "nostalgic", "vintage style", "antique"]],
  ["Landscape", SUBJECT, ["scenery", "panorama", "vista", "valley", "desert", "countryside"]],
  ["Landscape", STYLE, ["horizon"]],
  ["Galaxy", SUBJECT, ["cosmic", "milky way"]],
  ["Galaxy", STYLE, ["star", "astronomy"]],
  ["Pastel", LAST, ["pastel"]],
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

/** The category for Vision labels in score order, best first. */
export function mapLabelsToCategory(labels: string[]): string {
  const labelWords = labels.map(wordsOf);
  for (const tier of [SUBJECT, STYLE, LAST]) {
    for (const label of labelWords) {
      const rule = CATEGORY_RULES.find(([, ruleTier, keywords]) =>
        ruleTier === tier && keywords.some((keyword) => labelHas(label, wordsOf(keyword))));
      if (rule) return rule[0];
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
