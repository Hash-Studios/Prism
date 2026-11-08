import assert from "node:assert/strict";
import test from "node:test";
import {readFileSync} from "node:fs";
import path from "node:path";
import * as admin from "firebase-admin";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";
import {notificationCopyPayload} from "../notificationCatalog";
import {sendToUser} from "../notificationHelper";
import {buildWrappedDocs, claimWrappedNotification, notifyWrapped} from "../scripts/buildWrapped";
import {
  buildWrapped,
  CreatorProfile,
  longestRun,
  loadWallIndex,
  readCreatorProfile,
  readWrappedSignals,
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

const MAYA: CreatorProfile = {uid: "maya", username: "maya"};


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
  assert.deepEqual(card(doc.cards, "creator")?.creator, {username: "maya"}, "only the public username is persisted");
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

test("on-screen ties prefer the most recently saved wall, then the wall id", () => {
  const base = heavy({ai: {count: 0, image: ""}, folders: {count: 0, cover: ""}, claimDays: []});
  const recent = buildWrapped({...base, uses: new Map([["W2", 4], ["W5", 4]])}, MAYA, WINDOW, NOW)!;
  assert.equal(card(recent.cards, "onScreen")?.hero.wallId, "W5");

  const sameTimeSaves = base.saves.map((saved) => saved.wallId === "W2" || saved.wallId === "W5" ?
    {...saved, savedAt: day("2026-10-01")} : saved);
  const byId = buildWrapped({...base, saves: sameTimeSaves, uses: new Map([["W5", 4], ["W2", 4]])}, MAYA, WINDOW, NOW)!;
  assert.equal(card(byId.cards, "onScreen")?.hero.wallId, "W2");
  assert.equal(card(byId.cards, "onScreen")?.hero.url, "https://img/W2.jpg");
  assert.notEqual(byId.cards[0].hero.url, "https://img/W2.jpg", "the earlier intro reserves the winning wall when possible");
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

test("creator profile requires a live account and exposes only its public username", async (t) => {
  const store = installFakeDb(t, {"profiles/maya": {username: "public-maya", name: "Maya",
    profilePhoto: "https://example.com/photo"}, "usersv2/maya": {username: "private-maya", deleted: false}});
  assert.deepEqual(await readCreatorProfile(db, "maya"), {uid: "maya", username: "public-maya"});
  store.delete("usersv2/maya");
  assert.equal(await readCreatorProfile(db, "maya"), null, "an orphaned public profile is not eligible");
  store.set("usersv2/maya", {username: "private-maya", deleted: true});
  assert.equal(await readCreatorProfile(db, "maya"), null, "a deleted creator is not eligible");
  store.set("usersv2/maya", {username: "private-maya", deleted: false});
  store.delete("profiles/maya");
  assert.equal(await readCreatorProfile(db, "maya"), null, "a missing public profile is not eligible");
});

test("coin signals page through large ledgers without dropping aggregates", async (t) => {
  const seed: Record<string, Record<string, unknown>> = {};
  Array.from({length: 1002}, (_, index) => {
    const id = `coinTransactions/c${String(index).padStart(4, "0")}`;
    const createdAt = admin.firestore.Timestamp.fromMillis(Date.parse("2026-06-01T00:00:00Z") + index);
    seed[id] = {userId: "me", createdAt, action: index < 501 ? "tipSent" : "dailyLogin", delta: -1};
  });
  installFakeDb(t, seed);
  const pageSizes: number[] = [];
  const originalCollection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    const collection = originalCollection(name);
    if (name !== "coinTransactions") return collection;
    const wrap = (query: object): object => new Proxy(query, {get: (target, key, receiver) => {
      const value: unknown = Reflect.get(target, key, receiver);
      if (typeof value !== "function") return value;
      if (["where", "orderBy", "startAfter", "limit"].includes(String(key))) {
        return (...args: unknown[]) => {
          if (key === "limit") pageSizes.push(args[0] as number);
          return wrap(Reflect.apply(value, target, args) as object);
        };
      }
      return value.bind(target);
    }});
    return wrap(collection) as ReturnType<typeof db.collection>;
  });
  const signals = await readWrappedSignals(db, "me", {}, new Map(), WINDOW);
  assert.deepEqual(signals.tips, {count: 501, coins: 501});
  assert.deepEqual(signals.claimDays, ["2026-06-01"]);
  assert.deepEqual(pageSizes, [500, 500, 500], "coin reads use bounded Firestore pages");
});

test("ranged signal reads order by the direction of their deployed composite index", async (t) => {
  installFakeDb(t, {});
  const orders: Record<string, unknown[][]> = {};
  const originalCollection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    const collection = originalCollection(name);
    if (name !== "coinTransactions" && name !== "aiGenerations") return collection;
    const wrap = (query: object): object => new Proxy(query, {get: (target, key, receiver) => {
      const value: unknown = Reflect.get(target, key, receiver);
      if (typeof value !== "function") return value;
      if (["where", "orderBy", "startAfter", "limit"].includes(String(key))) {
        return (...args: unknown[]) => {
          if (key === "orderBy") (orders[name] ??= []).push(args);
          return wrap(Reflect.apply(value, target, args) as object);
        };
      }
      return value.bind(target);
    }});
    return wrap(collection) as ReturnType<typeof db.collection>;
  });
  await readWrappedSignals(db, "me", {}, new Map(), WINDOW);
  const indexes = (JSON.parse(readFileSync(path.join(__dirname, "../../../firestore.indexes.json"), "utf8")) as {
    indexes: Array<{collectionGroup: string; fields: Array<{fieldPath: string; order?: string}>}>;
  }).indexes;
  for (const name of ["coinTransactions", "aiGenerations"]) {
    assert.ok(orders[name]?.length, `${name} is read in createdAt order`);
    for (const [field, direction] of orders[name]) {
      assert.equal(field, "createdAt");
      const order = direction === "desc" ? "DESCENDING" : "ASCENDING";
      assert.ok(indexes.some((index) => index.collectionGroup === name &&
        index.fields[0]?.fieldPath === "userId" && index.fields[1]?.fieldPath === "createdAt" &&
        index.fields[1]?.order === order), `${name} has a (userId, createdAt ${order}) index`);
    }
  }
});

test("claim days use the server-locked, clamped claim offset", async (t) => {
  const timestamp = (iso: string) => admin.firestore.Timestamp.fromDate(new Date(iso));
  installFakeDb(t, {
    "coinTransactions/late": {userId: "me", action: "dailyLogin", createdAt: timestamp("2026-04-01T20:00:00Z")},
  });
  const locked = await readWrappedSignals(db, "me",
    {coinState: {streakTimezoneOffsetMinutes: 0, streakClaimTimezoneOffsetMinutes: 330}}, new Map(), WINDOW);
  assert.deepEqual(locked.claimDays, ["2026-04-02"], "the locked claim offset wins over the client offset");
  const huge = await readWrappedSignals(db, "me",
    {coinState: {streakTimezoneOffsetMinutes: 1e12}}, new Map(), WINDOW);
  assert.deepEqual(huge.claimDays, ["2026-04-02"], "an out-of-range offset is clamped to +14:00");
});

test("signal reads deduplicate saves, prefer favouritedAt, keep legacy fallback, filter by user and use the UTC offset", async (t) => {
  const timestamp = (iso: string) => admin.firestore.Timestamp.fromDate(new Date(iso));
  const seed = {
    "usersv2/me/images/BOTH": {id: "BOTH", provider: "Prism", favouritedAt: timestamp("2026-02-02T00:00:00Z"),
      createdAt: timestamp("2026-02-01T00:00:00Z")},
    "usersv2/me/images/LEGACY": {id: "LEGACY", provider: "Prism", createdAt: timestamp("2026-03-01T00:00:00Z")},
    "usersv2/me/images/FAVOURITED": {id: "FAVOURITED", provider: "Prism",
      favouritedAt: timestamp("2026-04-01T00:00:00Z"), createdAt: timestamp("2025-12-01T00:00:00Z")},
    "usersv2/me/images/OUTSIDE": {id: "OUTSIDE", provider: "Prism",
      favouritedAt: timestamp("2025-12-31T00:00:00Z"), createdAt: timestamp("2026-05-01T00:00:00Z")},
    "usersv2/me/images/EXTERNAL": {id: "EXTERNAL", provider: "Pexels",
      favouritedAt: timestamp("2026-06-01T00:00:00Z")},
    "usersv2/me/images/pexels_EXTERNAL": {id: "EXTERNAL", provider: "Pexels",
      favouritedAt: timestamp("2026-06-01T00:00:00Z")},
    "usersv2/me/images/wallhaven_EXTERNAL": {id: "EXTERNAL", provider: "Wallhaven",
      favouritedAt: timestamp("2026-06-01T00:00:00Z")},
    "usersv2/me/images/OLD": {id: "OLD", provider: "Prism", createdAt: timestamp("2025-12-31T00:00:00Z")},
    "coinTransactions/local-day": {userId: "me", action: "dailyLogin", createdAt: timestamp("2026-01-01T20:00:00Z")},
    "coinTransactions/end-exclusive": {userId: "me", action: "dailyLogin", createdAt: timestamp("2026-11-25T12:00:00Z")},
    "coinTransactions/other-user": {userId: "other", action: "tipSent", delta: -99,
      createdAt: timestamp("2026-01-02T00:00:00Z")},
  };
  installFakeDb(t, seed);
  const signals = await readWrappedSignals(db, "me", {coinState: {streakTimezoneOffsetMinutes: 330}}, new Map(), WINDOW);
  assert.deepEqual(signals.saves.map((saved) => [saved.wallId, saved.savedAt]).sort(([a], [b]) =>
    String(a).localeCompare(String(b))), [
    ["BOTH", Date.parse("2026-02-02T00:00:00Z")],
    ["EXTERNAL", Date.parse("2026-06-01T00:00:00Z")],
    ["EXTERNAL", Date.parse("2026-06-01T00:00:00Z")],
    ["FAVOURITED", Date.parse("2026-04-01T00:00:00Z")],
    ["LEGACY", Date.parse("2026-03-01T00:00:00Z")],
  ]);
  assert.deepEqual(signals.claimDays, ["2026-01-02"]);
  assert.deepEqual(signals.tips, {count: 0, coins: 0});
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

test("eligible users without saves use their own signal images for intro and summary heroes", () => {
  const signals = heavy({
    saves: [],
    walls: new Map(),
    claimDays: ["2026-05-01", "2026-05-02", "2026-05-03"],
    ai: {count: 10, image: "https://img/own-ai.jpg"},
    folders: {count: 1, cover: "https://img/own-folder.jpg"},
    challenges: {count: 1, wallId: "own-wall"},
    tips: {count: 0, coins: 0},
    uses: new Map(),
  });
  const doc = buildWrapped(signals, null, WINDOW, NOW);
  assert.ok(doc);
  for (const item of doc.cards) assert.notEqual(item.hero.url, "", `${item.id} has an image`);
  assert.equal(doc.cards[0].hero.url, "https://img/own-ai.jpg");
  assert.equal(doc.cards.at(-1)?.hero.url, "https://img/own-ai.jpg");
});

test("the window starts on 1 January UTC and ends at build time, never past the year", () => {
  assert.deepEqual(wrappedWindow(new Date("2026-11-25T12:00:00Z")),
    {startMs: Date.UTC(2026, 0, 1), endMs: Date.parse("2026-11-25T12:00:00Z")});
  assert.equal(wrappedWindow(new Date("2027-02-01T00:00:00Z")).endMs, Date.UTC(2027, 0, 1));
});

test("the wall index loads large collections in bounded pages", async () => {
  const docs = Array.from({length: 501}, (_, index) => {
    const id = `W${String(index + 1).padStart(4, "0")}`;
    return {id, data: () => ({id, colors: ["blue"], creatorUid: "creator", category: "Nature"})};
  });
  let cursor = "";
  let calls = 0;
  const pageSizes: number[] = [];
  type FakeQuery = {
    select: () => FakeQuery;
    orderBy: (field: unknown) => FakeQuery;
    limit: (size: number) => FakeQuery;
    startAfter: (doc: {id: string}) => FakeQuery;
    get: () => Promise<{docs: typeof docs; size: number}>;
  };
  const query: FakeQuery = {
    select: () => query,
    orderBy: () => query,
    limit: (size: number) => {
      pageSizes.push(size);
      return query;
    },
    startAfter: (doc: {id: string}) => {
      cursor = doc.id;
      return query;
    },
    get: async () => {
      calls += 1;
      const remaining = cursor ? docs.filter((doc) => doc.id > cursor) : docs;
      const page = remaining.slice(0, 500);
      cursor = "";
      return {docs: page, size: page.length};
    },
  };
  const fakeDb = {collection: () => query} as unknown as admin.firestore.Firestore;
  const walls = await loadWallIndex(fakeDb);
  assert.equal(calls, 2);
  assert.deepEqual(pageSizes, [500, 500]);
  assert.equal(walls.size, 501);
});

test("the Wrapped jobs reject invalid page, concurrency, and time options before reading Firestore", async () => {
  const noFirestore = new Proxy({}, {
    get: () => {
      throw new Error("Unexpected Firestore access");
    },
  }) as admin.firestore.Firestore;
  for (const options of [
    {concurrency: 0}, {concurrency: Number.NaN}, {concurrency: 51}, {pageSize: 0}, {pageSize: 1.5},
    {maxPages: 0}, {maxPages: Number.NaN}, {now: new Date(Number.NaN)},
  ]) {
    await assert.rejects(() => buildWrappedDocs(noFirestore, {apply: false, ...options}), /Invalid/);
    await assert.rejects(() => notifyWrapped(noFirestore, {apply: false, ...options}), /Invalid/);
  }
});

test("the yearly notification claim survives deleting and rebuilding an ineligible Wrapped doc", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {email: "u1@example.com"},
    "wrapped/u1/years/2026": {uid: "u1", year: 2026},
    "wrappedRuns/2026": {phase: "built", runId: "run-1"},
  });
  const copy = notificationCopyPayload({kind: "wrappedReady", year: 2026});

  const email = await claimWrappedNotification(db, "u1", db.doc("wrapped/u1/years/2026"), "run-1", copy);
  assert.equal(email, "u1@example.com");
  assert.ok(store.get("wrapped/u1")?.notifiedAt_2026);
  const inbox = store.get("notifications/wrapped_2026_u1");
  assert.ok(inbox?.createdAt);
  assert.deepEqual({...inbox, createdAt: undefined}, {
    notification: {title: copy.title, body: copy.body},
    message: {kind: copy.message.kind, args: copy.message.args},
    data: {route: "wrapped", imageUrl: "", url: "", pageName: "", arguments: []},
    modifier: email,
    pushHandled: true,
    createdAt: undefined,
  });

  store.delete("wrapped/u1/years/2026");
  store.set("wrapped/u1/years/2026", {uid: "u1", year: 2026});
  assert.equal(await claimWrappedNotification(db, "u1", db.doc("wrapped/u1/years/2026"), "run-1", copy), null,
    "a doc recreated after an ineligible period cannot claim a second notice");

  // Account deletion clears the inbox after the claim. The late push path must not recreate it.
  await db.doc("notifications/wrapped_2026_u1").delete();
  await db.doc("usersv2/u1").set({deleted: true, email: ""});
  await sendToUser({
    ...copy, data: {route: "wrapped"}, modifier: "u1@example.com", channelId: "recommendations",
    docId: "wrapped_2026_u1", pushOnly: true,
  }, {uid: "u1", email: "", loggedOut: true});
  assert.equal(store.has("notifications/wrapped_2026_u1"), false);
});
