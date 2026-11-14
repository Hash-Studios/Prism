import assert from "node:assert/strict";
import test from "node:test";
import {STUDIO_SERIES, type StudioSeries} from "../studio/series";

const winter = STUDIO_SERIES.find((s) => s.id === "winter-light") as StudioSeries;

const BANNED = ["person", "people", "man", "woman", "child", "children", "girl", "boy", "skier", "santa", "ornament",
  "ornaments", "bauble", "gift", "gifts", "present", "church", "chapel", "cathedral", "temple", "mosque", "synagogue",
  "shrine", "cross", "crucifix", "angel", "nativity", "menorah", "christmas"];
const BANNED_RE = new RegExp(`\\b(${BANNED.join("|")})\\b`, "i");

test("series ids are unique", () => {
  const ids = STUDIO_SERIES.map((s) => s.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("subject ids are unique across all series, because cooldown docs are keyed by subject id", () => {
  const ids = STUDIO_SERIES.flatMap((s) => s.subjects.map((subject) => subject.id));
  assert.equal(new Set(ids).size, ids.length);
});

test("palette ids are unique inside each series", () => {
  for (const series of STUDIO_SERIES) {
    const ids = series.palettes.map((p) => p.id);
    assert.equal(new Set(ids).size, ids.length, series.id);
  }
});

test("winter-light is a Nature series that starts off, with no depth", () => {
  assert.equal(winter.category, "Nature");
  assert.deepEqual(winter.tags, ["winter", "snow"]);
  assert.equal(winter.startsOff, true);
  assert.equal(winter.depth, undefined);
});

test("winter-light has 30 subjects and 6 palettes, each with the required fields", () => {
  assert.equal(winter.subjects.length, 30);
  assert.equal(winter.palettes.length, 6);
  for (const subject of winter.subjects) {
    assert.ok(subject.id.length > 0, "subject id");
    assert.ok(subject.title.length > 0, `title of ${subject.id}`);
    assert.ok(subject.prompt.length > 0, `prompt of ${subject.id}`);
    assert.equal(subject.tags.length, 2, `tags of ${subject.id}`);
    assert.ok(subject.tags.every((t) => t.length > 0), `tags of ${subject.id}`);
  }
  for (const palette of winter.palettes) {
    assert.ok(palette.id.length > 0, "palette id");
    assert.ok(palette.name.length > 0, `name of ${palette.id}`);
    assert.ok(palette.prompt.length > 0, `prompt of ${palette.id}`);
    assert.ok(palette.tags.length >= 1, `tags of ${palette.id}`);
  }
});

test("winter-light has no banned word in its style, subjects or palettes", () => {
  const texts = [
    winter.style,
    ...winter.subjects.flatMap((s) => [s.id, s.title, s.prompt, ...s.tags]),
    ...winter.palettes.flatMap((p) => [p.name, p.prompt, ...p.tags]),
  ];
  for (const text of texts) {
    assert.doesNotMatch(text, BANNED_RE, text);
  }
});
