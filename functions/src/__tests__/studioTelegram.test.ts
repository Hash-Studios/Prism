import assert from "node:assert/strict";
import test from "node:test";
import {STUDIO_SERIES} from "../studio/series";
import {studioPrompt} from "../studio/plan";
import {studioPostCaption} from "../studio/telegram";

test("the caption is the subject scene, the collection line and up to five hashtags", () => {
  const series = STUDIO_SERIES.find((s) => s.id === "paper-worlds");
  assert.ok(series);
  const subject = series.subjects.find((s) => s.id === "autumn-road");
  const palette = series.palettes.find((p) => p.id === "autumn");
  assert.ok(subject && palette);
  const caption = studioPostCaption({
    seriesId: series.id,
    aiPrompt: studioPrompt(series, subject, palette),
    tags: ["illustration", "paper", "autumn", "road", "Nature", "extra"],
  });
  assert.equal(caption,
    "A winding road through layered autumn hills and round trees.\n\n" +
    "Part of the Paper Worlds collection by @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n" +
    "#wallpaper #illustration #paper #autumn #road");
});

test("an unknown series falls back to the prompt up to its first comma", () => {
  assert.equal(studioPostCaption({seriesId: "gone", aiPrompt: "a red kite, sunset palette. Style.", tags: ["kite"]}),
    "A red kite.\n\nBy @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n#wallpaper #kite");
});
