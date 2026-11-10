process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import * as remoteConfig from "firebase-admin/remote-config";
import {db} from "../common";
import {dropFromDiscovery} from "../folderSignals";
import {
  buildPages,
  categorySlug,
  cleanText,
  isCatalogChange,
  PAGE_SIZE,
  rebuildWebCatalog,
  sectionGroups,
  syncWebWall,
  webCatalogDeps,
  type WebCard,
  type WebWall,
} from "../webCatalog";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = "2026-10-31T00:00:00.000Z";
const THUMB = "https://img.prismwalls.com/previews/aaa.img";
const BLUR = "data:image/jpeg;base64,AAAA";

function stubDeps(t: TestContext, now: () => Date = () => new Date(NOW)) {
  t.mock.method(webCatalogDeps, "premium", async () => ["abstract"]);
  t.mock.method(webCatalogDeps, "blur", async () => BLUR);
  t.mock.method(webCatalogDeps, "now", now);
}

function liveWall(overrides: Doc = {}): Doc {
  return {
    id: "W1", review: true, originalProtected: true, wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "",
    thumb_path: "", thumb_sha: "", collections: ["community"], wallpaper_thumb: THUMB, title: "Sunset",
    desc: "Warm sky", tags: ["sky"], category: "Nature", colors: ["red", "notacolor"], resolution: "1080x2340",
    by: "Sam", creatorUid: "u1", email: "sam@example.com",
    createdAt: admin.firestore.Timestamp.fromMillis(Date.parse("2026-10-01T00:00:00Z")),
    ...overrides,
  };
}

const samProfile: Doc = {
  username: "sam", name: "Sam K", bio: "Hi", profilePhoto: "https://lh3.googleusercontent.com/p.jpg",
  email: "sam@example.com", links: {email: "sam@example.com"},
};

function keysDeep(value: unknown): string[] {
  if (Array.isArray(value)) return value.flatMap(keysDeep);
  if (value && typeof value === "object") return Object.entries(value).flatMap(([k, v]) => [k, ...keysDeep(v)]);
  return [];
}

function valuesDeep(value: unknown): unknown[] {
  if (Array.isArray(value)) return value.flatMap(valuesDeep);
  if (value && typeof value === "object") return Object.values(value).flatMap(valuesDeep);
  return [value];
}

function liveCard(n: number, overrides: Partial<WebWall> = {}): WebWall {
  const id = `W${String(n).padStart(2, "0")}`;
  return {
    state: "live", updatedAt: NOW, title: `Wall ${id}`, category: "Nature", categorySlug: "nature",
    width: 1080, height: 2340, thumb: `https://img.prismwalls.com/previews/${id}.img`,
    createdAt: new Date(Date.UTC(2026, 0, 1) + n * 86_400_000).toISOString(), creatorName: "", creator: null,
    ...overrides,
  };
}

function thirtyWalls(): Map<string, WebWall> {
  const walls = new Map<string, WebWall>();
  for (let n = 1; n <= 30; n++) walls.set(`W${String(n).padStart(2, "0")}`, liveCard(n));
  walls.set("GATED", {
    state: "gated", updatedAt: NOW, title: "Hidden", category: "Nature", categorySlug: "nature",
    createdAt: new Date(Date.UTC(2027, 0, 1)).toISOString(), creatorName: "", creator: null, blur: BLUR,
  });
  return walls;
}

function pageOf(pages: ReturnType<typeof buildPages>, key: string) {
  const doc = pages.get(key);
  assert.ok(doc, `missing page ${key}`);
  return doc as unknown as {
    kind: string; page: number; pages: number; total: number; items: WebCard[]; entries: string;
    sitemaps: Array<{name: string; lastmod: string}>; owner: {username: string; name: string; hasPage: boolean} | null;
  };
}

test("syncWebWall projects a live wall into webWalls with only public fields", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data();
  assert.deepEqual(doc, {
    state: "live",
    updatedAt: NOW,
    title: "Sunset",
    description: "Warm sky",
    category: "Nature",
    categorySlug: "nature",
    tags: ["sky"],
    colors: [{name: "red", hex: "#cc0000"}],
    width: 1080,
    height: 2340,
    createdAt: "2026-10-01T00:00:00.000Z",
    creatorName: "Sam K",
    creator: {username: "sam", name: "Sam K"},
    thumb: THUMB,
  });
});

test("syncWebWall titles and tags an untitled wall from its Vision labels", async (t) => {
  stubDeps(t);
  const cases: Array<[Doc, string, string[]]> = [
    [{visionLabels: ["Graphics", "Rock", "Rubble", "Natural material"]}, "Rock and rubble wallpaper", ["Rock", "Rubble"]],
    [{visionLabels: ["Blue", "Triangle", "Red"]}, "Blue triangle wallpaper", ["Triangle", "Blue", "Red"]],
    [{visionLabels: ["Natural landscape", "Landscape", "Cloud"]}, "Natural landscape and cloud wallpaper",
      ["Natural landscape", "Landscape", "Cloud"]],
    [{visionLabels: ["White", "Grey"], category: "Minimal"}, "White and grey minimal wallpaper", ["White", "Grey"]],
    [{visionLabels: ["Pink", "Purple"], category: "General"}, "Pink and purple wallpaper", ["Pink", "Purple"]],
    [{visionLabels: ["Graphics"], category: "General"}, "", []],
    [{visionLabels: ["Rock"], title: "Sunset", tags: ["sky"]}, "Sunset", ["sky"]],
    [{visionLabels: ["Rock"], title: "Sunset", tags: []}, "Sunset", ["Rock"]],
    [{visionLabels: ["Rock"], title: "", tags: ["sky"]}, "Rock wallpaper", ["sky"]],
    [{visionLabels: [42, {}, ["nested"]]}, "", []],
    [{visionLabels: "Rock"}, "", []],
  ];
  for (const [overrides, title, tags] of cases) {
    installFakeDb(t, {"walls/d1": liveWall({title: "", tags: [], ...overrides}), "profiles/u1": samProfile});
    await syncWebWall("W1");
    const doc = (await db.collection("webWalls").doc("W1").get()).data();
    assert.equal(doc?.title, title, JSON.stringify(overrides));
    assert.deepEqual(doc?.tags, tags, JSON.stringify(overrides));
  }
});

test("Vision labels ignore malformed values and clean, bound, and deduplicate public text", async (t) => {
  stubDeps(t);
  const longLabel = "A very long mountain range label that exceeds the limit";
  installFakeDb(t, {"walls/d1": liveWall({title: "", tags: [], visionLabels: [
    42, {}, ["nested"], null, "  Rock\u0000 formation  ", "rock formation", longLabel,
  ]})});

  await syncWebWall("W1");

  const doc = (await db.collection("webWalls").doc("W1").get()).data();
  assert.equal(doc?.title, "Rock formation and a very long mountain range labe… wallpaper");
  assert.deepEqual(doc?.tags, ["Rock formation", "A very long mountain range labe…"]);
  assert.ok((doc?.title as string).length <= 90);
  assert.ok((doc?.tags as string[]).every((tag) => tag.length <= 32));
});

test("a Vision label change re-projects the wall", () => {
  assert.equal(isCatalogChange({visionLabels: ["Rock"]}, {visionLabels: ["Sky"]}), true);
});

test("syncWebWall keeps legacy walls with no creator uid and uses their public display name", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({creatorUid: undefined, by: "Legacy creator"})});

  await syncWebWall("W1");

  const doc = (await db.collection("webWalls").doc("W1").get()).data();
  assert.equal(doc?.creatorName, "Legacy creator");
  assert.equal(doc?.creator, null);
});

test("syncWebWall output carries no private fields and a fixed key set", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  const keys = keysDeep(doc);
  for (const forbidden of ["creatorUid", "email", "uid", "ownerId", "wallpaper_url", "originalProtected"]) {
    assert.ok(!keys.includes(forbidden), `${forbidden} must not be published`);
  }
  assert.ok(!valuesDeep(doc).includes("u1"), "the owner uid must not be published");
  assert.ok(!JSON.stringify(doc).includes("sam@example.com"));
  assert.ok(!JSON.stringify(doc).includes("wallpaper_url"));
  assert.ok(!JSON.stringify(doc).includes("originalProtected"));
  assert.deepEqual(Object.keys(doc).sort(), [
    "categorySlug", "category", "colors", "createdAt", "creator", "creatorName", "description", "height",
    "state", "tags", "thumb", "title", "updatedAt", "width",
  ].sort());
});

test("syncWebWall gates a wall in a premium collection and blurs it without a thumb", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({collections: ["abstract"]}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.state, "gated");
  assert.equal(doc.blur, BLUR);
  assert.equal("thumb" in doc, false);
});

test("syncWebWall preserves the creator identity on a gated wall", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({collections: ["abstract"]}), "profiles/u1": samProfile});

  await syncWebWall("W1");

  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.state, "gated");
  assert.deepEqual(doc.creator, {username: "sam", name: "Sam K"});
});

test("syncWebWall may publish derived descriptive copy for gated walls but never their thumbnail", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({title: "", tags: [], visionLabels: ["Blue", "Triangle"],
    collections: ["abstract"]})});

  await syncWebWall("W1");

  const doc = (await db.collection("webWalls").doc("W1").get()).data();
  assert.equal(doc?.state, "gated");
  assert.equal(doc?.title, "Blue triangle wallpaper");
  assert.deepEqual(doc?.tags, ["Triangle", "Blue"]);
  assert.equal("thumb" in (doc ?? {}), false);
});

test("syncWebWall hides walls without publishing Vision-derived copy", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({review: false, title: "", tags: [], visionLabels: ["Blue", "Triangle"]})});

  await syncWebWall("W1");

  assert.deepEqual((await db.collection("webWalls").doc("W1").get()).data(), {state: "hidden", updatedAt: NOW});
});

test("syncWebWall does not reuse a non-image value as a cached blurred preview", async (t) => {
  stubDeps(t);
  const blurKey = createHash("sha256").update(THUMB).digest("hex").slice(0, 16);
  installFakeDb(t, {
    "walls/d1": liveWall({collections: ["abstract"]}),
    "webWalls/W1": {state: "gated", updatedAt: "old", blurKey, blur: "https://private.example/original.jpg"},
  });

  await syncWebWall("W1");

  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.blur, BLUR);
  assert.equal(JSON.stringify(doc).includes("private.example"), false);
});

test("syncWebWall gates an is_streak_exclusive wall", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({is_streak_exclusive: true}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  assert.equal((await db.collection("webWalls").doc("W1").get()).data()?.state, "gated");
});

test("syncWebWall gates a dropReserved wall", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({dropReserved: true}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  assert.equal((await db.collection("webWalls").doc("W1").get()).data()?.state, "gated");
});

test("syncWebWall gates a wall in a drop week without publishing its thumbnail", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({dropWeek: "2026-10-31"}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.state, "gated");
  assert.equal("thumb" in doc, false);
});

test("syncWebWall gates an unprotected wall without publishing its thumbnail", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({originalProtected: false}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.state, "gated");
  assert.equal("thumb" in doc, false);
});

test("syncWebWall omits an invalid non-preview thumbnail entirely", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({wallpaper_thumb: "https://example.com/original.jpg"}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  const doc = (await db.collection("webWalls").doc("W1").get()).data() as Doc;
  assert.equal(doc.state, "gated");
  assert.equal("thumb" in doc, false);
  assert.equal("blur" in doc, false);
});

test("syncWebWall fails closed when the premium collection config is missing", async (t) => {
  t.mock.method(remoteConfig, "getRemoteConfig", () => ({
    getTemplate: async () => {
      throw new Error("Remote Config unavailable");
    },
  }) as never);
  t.mock.method(webCatalogDeps, "blur", async () => BLUR);
  t.mock.method(webCatalogDeps, "now", () => new Date(NOW));
  const store = installFakeDb(t, {"walls/d1": liveWall({collections: ["abstract"]})});

  await assert.rejects(syncWebWall("W1"), /Remote Config unavailable/);

  assert.equal(store.has("webWalls/W1"), false);
});

test("syncWebWall still withdraws a deleted wall when premium config is unavailable", async (t) => {
  t.mock.method(remoteConfig, "getRemoteConfig", () => ({
    getTemplate: async () => {
      throw new Error("Remote Config unavailable");
    },
  }) as never);
  t.mock.method(webCatalogDeps, "blur", async () => BLUR);
  t.mock.method(webCatalogDeps, "now", () => new Date(NOW));
  const store = installFakeDb(t, {"webWalls/W1": {state: "live", updatedAt: "old", thumb: THUMB}});

  await syncWebWall("W1");

  assert.deepEqual(store.get("webWalls/W1"), {state: "gone", updatedAt: NOW});
});

test("premium collection config rejects malformed JSON rather than opening its collection", async (t) => {
  let value: string | undefined = "[\" abstract \",\"space\"]";
  t.mock.method(remoteConfig, "getRemoteConfig", () => ({
    getTemplate: async () => ({parameters: value === undefined ? {} :
      {premiumCollections: {defaultValue: {value}}}}),
  }) as never);

  assert.deepEqual(await webCatalogDeps.premium(), ["abstract", "space"]);
  value = "abstract, space";
  assert.deepEqual(await webCatalogDeps.premium(), ["abstract", "space"]);

  for (value of ["{\"premium\":[\"abstract\"]}", "[]", "[\"abstract\",3]"]) {
    await assert.rejects(webCatalogDeps.premium(), /premiumCollections is invalid/);
  }
  value = undefined;
  await assert.rejects(webCatalogDeps.premium(), /premiumCollections is empty or missing/);
});

test("syncWebWall hides an unreviewed wall, and marks a deleted wall gone", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall({review: false}), "profiles/u1": samProfile});
  await syncWebWall("W1");
  assert.deepEqual((await db.collection("webWalls").doc("W1").get()).data(), {state: "hidden", updatedAt: NOW});
});

test("syncWebWall marks a deleted wall gone", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"webWalls/W1": {state: "live", updatedAt: "x"}});
  await syncWebWall("W1");
  assert.deepEqual((await db.collection("webWalls").doc("W1").get()).data(), {state: "gone", updatedAt: NOW});
});

test("syncWebWall hides a share id that two approved walls share", async (t) => {
  stubDeps(t);
  installFakeDb(t, {"walls/d1": liveWall(), "walls/d2": liveWall(), "profiles/u1": samProfile});
  await syncWebWall("W1");
  assert.deepEqual((await db.collection("webWalls").doc("W1").get()).data(), {state: "hidden", updatedAt: NOW});
});

test("syncWebWall keeps the old updatedAt when nothing changed", async (t) => {
  let clock = new Date(NOW);
  stubDeps(t, () => clock);
  installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});
  await syncWebWall("W1");
  clock = new Date("2026-11-05T00:00:00.000Z");
  await syncWebWall("W1");
  assert.equal((await db.collection("webWalls").doc("W1").get()).data()?.updatedAt, NOW);
});

test("syncWebWall does not let a delayed stale projection overwrite a newer gate", async (t) => {
  const clock = () => new Date(NOW);
  let releaseFirst!: () => void;
  let enteredFirst!: () => void;
  const firstEntered = new Promise<void>((resolve) => {
    enteredFirst = resolve;
  });
  const firstGate = new Promise<void>((resolve) => {
    releaseFirst = resolve;
  });
  let calls = 0;
  t.mock.method(webCatalogDeps, "premium", async () => {
    calls++;
    if (calls === 1) {
      enteredFirst();
      await firstGate;
    }
    return ["abstract"];
  });
  t.mock.method(webCatalogDeps, "blur", async () => BLUR);
  t.mock.method(webCatalogDeps, "now", clock);
  const store = installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});

  const staleSync = syncWebWall("W1");
  await firstEntered;
  store.set("walls/d1", liveWall({collections: ["abstract"]}));
  await syncWebWall("W1");
  releaseFirst();
  await staleSync;

  assert.equal(store.get("webWalls/W1")?.state, "gated");
  assert.equal("thumb" in (store.get("webWalls/W1") ?? {}), false);
});

test("isCatalogChange ignores counter-only changes and reacts to shown fields", () => {
  assert.equal(isCatalogChange({views: 1, title: "a"}, {views: 2, title: "a"}), false);
  assert.equal(isCatalogChange({title: "a"}, {title: "b"}), true);
  assert.equal(isCatalogChange(undefined, {title: "a"}), true);
  assert.equal(isCatalogChange({title: "a"}, undefined), true);
});

test("cleanText strips hidden characters and clips with an ellipsis; categorySlug normalises", () => {
  assert.equal(cleanText("a‮b\u0000c", 90), "a b c");
  assert.equal(cleanText("abcdefghij", 5), "abcd…");
  assert.equal(cleanText(`${"x".repeat(30)}😀rest`, 32), `${"x".repeat(30)}…`);
  assert.equal(categorySlug("3D Render"), "3d-render");
  assert.equal(categorySlug(""), "general");
});

test("buildPages pages live walls newest first and keeps gated walls out of every page", () => {
  const pages = buildPages(thirtyWalls(), [], [], new Map());
  for (const key of ["latest~1", "latest~2", "category~nature~1", "category~nature~2"]) {
    assert.ok(pages.has(key), `missing ${key}`);
  }
  const latest1 = pageOf(pages, "latest~1");
  assert.equal(latest1.items.length, PAGE_SIZE);
  assert.equal(latest1.items[0].id, "W30");
  assert.equal(latest1.total, 30);
  assert.equal(latest1.pages, 2);
  assert.equal(pageOf(pages, "latest~2").items.length, 30 - PAGE_SIZE);
  assert.ok(!JSON.stringify([...pages.values()]).includes("GATED"));
});

test("buildPages writes one sitemap line per live wall and indexes every sitemap", () => {
  const pages = buildPages(thirtyWalls(), [], [], new Map());
  const lines = pageOf(pages, "sitemap~walls-1").entries.split("\n");
  assert.equal(lines.length, 30);
  const paths = lines.map((line) => line.split("\t")[0]).sort();
  const expected = Array.from({length: 30}, (_, i) => `/wallpaper/W${String(i + 1).padStart(2, "0")}`).sort();
  assert.deepEqual(paths, expected);
  for (const line of lines) assert.equal(line.split("\t")[1], NOW);
  const names = pageOf(pages, "sitemap~index").sitemaps.map((sitemap) => sitemap.name);
  assert.ok(names.includes("walls-1"));
  assert.ok(names.includes("categories-1"));
});

test("buildPages popular list keeps only known live ids, case-insensitively", () => {
  const pages = buildPages(thirtyWalls(), ["w05", "W99"], [], new Map());
  const popular = pageOf(pages, "popular~1");
  assert.deepEqual(popular.items.map((item) => item.id), ["W05"]);
  assert.equal(popular.total, 1);
});

test("buildPages makes a creator page keyed by lower-cased username", () => {
  const walls = new Map<string, WebWall>([
    ["W01", liveCard(1, {creator: {username: "Sam", name: "Sam"}, creatorName: "Sam"})],
  ]);
  const creators = new Map([["u1", {username: "Sam", name: "Sam", bio: "", photo: ""}]]);
  const pages = buildPages(walls, [], [], creators);
  const creator = pageOf(pages, "creator~sam~1");
  assert.equal(creator.kind, "creator");
  assert.deepEqual(creator.items.map((item) => item.id), ["W01"]);
});

test("buildPages marks a folder owner's creator page only when the owner has live walls", () => {
  const walls = new Map<string, WebWall>([
    ["W01", liveCard(1, {creator: {username: "Sam", name: "Sam"}, creatorName: "Sam"})],
  ]);
  const sam = {username: "Sam", name: "Sam", bio: "", photo: ""};
  const ana = {username: "ana", name: "Ana", bio: "", photo: ""};
  const folders = [
    {id: "F1", name: "Faves", owner: sam, wallIds: ["W01"], updatedAt: NOW},
    {id: "F2", name: "Saved", owner: ana, wallIds: ["W01"], updatedAt: NOW},
  ];
  const pages = buildPages(walls, [], folders, new Map([["u1", sam], ["u2", ana]]));

  assert.deepEqual(pageOf(pages, "folder~F1").owner, {username: "Sam", name: "Sam", hasPage: true});
  assert.deepEqual(pageOf(pages, "folder~F2").owner, {username: "ana", name: "Ana", hasPage: false});
  assert.equal(pages.has("creator~ana~1"), false);
});

test("buildPages matches folder owners to creator page keys without case sensitivity", () => {
  const walls = new Map<string, WebWall>([
    ["W01", liveCard(1, {creator: {username: "Sam", name: "Sam"}})],
  ]);
  const owner = {username: "sAM", name: "Sam", bio: "", photo: ""};
  const pages = buildPages(walls, [], [{id: "F1", name: "Faves", owner, wallIds: [], updatedAt: NOW}],
    new Map([["u1", {username: "sam", name: "Sam", bio: "", photo: ""}]]));

  assert.equal(pageOf(pages, "folder~F1").owner?.hasPage, true);
  assert.ok(pages.has("creator~sam~1"));
  assert.ok(JSON.stringify([...pages.values()]).includes("/creator/sam"));
});

test("buildPages does not emit creator links for dot-segment usernames", () => {
  const walls = new Map<string, WebWall>([
    ["W01", liveCard(1, {creator: {username: "..", name: "Dot"}})],
  ]);
  const dot = {username: "..", name: "Dot", bio: "", photo: ""};
  const pages = buildPages(walls, [], [{id: "F1", name: "Faves", owner: dot, wallIds: [], updatedAt: NOW}],
    new Map([["u1", dot]]));

  assert.equal(pageOf(pages, "folder~F1").owner?.hasPage, false);
  assert.equal(pages.has("creator~..~1"), false);
  assert.equal(JSON.stringify([...pages.values()]).includes("/creator/.."), false);
});

test("buildPages does not mark folder owners with gated-only walls as creator pages", () => {
  const walls = new Map<string, WebWall>([["G1", {
    ...liveCard(1, {creator: {username: "sam", name: "Sam"}}), state: "gated",
  }]]);
  const sam = {username: "sam", name: "Sam", bio: "", photo: ""};
  const pages = buildPages(walls, [], [{id: "F1", name: "Faves", owner: sam, wallIds: [], updatedAt: NOW}],
    new Map([["u1", sam]]));

  assert.equal(pageOf(pages, "folder~F1").owner?.hasPage, false);
  assert.equal(pages.has("creator~sam~1"), false);
});

test("buildPages does not link a creator-tagged wall when its profile is missing", () => {
  const walls = new Map<string, WebWall>([
    ["W01", liveCard(1, {creator: {username: "sam", name: "Sam"}})],
  ]);
  const sam = {username: "sam", name: "Sam", bio: "", photo: ""};
  const pages = buildPages(walls, [], [{id: "F1", name: "Faves", owner: sam, wallIds: [], updatedAt: NOW}], new Map());

  assert.equal(pageOf(pages, "folder~F1").owner?.hasPage, false);
  assert.equal(pages.has("creator~sam~1"), false);
  assert.equal(pages.has("sitemap~creators-1"), false);
});

test("buildPages sitemap targets exist in an empty catalogue", () => {
  const pages = buildPages(new Map(), [], [], new Map());

  assert.ok(pages.has("latest~1"));
  assert.ok(pages.has("popular~1"));
  const entries = pageOf(pages, "sitemap~categories-1").entries.split("\n").map((line) => line.split("\t")[0]);
  assert.deepEqual(entries, ["/wallpapers", "/wallpapers/popular"]);
});

test("buildPages lists trending and new discover folders, skipping hidden and unlisted ones", () => {
  const sam = {username: "sam", name: "Sam K", bio: "", photo: ""};
  const folders = [
    {id: "f1", name: "Calm", owner: sam, wallIds: ["W01", "W02", "W03", "W04", "W05"], total: 5, updatedAt: NOW},
    {id: "f2", name: "Hidden", owner: null, wallIds: ["W06"], updatedAt: NOW, discoveryHidden: true},
    {id: "f3", name: "Fresh", owner: null, wallIds: ["W07"], updatedAt: NOW},
    {id: "f4", name: "Unlisted", owner: null, wallIds: ["W08"], updatedAt: NOW},
  ];
  const pages = buildPages(thirtyWalls(), [], folders, new Map(), {trending: ["f1", "f2"], new: ["f3"]});

  const discover = pageOf(pages, "folders") as unknown as {
    kind: string; trending: Array<{id: string; name: string; total: number; covers: string[]; owner: unknown}>;
    new: Array<{id: string; name: string; total: number; covers: string[]; owner: unknown}>;
  };
  assert.equal(discover.kind, "folders");
  assert.deepEqual(discover.trending.map((card) => card.id), ["f1"]);
  assert.deepEqual(discover.new.map((card) => card.id), ["f3"]);
  assert.deepEqual(discover.trending[0], {
    id: "f1",
    name: "Calm",
    total: 5,
    covers: [
      "https://img.prismwalls.com/previews/W01.img",
      "https://img.prismwalls.com/previews/W02.img",
      "https://img.prismwalls.com/previews/W03.img",
      "https://img.prismwalls.com/previews/W04.img",
    ],
    owner: {username: "sam", name: "Sam K", hasPage: false},
  });
  const entries = pageOf(pages, "sitemap~categories-1").entries.split("\n").map((line) => line.split("\t")[0]);
  assert.ok(entries.includes("/folders"));
});

test("buildPages drops the folders page when discover names only a hidden or non-public folder", () => {
  const folders = [
    {id: "f2", name: "Hidden", owner: null, wallIds: ["W06"], updatedAt: NOW, discoveryHidden: true},
  ];
  const pages = buildPages(thirtyWalls(), [], folders, new Map(), {trending: ["f2"], new: ["f9"]});

  assert.equal(pages.has("folders"), false);
  const entries = pageOf(pages, "sitemap~categories-1").entries.split("\n").map((line) => line.split("\t")[0]);
  assert.equal(entries.includes("/folders"), false);
});

test("buildPages keeps a public folder page when its current name is unsafe for discovery", () => {
  const folders = [
    {id: "f1", name: "porn", owner: null, wallIds: ["W06"], updatedAt: NOW, discoveryEligible: false},
  ];
  const pages = buildPages(thirtyWalls(), [], folders, new Map(), {trending: ["f1"], new: []});

  assert.ok(pages.has("folder~f1"));
  assert.equal(pages.has("folders"), false);
});

test("rebuildWebCatalog keeps a public folder but drops an unsafe renamed folder from discovery", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "publicFolders/F1": {ownerId: "u1", name: "Calm", itemCount: 8},
    "publicFolders/F1/items/i1": {id: "W1"},
    "folderTrending/current": {trending: [{id: "F1"}], new: []},
  });

  await rebuildWebCatalog();
  assert.ok(store.has("webPages/folders"));
  store.set("publicFolders/F1", {ownerId: "u1", name: "porn", itemCount: 8});

  await rebuildWebCatalog();

  assert.equal(store.has("webPages/folders"), false);
  assert.equal(store.get("webPages/folder~F1")?.name, "porn");
});

test("rebuildWebCatalog drops folders below the live-wall discovery minimum", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "publicFolders/F1": {ownerId: "u1", name: "Calm", itemCount: 8},
    "publicFolders/F1/items/i1": {id: "W1"},
    "folderTrending/current": {trending: [{id: "F1"}], new: []},
  });

  await rebuildWebCatalog();
  store.set("publicFolders/F1", {ownerId: "u1", name: "Calm", itemCount: 7});

  await rebuildWebCatalog();

  assert.equal(store.has("webPages/folders"), false);
  assert.ok(store.has("webPages/folder~F1"));
});

test("hiding a folder from discovery does not remove it from its creator page", () => {
  const walls = thirtyWalls();
  walls.set("W01", liveCard(1, {creator: {username: "sam", name: "Sam K"}}));
  const folders = [
    {id: "f1", name: "Calm", owner: {username: "sam", name: "Sam K", bio: "", photo: ""},
      wallIds: ["W01"], total: 8, updatedAt: NOW, discoveryHidden: true},
  ];
  const pages = buildPages(walls, [], folders, new Map([["u1", samProfile as never]]), {
    trending: ["f1"], new: [],
  });

  assert.equal(pages.has("folders"), false);
  assert.ok(pages.has("folder~f1"));
  assert.deepEqual((pages.get("creator~sam~1")?.folders as Array<{id: string}>).map((folder) => folder.id), ["f1"]);
});

test("rebuildWebCatalog restores the discover page after hide then unhide without a content hash change", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "publicFolders/F1": {ownerId: "u1", name: "Faves", itemCount: 8},
    "publicFolders/F1/items/i1": {id: "W1"},
    "folderTrending/current": {trending: [{id: "F1"}], new: []},
  });

  await rebuildWebCatalog();
  await dropFromDiscovery("F1");
  store.set("folderTrending/current", {trending: [{id: "F1"}], new: []});

  await rebuildWebCatalog();

  assert.deepEqual((store.get("webPages/folders")?.trending as Array<{id: string}>).map((card) => card.id), ["F1"]);
});

test("a stale rebuild cannot restore a folder removed from discovery during its build", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "walls/d2": liveWall({id: "W2", collections: ["abstract"]}),
    "publicFolders/F1": {ownerId: "u1", name: "Faves", itemCount: 8},
    "publicFolders/F1/items/i1": {id: "W1"},
    "folderTrending/current": {trending: [{id: "F1"}], new: []},
  });
  const original = webCatalogDeps.blur;
  let pause = false;
  let entered!: () => void;
  let release!: () => void;
  const enteredPromise = new Promise<void>((resolve) => {
    entered = resolve;
  });
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  t.mock.method(webCatalogDeps, "blur", async (...args: Parameters<typeof original>) => {
    if (pause) {
      entered();
      await gate;
    }
    return original(...args);
  });
  // Keep W1 live in the folder and use a separate wall for the slow blur.
  pause = true;
  const staleBuild = rebuildWebCatalog();
  await enteredPromise;
  store.set("folderTrending/current", {trending: [], new: []});
  await dropFromDiscovery("F1");
  release();
  await staleBuild;

  assert.equal(store.has("webPages/folders"), false);
});

test("a later stable rebuild deletes a stale discover page after the manifest already dropped its hash", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "walls/d2": liveWall({id: "W2", collections: ["abstract"]}),
    "publicFolders/F1": {ownerId: "u1", name: "Faves", itemCount: 8},
    "publicFolders/F1/items/i1": {id: "W1"},
    "folderTrending/current": {trending: [{id: "F1"}], new: []},
  });
  await rebuildWebCatalog();
  assert.ok(store.has("webPages/folders"));

  store.set("publicFolders/F1", {ownerId: "u1", name: "Faves", itemCount: 7});
  let pause = false;
  let entered!: () => void;
  let release!: () => void;
  const enteredPromise = new Promise<void>((resolve) => {
    entered = resolve;
  });
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const original = webCatalogDeps.blur;
  t.mock.method(webCatalogDeps, "blur", async (...args: Parameters<typeof original>) => {
    if (pause) {
      entered();
      await gate;
    }
    return original(...args);
  });
  store.set("walls/d2", liveWall({id: "W2", collections: ["abstract"],
    wallpaper_thumb: "https://img.prismwalls.com/previews/W2-changed.img"}));
  pause = true;
  const staleBuild = rebuildWebCatalog();
  await enteredPromise;
  store.set("publicFolders/F1", {ownerId: "u1", name: "Faves", itemCount: 6});
  release();
  await staleBuild;

  assert.ok(store.has("webPages/folders"), "the stale page remains until a stable snapshot can safely remove it");
  const manifest = store.get("webCatalogState/pages")?.hashes as Record<string, string>;
  assert.equal(manifest.folders, undefined);

  await rebuildWebCatalog();

  assert.equal(store.has("webPages/folders"), false);
});

test("rebuildWebCatalog publishes only profile photos from the app's photo hosts", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": {...samProfile, profilePhoto: "https://tracker.example/pixel.gif"},
  });

  await rebuildWebCatalog();

  assert.equal((store.get("webPages/creator~sam~1")?.creator as {photo: string}).photo, "");
});

test("rebuildWebCatalog rejects profile photo host tricks and keeps approved hosts", async (t) => {
  stubDeps(t);
  const urls = [
    "https://raw.githubusercontent.com.attacker.example/photo.jpg",
    "https://firebasestorage.googleapis.com.attacker.example/photo.jpg",
    "https://lh3.googleusercontent.com.attacker.example/photo.jpg",
    "https://user@raw.githubusercontent.com/photo.jpg",
    "https://raw.githubusercontent.com:8443/photo.jpg",
    "https://trusted。googleusercontent.com.attacker.example/photo.jpg",
  ];
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": {...samProfile, profilePhoto: urls[0]},
  });

  for (const profilePhoto of urls) {
    store.set("profiles/u1", {...samProfile, profilePhoto});
    await rebuildWebCatalog();
    assert.equal((store.get("webPages/creator~sam~1")?.creator as {photo: string}).photo, "", profilePhoto);
  }
  for (const profilePhoto of [
    "https://raw.githubusercontent.com/Hash-Studios/Prism/photo.jpg",
    "https://lh3.googleusercontent.com/photo.jpg",
    "https://LH3.GOOGLEUSERCONTENT.COM/photo.jpg",
    "https://firebasestorage.googleapis.com/v0/b/prism/o/photo.jpg",
  ]) {
    store.set("profiles/u1", {...samProfile, profilePhoto});
    await rebuildWebCatalog();
    assert.equal((store.get("webPages/creator~sam~1")?.creator as {photo: string}).photo, profilePhoto);
  }
});

test("buildPages folder page lists live walls only and counts every saved wall", () => {
  const folders = [{
    id: "F1", name: "Faves", owner: null, wallIds: ["w01", "W02", "GATED"], updatedAt: "2026-10-02T00:00:00.000Z",
  }];
  const pages = buildPages(thirtyWalls(), [], folders, new Map());
  const folder = pageOf(pages, "folder~F1");
  assert.deepEqual(folder.items.map((item) => item.id), ["W01", "W02"]);
  assert.equal(folder.total, 3);
});

function folderCard(id: string): WebCard {
  return {id, title: id, thumb: `https://img.prismwalls.com/previews/${id}.img`, width: 1080, height: 2340};
}

test("sectionGroups leaves items in order and returns no groups when the folder has no sections", () => {
  const shown = [{card: folderCard("W1"), sectionId: "dark"}, {card: folderCard("W2")}];
  const result = sectionGroups(shown, []);
  assert.deepEqual(result.items.map((card) => card.id), ["W1", "W2"]);
  assert.deepEqual(result.groups, []);
});

test("sectionGroups returns no groups when no shown wall is in a section", () => {
  const shown = [{card: folderCard("W1")}, {card: folderCard("W2"), sectionId: "gone"}];
  const result = sectionGroups(shown, [{id: "dark", name: "Dark"}]);
  assert.deepEqual(result.items.map((card) => card.id), ["W1", "W2"]);
  assert.deepEqual(result.groups, []);
});

test("sectionGroups puts Unsorted first, then each section in order", () => {
  const shown = [
    {card: folderCard("W1"), sectionId: "dark"},
    {card: folderCard("W2")},
    {card: folderCard("W3"), sectionId: "lock"},
    {card: folderCard("W4"), sectionId: "dark"},
    {card: folderCard("W5"), sectionId: "gone"},
  ];
  const result = sectionGroups(shown, [{id: "lock", name: "Lock screens"}, {id: "dark", name: "Dark"}]);
  assert.deepEqual(result.items.map((card) => card.id), ["W2", "W5", "W3", "W1", "W4"]);
  assert.deepEqual(result.groups, [
    {name: "", count: 2},
    {name: "Lock screens", count: 1},
    {name: "Dark", count: 2},
  ]);
});

test("sectionGroups leaves out an empty section and an Unsorted group when every wall is sorted", () => {
  const shown = [{card: folderCard("W1"), sectionId: "dark"}];
  const result = sectionGroups(shown, [{id: "lock", name: "Lock"}, {id: "dark", name: "Dark"}]);
  assert.deepEqual(result.items.map((card) => card.id), ["W1"]);
  assert.deepEqual(result.groups, [{name: "Dark", count: 1}]);
});

test("buildPages orders a sectioned folder page by group with Unsorted first", () => {
  const folders = [{
    id: "F1", name: "Faves", owner: null, wallIds: ["W01", "W02", "W03"], updatedAt: NOW,
    sections: [{id: "dark", name: "Dark"}], sectionOf: {W02: "dark"},
  }];
  const folder = buildPages(thirtyWalls(), [], folders, new Map()).get("folder~F1") as unknown as {
    items: WebCard[]; groups?: Array<{name: string; count: number}>;
  };
  assert.deepEqual(folder.items.map((item) => item.id), ["W01", "W03", "W02"]);
  assert.deepEqual(folder.groups, [{name: "", count: 2}, {name: "Dark", count: 1}]);
});

test("buildPages gives a folder page without sections no groups key", () => {
  const folders = [{id: "F1", name: "Faves", owner: null, wallIds: ["W01", "W02"], updatedAt: NOW}];
  const folder = buildPages(thirtyWalls(), [], folders, new Map()).get("folder~F1");
  assert.ok(folder);
  assert.equal("groups" in folder, false);
});

test("buildPages uses the folder's full header count rather than its sampled wall items", () => {
  const folders = [{
    id: "F1", name: "Faves", owner: null, wallIds: ["W01", "W02"], total: 100, updatedAt: NOW,
  }];

  assert.equal(pageOf(buildPages(thirtyWalls(), [], folders, new Map()), "folder~F1").total, 100);
});

test("buildPages keeps maximum-length wall URLs under Firestore's document size limit", () => {
  const walls = new Map<string, WebWall>();
  for (let i = 0; i < 5000; i++) walls.set(`${String(i).padStart(4, "0")}${"x".repeat(196)}`, liveCard(i));

  for (const [key, page] of buildPages(walls, [], [], new Map())) {
    if (key.startsWith("sitemap~") && key !== "sitemap~index") {
      assert.ok(Buffer.byteLength(JSON.stringify(page)) < 1_048_576, `${key} exceeds Firestore's 1 MiB document limit`);
    }
  }
});

test("a 60-wall folder with 20 maximum-length sections stays within one document", (t) => {
  const sections = Array.from({length: 20}, (_, i) => ({id: String(i).padStart(32, "s"), name: "\u754c".repeat(160)}));
  const walls = new Map(Array.from({length: 60}, (_, i): [string, WebWall] => {
    const id = String(i).padStart(200, "W");
    return [id, liveCard(i, {title: "\u754c".repeat(90), thumb: `https://img.prismwalls.com/previews/${id}.img`})];
  }));
  const wallIds = [...walls.keys()];
  const folders = [{id: "F1", name: "Faves", owner: null, wallIds, updatedAt: NOW, sections,
    sectionOf: Object.fromEntries(wallIds.map((id, i) => [id, sections[i % 20].id]))}];
  const folder = buildPages(walls, [], folders, new Map()).get("folder~F1");
  assert.ok(folder);
  assert.equal((folder.items as WebCard[]).length, 60);
  assert.equal((folder.groups as unknown[]).length, 20);
  assert.ok(Buffer.byteLength(JSON.stringify(folder)) < 64_000);
  t.diagnostic(`20-section, 60-wall page JSON bytes: ${Buffer.byteLength(JSON.stringify(folder))}`);
});

test("rebuildWebCatalog writes the catalogue once, then writes nothing on a second run", async (t) => {
  stubDeps(t);
  const writes = {reads: 0, writes: 0, outsideWrites: 0};
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": samProfile,
    "popular/current": {wallIds: ["W1"]},
  }, writes);
  const first = await rebuildWebCatalog();
  assert.equal(first.walls, 1);
  assert.equal(first.pages, 9);
  assert.deepEqual(store.get("webPages/desktop~1")?.items, []);
  assert.ok(store.has("webWalls/W1"));
  assert.ok(store.has("webPages/latest~1"));
  assert.ok(store.has("webPages/sitemap~index"));
  assert.ok(store.has("webCatalogState/pages"));
  const writesAfterFirst = writes.writes;
  writes.outsideWrites = 0;
  const second = await rebuildWebCatalog();
  assert.equal(second.written, 0);
  assert.equal(writes.writes, writesAfterFirst);
  assert.equal(writes.outsideWrites, 0);
});

test("rebuild migrates old projections to Vision labels and clears derived copy when labels disappear", async (t) => {
  stubDeps(t);
  const writes = {reads: 0, writes: 0, outsideWrites: 0};
  const store = installFakeDb(t, {
    "walls/d1": liveWall({title: "", tags: [], visionLabels: ["Blue", "Triangle"]}),
    "webWalls/W1": {state: "live", updatedAt: "old", title: "", tags: [], thumb: THUMB},
  }, writes);

  const first = await rebuildWebCatalog();
  assert.equal(first.walls, 1);
  assert.equal(store.get("webWalls/W1")?.title, "Blue triangle wallpaper");
  assert.deepEqual(store.get("webWalls/W1")?.tags, ["Triangle", "Blue"]);
  assert.equal((store.get("webPages/latest~1")?.items as WebCard[])[0].title, "Blue triangle wallpaper");
  const writesAfterMigration = writes.writes;
  assert.equal((await rebuildWebCatalog()).written, 0);
  assert.equal(writes.writes, writesAfterMigration);

  store.set("walls/d1", liveWall({title: "", tags: [], visionLabels: []}));
  await rebuildWebCatalog();
  assert.equal(store.get("webWalls/W1")?.title, "");
  assert.deepEqual(store.get("webWalls/W1")?.tags, []);
  assert.equal((store.get("webPages/latest~1")?.items as WebCard[])[0].title, "");
});

test("rebuildWebCatalog projects new walls in parallel and blurs each gated wall once", async (t) => {
  stubDeps(t);
  let inFlight = 0;
  let maxInFlight = 0;
  let blurs = 0;
  t.mock.method(webCatalogDeps, "blur", async () => {
    blurs++;
    maxInFlight = Math.max(maxInFlight, ++inFlight);
    await new Promise((resolve) => setTimeout(resolve, 5));
    inFlight--;
    return BLUR;
  });
  const seed: Record<string, Doc> = {"profiles/u1": samProfile};
  for (let n = 0; n < 12; n++) seed[`walls/d${n}`] = liveWall({id: `G${n}`, collections: ["abstract"]});
  const store = installFakeDb(t, seed);
  const result = await rebuildWebCatalog();
  assert.equal(result.walls, 12);
  assert.ok(maxInFlight > 1, "walls must not be projected one at a time");
  assert.equal(blurs, 12);
  assert.equal(store.get("webWalls/G0")?.blur, BLUR);
  assert.equal((await rebuildWebCatalog()).written, 0);
});

test("rebuildWebCatalog hides an id shared by approved and unapproved walls", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/approved": liveWall(),
    "walls/unapproved": liveWall({review: false}),
  });

  await rebuildWebCatalog();

  assert.deepEqual(store.get("webWalls/W1"), {state: "hidden", updatedAt: NOW});
});

test("rebuildWebCatalog marks deleted walls gone and scrubs old projection fields", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "webWalls/W1": {state: "live", updatedAt: "old", thumb: THUMB, creatorUid: "private", email: "private"},
  });

  await rebuildWebCatalog();

  assert.deepEqual(store.get("webWalls/W1"), {state: "gone", updatedAt: NOW});
});

test("rebuildWebCatalog does not refresh a folder page when its header has no updatedAt", async (t) => {
  let clock = new Date(NOW);
  stubDeps(t, () => clock);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": samProfile,
    "publicFolders/F1": {ownerId: "u1", name: "Faves"},
    "publicFolders/F1/items/i1": {id: "W1"},
  });

  await rebuildWebCatalog();
  const folderPage = store.get("webPages/folder~F1");
  clock = new Date("2026-11-05T00:00:00.000Z");
  const second = await rebuildWebCatalog();

  assert.equal(second.written, 0);
  assert.deepEqual(store.get("webPages/folder~F1"), folderPage);
});

test("rebuildWebCatalog rewrites a legacy folder doc missing hasPage and then stabilizes", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": samProfile,
    "publicFolders/F1": {ownerId: "u1", name: "Faves", updatedAt: admin.firestore.Timestamp.fromMillis(Date.parse(NOW))},
    "publicFolders/F1/items/i1": {id: "W1"},
  });

  await rebuildWebCatalog();
  const legacyPage = store.get("webPages/folder~F1") as Doc;
  const legacyOwner = legacyPage.owner as Doc;
  delete legacyOwner.hasPage;
  const legacyHash = createHash("sha256").update(JSON.stringify(legacyPage, (_, value) =>
    value && typeof value === "object" && !Array.isArray(value) ?
      Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b))) : value)).digest("hex").slice(0, 20);
  store.set("webPages/folder~F1", legacyPage);
  const state = store.get("webCatalogState/pages") as Doc;
  store.set("webCatalogState/pages", {hashes: {...state.hashes as Doc, "folder~F1": legacyHash}});

  const rewritten = await rebuildWebCatalog();

  assert.equal((store.get("webPages/folder~F1")?.owner as {hasPage?: boolean}).hasPage, true);
  assert.equal(rewritten.written, 1);
  assert.equal((await rebuildWebCatalog()).written, 0);
});

test("rebuildWebCatalog rejects dot-segment profile names before publishing creator URLs", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": {...samProfile, username: ".."},
  });

  await rebuildWebCatalog();

  assert.equal(store.has("webPages/creator~..~1"), false);
  assert.equal(JSON.stringify([...store.entries()]).includes("/creator/.."), false);
});

test("rebuildWebCatalog scrubs old fields from retained terminal projections", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "webWalls/W1": {state: "hidden", updatedAt: "old", thumb: THUMB, creatorUid: "private", email: "private"},
  });

  await rebuildWebCatalog();

  assert.deepEqual(store.get("webWalls/W1"), {state: "gone", updatedAt: NOW});
});

test("rebuildWebCatalog cannot overwrite a newer wall projection after a slow blur", async (t) => {
  let releaseBlur!: () => void;
  let enteredBlur!: () => void;
  const blurEntered = new Promise<void>((resolve) => {
    enteredBlur = resolve;
  });
  const blurGate = new Promise<void>((resolve) => {
    releaseBlur = resolve;
  });
  t.mock.method(webCatalogDeps, "premium", async () => ["abstract"]);
  t.mock.method(webCatalogDeps, "blur", async () => {
    enteredBlur();
    await blurGate;
    return BLUR;
  });
  t.mock.method(webCatalogDeps, "now", () => new Date(NOW));
  const store = installFakeDb(t, {"walls/d1": liveWall({collections: ["abstract"]}), "profiles/u1": samProfile});

  const staleBuild = rebuildWebCatalog();
  await blurEntered;
  store.set("walls/d1", liveWall());
  await syncWebWall("W1");
  releaseBlur();
  await staleBuild;

  assert.equal(store.get("webWalls/W1")?.state, "live");
  assert.equal(store.get("webWalls/W1")?.thumb, THUMB);
});

test("rebuildWebCatalog retries a failed manifest commit without rewriting already-current pages", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});
  const storeSet = store.set.bind(store);
  let failManifest = false;
  let pageWrites = 0;
  store.set = (path, data) => {
    if (path.startsWith("webPages/")) pageWrites++;
    if (failManifest && path === "webCatalogState/pages") {
      failManifest = false;
      throw new Error("injected manifest write failure");
    }
    return storeSet(path, data);
  };
  await rebuildWebCatalog();
  pageWrites = 0;
  store.set("walls/d1", liveWall({title: "Changed"}));
  failManifest = true;

  await assert.rejects(rebuildWebCatalog(), /injected manifest write failure/);
  const pagesWrittenBeforeRetry = pageWrites;
  const retry = await rebuildWebCatalog();

  assert.equal(retry.written, 0);
  assert.equal(pageWrites, pagesWrittenBeforeRetry);
});

test("rebuildWebCatalog retries a failed manifest commit without deleting an already-removed page", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {"walls/d1": liveWall(), "profiles/u1": samProfile});
  const storeSet = store.set.bind(store);
  const storeDelete = store.delete.bind(store);
  let failManifest = false;
  let pageDeletes = 0;
  store.set = (path, data) => {
    if (failManifest && path === "webCatalogState/pages") {
      failManifest = false;
      throw new Error("injected manifest write failure");
    }
    return storeSet(path, data);
  };
  store.delete = (path) => {
    if (path.startsWith("webPages/")) pageDeletes++;
    return storeDelete(path);
  };
  await rebuildWebCatalog();
  store.set("walls/d1", liveWall({category: ""}));
  failManifest = true;

  await assert.rejects(rebuildWebCatalog(), /injected manifest write failure/);
  const pageDeletesBeforeRetry = pageDeletes;
  const retry = await rebuildWebCatalog();

  assert.equal(retry.written, 0);
  assert.equal(pageDeletes, pageDeletesBeforeRetry);
});
