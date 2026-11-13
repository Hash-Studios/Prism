import assert from "node:assert/strict";
import test from "node:test";

import {mapLabelsToCategory} from "../wallCategory";

test("mapLabelsToCategory matches labels case-insensitively", () => {
  assert.equal(mapLabelsToCategory(["Mountain"]), "Nature");
  assert.equal(mapLabelsToCategory(["Anime girl"]), "Anime");
  assert.equal(mapLabelsToCategory(["Coral reef"]), "Ocean");
});

// #538. Vision gives labels best first. The old rule let the first matching rule win, so Nature took these walls.
test("the best-ranked label picks the category", () => {
  assert.equal(mapLabelsToCategory(["Anime girl", "Sky"]), "Anime");
  assert.equal(mapLabelsToCategory(["Sports car", "Sky"]), "Cars");
  assert.equal(mapLabelsToCategory(["Sports car", "Mountain"]), "Cars");
  assert.equal(mapLabelsToCategory(["Mountain", "Sports car"]), "Nature");
  assert.equal(mapLabelsToCategory(["Lighthouse", "Tower", "Beacon", "Sea", "Ocean"]), "Architecture");
  assert.equal(mapLabelsToCategory(["Desert", "Dune", "Sunset", "Sand"]), "Landscape");
});

test("a style or backdrop label loses to any subject label", () => {
  assert.equal(mapLabelsToCategory(["Sky", "Anime girl"]), "Anime");
  assert.equal(mapLabelsToCategory(["Sky", "Moon", "Cloud", "Astronomical object"]), "Space");
  assert.equal(mapLabelsToCategory(["Night", "Skyscraper", "Tower"]), "Architecture");
  assert.equal(mapLabelsToCategory(["Light", "Car"]), "Cars");
  assert.equal(mapLabelsToCategory(["Art", "Moon"]), "Space");
  assert.equal(mapLabelsToCategory(["Home", "Mountain"]), "Nature");
  assert.equal(mapLabelsToCategory(["Old-growth forest"]), "Nature");
  assert.equal(mapLabelsToCategory(["Leaf", "Green", "Petal", "Plant stem"]), "Flowers");
  assert.equal(mapLabelsToCategory(["Lighting", "Electricity", "Night", "Neon"]), "Neon");
});

test("with only style labels, the best-ranked one picks the category", () => {
  assert.equal(mapLabelsToCategory(["Red", "Art", "Pink", "Modern art"]), "Abstract");
  assert.equal(mapLabelsToCategory(["Night", "Star", "Midnight"]), "Dark");
  assert.equal(mapLabelsToCategory(["White", "Black", "Grey"]), "Minimal");
  assert.equal(mapLabelsToCategory(["Sky", "Cloud"]), "Nature");
});

test("in one label, the rule order breaks the tie", () => {
  assert.equal(mapLabelsToCategory(["Black and white"]), "Dark");
  assert.equal(mapLabelsToCategory(["Modern art"]), "Abstract");
  assert.equal(mapLabelsToCategory(["City car"]), "Architecture");
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

test("Gaming takes a wall only when its game label ranks first", () => {
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

// #538 regressions. Labels are the stored Vision labels of real approved walls, in score order.
test("a label that names anime beats Nature, so an anime wall with a sky stays Anime", () => {
  assert.equal(mapLabelsToCategory(["Sky", "Cloud", "Anime", "Cartoon"]), "Anime");
  assert.equal(mapLabelsToCategory(["Manga", "Tree"]), "Anime");
});

test("a space subject beats a plain illustration label", () => {
  assert.equal(mapLabelsToCategory(["Astronaut", "Astronomical object", "Outer space", "Illustration", "Animation",
    "Graphics"]), "Space");
});

test("flower close-up labels pick Flowers, and a plain flower in a landscape stays Nature", () => {
  assert.equal(mapLabelsToCategory(["Flower", "Petal", "Garden roses", "Flower bouquet", "Floristry", "Cut flowers"]),
    "Flowers");
  assert.equal(mapLabelsToCategory(["Mountain", "Flower", "Grass"]), "Nature");
});
