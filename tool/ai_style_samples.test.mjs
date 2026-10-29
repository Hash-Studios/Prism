import assert from 'node:assert/strict';
import { access, mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  generationId,
  main,
  planSamples,
  promptFor,
  rawImage,
  readStyles,
  remoteExists,
  sampleUrl,
  SEED_OVERRIDES,
  seedFor,
  selectStyles,
} from './ai_style_samples.mjs';

const dartEnum = await readFile(new URL('../lib/features/ai_wallpaper/domain/entities/ai_style_preset.dart', import.meta.url), 'utf8');
const styles = readStyles(dartEnum);

test('reads the 13 styles from the Dart enum with the app slugs', () => {
  assert.deepEqual(
    styles.map((s) => s.slug),
    ['anime', 'minimal', 'cyberpunk', 'watercolor', 'mesh-gradient', 'abstract', 'nature', 'space-art', 'synthwave',
      'pixel-art', '3d-render', 'oil-painting', 'ukiyo-e'],
  );
});

test('builds the same URL as AiStylePreset.sampleUrl', () => {
  assert.equal(
    sampleUrl('mesh-gradient', 'tile'),
    'https://prismwalls.com/api/ai/assets/ai/studio/style-samples-v1-mesh-gradient-tile.webp',
  );
});

test('dry run lists 13 styles x 2 sizes when nothing exists', async () => {
  const plan = await planSamples({ styles, exists: async () => false });
  assert.equal(plan.items.length, 26);
  assert.equal(plan.items.filter((i) => i.size === 'tile').length, 13);
  assert.equal(plan.items.filter((i) => i.size === 'sheet').length, 13);
  assert.equal(plan.generate.length, 13);
  assert.equal(plan.costUsd, 0.52);
});

test('skips files that exist and generates only styles with a missing size', async () => {
  const present = new Set([
    sampleUrl('anime', 'tile'),
    sampleUrl('anime', 'sheet'),
    sampleUrl('nature', 'tile'),
  ]);
  const plan = await planSamples({ styles, exists: async (url) => present.has(url) });
  assert.deepEqual(plan.items.filter((i) => i.exists).map((i) => i.fileName), [
    'style-samples-v1-anime-tile.webp',
    'style-samples-v1-anime-sheet.webp',
    'style-samples-v1-nature-tile.webp',
  ]);
  assert.equal(plan.generate.length, 12);
  assert.ok(!plan.generate.some((s) => s.slug === 'anime'));
  assert.ok(plan.generate.some((s) => s.slug === 'nature'));
  assert.equal(plan.costUsd, 0.48);
});

test('a second run after a full upload plans nothing', async () => {
  const plan = await planSamples({ styles, exists: async () => true });
  assert.equal(plan.generate.length, 0);
  assert.equal(plan.costUsd, 0);
});

test('remoteExists reads 200 and 404 and refuses anything else', async () => {
  const reply = (status) => async () => ({ status });
  assert.equal(await remoteExists('u', reply(200)), true);
  assert.equal(await remoteExists('u', reply(404)), false);
  await assert.rejects(remoteExists('u', reply(503)), /503/);
});

test('--replace makes a style again even when its files exist', async () => {
  const plan = await planSamples({ styles, exists: async () => true, replace: ['3d-render'] });
  assert.deepEqual(plan.items.filter((i) => !i.exists).map((i) => i.fileName), [
    'style-samples-v1-3d-render-tile.webp',
    'style-samples-v1-3d-render-sheet.webp',
  ]);
  assert.deepEqual(plan.generate.map((s) => s.slug), ['3d-render']);
  assert.equal(plan.costUsd, 0.04);
});

test('--replace works with --only and rejects an excluded or unknown style', () => {
  const selected = selectStyles(styles, { only: ['3d-render'], replace: ['3d-render'] });
  assert.deepEqual(selected.map((style) => style.slug), ['3d-render']);
  assert.throws(
    () => selectStyles(styles, { only: ['anime'], replace: ['3d-render'] }),
    /excluded by --only: 3d-render/,
  );
  assert.throws(() => selectStyles(styles, { only: ['missing'], replace: [] }), /Unknown style: missing/);
  assert.throws(() => selectStyles(styles, { only: ['anime'], replace: ['missing'] }), /Unknown style: missing/);
});

test('--dry-run --replace checks URLs without generation or file writes', async () => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'ai-style-samples-dry-run-'));
  const outputDir = path.join(tempDir, 'output');
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  const originalSecret = process.env.STUDIO_SECRET;
  const requests = [];
  const logs = [];
  console.log = (message) => logs.push(String(message));
  globalThis.fetch = async (url, init) => {
    requests.push({ url: String(url), method: init.method });
    if (init.method !== 'HEAD') throw new Error('unexpected request');
    return new Response(null, { status: 200 });
  };
  delete process.env.STUDIO_SECRET;
  try {
    await main(['--dry-run', '--only=anime,3d-render', '--replace=3d-render', `--out=${outputDir}`]);
    assert.equal(requests.length, 2);
    assert.ok(requests.every((request) => request.method === 'HEAD'));
    assert.ok(logs.some((message) => message.includes('4 files (2 styles x 2 sizes), 2 missing, 1 generations')));
    await assert.rejects(access(outputDir));
  } finally {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
    if (originalSecret === undefined) delete process.env.STUDIO_SECRET;
    else process.env.STUDIO_SECRET = originalSecret;
    await rm(tempDir, { recursive: true, force: true });
  }
});

test('a new seed gets a new generation id and raw cache path; the same id reuses raw bytes', async () => {
  assert.equal(seedFor('3d-render'), 20261031);
  assert.equal(generationId('3d-render'), 'style-samples-v1-3d-render-20261031');

  const out = await mkdtemp(path.join(os.tmpdir(), 'ai-style-samples-'));
  const originalFetch = globalThis.fetch;
  const originalSeed = SEED_OVERRIDES['3d-render'];
  const requests = [];
  let generated = 0;
  globalThis.fetch = async (url, init = {}) => {
    requests.push({ url: String(url), method: init.method ?? 'GET', body: init.body });
    if (init.method === 'POST') {
      generated += 1;
      return new Response(JSON.stringify({ imageUrl: `https://example.test/image-${generated}`, width: 1080, height: 1920 }));
    }
    return new Response(Buffer.from(`raw image bytes ${url.endsWith('image-1') ? '1' : '2'}`));
  };
  try {
    const style = styles.find((item) => item.slug === '3d-render');
    SEED_OVERRIDES['3d-render'] = 20261030;
    const first = await rawImage(style, out, 'test-secret');
    const cached = await rawImage(style, out, 'test-secret');
    SEED_OVERRIDES['3d-render'] = 20261031;
    const regenerated = await rawImage(style, out, 'test-secret');
    assert.deepEqual(first, Buffer.from('raw image bytes 1'));
    assert.deepEqual(cached, first);
    assert.deepEqual(regenerated, Buffer.from('raw image bytes 2'));
    assert.equal(requests.length, 4);
    assert.notEqual('style-samples-v1-3d-render-20261030', generationId('3d-render'));
    assert.deepEqual(requests.filter((request) => request.method === 'POST').map((request) => JSON.parse(request.body).id), [
      'style-samples-v1-3d-render-20261030',
      'style-samples-v1-3d-render-20261031',
    ]);
  } finally {
    SEED_OVERRIDES['3d-render'] = originalSeed;
    globalThis.fetch = originalFetch;
    await rm(out, { recursive: true, force: true });
  }
});

test('the sample prompt uses the worker style text', () => {
  const style = (slug) => styles.find((s) => s.slug === slug);
  assert.equal(promptFor(style('anime')), 'a lighthouse on a cliff at dusk, anime style');
  assert.equal(
    promptFor(style('3d-render')),
    'a lighthouse on a cliff at dusk, stylized 3D render, smooth matte clay-like materials, soft global illumination, '
      + 'rendered CGI look',
  );
});
