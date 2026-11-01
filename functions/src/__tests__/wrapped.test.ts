import assert from "node:assert/strict";
import test from "node:test";
import {
  buildWrapped,
  CreatorProfile,
  longestRun,
  SavedWall,
  topColours,
  topCreator,
  WallInfo,
  WrappedCard,
  WrappedSignals,
  wrappedWindow,
} from "../wrapped";

const NOW = new Date("2026-11-25T12:00:00Z");
const WINDOW = wrappedWindow(NOW);
const day = (iso: string) => Date.parse(`${iso}T10:00:00Z`);

function save(wallId: string, savedOn: string, extra: Partial<SavedWall> = {}): SavedWall {
  return {wallId, prism: true, thumb: `https://img/${wallId}.jpg`, savedAt: day(savedOn), category: "", ...extra};
}

function wall(colors: string[], creatorUid: string, category = ""): WallInfo {
  return {colors, creatorUid, category, thumb: ""};
}

const MAYA: CreatorProfile = {uid: "maya", username: "maya", name: "Maya", photo: ""};

/** A heavy user: twelve saves, a 5-day run, AI walls, a folder, a challenge entry, tips and a much-used wall. */
function heavy(overrides: Partial<WrappedSignals> = {}): WrappedSignals {
  const walls = new Map<string, WallInfo>();
  const saves: SavedWall[] = [];
  for (let i = 1; i <= 12; i++) {
    const id = `W${i}`;
    walls.set(id, wall(i <= 6 ? ["purple", "blue", "pink"] : ["blue", "teal"], i <= 4 ? "maya" : `c${i}`,
      i <= 5 ? "Nature" : "Space"));
    saves.push(save(id, `2026-0${1 + (i % 9)}-1${i % 10}`));
  }
  return {
    uid: "me",
    saves,
    walls,
    claimDays: ["2026-03-10", "2026-03-11", "2026-03-12", "2026-03-13", "2026-03-14", "2026-04-01"],
    ai: {count: 2, image: "https://img/ai.jpg"},
    folders: {count: 1, cover: "https://img/folder.jpg"},
    challenges: {count: 1, wallId: "W3"},
    tips: {count: 2, coins: 20},
    uses: new Map([["W2", 4], ["W5", 1]]),
    ...overrides,
  };
}

const ids = (cards: WrappedCard[]) => cards.map((card) => card.id);
const card = (cards: WrappedCard[], id: string) => cards.find((c) => c.id === id);

test("a heavy year builds every stat from seeded data, capped at nine cards", () => {
  const doc = buildWrapped(heavy(), MAYA, WINDOW, NOW);
  assert.ok(doc);
  assert.deepEqual(ids(doc.cards), ["intro", "saves", "colours", "creator", "streak", "ai", "category", "folders", "summary"]);
  assert.equal(card(doc.cards, "saves")?.value, 12);
  assert.deepEqual(card(doc.cards, "colours")?.colours, ["blue", "purple", "teal"]);
  assert.equal(card(doc.cards, "creator")?.value, 4);
  assert.deepEqual(card(doc.cards, "creator")?.creator, MAYA);
  assert.equal(card(doc.cards, "streak")?.value, 5);
  assert.equal(card(doc.cards, "ai")?.value, 2);
  assert.equal(card(doc.cards, "category")?.category, "Space");
  assert.equal(card(doc.cards, "category")?.value, 7);
  assert.equal(card(doc.cards, "folders")?.value, 1);
  assert.equal(doc.actions, 12 + 2 + 1 + 1 + 2);
  assert.deepEqual(doc.accents, ["blue", "purple", "teal"]);
  assert.equal(doc.through.toMillis(), NOW.getTime());
});

test("without the cap the later stats keep their own values", () => {
  const doc = buildWrapped(heavy({ai: {count: 0, image: ""}, folders: {count: 0, cover: ""}, claimDays: []}),
    MAYA, WINDOW, NOW);
  assert.ok(doc);
  assert.deepEqual(ids(doc.cards), ["intro", "saves", "colours", "creator", "category", "onScreen", "challenges", "tips",
    "summary"]);
  assert.equal(card(doc.cards, "onScreen")?.value, 4);
  assert.equal(card(doc.cards, "onScreen")?.hero.wallId, "W2");
  assert.equal(card(doc.cards, "challenges")?.value, 1);
  assert.equal(card(doc.cards, "tips")?.value, 2);
  assert.equal(card(doc.cards, "tips")?.coins, 20);
});

test("signals that start late carry since; full-year signals do not", () => {
  const doc = buildWrapped(heavy({folders: {count: 0, cover: ""}, claimDays: []}), MAYA, WINDOW, NOW);
  assert.ok(doc);
  const since = Object.fromEntries(doc.cards.map((c) => [c.id, c.since ?? null]));
  assert.equal(since.saves, null);
  assert.equal(since.colours, null);
  assert.equal(since.creator, null);
  assert.equal(since.category, null);
  assert.equal(since.ai, "2026-02-19");
  assert.equal(since.onScreen, "2026-10-30");
  assert.equal(since.challenges, "2026-10-30");
  const streak = buildWrapped(heavy(), MAYA, WINDOW, NOW);
  assert.equal(card(streak!.cards, "streak")?.since, "2026-03-02");
  assert.equal(card(streak!.cards, "folders")?.since, "2026-10-27");
});

test("weak stats are skipped, never shown as zero", () => {
  const light = heavy({
    saves: heavy().saves.slice(0, 10),
    ai: {count: 0, image: ""},
    folders: {count: 0, cover: ""},
    challenges: {count: 0, wallId: ""},
    tips: {count: 0, coins: 0},
    uses: new Map([["W2", 1]]),
    claimDays: ["2026-05-01", "2026-05-02", "2026-05-03"],
  });
  assert.equal(buildWrapped({...light, claimDays: ["2026-05-01", "2026-05-02"]}, null, WINDOW, NOW), null,
    "a 2-day run is below the floor, which leaves three stats");
  const doc = buildWrapped(light, null, WINDOW, NOW);
  assert.ok(doc);
  assert.deepEqual(ids(doc.cards), ["intro", "saves", "colours", "streak", "category", "summary"]);
  for (const c of doc.cards) {
    if (typeof c.value === "number") assert.ok(c.value > 0, `${c.id} has value ${c.value}`);
  }
  assert.equal(card(doc.cards, "ai"), undefined);
  assert.equal(card(doc.cards, "creator"), undefined, "no profile means no creator card");
  assert.equal(card(doc.cards, "onScreen"), undefined, "one use is below the floor");
});

test("eligibility needs ten actions and four strong stats", () => {
  const nine = heavy({
    saves: heavy().saves.slice(0, 9),
    ai: {count: 0, image: ""},
    folders: {count: 0, cover: ""},
    challenges: {count: 0, wallId: ""},
    tips: {count: 0, coins: 0},
  });
  assert.equal(buildWrapped(nine, MAYA, WINDOW, NOW), null, "nine actions is not enough");
  assert.ok(buildWrapped({...nine, tips: {count: 1, coins: 5}}, MAYA, WINDOW, NOW), "ten actions with strong stats");

  const thin = heavy({
    saves: Array.from({length: 10}, (_, i) => save(`X${i}`, "2026-06-01", {prism: false})),
    walls: new Map(),
    claimDays: [],
    ai: {count: 0, image: ""},
    folders: {count: 0, cover: ""},
    challenges: {count: 0, wallId: ""},
    tips: {count: 0, coins: 0},
    uses: new Map(),
  });
  assert.equal(buildWrapped(thin, null, WINDOW, NOW), null, "ten saves with nothing else is one stat card");
  assert.equal(buildWrapped(heavy({saves: [], walls: new Map()}), MAYA, WINDOW, NOW), null);
});

test("top colours need three coloured walls and break ties by palette order", () => {
  const walls = new Map([["A", wall(["red"], "x")], ["B", wall(["blue"], "x")], ["C", wall(["green"], "x")]]);
  const saves = [save("A", "2026-02-01"), save("B", "2026-02-02"), save("C", "2026-02-03")];
  assert.deepEqual(topColours(saves, walls), {ids: ["red", "green", "blue"], walls: 3});
  assert.deepEqual(topColours([save("Z", "2026-02-01", {prism: false})], walls), {ids: [], walls: 0});
});

test("top creator ignores the user's own walls and breaks ties by the latest save, then uid", () => {
  const walls = new Map([
    ["A", wall([], "me")], ["B", wall([], "me")], ["C", wall([], "zed")], ["D", wall([], "amy")],
    ["E", wall([], "zed")], ["F", wall([], "amy")],
  ]);
  const base = {uid: "me", walls};
  assert.deepEqual(topCreator({...base, saves: [save("A", "2026-01-01"), save("B", "2026-01-02"),
    save("C", "2026-01-03"), save("D", "2026-01-04"), save("E", "2026-01-05"), save("F", "2026-01-06")]}),
  {uid: "amy", count: 2}, "same count, amy saved most recently");
  assert.deepEqual(topCreator({...base, saves: [save("C", "2026-01-03"), save("D", "2026-01-03")]}),
    {uid: "amy", count: 1}, "same count and day, uid decides");
  assert.equal(topCreator({...base, saves: [save("A", "2026-01-01")]}), null);
});

test("top category skips the default General and breaks ties by the latest save", () => {
  const walls = new Map([["A", wall([], "x", "General")], ["B", wall([], "x", "Anime")], ["C", wall([], "x", "Cars")]]);
  const signals = heavy({
    walls,
    saves: [
      save("A", "2026-01-01"), save("A2", "2026-01-01", {prism: false, category: "General"}),
      save("B", "2026-01-02"), save("B2", "2026-01-03", {prism: false, category: "Anime"}),
      save("B3", "2026-01-04", {prism: false, category: "Anime"}),
      save("C", "2026-01-05"), save("C2", "2026-01-06", {prism: false, category: "Cars"}),
      save("C3", "2026-01-07", {prism: false, category: "Cars"}),
      save("D1", "2026-01-08", {prism: false}), save("D2", "2026-01-09", {prism: false}),
    ],
  });
  const doc = buildWrapped(signals, null, WINDOW, NOW);
  assert.equal(card(doc!.cards, "category")?.category, "Cars");
  assert.equal(card(doc!.cards, "category")?.value, 3);
});

test("longest run counts consecutive local days once each", () => {
  assert.equal(longestRun([]), 0);
  assert.equal(longestRun(["2026-03-01", "2026-03-01", "2026-03-02", "2026-03-04"]), 2);
  assert.equal(longestRun(["2026-12-31", "2026-12-30", "2026-12-29"]), 3);
});

test("heroes are the user's own walls and cards in a row avoid repeats", () => {
  const doc = buildWrapped(heavy(), MAYA, WINDOW, NOW)!;
  const urls = doc.cards.filter((c) => c.id !== "summary").map((c) => c.hero.url);
  for (const url of urls) assert.match(url, /^https:\/\/img\//);
  assert.equal(new Set(urls).size, urls.length);
  assert.equal(card(doc.cards, "ai")?.hero.url, "https://img/ai.jpg");
  const summary = card(doc.cards, "summary");
  assert.equal((summary?.thumbs as string[]).length, 4);
});

test("the window starts on 1 January UTC and ends at build time, never past the year", () => {
  assert.deepEqual(wrappedWindow(new Date("2026-11-25T12:00:00Z")),
    {startMs: Date.UTC(2026, 0, 1), endMs: Date.parse("2026-11-25T12:00:00Z")});
  assert.equal(wrappedWindow(new Date("2027-02-01T00:00:00Z")).endMs, Date.UTC(2027, 0, 1));
});
