import type {Rng} from "./ids";
import {DUO_REVEAL_SPEC, hasBannedDuoPhrase} from "../duo_reveal_spec";
import {DEFAULT_CATEGORY} from "../wallCategory";
import {REQUEST_CATEGORIES, type StudioRequestPick} from "../wallRequests";
import {
  STUDIO_COMPOSITION, STUDIO_DEPTH_COMPOSITION, type StudioPalette, type StudioSeries, type StudioSubject,
} from "./series";

export const STUDIO_TITLE_MAX_LENGTH = 60;
export const STUDIO_TAG_MAX_LENGTH = 24;
export const STUDIO_MAX_TAGS = 8;
/** A plan of up to STUDIO_CATEGORY_CAP_MAX_COUNT candidates over more than one series has at most this many per category. */
export const STUDIO_CATEGORY_CAP = 2;
export const STUDIO_CATEGORY_CAP_MAX_COUNT = 10;

export interface StudioPlanItem {
  duoPresetId?: string;
  seriesId: string;
  subjectId: string;
  paletteId: string;
  prompt: string;
  title: string;
  category: string;
  tags: string[];
  seed: number;
  /** Set when the candidate fills a wall request. */
  requestId?: string;
}

export const STUDIO_REQUEST_SERIES = "request";
/** Request tags that are browse categories without a classifier category of their own. */
const CLASSIFIER_CATEGORY: Record<string, string> = {Aesthetic: "Abstract", Forest: "Nature", AMOLED: "Dark"};

export interface StudioPlanInput {
  manualSeriesId?: string;
  series: StudioSeries[];
  count: number;
  /** Series id -> weight. A series that is not in the map has weight 1; weight 0 leaves it out. */
  weights: Record<string, number>;
  /** Subjects used within STUDIO_SUBJECT_COOLDOWN_DAYS. */
  recentSubjectIds: Set<string>;
  rng: Rng;
}

const pick = <T>(items: T[], rng: Rng): T => items[Math.floor(rng() * items.length)];

function shuffle<T>(items: T[], rng: Rng): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/** Splits `count` slots by weight with the largest remainder method. The rng breaks ties. */
function apportion(weights: number[], count: number, rng: Rng): number[] {
  const normalized = weights.map((w) => w / Math.max(...weights));
  const total = normalized.reduce((a, b) => a + b, 0);
  const exact = normalized.map((w) => count * w / total);
  const slots = exact.map(Math.floor);
  const left = count - slots.reduce((a, b) => a + b, 0);
  const order = shuffle(weights.map((_, i) => i), rng).sort((a, b) => (exact[b] - slots[b]) - (exact[a] - slots[a]));
  for (let k = 0; k < left; k++) slots[order[k]]++;
  return slots;
}

/** Unique lower-case tags, each at most STUDIO_TAG_MAX_LENGTH characters, at most STUDIO_MAX_TAGS. */
export function studioTags(...lists: string[][]): string[] {
  const tags: string[] = [];
  for (const raw of lists.flat()) {
    const tag = raw.trim().toLowerCase();
    if (tag === "" || tag.length > STUDIO_TAG_MAX_LENGTH || tags.includes(tag)) continue;
    tags.push(tag);
    if (tags.length === STUDIO_MAX_TAGS) break;
  }
  return tags;
}

export function studioTitle(subject: StudioSubject, palette: StudioPalette): string {
  return `${subject.title} · ${palette.name}`.slice(0, STUDIO_TITLE_MAX_LENGTH).trim();
}

export function studioPrompt(series: StudioSeries, subject: StudioSubject, palette: StudioPalette): string {
  if (series.duoReveal) {
    if (hasBannedDuoPhrase([subject.id, subject.title, subject.prompt, subject.category, ...subject.tags,
      series.id, series.name, series.category, series.style, ...series.tags,
      palette.id, palette.prompt, palette.name, ...palette.tags, subject.foldedPrompt, subject.revealedPrompt].join(" "))) {
      throw new Error("Duo catalog contains a banned phrase.");
    }
    return `${subject.prompt}, ${palette.prompt}. ${series.style}`;
  }
  return `${subject.prompt}, ${palette.prompt}. ${series.style} ${series.depth ? STUDIO_DEPTH_COMPOSITION : STUDIO_COMPOSITION}`;
}

function categoryOf(tags: string[]): string {
  const tag = tags.find((t) => REQUEST_CATEGORIES.includes(t));
  return tag ? CLASSIFIER_CATEGORY[tag] ?? tag : DEFAULT_CATEGORY;
}

/** A candidate for a wall request: the request text with the composition rules. Category is the first category tag. */
export function requestPlanItem(pick: StudioRequestPick, rng: Rng): StudioPlanItem {
  return {
    seriesId: STUDIO_REQUEST_SERIES,
    subjectId: `request_${pick.requestId}`,
    paletteId: STUDIO_REQUEST_SERIES,
    prompt: `${pick.text}. ${STUDIO_COMPOSITION}`,
    title: pick.text.slice(0, STUDIO_TITLE_MAX_LENGTH).trim(),
    category: categoryOf(pick.tags),
    tags: studioTags(["request"], pick.tags.map((tag) => tag.replace(/_/g, " "))),
    seed: Math.floor(rng() * 2 ** 31),
    requestId: pick.requestId,
  };
}

/**
 * The candidates of one run: slots split across series by weight, no subject twice or within its cooldown, and at
 * most STUDIO_CATEGORY_CAP per category in a small mixed plan. A series that
 * runs out gives its slot to another one, so the plan can be shorter than `count` only when every series is out.
 * Same rng, same plan.
 */
export function buildDailyPlan(input: StudioPlanInput): StudioPlanItem[] {
  const {recentSubjectIds, rng} = input;
  const count = Math.max(0, Math.trunc(input.count));
  const eligible = input.series.filter((s) => (!s.manualOnly || input.manualSeriesId === s.id) &&
    (input.weights[s.id] ?? 1) > 0 && s.subjects.length > 0 &&
    s.palettes.length > 0);
  if (count === 0 || eligible.length === 0) return [];

  const capCategories = count <= STUDIO_CATEGORY_CAP_MAX_COUNT && eligible.length > 1;
  const usedSubjects = new Set<string>();
  const usedPalettes = new Set<string>();
  const perCategory = new Map<string, number>();

  const pickItem = (series: StudioSeries): StudioPlanItem | null => {
    const categoryOf = (subject: StudioSubject) => subject.category ?? series.category;
    const open = series.subjects.filter((s) => !usedSubjects.has(s.id) &&
      !recentSubjectIds.has(s.id) &&
      (!capCategories || (perCategory.get(categoryOf(s)) ?? 0) < STUDIO_CATEGORY_CAP));
    if (open.length === 0) return null;
    const subject = pick(open, rng);
    const unusedPalettes = series.palettes.filter((p) => !usedPalettes.has(`${series.id}/${p.id}`));
    const palette = pick(unusedPalettes.length > 0 ? unusedPalettes : series.palettes, rng);

    const category = categoryOf(subject);
    usedSubjects.add(subject.id);
    usedPalettes.add(`${series.id}/${palette.id}`);
    perCategory.set(category, (perCategory.get(category) ?? 0) + 1);
    return {
      seriesId: series.id,
      ...(series.duoReveal ? {duoPresetId: DUO_REVEAL_SPEC.presetId} : {}),
      subjectId: subject.id,
      paletteId: palette.id,
      prompt: studioPrompt(series, subject, palette),
      title: studioTitle(subject, palette),
      category,
      tags: studioTags(series.tags, subject.tags, palette.tags),
      seed: Math.floor(rng() * 2 ** 31),
    };
  };

  const slots = apportion(eligible.map((s) => input.weights[s.id] ?? 1), count, rng);
  const order = shuffle(eligible.flatMap((s, i) => Array<StudioSeries>(slots[i]).fill(s)), rng);
  const plan: StudioPlanItem[] = [];
  for (const series of order) {
    for (const candidate of [series, ...shuffle(eligible.filter((s) => s !== series), rng)]) {
      const item = pickItem(candidate);
      if (item) {
        plan.push(item);
        break;
      }
    }
  }
  return plan;
}
