import assert from "node:assert/strict";
import test from "node:test";
import sharp from "sharp";
import {
  dHash,
  duplicateCheck,
  hammingDistance,
  likelihoodRank,
  runGates,
  sizeCheck,
  visionCheck,
  type VisionResult,
} from "../studio/gates";
import {flatPng, gradientPng} from "./studioTestUtil";

const clean: VisionResult = {
  safeSearchAnnotation: {adult: "VERY_UNLIKELY", racy: "UNLIKELY", violence: "VERY_UNLIKELY", medical: "UNKNOWN"},
  textAnnotations: [],
  logoAnnotations: [],
};

test("likelihoods arrive as names or numbers; anything else is UNKNOWN", () => {
  assert.deepEqual(["UNKNOWN", "VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"].map(likelihoodRank),
    [0, 1, 2, 3, 4, 5]);
  assert.deepEqual([0, 3, 5].map(likelihoodRank), [0, 3, 5]);
  assert.deepEqual([undefined, null, "MAYBE", 9, -1, 2.5].map(likelihoodRank), [0, 0, 0, 0, 0, 0]);
});

test("size: portrait, short edge 1400+, long edge 3000+, height/width 2.0 to 2.4", () => {
  assert.deepEqual(sizeCheck(1440, 3200), {reasons: [], details: {width: 1440, height: 3200, aspect: 2.222}});
  assert.deepEqual(sizeCheck(1400, 3360).reasons, []);
  assert.deepEqual(sizeCheck(1080, 2400).reasons, ["too_small"]);
  assert.deepEqual(sizeCheck(3200, 1440).reasons, ["not_portrait", "aspect"]);
  assert.deepEqual(sizeCheck(1500, 2900).reasons, ["too_small", "aspect"]);
  assert.deepEqual(sizeCheck(1400, 3400).reasons, ["aspect"]);
});

test("safe search rejects POSSIBLE or higher for adult, racy, violence and medical, by name or number", () => {
  assert.deepEqual(visionCheck(clean).reasons, []);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {adult: "POSSIBLE", racy: 4, violence: 2, medical: 5}})
    .reasons, ["unsafe_adult", "unsafe_racy", "unsafe_medical"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {adult: 3, racy: "UNLIKELY"}}).reasons, ["unsafe_adult"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {violence: "VERY_LIKELY"}}).reasons, ["unsafe_violence"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {...clean.safeSearchAnnotation, spoof: "VERY_LIKELY"} as
    VisionResult["safeSearchAnnotation"]}).reasons, []);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: null}).reasons, ["safe_search_missing"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {adult: 4}}).details.safeSearch,
    {adult: "LIKELY", racy: "UNKNOWN", violence: "UNKNOWN", medical: "UNKNOWN"});
});

test("text rejects a detected word with 3 or more letters or digits; the first annotation is the whole block", () => {
  const words = (...w: string[]): VisionResult => ({...clean, textAnnotations: [{description: w.join(" ")},
    ...w.map((description) => ({description}))]});
  assert.deepEqual(visionCheck(words("ab", "a1", "1-2", "..")).reasons, []);
  assert.deepEqual(visionCheck(words("abc")).reasons, ["text"]);
  assert.deepEqual(visionCheck(words("a-1-b")).reasons, ["text"]);
  assert.deepEqual(visionCheck(words("ÉtÉ")).reasons, ["text"]);
  assert.deepEqual(visionCheck({...clean, textAnnotations: [{description: "LONG BLOCK"}]}).reasons, []);
  assert.deepEqual(visionCheck(words("ab", "xyz")).details.words, ["ab", "xyz"]);
});

test("a logo with score 0.5 or more rejects", () => {
  assert.deepEqual(visionCheck({...clean, logoAnnotations: [{description: "Brand", score: 0.49}]}).reasons, []);
  assert.deepEqual(visionCheck({...clean, logoAnnotations: [{description: "Brand", score: 0.5}]}).reasons, ["logo"]);
  assert.deepEqual(visionCheck({...clean, logoAnnotations: [{description: "Brand", score: null}]}).reasons, []);
});

test("hamming distance counts differing bits of two 16-hex hashes", () => {
  assert.equal(hammingDistance("0000000000000000", "0000000000000000"), 0);
  assert.equal(hammingDistance("0000000000000000", "ffffffffffffffff"), 64);
  assert.equal(hammingDistance("0000000000000001", "0000000000000003"), 1);
  assert.equal(hammingDistance("f0f0f0f0f0f0f0f0", "0f0f0f0f0f0f0f0f"), 64);
  assert.throws(() => hammingDistance("abc", "0000000000000000"));
});

test("dHash is 16 hex characters, stable through a JPEG round trip, and far from a mirrored image", async () => {
  const left = await gradientPng(90, 160, true);
  const right = await gradientPng(90, 160, false);
  const hash = await dHash(left);
  assert.match(hash, /^[0-9a-f]{16}$/);
  assert.equal(await dHash(left), hash);
  const jpeg = await sharp(left).resize(45, 80).jpeg({quality: 60}).toBuffer();
  assert.ok(hammingDistance(hash, await dHash(jpeg)) <= 6);
  assert.ok(hammingDistance(hash, await dHash(right)) > 6);
  assert.equal(await dHash(await flatPng(40, 40)), "0000000000000000");
});

test("a hash within distance 6 of a known one is a duplicate; the nearest one is recorded", () => {
  const known = [{hash: "ffffffffffffffff", wallId: "FAR"}, {hash: "000000000000003f", wallId: "NEAR"},
    {hash: "bad", wallId: "SKIP"}];
  assert.deepEqual(duplicateCheck("0000000000000000", known),
    {reasons: ["duplicate"], details: {hash: "0000000000000000", nearestDistance: 6, nearestWallId: "NEAR"}});
  assert.deepEqual(duplicateCheck("0000000000000000", [{hash: "000000000000007f", wallId: "W"}]).reasons, []);
  assert.deepEqual(duplicateCheck("0000000000000000", []).details,
    {hash: "0000000000000000", nearestDistance: null, nearestWallId: null});
});

test("runGates passes a clean wallpaper and sends Vision one downscaled JPEG", async () => {
  const sent: Buffer[] = [];
  const result = await runGates(await flatPng(1440, 3200), {
    annotate: async (jpeg) => {
      sent.push(jpeg);
      return clean;
    },
    knownHashes: async () => [{hash: "ffffffffffffffff", wallId: "W1"}],
  });
  assert.equal(result.passed, true);
  assert.deepEqual(result.reasons, []);
  assert.equal(result.hash, "0000000000000000");
  assert.deepEqual(result.details.duplicate, {hash: "0000000000000000", nearestDistance: 64, nearestWallId: "W1"});
  assert.equal(sent.length, 1);
  const meta = await sharp(sent[0]).metadata();
  assert.deepEqual([meta.format, meta.width, meta.height], ["jpeg", 720, 1600]);
});

test("runGates runs every check and lists all reasons", async () => {
  const result = await runGates(await flatPng(720, 1600), {
    annotate: async () => ({...clean, logoAnnotations: [{description: "X", score: 0.9}]}),
    knownHashes: async () => [{hash: "0000000000000001", wallId: "W1"}],
  });
  assert.equal(result.passed, false);
  assert.deepEqual(result.reasons, ["too_small", "duplicate", "logo"]);
});

test("runGates rejects bytes that do not decode without calling Vision", async () => {
  let calls = 0;
  const result = await runGates(Buffer.from("not an image at all"), {
    annotate: async () => {
      calls++;
      return clean;
    },
    knownHashes: async () => [],
  });
  assert.deepEqual(result, {passed: false, reasons: ["undecodable"], details: {}, hash: ""});
  assert.equal(calls, 0);
  const truncated = (await flatPng(1440, 3200)).subarray(0, 200);
  assert.deepEqual((await runGates(truncated, {annotate: async () => clean, knownHashes: async () => []})).reasons,
    ["undecodable"]);
});
