import assert from "node:assert/strict";
import test from "node:test";

import {categorizeWallpaper, parseWallId} from "../categorizeWallpaper";

test("a wall id must be a plain document id", () => {
  assert.equal(parseWallId(" abc123 "), "abc123");
  for (const bad of [undefined, null, 5, {}, "", "   ", "a/b", "..", ".", "__x__", "x".repeat(129)]) {
    assert.throws(() => parseWallId(bad), {code: "invalid-argument"});
  }
});

test("the callable rejects bad input before reading Firestore", async () => {
  for (const data of [undefined, null, {}, {wallId: 7}, {wallId: "a/b"}]) {
    await assert.rejects(async () => {
      await categorizeWallpaper.run({auth: {uid: "u1", token: {}}, data} as unknown as Parameters<
        typeof categorizeWallpaper.run>[0]);
    }, {code: "invalid-argument"});
  }
});
