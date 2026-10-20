import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db} from "../common";
import {onWallCategorize} from "../onWallCategorize";
import * as wallCategory from "../wallCategory";
import * as wallColors from "../wallColors";
import * as wallDepth from "../wallDepth";
import {type Doc, installFakeDb} from "./fakeDb";

const WALL_URL = "https://raw.githubusercontent.com/o/r/main/a.jpg";
const DETECTED = {tier: "menu", kind: "person", top: 0.15, v: 1, by: "detector"};
const ADMIN = {tier: "auto", kind: null, top: null, v: 1, by: "admin"};

const created = (data: Doc) => ({
  params: {wallId: "w1"},
  data: {data: () => data},
}) as unknown as Parameters<typeof onWallCategorize.run>[0];

function setup(
  t: TestContext,
  wall: Doc,
  depth: (store: Map<string, Doc>) => Promise<unknown>,
  labels: () => Promise<string[]> = async () => ["Mountain"],
) {
  const store = installFakeDb(t, {"walls/w1": wall});
  t.mock.method(wallCategory, "detectLabels", labels);
  t.mock.method(wallColors, "wallColorsFor", async () => ["blue"]);
  const depthMock = t.mock.method(wallDepth, "wallDepthFor", () => depth(store));
  return {store, depthMock};
}

test("a new wall with no depth gets the detector depth, colours and category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.deepEqual(wall?.depth, DETECTED);
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.equal(wall?.category, "Nature");
});

test("an admin depth set while the check runs is kept", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async (walls) => {
    walls.set("walls/w1", {...walls.get("walls/w1"), depth: ADMIN});
    return DETECTED;
  });
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.deepEqual(wall?.depth, ADMIN);
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.equal(wall?.category, "Nature");
});

test("a wall created with a depth never runs the depth check", async (t) => {
  const studio = {tier: "none", kind: null, top: null, v: 1, by: "detector"};
  const {store, depthMock} = setup(t, {wallpaper_url: WALL_URL, depth: studio}, async () => DETECTED);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL, depth: studio}));
  assert.equal(depthMock.mock.callCount(), 0);
  const wall = store.get("walls/w1");
  assert.deepEqual(wall?.depth, studio);
  assert.equal(wall?.category, "Nature");
});

test("a failed depth check writes no depth and keeps the colours and category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => undefined);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.equal("depth" in (wall ?? {}), false);
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.equal(wall?.category, "Nature");
});

test("a failed depth write logs a warning and keeps the colours and category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED);
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("contention");
  });
  const warn = t.mock.method(logger, "warn", () => undefined);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.equal("depth" in (wall ?? {}), false);
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.equal(wall?.category, "Nature");
  assert.deepEqual(warn.mock.calls[0].arguments, [
    "onWallCategorize: could not save depth",
    {wallId: "w1", error: "contention"},
  ]);
});

test("a wall approved before its check ends is filed into the collection of its new category", async (t) => {
  const wall = {wallpaper_url: WALL_URL, review: true, collections: ["community"]};
  const {store} = setup(t, wall, async () => DETECTED);
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("no remote config in tests");
  });
  await onWallCategorize.run(created(wall));
  assert.equal(store.get("walls/w1")?.category, "Nature");
  assert.deepEqual(store.get("walls/w1")?.collections, ["community", "landscapes"]);
});

test("a new wall keeps the Vision labels next to its category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => undefined, async () => ["Mountain", "Sky"]);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  assert.deepEqual(store.get("walls/w1")?.visionLabels, ["Mountain", "Sky"]);
  assert.equal(store.get("walls/w1")?.category, "Nature");
});

test("a wall that already has a category still gets its Vision labels and keeps the category", async (t) => {
  const wall = {wallpaper_url: WALL_URL, category: "Space", colors: ["blue"]};
  const {store} = setup(t, wall, async () => undefined, async () => ["Mountain"]);
  await onWallCategorize.run(created(wall));
  assert.deepEqual(store.get("walls/w1"), {...wall, visionLabels: ["Mountain"]});
});

test("a wall with no labels from Vision gets the default category and an empty label list", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => undefined, async () => []);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  assert.equal(store.get("walls/w1")?.category, "General");
  assert.deepEqual(store.get("walls/w1")?.visionLabels, []);
});

test("a Vision failure writes no labels, keeps the colours and gives a new wall the default category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => undefined, async () => {
    throw new Error("vision down");
  });
  const error = t.mock.method(logger, "error", () => undefined);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.equal("visionLabels" in (wall ?? {}), false);
  assert.equal(wall?.category, "General");
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.deepEqual(error.mock.calls[0].arguments, [
    "onWallCategorize: failed to detect labels",
    {wallId: "w1", error: "vision down"},
  ]);
});

test("a Vision failure on a wall with a category keeps the category and still writes the colours", async (t) => {
  const wall = {wallpaper_url: WALL_URL, category: "Space"};
  const {store} = setup(t, wall, async () => undefined, async () => {
    throw new Error("vision down");
  });
  t.mock.method(logger, "error", () => undefined);
  await onWallCategorize.run(created(wall));
  assert.deepEqual(store.get("walls/w1"), {...wall, colors: ["blue"]});
});
