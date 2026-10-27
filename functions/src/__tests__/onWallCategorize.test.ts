import assert from "node:assert/strict";
import test, {beforeEach, type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db} from "../common";
import {onWallCategorize} from "../onWallCategorize";
import * as wallCategory from "../wallCategory";
import * as wallColors from "../wallColors";
import * as wallDepth from "../wallDepth";
import * as wallSpatial from "../wallSpatial";
import {type Doc, installFakeDb} from "./fakeDb";
import {resolveOriginalAccess} from "../originalAccess";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {r2ObjectId} from "../r2Storage";

const WALL_URL = "https://raw.githubusercontent.com/o/r/main/a.jpg";
const DETECTED = {tier: "menu", kind: "person", top: 0.15, v: 1, by: "detector"};
const ADMIN = {tier: "auto", kind: null, top: null, v: 1, by: "admin"};
const SPATIAL = {tier: "ok", map: "https://images.example.com/spatial/v1/w1.png", v: 1};

beforeEach((t) => {
  assert.ok("mock" in t);
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
});

const created = (data: Doc) => ({
  params: {wallId: "w1"},
  data: {data: () => data, createTime: admin.firestore.Timestamp.fromMillis(1)},
}) as unknown as Parameters<typeof onWallCategorize.run>[0];

function setup(
  t: TestContext,
  wall: Doc,
  depth: (store: Map<string, Doc>) => Promise<unknown>,
  labels: () => Promise<string[]> = async () => ["Mountain"],
  spatial: (store: Map<string, Doc>) => Promise<unknown> = async () => undefined,
) {
  const store = installFakeDb(t, {"walls/w1": wall});
  t.mock.method(wallCategory, "detectLabels", labels);
  t.mock.method(wallColors, "wallColorsFor", async () => ["blue"]);
  const depthMock = t.mock.method(wallDepth, "wallDepthFor", () => depth(store));
  const spatialMock = t.mock.method(wallSpatial, "wallSpatialFor", () => spatial(store));
  return {store, depthMock, spatialMock};
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

test("a failed categorization transaction writes none of the image fields", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED);
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("contention");
  });
  const warn = t.mock.method(logger, "warn", () => undefined);
  await assert.rejects(() => onWallCategorize.run(created({wallpaper_url: WALL_URL})), /contention/);
  const wall = store.get("walls/w1");
  assert.equal("depth" in (wall ?? {}), false);
  assert.equal(wall?.colors, undefined);
  assert.equal(wall?.category, undefined);
  assert.equal(warn.mock.callCount(), 0);
});

test("slow categorization preserves intervening admin category, premium collections, colors and depth", async (t) => {
  const initial = {wallpaper_url: WALL_URL, collections: ["community"]};
  const edited = {...initial, review: true, category: "Space", collections: ["premium"], colors: ["red"], depth: ADMIN};
  const {store} = setup(t, initial, async (walls) => {
    walls.set("walls/w1", edited);
    return DETECTED;
  });
  await onWallCategorize.run(created(initial));
  assert.deepEqual(store.get("walls/w1"), {...edited, visionLabels: ["Mountain"]});
});

test("original access still quotes the premium price after an admin classifies during analysis", async (t) => {
  const previous = {...process.env};
  Object.assign(process.env, {R2_PREVIEW_BASE_URL: "https://images.example.com", R2_PRIVATE_BUCKET: "private",
    GH_REPO_WALLS: "walls"});
  t.after(() => {
    process.env = previous;
  });
  resetEconomyCache();
  const object = (path: string, digest: string) => {
    const source = {uid: "owner", repo: "walls", path, sha: "c".repeat(40), sourceKind: "owned" as const};
    const objectId = r2ObjectId(source, digest);
    return {...source, bucket: "private", object: `private-originals/${objectId}`, objectId, sha256: digest};
  };
  const original = object("original/path", "b".repeat(64));
  const thumbnail = object("thumb_path", "d".repeat(64));
  const thumb = {...thumbnail, previewObjectId: thumbnail.objectId};
  const wall = {id: "asset", wallpaper_url: "", wallpaper_thumb: `https://images.example.com/previews/${thumb.objectId}.img`,
    wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: "", originalProtected: true,
    originalObjectId: original.objectId, collections: ["community"]};
  const {store} = setup(t, wall, async (walls) => {
    walls.set("walls/w1", {...wall, review: true, category: "Space", collections: ["premium"]});
    return DETECTED;
  });
  store.set("usersv2/viewer", {coins: 100});
  store.set("usersv2/viewer/private/economy", {graceDownloadsUsed: 100});
  store.set("ownedAssets/asset", {status: "ready", canonicalPath: "walls/w1", incarnation: 1,
    incarnationNanos: 1_000_000, original, thumb});
  for (const stored of [original, thumb]) {
    store.set(`r2ObjectRegistry/${stored.objectId}`, {...stored, status: "active", uploadId: "imported"});
  }
  await onWallCategorize.run(created(wall));
  const quote = await resolveOriginalAccess.run({auth: {uid: "viewer", token: {}}, data: {
    assetId: "asset", action: "download", requestId: "request_quote", mode: "quote",
  }} as unknown as Parameters<typeof resolveOriginalAccess.run>[0]);
  assert.equal(quote.status, "quoted");
  assert.equal("requiredCoins" in quote && quote.requiredCoins, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
});

test("no-label fallback does not reset admin collections or a custom category", async (t) => {
  const initial = {wallpaper_url: WALL_URL};
  const {store} = setup(t, initial, async (walls) => {
    walls.set("walls/w1", {...initial, category: "Custom", collections: ["premium"]});
    return undefined;
  }, async () => []);
  await onWallCategorize.run(created(initial));
  assert.equal(store.get("walls/w1")?.category, "Custom");
  assert.deepEqual(store.get("walls/w1")?.collections, ["premium"]);
});

for (const change of ["source", "recreate", "delete"] as const) {
  test(`categorization discards all stale results after ${change}`, async (t) => {
    const initial = {wallpaper_url: WALL_URL};
    const {store} = setup(t, initial, async (walls) => {
      if (change === "source") walls.set("walls/w1", {wallpaper_url: `${WALL_URL}?new`});
      else {
        walls.delete("walls/w1");
        if (change === "recreate") walls.set("walls/w1", {...initial});
      }
      return DETECTED;
    });
    await onWallCategorize.run(created(initial));
    assert.deepEqual(store.get("walls/w1"), change === "delete" ? undefined :
      {wallpaper_url: change === "source" ? `${WALL_URL}?new` : WALL_URL});
  });
}

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

test("a new wall with no spatial gets the Spatial Scene tier and map", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED, undefined, async () => SPATIAL);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  assert.deepEqual(store.get("walls/w1")?.spatial, SPATIAL);
  assert.equal(store.get("walls/w1")?.category, "Nature");
});

test("an admin spatial set while the check runs is kept", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED, undefined, async (walls) => {
    walls.set("walls/w1", {...walls.get("walls/w1"), spatial: {...SPATIAL, tier: "none"}});
    return SPATIAL;
  });
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  assert.deepEqual(store.get("walls/w1")?.spatial, {...SPATIAL, tier: "none"});
});

test("a wall created with a spatial never runs the Spatial Scene check", async (t) => {
  const {store, spatialMock} = setup(t, {wallpaper_url: WALL_URL, spatial: SPATIAL}, async () => DETECTED,
    undefined, async () => SPATIAL);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL, spatial: SPATIAL}));
  assert.equal(spatialMock.mock.callCount(), 0);
  assert.deepEqual(store.get("walls/w1")?.spatial, SPATIAL);
});

test("a failed Spatial Scene check writes no spatial field and keeps the colours and category", async (t) => {
  const {store} = setup(t, {wallpaper_url: WALL_URL}, async () => DETECTED, undefined, async () => undefined);
  await onWallCategorize.run(created({wallpaper_url: WALL_URL}));
  const wall = store.get("walls/w1");
  assert.equal("spatial" in (wall ?? {}), false);
  assert.deepEqual(wall?.colors, ["blue"]);
  assert.equal(wall?.category, "Nature");
});
