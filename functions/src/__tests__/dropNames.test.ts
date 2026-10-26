import assert from "node:assert/strict";
import test from "node:test";
import {dropMood, isoWeekNumber, pickDropName} from "../dropNames";

test("dropMood reads a night set", () => {
  assert.equal(dropMood([["black", "purple"], ["grey"], ["black"]]), "night");
});

test("dropMood reads a warm set", () => {
  assert.equal(dropMood([["orange", "red"], ["red"], ["yellow"]]), "warm");
});

test("dropMood reads a cool set", () => {
  assert.equal(dropMood([["blue", "teal"], ["teal"], ["blue"]]), "cool");
});

test("dropMood returns mixed for an even warm and cool split", () => {
  assert.equal(dropMood([["red"], ["blue"]]), "mixed");
});

test("dropMood returns mixed for empty input", () => {
  assert.equal(dropMood([]), "mixed");
});

test("dropMood ignores non-array entries and unknown ids", () => {
  assert.equal(dropMood([["black"], "x", null, ["nope"]]), "night");
});

test("dropMood ignores inherited object keys in malformed palette data", () => {
  assert.equal(dropMood([["constructor", "blue", "red"]]), "cool");
});

test("pickDropName returns the first name when nothing is recent", () => {
  assert.equal(pickDropName("night", [], 0), "After Hours");
});

test("pickDropName starts from the seed", () => {
  assert.equal(pickDropName("night", [], 9), "Blue Hour");
});

test("pickDropName skips names used by recent titles", () => {
  assert.equal(pickDropName("night", ["after hours ", "Blue Hour"], 0), "Low Light");
});

test("pickDropName returns the start name when every name is used", () => {
  const all = ["After Hours", "Blue Hour", "Low Light", "Night Shift", "Small Hours", "Moonrise", "Dark Room", "Night Swim"];
  assert.equal(pickDropName("night", all, 2), "Low Light");
});

test("pickDropName accepts a negative seed", () => {
  assert.equal(pickDropName("night", [], -1), "Night Swim");
});

test("isoWeekNumber reads the week number", () => {
  assert.equal(isoWeekNumber("2026-W44"), 44);
});

test("isoWeekNumber returns 0 for a bad key", () => {
  assert.equal(isoWeekNumber("bad"), 0);
});
