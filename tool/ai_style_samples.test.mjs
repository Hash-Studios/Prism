import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { planSamples, readStyles, remoteExists, sampleUrl } from './ai_style_samples.mjs';

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
