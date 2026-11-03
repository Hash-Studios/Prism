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

test("maps game labels to Gaming", () => {
  assert.equal(mapLabelsToCategory(["Video game software"]), "Gaming");
  assert.equal(mapLabelsToCategory(["PC game"]), "Gaming");
  assert.equal(mapLabelsToCategory(["Action-adventure game"]), "Gaming");
  assert.equal(mapLabelsToCategory(["Game controller"]), "Gaming");
  assert.equal(mapLabelsToCategory(["Esports"]), "Gaming");
  assert.equal(mapLabelsToCategory(["Shooter game"]), "Gaming");
});

test("maps pastel labels to Pastel", () => {
  assert.equal(mapLabelsToCategory(["Pastel"]), "Pastel");
  assert.equal(mapLabelsToCategory(["Pastel colors"]), "Pastel");
});

test("Gaming keeps out of the categories before it", () => {
  assert.equal(mapLabelsToCategory(["Mountain", "PC game"]), "Nature");
  assert.equal(mapLabelsToCategory(["Building", "Video game"]), "Architecture");
  assert.equal(mapLabelsToCategory(["Sports car", "Video game software"]), "Cars");
  assert.equal(mapLabelsToCategory(["Anime", "Video game"]), "Anime");
  assert.equal(mapLabelsToCategory(["Manga", "PC game"]), "Anime");
});

test("Gaming takes game art that only names a character", () => {
  assert.equal(mapLabelsToCategory(["Fictional character", "Video game software"]), "Gaming");
  assert.equal(mapLabelsToCategory(["CG artwork", "Fictional character", "PC game", "Armour"]), "Gaming");
  assert.equal(mapLabelsToCategory(["Fictional character"]), "Anime");
  assert.equal(mapLabelsToCategory(["Cartoon"]), "Anime");
  assert.equal(mapLabelsToCategory(["Illustration"]), "Anime");
});

test("a plain game word is not Gaming", () => {
  assert.equal(mapLabelsToCategory(["Dice game"]), "General");
  assert.equal(mapLabelsToCategory(["Card game", "Gambling"]), "General");
  assert.equal(mapLabelsToCategory(["Bat-and-ball games", "Baseball"]), "General");
});

test("Pastel never takes a wall that another category matches", () => {
  const pairs: ReadonlyArray<readonly [string, string]> = [
    ["Nature", "mountain"],
    ["Architecture", "building"],
    ["Cars", "car"],
    ["Anime", "anime"],
    ["Gaming", "video game"],
    ["Space", "planet"],
    ["Ocean", "coral"],
    ["Flowers", "tulip"],
    ["Neon", "neon"],
    ["Dark", "darkness"],
    ["Abstract", "geometric"],
    ["3D Render", "cgi"],
    ["Minimal", "plain"],
    ["Gradient", "color gradient"],
    ["AI Art", "generated"],
    ["Cyberpunk", "robot"],
    ["Vintage", "retro"],
    ["Landscape", "desert"],
    ["Galaxy", "milky way"],
  ];

  for (const [category, keyword] of pairs) {
    assert.equal(mapLabelsToCategory([keyword, "Pastel"]), category, `${category}: ${keyword} then Pastel`);
    assert.equal(mapLabelsToCategory(["Pastel", keyword]), category, `${category}: Pastel then ${keyword}`);
  }
});

test("Pastel does not take Gradient or Minimal walls", () => {
  assert.equal(mapLabelsToCategory(["Gradient", "Pastel"]), "Gradient");
  assert.equal(mapLabelsToCategory(["Mesh gradient", "Pastel colors"]), "Gradient");
  assert.equal(mapLabelsToCategory(["White", "Pastel"]), "Minimal");
  assert.equal(mapLabelsToCategory(["Simple", "Pastel"]), "Minimal");
});
