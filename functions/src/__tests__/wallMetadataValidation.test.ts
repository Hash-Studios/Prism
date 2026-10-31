import assert from "node:assert/strict";
import test from "node:test";
import {boundedDisplayText, parseWallText} from "../wallMetadataValidation";

test("wall metadata validation exists and rejects unsafe text without request filler restrictions", () => {
  assert.deepEqual(parseWallText({title: " The wall ", desc: "", tags: ["#Blue", "blue"]}),
    {title: "The wall", desc: "", tags: ["blue"]});
  for (const title of ["p0rn", "nuuudes", "secret\u202e", "x".repeat(61)]) {
    assert.throws(() => parseWallText({title, desc: "", tags: []}), {code: "invalid-argument"});
  }
  assert.throws(() => parseWallText({title: "safe", desc: "", tags: [], review: true}), {code: "invalid-argument"});
});

test("wall text policy accepts optional filler fields but rejects raw/Unicode/type/size bypasses", () => {
  for (const metadata of [
    {title: "", desc: "", tags: []}, {title: "wall", desc: "the", tags: ["#Blue", "blue"]},
    {title: "a".repeat(60), desc: "d".repeat(500), tags: Array.from({length: 8}, (_, i) => `tag${i}`)},
  ]) assert.doesNotThrow(() => parseWallText(metadata));
  for (const metadata of [
    {title: 1, desc: "", tags: []}, {title: {}, desc: "", tags: []}, {title: "safe", desc: null, tags: []},
    {title: "safe", desc: "", tags: [1]}, {title: "safe", desc: "", tags: ["x".repeat(25)]},
    {title: "safe", desc: "x".repeat(501), tags: []}, {title: "safe", desc: "", tags: Array(9).fill("x")},
    {title: "safe\ntext", desc: "", tags: []}, {title: "safe\u0000", desc: "", tags: []},
    {title: "safe", desc: "n\u0301u\u0301de", tags: []}, {title: "safe", desc: "", tags: ["p0rn"]},
    {title: "x" + "\u0301".repeat(300), desc: "", tags: []}, {title: "\ud800", desc: "", tags: []},
  ]) assert.throws(() => parseWallText(metadata), {code: "invalid-argument"});
});

test("private admin reasons reject malformed, control and oversized input but allow moderation vocabulary", () => {
  assert.equal(boundedDisplayText(" NSFW / sexual content ", 2000), "NSFW / sexual content");
  for (const value of [null, {}, 1, "x".repeat(2001), "unsafe\u202e", "line\ncontrol", "\ud800"]) {
    assert.throws(() => boundedDisplayText(value, 2000), {code: "invalid-argument"});
  }
});
