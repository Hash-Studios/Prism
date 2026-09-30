import assert from "node:assert/strict";
import test from "node:test";

import {mapLabelsToCategory} from "../wallCategory";

test("mapLabelsToCategory returns the first matching category, case-insensitively", () => {
  assert.equal(mapLabelsToCategory(["Mountain"]), "Nature");
  assert.equal(mapLabelsToCategory(["Anime girl"]), "Anime");
  assert.equal(mapLabelsToCategory(["Coral reef"]), "Ocean");
  assert.equal(mapLabelsToCategory(["Sports car", "Sky"]), "Nature");
});

test("mapLabelsToCategory falls back to General", () => {
  assert.equal(mapLabelsToCategory([]), "General");
  assert.equal(mapLabelsToCategory(["zzz"]), "General");
});
