import assert from "node:assert/strict";
import test, {beforeEach} from "node:test";
import * as admin from "firebase-admin";
import * as wallCategory from "../wallCategory";
import * as wallColors from "../wallColors";
import * as adminConfig from "../adminConfig";
import {installFakeDb} from "./fakeDb";

import {categorizeWallpaper, parseWallId} from "../categorizeWallpaper";

beforeEach((t) => {
  assert.ok("mock" in t);
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
});

test("a wall id must be a plain document id", () => {
  assert.equal(parseWallId(" abc123 "), "abc123");
  for (const bad of [undefined, null, 5, {}, "", "   ", "a/b", "..", ".", "__x__", "x".repeat(129)]) {
    assert.throws(() => parseWallId(bad), {code: "invalid-argument"});
  }
});

const request = (token: Record<string, unknown> = {email: "owner@test", email_verified: true}) => ({
  auth: {uid: "owner", token}, data: {wallId: "w1"},
}) as unknown as Parameters<typeof categorizeWallpaper.run>[0];

test("non-admin categorization needs a verified, nonempty current owner email", async (t) => {
  const store = installFakeDb(t, {"walls/w1": {email: "", aiCategorized: true}});
  t.mock.method(adminConfig, "isAdminCaller", async () => false);
  await assert.rejects(() => categorizeWallpaper.run(request({})), {code: "permission-denied"});
  store.set("walls/w1", {email: "owner@test", aiCategorized: true});
  await assert.rejects(() => categorizeWallpaper.run(request({email: "owner@test"})), {code: "permission-denied"});
});

for (const edited of [false, true]) {
  test(`explicit admin recategorization ${edited ? "preserves an in-flight edit" : "replaces unchanged classification"}`, async (t) => {
    const original = {wallpaper_url: "https://image.test/a", category: "Space", collections: ["premium"],
      aiCategorized: true, colors: ["blue"]};
    const store = installFakeDb(t, {"walls/w1": original});
    t.mock.method(adminConfig, "isAdminCaller", async () => true);
    t.mock.method(wallCategory, "detectLabels", async () => {
      if (edited) store.set("walls/w1", {...original, category: "Custom", colors: ["red"], collections: ["curated"]});
      return ["Mountain"];
    });
    t.mock.method(wallColors, "wallColorsFor", async () => ["green"]);
    await categorizeWallpaper.run(request());
    assert.equal(store.get("walls/w1")?.category, edited ? "Custom" : "Nature");
    assert.deepEqual(store.get("walls/w1")?.collections, edited ? ["curated"] : ["premium"]);
    assert.deepEqual(store.get("walls/w1")?.colors, edited ? ["red"] : ["green"]);
  });
}

for (const change of ["owner", "source", "recreate", "delete"] as const) {
  test(`callable discards results after ${change} changes during remote analysis`, async (t) => {
    const original = {email: "owner@test", wallpaper_url: "https://image.test/a"};
    const store = installFakeDb(t, {"walls/w1": original});
    t.mock.method(adminConfig, "isAdminCaller", async () => false);
    t.mock.method(wallCategory, "detectLabels", async () => {
      if (change === "owner") store.set("walls/w1", {...original, email: "other@test"});
      if (change === "source") store.set("walls/w1", {...original, wallpaper_url: "https://image.test/new"});
      if (change === "recreate" || change === "delete") store.delete("walls/w1");
      if (change === "recreate") store.set("walls/w1", original);
      return ["Mountain"];
    });
    t.mock.method(wallColors, "wallColorsFor", async () => ["blue"]);
    await assert.rejects(() => categorizeWallpaper.run(request()), {code: "failed-precondition"});
    assert.equal(store.get("walls/w1")?.colors, undefined);
    assert.equal(store.get("walls/w1")?.category, undefined);
  });
}

test("the callable rejects bad input before reading Firestore", async () => {
  for (const data of [undefined, null, {}, {wallId: 7}, {wallId: "a/b"}]) {
    await assert.rejects(async () => {
      await categorizeWallpaper.run({auth: {uid: "u1", token: {}}, data} as unknown as Parameters<
        typeof categorizeWallpaper.run>[0]);
    }, {code: "invalid-argument"});
  }
});
