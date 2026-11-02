import assert from "node:assert/strict";
import test from "node:test";
import sharp from "sharp";
import {DUO_REVEAL_SPEC as spec, hasBannedDuoPhrase} from "../duo_reveal_spec";
import {DUO_SERIES, DUO_SUBJECT_PAIRS} from "../studio/duo";
import {buildDailyPlan, studioPrompt} from "../studio/plan";
import {sizeCheck} from "../studio/gates";
import {renderWallpaper} from "../studio/process";
import {seededRng} from "./studioTestUtil";

test("Duo manual plan has 24 unique original pairs, never scheduled by weights", () => {
  const input = {series: [DUO_SERIES], count: 24, weights: {"duo-reveal": 1000},
    recentSubjectIds: new Set<string>(), rng: seededRng(5)};
  assert.deepEqual(buildDailyPlan(input), []);
  const plan = buildDailyPlan({...input, manualSeriesId: "duo-reveal"});
  assert.equal(plan.length, 24);
  assert.equal(new Set(plan.map((item) => item.subjectId)).size, 24);
  assert.equal(DUO_SUBJECT_PAIRS.length, 24);
  for (const item of plan) {
    assert.equal(item.duoPresetId, "prism-right-v1");
    assert.deepEqual(item.tags.slice(0, 2), ["duo", "duo-reveal"]);
    assert.ok(item.prompt.includes("2670x1878"));
    assert.ok(!item.prompt.includes("Vertical phone"));
    assert.equal(hasBannedDuoPhrase(item.prompt), false);
  }
});

test("Duo catalog checks tags, titles, palette and full Unicode phrases", () => {
  for (const text of ["ＳＴＡＲ　ＷＡＲＳ", "mickey-mouse", "Ta\u200bylor Swift", "pokémon"]) {
    assert.equal(hasBannedDuoPhrase(text), true, text);
  }
  assert.equal(hasBannedDuoPhrase("a batmanlike rock and a sonic wave"), false);
  const subject = DUO_SERIES.subjects[0];
  const palette = DUO_SERIES.palettes[0];
  for (const replacement of [{title: "Mickey Mouse"}, {tags: ["star wars"]}, {foldedPrompt: "Pikachu"}]) {
    assert.throws(() => studioPrompt(DUO_SERIES, {...subject, ...replacement}, palette), /banned phrase/);
  }
  assert.throws(() => studioPrompt(DUO_SERIES, subject, {...palette, prompt: "Disney"}), /banned phrase/);
});

test("Duo size gate does not weaken portrait gates", () => {
  assert.deepEqual(sizeCheck(2670, 1878, true).reasons, []);
  assert.deepEqual(sizeCheck(2688, 1888, true).reasons, []);
  assert.ok(sizeCheck(2000, 1408, true).reasons.includes("duo_size"));
  assert.ok(sizeCheck(2670, 1878).reasons.includes("not_portrait"));
  assert.deepEqual(sizeCheck(1440, 3200).reasons, []);
});

test("sharp writes exact wide original and never upscales a small candidate", async () => {
  const bytes = await sharp({create: {width: 2688, height: 1888, channels: 3, background: "red"}}).png().toBuffer();
  const rendered = await renderWallpaper(bytes, true);
  assert.equal(rendered.width, 2670);
  assert.equal(rendered.height, 1878);
  const meta = await sharp(rendered.wall).metadata();
  assert.equal(meta.width, 2670);
  assert.equal(meta.height, 1878);
  assert.equal(meta.format, "jpeg");
  const small = await sharp(bytes).resize(2000, 1408).png().toBuffer();
  await assert.rejects(renderWallpaper(small, true), /cannot be enlarged/);
  assert.equal(spec.foldedLeftFraction, 1 - (1878 * 1398 / 2034 / 2670));
});
