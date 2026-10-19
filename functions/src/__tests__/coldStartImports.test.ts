import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import path from "node:path";
import {test} from "node:test";

function runChild(script: string, ...args: string[]): void {
  const child = spawnSync(process.execPath, ["-e", script, ...args], {
    cwd: path.resolve(__dirname, "../.."),
    encoding: "utf8",
    env: {...process.env, FUNCTION_TARGET: "awardCoins"},
  });

  assert.equal(child.error, undefined, child.error?.message);
  assert.equal(child.status, 0, `${child.stdout}\n${child.stderr}`);
}

const entrypoint = path.resolve(__dirname, "../index.js");

test("loading the callable entrypoint does not load image SDKs", () => {
  const script = [
    "const index = require(process.argv[1]);",
    "if (typeof index.awardCoins?.run !== 'function') throw new Error('awardCoins callable is unavailable');",
    "const cache = Object.keys(require.cache);",
    "const loaded = cache.filter((filename) =>",
    "  /(?:^|\\/)node_modules\\/(?:sharp|@google-cloud\\/vision)(?:\\/|$)/.test(filename));",
    "if (loaded.length) throw new Error(`image SDKs loaded: ${loaded.join(', ')}`);",
  ].join("\n");
  runChild(script, entrypoint);
});

test("the Studio image path lazily loads sharp and keeps its image output", () => {
  const processModule = path.resolve(__dirname, "../studio/process.js");
  const gatesModule = path.resolve(__dirname, "../studio/gates.js");
  const script = [
    "const index = require(process.argv[1]);",
    "if (typeof index.awardCoins?.run !== 'function') throw new Error('awardCoins callable is unavailable');",
    "const {imageSignature} = require(process.argv[2]);",
    "const {renderWallpaper} = require(process.argv[3]);",
    "const image = Buffer.from('<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"20\"><rect width=\"10\" height=\"20\" fill=\"black\"/></svg>');",
    "Promise.all([imageSignature(image), renderWallpaper(image)]).then(([signature, rendered]) => {",
    "  if (signature !== Buffer.alloc(16 * 36).toString('base64')) throw new Error('unexpected image signature');",
    "  if (rendered.width !== 10 || rendered.height !== 20) throw new Error('unexpected rendered dimensions');",
    "  const cache = Object.keys(require.cache);",
    "  if (!cache.some((filename) => /(?:^|\\/)node_modules\\/sharp(?:\\/|$)/.test(filename))) {",
    "    throw new Error('sharp was not cached after image work');",
    "  }",
    "  if (cache.some((filename) => /(?:^|\\/)node_modules\\/@google-cloud\\/vision(?:\\/|$)/.test(filename))) {",
    "    throw new Error('Vision loaded during sharp-only image work');",
    "  }",
    "}).catch((error) => { console.error(error); process.exitCode = 1; });",
  ].join("\n");

  runChild(script, entrypoint, gatesModule, processModule);
});

test("Vision-backed helpers preserve their requests without making network calls", () => {
  const wallCategoryModule = path.resolve(__dirname, "../wallCategory.js");
  const gatesModule = path.resolve(__dirname, "../studio/gates.js");
  const wallDepthModule = path.resolve(__dirname, "../wallDepth.js");
  const script = [
    "const index = require(process.argv[1]);",
    "if (typeof index.awardCoins?.run !== 'function') throw new Error('awardCoins callable is unavailable');",
    "const {ImageAnnotatorClient} = require('@google-cloud/vision');",
    "const requests = [];",
    "ImageAnnotatorClient.prototype.annotateImage = async function(request) {",
    "  requests.push(request);",
    "  return [{labelAnnotations: [{description: 'nature', score: 0.9}], safeSearchAnnotation: {adult: 'VERY_UNLIKELY', racy: 'VERY_UNLIKELY', violence: 'VERY_UNLIKELY', medical: 'VERY_UNLIKELY'}, textAnnotations: [{description: 'whole image'}], logoAnnotations: []}];",
    "};",
    "const {detectLabels} = require(process.argv[2]);",
    "const {annotateWithVision} = require(process.argv[3]);",
    "const {annotateForDepth} = require(process.argv[4]);",
    "Promise.all([detectLabels('https://example.com/wall.jpg'), annotateWithVision(Buffer.from('jpeg')), annotateForDepth({url: 'https://example.com/depth.jpg'}), annotateForDepth({jpeg: Buffer.from('depth-jpeg')})]).then(([labels, studioResult, depthUrlResult, depthContentResult]) => {",
    "  if (labels.length !== 1 || labels[0] !== 'nature') throw new Error('unexpected labels');",
    "  const categoryRequest = requests.find((request) => request.features.some((feature) => feature.type === 'LABEL_DETECTION' && feature.maxResults === 10));",
    "  const studioRequest = requests.find((request) => request.features.some((feature) => feature.type === 'SAFE_SEARCH_DETECTION'));",
    "  const depthRequests = requests.filter((request) => request.features.some((feature) => feature.type === 'OBJECT_LOCALIZATION'));",
    "  if (!categoryRequest || categoryRequest.features[0].type !== 'LABEL_DETECTION' || categoryRequest.image.source.imageUri !== 'https://example.com/wall.jpg') throw new Error('category Vision payload changed');",
    "  if (!studioRequest || studioRequest.features.map((feature) => feature.type).join(',') !== 'SAFE_SEARCH_DETECTION,TEXT_DETECTION,LOGO_DETECTION' || !studioRequest.image.content.equals(Buffer.from('jpeg'))) throw new Error('Studio Vision payload changed');",
    "  if (studioResult.safeSearchAnnotation.adult !== 'VERY_UNLIKELY') throw new Error('Studio Vision response was not returned');",
    "  if (depthRequests.length !== 2) throw new Error('expected URL and content depth requests');",
    "  const depthUrlRequest = depthRequests.find((request) => request.image.source?.imageUri === 'https://example.com/depth.jpg');",
    "  const depthContentRequest = depthRequests.find((request) => request.image.content?.equals(Buffer.from('depth-jpeg')));",
    "  for (const request of depthRequests) if (request.features.map((feature) => `${feature.type}:${feature.maxResults}`).join(',') !== 'LABEL_DETECTION:20,OBJECT_LOCALIZATION:10') throw new Error('depth Vision features changed');",
    "  if (!depthUrlRequest || !depthContentRequest || depthUrlResult.labelAnnotations[0].description !== 'nature' || depthContentResult.labelAnnotations[0].description !== 'nature') throw new Error('depth Vision payload or response changed');",
    "}).catch((error) => { console.error(error); process.exitCode = 1; });",
  ].join("\n");

  runChild(script, entrypoint, wallCategoryModule, gatesModule, wallDepthModule);
});
