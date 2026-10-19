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

test("mapLabelsToCategory matches whole words, so a keyword inside a longer word does not count", () => {
  assert.equal(mapLabelsToCategory(["Playing card"]), "General");
  assert.equal(mapLabelsToCategory(["Cartoon"]), "Anime");
  assert.equal(mapLabelsToCategory(["Street", "Seat", "Train"]), "General");
  assert.equal(mapLabelsToCategory(["Car"]), "Cars");
});

test("mapLabelsToCategory matches plurals and keywords of more than one word", () => {
  assert.equal(mapLabelsToCategory(["Mountains"]), "Nature");
  assert.equal(mapLabelsToCategory(["Natural landscape"]), "Nature");
  assert.equal(mapLabelsToCategory(["Darkness"]), "Dark");
  assert.equal(mapLabelsToCategory(["Milky Way"]), "Galaxy");
  assert.equal(mapLabelsToCategory(["3D modeling"]), "3D Render");
});
