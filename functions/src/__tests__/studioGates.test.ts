import assert from "node:assert/strict";
import test from "node:test";
import sharp from "sharp";
import {
  depthCheck,
  duplicateCheck,
  imageSignature,
  likelihoodRank,
  runGates,
  signatureSimilarity,
  sizeCheck,
  visionCheck,
  type VisionResult,
} from "../studio/gates";
import {flatPng, gradientPng} from "./studioTestUtil";

const clean: VisionResult = {
  safeSearchAnnotation: {adult: "VERY_UNLIKELY", racy: "UNLIKELY", violence: "VERY_UNLIKELY", medical: "VERY_UNLIKELY"},
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
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {adult: 3, racy: "UNLIKELY"}}).reasons,
    ["unsafe_adult", "safe_search_unknown_violence", "safe_search_unknown_medical"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {violence: "VERY_LIKELY"}}).reasons,
    ["safe_search_unknown_adult", "safe_search_unknown_racy", "unsafe_violence", "safe_search_unknown_medical"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {...clean.safeSearchAnnotation, spoof: "VERY_LIKELY"} as
    VisionResult["safeSearchAnnotation"]}).reasons, []);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: null}).reasons, ["safe_search_missing"]);
  assert.deepEqual(visionCheck({...clean, safeSearchAnnotation: {adult: "UNKNOWN", racy: "UNLIKELY"}}).reasons,
    ["safe_search_unknown_adult", "safe_search_unknown_violence", "safe_search_unknown_medical"]);
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

/** A near-black AMOLED wall with faint grain and one lit subject, like the After Dark series. */
function darkWall(subject: string, grainSeed = 7): Promise<Buffer> {
  let state = grainSeed;
  const next = () => (state = (state * 1103515245 + 12345) % 2147483648) / 2147483648;
  let grain = "";
  for (let i = 0; i < 300; i++) {
    const v = Math.floor(next() * 14);
    grain += `<circle cx='${next() * 1440}' cy='${next() * 3200}' r='${20 + next() * 80}' fill='rgb(${v},${v},${v + 3})'/>`;
  }
  const svg = "<svg xmlns='http://www.w3.org/2000/svg' width='1440' height='3200'>" +
    `<rect width='100%' height='100%' fill='#050507'/>${grain}${subject}</svg>`;
  return sharp(Buffer.from(svg)).png().toBuffer();
}

const LIGHTHOUSE = "<rect x='690' y='1400' width='60' height='700' fill='#eee'/>" +
  "<polygon points='720,1450 1440,1200 1440,1350' fill='#ffd27f' opacity='0.6'/>";
const JELLYFISH = "<ellipse cx='760' cy='1450' rx='200' ry='140' fill='#a26bff'/>" +
  "<rect x='600' y='1500' width='12' height='500' fill='#a26bff'/><rect x='760' y='1500' width='12' height='600' fill='#a26bff'/>";

test("a signature survives a JPEG round trip, a tint and a small crop", async () => {
  const wall = await darkWall(LIGHTHOUSE);
  const signature = await imageSignature(wall);
  assert.equal(Buffer.from(signature, "base64").length, 16 * 36);
  const copies = [
    await sharp(wall).jpeg({quality: 60}).toBuffer(),
    await sharp(wall).modulate({brightness: 1.08, saturation: 1.2, hue: 12}).png().toBuffer(),
    await sharp(wall).extract({left: 14, top: 32, width: 1412, height: 3136}).resize(1440, 3200).png().toBuffer(),
  ];
  for (const copy of copies) assert.ok(signatureSimilarity(signature, await imageSignature(copy)) >= 0.93);
});

test("two different dark walls are not duplicates (a 64-bit dHash called them the same)", async () => {
  const lighthouse = await imageSignature(await darkWall(LIGHTHOUSE));
  const jellyfish = await imageSignature(await darkWall(JELLYFISH));
  assert.ok(signatureSimilarity(lighthouse, jellyfish) < 0.93);
  const left = await imageSignature(await gradientPng(90, 160, true));
  const right = await imageSignature(await gradientPng(90, 160, false));
  assert.ok(signatureSimilarity(left, right) < 0);
});

test("a flat image or a bad signature has similarity 0", async () => {
  const flat = await imageSignature(await flatPng(40, 40));
  const wall = await imageSignature(await darkWall(LIGHTHOUSE));
  assert.equal(signatureSimilarity(flat, wall), 0);
  assert.equal(signatureSimilarity("bad", wall), 0);
});

test("an exact flat duplicate is rejected and a corrupt known signature fails closed", async () => {
  const flat = await imageSignature(await flatPng(40, 40));
  assert.deepEqual(duplicateCheck(flat, [{signature: flat, wallId: "FLAT"}]).reasons, ["duplicate"]);
  assert.deepEqual(duplicateCheck(flat, [{signature: "bad", wallId: "BROKEN"}]).reasons,
    ["invalid_known_signature"]);
});

test("the most similar known wall decides a duplicate and is recorded", async () => {
  const lighthouse = await imageSignature(await darkWall(LIGHTHOUSE));
  const copy = await imageSignature(await sharp(await darkWall(LIGHTHOUSE)).jpeg({quality: 70}).toBuffer());
  const jellyfish = await imageSignature(await darkWall(JELLYFISH));
  const known = [{signature: jellyfish, wallId: "FAR"}, {signature: copy, wallId: "NEAR"}];
  const result = duplicateCheck(lighthouse, known);
  assert.deepEqual(result.reasons, ["duplicate"]);
  assert.equal(result.details.nearestWallId, "NEAR");
  assert.deepEqual(duplicateCheck(lighthouse, [{signature: jellyfish, wallId: "W"}]).reasons, []);
  assert.deepEqual(duplicateCheck(lighthouse, []).details, {nearestSimilarity: null, nearestWallId: null});
});

test("runGates passes a clean wallpaper and sends Vision one downscaled JPEG", async () => {
  const sent: Buffer[] = [];
  const result = await runGates(await flatPng(1440, 3200), {
    annotate: async (jpeg) => {
      sent.push(jpeg);
      return clean;
    },
    knownSignatures: async () => [{signature: await imageSignature(await darkWall(JELLYFISH)), wallId: "W1"}],
  });
  assert.equal(result.passed, true);
  assert.deepEqual(result.reasons, []);
  assert.equal(result.signature, await imageSignature(await flatPng(1440, 3200)));
  assert.deepEqual(result.details.duplicate, {nearestSimilarity: 0, nearestWallId: "W1"});
  assert.equal(sent.length, 1);
  const meta = await sharp(sent[0]).metadata();
  assert.deepEqual([meta.format, meta.width, meta.height], ["jpeg", 720, 1600]);
});

test("runGates runs every check and lists all reasons", async () => {
  const small = await sharp(await darkWall(LIGHTHOUSE)).resize(720, 1600).png().toBuffer();
  const result = await runGates(small, {
    annotate: async () => ({...clean, logoAnnotations: [{description: "X", score: 0.9}]}),
    knownSignatures: async () => [{signature: await imageSignature(await darkWall(LIGHTHOUSE)), wallId: "W1"}],
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
    knownSignatures: async () => [],
  });
  assert.deepEqual(result, {passed: false, reasons: ["undecodable"], details: {}, signature: ""});
  assert.equal(calls, 0);
  const truncated = (await flatPng(1440, 3200)).subarray(0, 200);
  assert.deepEqual((await runGates(truncated, {annotate: async () => clean, knownSignatures: async () => []})).reasons,
    ["undecodable"]);
});

test("depthCheck passes auto and menu and rejects none as depth", () => {
  const depth = (tier: "auto" | "menu" | "none") => ({tier, kind: "person" as const, top: 0.2, v: 1, by: "detector" as const});
  assert.deepEqual(depthCheck(depth("auto")), {reasons: [], details: {tier: "auto", kind: "person", top: 0.2}});
  assert.deepEqual(depthCheck(depth("menu")).reasons, []);
  assert.deepEqual(depthCheck(depth("none")).reasons, ["depth"]);
});

test("runGates sends the depth check the same JPEG as Vision and adds its reason", async () => {
  const sent: Buffer[] = [];
  const checked: Buffer[] = [];
  const none = {tier: "none" as const, kind: "sky" as const, top: 0.5, v: 1, by: "detector" as const};
  const result = await runGates(await flatPng(1440, 3200), {
    annotate: async (jpeg) => {
      sent.push(jpeg);
      return clean;
    },
    knownSignatures: async () => [],
    depth: async (jpeg) => {
      checked.push(jpeg);
      return none;
    },
  });
  assert.equal(result.passed, false);
  assert.deepEqual(result.reasons, ["depth"]);
  assert.deepEqual(result.details.depth, {tier: "none", kind: "sky", top: 0.5});
  assert.deepEqual(result.depth, none);
  assert.ok(checked[0].equals(sent[0]));

  const plain = await runGates(await flatPng(1440, 3200), {annotate: async () => clean, knownSignatures: async () => []});
  assert.equal(plain.passed, true);
  assert.equal("depth" in plain.details, false);
  assert.equal(plain.depth, undefined);
});
