import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test from "node:test";

type Index = {collectionGroup: string; queryScope: string; fields: Array<{fieldPath: string; order?: string; arrayConfig?: string}>};
type Override = {collectionGroup: string; fieldPath: string; ttl?: boolean};

const fixtureRoot = process.env.PRISM_REPO_ROOT ?? join(__dirname, "../../..");
const config = JSON.parse(readFileSync(join(fixtureRoot, "firestore.indexes.json"), "utf8")) as {
  indexes: Index[];
  fieldOverrides: Override[];
};

test("walls have the tag search index: tags contains, review, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields[0]?.fieldPath === "tags" && i.fields[0].arrayConfig === "CONTAINS");
  assert.ok(index);
  assert.deepEqual(index.fields.slice(1).map((f) => [f.fieldPath, f.order]), [["review", "ASCENDING"], ["createdAt", "DESCENDING"]]);
});

test("walls have the search terms index next to the tag index: protected asset fields, searchTerms contains, review, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields.some((f) => f.fieldPath === "searchTerms"));
  assert.ok(index);
  assert.deepEqual(index.fields.map((f) => [f.fieldPath, f.order ?? f.arrayConfig]), [
    ["originalProtected", "ASCENDING"],
    ["wallpaper_url", "ASCENDING"],
    ["wallpaper_path", "ASCENDING"],
    ["wallpaper_sha", "ASCENDING"],
    ["thumb_path", "ASCENDING"],
    ["thumb_sha", "ASCENDING"],
    ["searchTerms", "CONTAINS"],
    ["review", "ASCENDING"],
    ["createdAt", "DESCENDING"],
  ]);
});

test("view rate docs expire through a TTL policy on expireAt", () => {
  assert.ok(config.fieldOverrides.some((o) => o.collectionGroup === "viewRate" && o.fieldPath === "expireAt" && o.ttl === true));
});

test("wall action rate docs and daily stats docs expire through a TTL policy on expireAt", () => {
  for (const collectionGroup of ["wallActionRate", "wallpaper_stats_daily"]) {
    assert.ok(config.fieldOverrides.some((o) => o.collectionGroup === collectionGroup && o.fieldPath === "expireAt" &&
      o.ttl === true), collectionGroup);
  }
});

test("walls have the colour search index: colors contains, review, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields[0]?.fieldPath === "colors" && i.fields[0].arrayConfig === "CONTAINS");
  assert.ok(index);
  assert.deepEqual(index.fields.slice(1).map((f) => [f.fieldPath, f.order]),
    [["review", "ASCENDING"], ["createdAt", "DESCENDING"], ["__name__", "DESCENDING"]]);
});

test("walls have the depth feed index: review, depth.tier in, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields[1]?.fieldPath === "depth.tier");
  assert.ok(index);
  assert.deepEqual(index.fields.map((f) => [f.fieldPath, f.order]),
    [["review", "ASCENDING"], ["depth.tier", "ASCENDING"], ["createdAt", "DESCENDING"], ["__name__", "DESCENDING"]]);
});

test("walls have the spatial feed index: review, spatial.tier in, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields[1]?.fieldPath === "spatial.tier");
  assert.ok(index);
  assert.deepEqual(index.fields.map((f) => [f.fieldPath, f.order]),
    [["review", "ASCENDING"], ["spatial.tier", "ASCENDING"], ["createdAt", "DESCENDING"], ["__name__", "DESCENDING"]]);
});

const hasIndex = (collectionGroup: string, fields: Array<[string, string]>, queryScope = "COLLECTION") =>
  config.indexes.some((i) => i.collectionGroup === collectionGroup &&
    i.queryScope === queryScope &&
    JSON.stringify(i.fields.map((f) => [f.fieldPath, f.order])) === JSON.stringify(fields));

test("economy v2 indexes: weekly xp leaderboard, drop reservation queue, active boosts", () => {
  assert.ok(hasIndex("usersv2", [["xpWeek.weekKey", "ASCENDING"], ["xpWeek.xp", "DESCENDING"]]));
  assert.ok(hasIndex("walls", [["dropReserved", "ASCENDING"], ["review", "ASCENDING"], ["createdAt", "ASCENDING"]]));
  assert.ok(hasIndex("boosts", [["endsAt", "ASCENDING"], ["startsAt", "DESCENDING"]]));
  assert.ok(hasIndex("draws", [["status", "ASCENDING"], ["settledAt", "DESCENDING"]]));
});

test("quest event rate docs expire through a TTL policy on expireAt", () => {
  assert.ok(config.fieldOverrides.some((o) => o.collectionGroup === "questEventRate" && o.fieldPath === "expireAt" &&
    o.ttl === true));
});

test("folders have the owner index: ownerId, newest update first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "folders");
  assert.ok(index);
  assert.deepEqual(index.fields.map((f) => [f.fieldPath, f.order]), [["ownerId", "ASCENDING"], ["updatedAt", "DESCENDING"]]);
});

test("folder items: account deletion finds them by owner across folders, repair reads the newest by owner", () => {
  const override = config.fieldOverrides.find((o) => o.collectionGroup === "items" && o.fieldPath === "ownerId") as
    (Override & {indexes: Array<{order?: string; queryScope: string}>}) | undefined;
  assert.ok(override);
  // An override replaces the default single-field indexes, so the client's per-folder query keeps its own scope.
  assert.deepEqual(override.indexes.map((i) => [i.order, i.queryScope]),
    [["ASCENDING", "COLLECTION"], ["ASCENDING", "COLLECTION_GROUP"]]);
  assert.ok(hasIndex("items", [["ownerId", "ASCENDING"], ["addedAt", "DESCENDING"]]));
});

test("walls have the remix index: remixOf, review, newest first", () => {
  assert.ok(hasIndex("walls", [["remixOf", "ASCENDING"], ["review", "ASCENDING"], ["createdAt", "DESCENDING"],
    ["__name__", "DESCENDING"]]));
});

test("walls have the protected spatial index the app queries: protected asset fields, review, spatial.tier, newest first", () => {
  const protectedFields = ["originalProtected", "wallpaper_url", "wallpaper_path", "wallpaper_sha", "thumb_path", "thumb_sha"]
    .map((field): [string, string] => [field, "ASCENDING"]);
  assert.ok(hasIndex("walls", [...protectedFields, ["review", "ASCENDING"], ["spatial.tier", "ASCENDING"],
    ["createdAt", "DESCENDING"], ["__name__", "DESCENDING"]]));
});
