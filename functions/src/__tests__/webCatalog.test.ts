process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  buildPages,
  categorySlug,
  cleanText,
  isCatalogChange,
  PAGE_SIZE,
  rebuildWebCatalog,
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
    sitemaps: Array<{name: string; lastmod: string}>;
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

test("isCatalogChange ignores counter-only changes and reacts to shown fields", () => {
  assert.equal(isCatalogChange({views: 1, title: "a"}, {views: 2, title: "a"}), false);
  assert.equal(isCatalogChange({title: "a"}, {title: "b"}), true);
  assert.equal(isCatalogChange(undefined, {title: "a"}), true);
  assert.equal(isCatalogChange({title: "a"}, undefined), true);
});

test("cleanText strips hidden characters and clips with an ellipsis; categorySlug normalises", () => {
  assert.equal(cleanText("a‮b\u0000c", 90), "a b c");
  assert.equal(cleanText("abcdefghij", 5), "abcd…");
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

test("buildPages folder page lists live walls only and counts every saved wall", () => {
  const folders = [{
    id: "F1", name: "Faves", owner: null, wallIds: ["w01", "W02", "GATED"], updatedAt: "2026-10-02T00:00:00.000Z",
  }];
  const pages = buildPages(thirtyWalls(), [], folders, new Map());
  const folder = pageOf(pages, "folder~F1");
  assert.deepEqual(folder.items.map((item) => item.id), ["W01", "W02"]);
  assert.equal(folder.total, 3);
});

test("rebuildWebCatalog writes the catalogue once, then writes nothing on a second run", async (t) => {
  stubDeps(t);
  const store = installFakeDb(t, {
    "walls/d1": liveWall(),
    "profiles/u1": samProfile,
    "popular/current": {wallIds: ["W1"]},
  });
  const first = await rebuildWebCatalog();
  assert.equal(first.walls, 1);
  assert.equal(first.pages, 8);
  assert.ok(store.has("webWalls/W1"));
  assert.ok(store.has("webPages/latest~1"));
  assert.ok(store.has("webPages/sitemap~index"));
  assert.ok(store.has("webCatalogState/pages"));
  const second = await rebuildWebCatalog();
  assert.equal(second.written, 0);
});
