import assert from "node:assert/strict";
import test from "node:test";
import {parseStudioConfig, STUDIO_MAX_CANDIDATES_PER_DAY} from "../studio/config";
import {randomWallId, studioCandidateId} from "../studio/ids";
import {buildDailyPlan, type StudioPlanInput, studioTags} from "../studio/plan";
import {STUDIO_COMPOSITION, STUDIO_SERIES, STUDIO_SUBJECT_COOLDOWN_DAYS, type StudioSeries} from "../studio/series";
import {seededRng} from "./studioTestUtil";

const plan = (patch: Partial<StudioPlanInput> = {}) => buildDailyPlan({
  series: STUDIO_SERIES, count: 10, weights: {}, recentSubjectIds: new Set(), rng: seededRng(1), ...patch,
});
const countBy = <T>(items: T[], key: (item: T) => string) => items.reduce((m, item) =>
  m.set(key(item), (m.get(key(item)) ?? 0) + 1), new Map<string, number>());
const afterDark = STUDIO_SERIES.find((s) => s.id === "after-dark") as StudioSeries;

test("subject ids are unique across all series, because cooldown docs are keyed by subject id", () => {
  const ids = STUDIO_SERIES.flatMap((s) => s.subjects.map((subject) => subject.id));
  assert.equal(new Set(ids).size, ids.length);
});

test("the same rng gives the same plan, another seed gives another plan", () => {
  assert.deepEqual(plan({rng: seededRng(7)}), plan({rng: seededRng(7)}));
  assert.notDeepEqual(plan({rng: seededRng(7)}), plan({rng: seededRng(8)}));
});

test("the catalog fills ten candidates every day under the cooldown, for 120 days", () => {
  // planRun treats a subject as recent while lastUsedAt >= now - cooldown, so a subject used on day d is
  // blocked through day d + STUDIO_SUBJECT_COOLDOWN_DAYS.
  for (const seed of [1, 2, 3]) {
    const rng = seededRng(seed);
    const lastUsed = new Map<string, number>();
    for (let day = 0; day < 120; day++) {
      const recentSubjectIds = new Set([...lastUsed].filter(([, d]) => day - d <= STUDIO_SUBJECT_COOLDOWN_DAYS)
        .map(([id]) => id));
      const items = plan({recentSubjectIds, rng});
      assert.equal(items.length, 10, `seed ${seed}, day ${day}`);
      for (const item of items) lastUsed.set(item.subjectId, day);
    }
  }
});

test("equal weights spread ten candidates 4/3/3, with no subject twice and at most two per category", () => {
  for (let seed = 1; seed <= 50; seed++) {
    const items = plan({rng: seededRng(seed)});
    assert.equal(items.length, 10);
    assert.deepEqual([...countBy(items, (i) => i.seriesId).values()].sort(), [3, 3, 4]);
    assert.equal(new Set(items.map((i) => i.subjectId)).size, 10);
    for (const n of countBy(items, (i) => i.category).values()) assert.ok(n <= 2, `seed ${seed}`);
  }
});

test("weights move the slots and weight 0 leaves a series out", () => {
  const weighted = plan({weights: {"after-dark": 3}});
  assert.deepEqual(Object.fromEntries(countBy(weighted, (i) => i.seriesId)),
    {"after-dark": 6, "quiet-architecture": 2, "paper-worlds": 2});
  const without = plan({weights: {"after-dark": 0}});
  assert.equal(without.length, 10);
  assert.ok(without.every((i) => i.seriesId !== "after-dark"));
});

test("subjects on cooldown are skipped while a series has fresh ones", () => {
  const recent = new Set(STUDIO_SERIES.flatMap((s) => s.subjects.filter((_, i) => i % 2 === 0).map((x) => x.id)));
  for (let seed = 1; seed <= 20; seed++) {
    assert.ok(plan({recentSubjectIds: recent, rng: seededRng(seed)}).every((i) => !recent.has(i.subjectId)));
  }
  const allButEclipse = new Set(afterDark.subjects.map((s) => s.id).filter((id) => id !== "eclipse"));
  assert.equal(plan({series: [afterDark], count: 1, recentSubjectIds: allButEclipse})[0].subjectId, "eclipse");
  assert.deepEqual(plan({series: [afterDark], count: 1, recentSubjectIds: new Set(afterDark.subjects.map((s) => s.id))}), []);
});

test("finite weights near the numeric limit still produce the requested plan", () => {
  const items = plan({weights: {
    "after-dark": Number.MAX_VALUE,
    "quiet-architecture": Number.MAX_VALUE,
    "paper-worlds": Number.MAX_VALUE,
  }});
  assert.equal(items.length, 10);
});

test("the category cap holds only for a mixed plan of ten or fewer", () => {
  const big = plan({count: 30});
  assert.equal(big.length, 30);
  assert.equal(new Set(big.map((i) => i.subjectId)).size, 30);
  assert.ok([...countBy(big, (i) => i.category).values()].some((n) => n > 2));
  const single = plan({series: [afterDark], count: 10});
  assert.equal(single.length, 10);
});

test("a series with too few subjects gives its slots away, and the plan ends when every series is out", () => {
  const tiny: StudioSeries = {...afterDark, id: "tiny", subjects: afterDark.subjects.slice(0, 2)};
  assert.equal(plan({series: [tiny], count: 5}).length, 2);
  const mixed = plan({series: [tiny, STUDIO_SERIES[2]], count: 8});
  assert.equal(mixed.length, 8);
  assert.equal(mixed.filter((i) => i.seriesId === "tiny").length, 2);
});

test("prompt, title, category and seed follow the series data", () => {
  const [item] = plan({series: [afterDark], count: 1, rng: seededRng(3)});
  const subject = afterDark.subjects.find((s) => s.id === item.subjectId) as StudioSeries["subjects"][number];
  const palette = afterDark.palettes.find((p) => p.id === item.paletteId) as StudioSeries["palettes"][number];
  assert.equal(item.prompt, `${subject.prompt}, ${palette.prompt}. ${afterDark.style} ${STUDIO_COMPOSITION}`);
  assert.equal(item.title, `${subject.title} · ${palette.name}`);
  assert.equal(item.category, subject.category ?? afterDark.category);
  assert.ok(Number.isInteger(item.seed) && item.seed >= 0 && item.seed < 2 ** 31);
});

test("titles are at most 60 characters", () => {
  const long: StudioSeries = {
    ...afterDark,
    subjects: [{...afterDark.subjects[0], title: "A very long subject title ".repeat(4)}],
  };
  const [item] = plan({series: [long], count: 1});
  assert.ok(item.title.length <= 60);
  assert.ok(item.title.startsWith("A very long subject title"));
});

test("tags are unique, lower case, at most 24 characters and at most 8", () => {
  assert.deepEqual(studioTags(["AMOLED", "dark"], ["Dark", " Night ", "x".repeat(25)], ["orange"]),
    ["amoled", "dark", "night", "orange"]);
  assert.equal(studioTags(["a", "b", "c", "d", "e"], ["f", "g", "h", "i", "j"]).length, 8);
  for (const item of plan({count: 30})) {
    assert.ok(item.tags.length <= 8 && item.tags.every((t) => t === t.toLowerCase() && t.length <= 24));
    assert.equal(new Set(item.tags).size, item.tags.length);
    assert.ok(!item.tags.includes("prism studio"));
  }
});

test("wall ids look like the app's randomUploadId(10): ten capitals with exactly one digit", () => {
  for (let seed = 1; seed <= 200; seed++) {
    const id = randomWallId(seededRng(seed));
    assert.match(id, /^[A-Z0-9]{10}$/);
    assert.equal(id.replace(/[A-Z]/g, "").length, 1, id);
  }
  assert.equal(randomWallId(seededRng(5)), randomWallId(seededRng(5)));
  assert.match(randomWallId(), /^[A-Z0-9]{10}$/);
});

test("candidate ids keep to [A-Za-z0-9_-] and 8 to 64 characters", () => {
  assert.equal(studioCandidateId("d20261012", 3), "d20261012-3");
  assert.equal(studioCandidateId("m1.2 3/x", 0), "m1_2_3_x-0");
  assert.equal(studioCandidateId("r".repeat(80), 1).length, 64);
  assert.throws(() => studioCandidateId("d1", 0));
});

test("config is off without the flag or an identity email, and numbers are clamped", () => {
  const off = parseStudioConfig(undefined);
  assert.equal(off.generationEnabled, false);
  assert.deepEqual([off.dailyCandidates, off.maxCandidatesPerDay, off.width, off.height], [10, 30, 1440, 3200]);
  assert.equal(off.model, "openai/gpt-image-2.5/sunburst/text-to-image");
  const identity = {by: "Prism Studio", email: "studio@example.com", userPhoto: "https://p/s.png"};
  assert.equal(parseStudioConfig({generationEnabled: true, identity}).generationEnabled, true);
  assert.deepEqual(parseStudioConfig({generationEnabled: true, identity}).identity, identity);
  assert.equal(parseStudioConfig({generationEnabled: true}).generationEnabled, false);
  assert.equal(parseStudioConfig({generationEnabled: true, identity: {...identity, email: " "}}).generationEnabled, false);
  assert.equal(parseStudioConfig({generationEnabled: "yes", identity}).generationEnabled, false);
  const clamped = parseStudioConfig({generationEnabled: true, identity, dailyCandidates: 100, maxCandidatesPerDay: 99,
    width: -5, height: 2.5});
  assert.equal(clamped.generationEnabled, false);
  assert.deepEqual([clamped.dailyCandidates, clamped.maxCandidatesPerDay, clamped.width, clamped.height],
    [30, STUDIO_MAX_CANDIDATES_PER_DAY, -5, 2.5]);
  assert.equal(parseStudioConfig({dailyCandidates: 0}).dailyCandidates, 1);
  assert.deepEqual(parseStudioConfig({seriesWeights: {"a": 2, "b": -1, "c": "x", "d": 0}}).seriesWeights, {a: 2, d: 0});
  const customModel = parseStudioConfig({generationEnabled: true, identity, model: "unlisted/model"});
  assert.equal(customModel.generationEnabled, true);
  assert.equal(customModel.model, "unlisted/model");
  const invalidDimensions = parseStudioConfig({generationEnabled: true, identity, width: 1400, height: 2500});
  assert.equal(invalidDimensions.generationEnabled, false);
  assert.deepEqual([invalidDimensions.width, invalidDimensions.height], [1400, 2500]);
});
