import type {Rng} from "./ids";
import {STUDIO_COMPOSITION, type StudioPalette, type StudioSeries, type StudioSubject} from "./series";

export const STUDIO_TITLE_MAX_LENGTH = 60;
export const STUDIO_TAG_MAX_LENGTH = 24;
export const STUDIO_MAX_TAGS = 8;
/** A plan of up to STUDIO_CATEGORY_CAP_MAX_COUNT candidates over more than one series has at most this many per category. */
export const STUDIO_CATEGORY_CAP = 2;
export const STUDIO_CATEGORY_CAP_MAX_COUNT = 10;

export interface StudioPlanItem {
  seriesId: string;
  subjectId: string;
  paletteId: string;
  prompt: string;
  title: string;
  category: string;
  tags: string[];
  seed: number;
}

export interface StudioPlanInput {
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
  return `${subject.prompt}, ${palette.prompt}. ${series.style} ${STUDIO_COMPOSITION}`;
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
  const eligible = input.series.filter((s) => (input.weights[s.id] ?? 1) > 0 && s.subjects.length > 0 &&
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
