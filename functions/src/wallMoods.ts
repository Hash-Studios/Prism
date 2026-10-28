import * as admin from "firebase-admin";
import {db} from "./common";
import {isWotdEligible, premiumCollections, protectedWalls} from "./wallOfTheDay";

export type MoodRule = {
  id: string;
  firstColour?: readonly string[];
  onlyColours?: readonly string[];
  maxColours?: number;
  minColoursFrom?: {colours: readonly string[]; count: number};
  noColours?: readonly string[];
  anyLabel?: readonly string[];
  noLabel?: readonly string[];
  anyCollection?: readonly string[];
  spatialTiers?: readonly string[];
  depthTiers?: readonly string[];
};

export const MIN_MOOD_WALLS = 12;
export const MAX_MOOD_WALLS = 60;

export const MOODS: readonly MoodRule[] = [
  {
    id: "dreamy",
    firstColour: ["pink", "purple", "teal", "white", "blue"],
    onlyColours: ["pink", "purple", "teal", "white", "blue", "grey"],
    anyLabel: ["cloud", "sky", "dusk", "afterglow", "evening", "sunset", "sunrise", "dawn", "horizon", "morning", "fluid", "petal", "flower", "pastel", "atmospheric phenomenon", "red sky at morning"],
  },
  {
    id: "dark_quiet",
    firstColour: ["black"],
    maxColours: 2,
    onlyColours: ["black", "grey", "blue", "teal", "purple", "brown", "white"],
    anyLabel: ["night", "darkness", "moon", "midnight", "moonlight", "silhouette", "star", "outer space", "astronomical object", "black", "monochrome", "black and white", "universe", "space"],
    noLabel: ["metropolis", "city", "cityscape", "automotive lighting", "skyscraper", "street", "road", "nebula", "neon", "light", "fireworks", "sparkler", "event", "new year",
      "sunset", "afterglow", "red sky at morning"],
  },
  {
    id: "bright_bold",
    firstColour: ["red", "orange", "yellow", "pink", "green"],
    minColoursFrom: {colours: ["red", "orange", "yellow", "pink", "green"], count: 2},
    noColours: ["black"],
  },
  {
    id: "minimal",
    maxColours: 2,
    anyCollection: ["minimal"],
    noLabel: ["pattern", "illustration", "fictional character", "cartoon", "art", "visual arts", "font", "text", "animation"],
  },
  {
    id: "spatial_ready",
    spatialTiers: ["great"],
  },
  {
    id: "depth_ready",
    depthTiers: ["auto", "menu"],
  },
];

const strings = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];

const tier = (value: unknown): string => (typeof value === "string" ? value : "");

/** True when the wall satisfies every field the rule sets. */
export function matchesMood(rule: MoodRule, wall: admin.firestore.DocumentData): boolean {
  const colors = strings(wall.colors);
  const labels = strings(wall.visionLabels).map((l) => l.toLowerCase());
  const category = typeof wall.category === "string" ? wall.category.toLowerCase() : "";
  const collections = [...strings(wall.collections).map((c) => c.trim().toLowerCase()), category];

  if (rule.firstColour && !rule.firstColour.includes(colors[0])) return false;
  if (rule.onlyColours && !colors.every((c) => rule.onlyColours?.includes(c))) return false;
  if (rule.maxColours !== undefined && colors.length > rule.maxColours) return false;
  if (rule.minColoursFrom) {
    const {colours, count} = rule.minColoursFrom;
    if (colors.filter((c) => colours.includes(c)).length < count) return false;
  }
  if (rule.noColours && colors.some((c) => rule.noColours?.includes(c))) return false;
  if (rule.anyLabel && !labels.some((l) => rule.anyLabel?.includes(l))) return false;
  if (rule.noLabel && labels.some((l) => rule.noLabel?.includes(l))) return false;
  if (rule.anyCollection && !collections.some((c) => rule.anyCollection?.includes(c))) return false;
  if (rule.spatialTiers && !rule.spatialTiers.includes(tier(wall.spatial?.tier))) return false;
  if (rule.depthTiers && !rule.depthTiers.includes(tier(wall.depth?.tier))) return false;
  return true;
}

const createdMillis = (wall: {data: admin.firestore.DocumentData}): number => {
  const ms = (wall.data.createdAt as admin.firestore.Timestamp | undefined)?.toMillis?.();
  return typeof ms === "number" ? ms : -Infinity;
};

/** The logical id the app queries and the owned-preview service accepts. */
const wallId = (wall: {id: string; data: admin.firestore.DocumentData}): string | undefined => {
  const id = typeof wall.data.id === "string" ? wall.data.id : "";
  return /^[A-Za-z0-9_-]{1,200}$/.test(id) ? id : undefined;
};

/** Newest first, ties by wall id. A wall without createdAt sorts last. */
function newestFirst(a: {id: string; data: admin.firestore.DocumentData}, b: typeof a): number {
  const x = createdMillis(a);
  const y = createdMillis(b);
  if (x !== y) return x > y ? -1 : 1;
  const [ia, ib] = [wallId(a) ?? "", wallId(b) ?? ""];
  return ia < ib ? -1 : ia > ib ? 1 : 0;
}

/** The wall ids for each mood with at least MIN_MOOD_WALLS matches, in MOODS order and capped at MAX_MOOD_WALLS. */
export function moodLists(
  walls: Array<{id: string; data: admin.firestore.DocumentData}>,
  premium: string[],
): Array<{id: string; wallIds: string[]}> {
  const eligible = walls
    .filter((w) => w.data.review === true && isWotdEligible(w.data, premium) && wallId(w) !== undefined)
    .sort(newestFirst);
  return MOODS.flatMap((rule) => {
    const seen = new Set<string>();
    const matches: string[] = [];
    for (const wall of eligible) {
      const id = wallId(wall);
      if (id === undefined || seen.has(id) || !matchesMood(rule, wall.data)) continue;
      seen.add(id);
      matches.push(id);
    }
    if (matches.length < MIN_MOOD_WALLS) return [];
    return [{id: rule.id, wallIds: matches.slice(0, MAX_MOOD_WALLS)}];
  });
}

/** Writes moods/current from the walls the app lists and returns the wall count per mood id. */
export async function refreshMoods(): Promise<Record<string, number>> {
  const snap = await protectedWalls()
    .select("id", "review", "createdAt", "colors", "visionLabels", "collections", "category", "spatial", "depth",
      "originalProtected", "is_streak_exclusive", "dropReserved", "dropWeek")
    .get();
  const premium = await premiumCollections();
  const lists = moodLists(snap.docs.map((d) => ({id: d.id, data: d.data()})), premium);
  await db.collection("moods").doc("current").set({
    moods: lists,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return Object.fromEntries(lists.map((l) => [l.id, l.wallIds.length]));
}
