import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync, mkdirSync, mkdtempSync, copyFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
test('spec generator writes literal modules and check detects drift in each target', () => {
  const temp = mkdtempSync(join(tmpdir(), 'prism-duo-spec-'));
  try {
    for (const path of ['tool/generate_duo_reveal.mjs', 'shared/duo_reveal.json', 'shared/duo_banned_phrases.json']) {
      mkdirSync(dirname(join(temp, path)), {recursive: true});
      copyFileSync(join(root, path), join(temp, path));
    }
    const run = (...args) => spawnSync(process.execPath, [join(temp, 'tool/generate_duo_reveal.mjs'), ...args]);
    assert.equal(run().status, 0);
    assert.equal(run('--check').status, 0);
    for (const path of ['lib/core/wallpaper/duo_reveal_spec.g.dart', 'functions/src/duo_reveal_spec.ts',
      'infra/cloudflare/worker/src/duo_reveal_spec.ts', 'web/lib/duo_reveal_spec.ts']) {
      const full = join(temp, path);
      const original = readFileSync(full, 'utf8');
      assert.match(original, /canvasHeight \* outerWidth \/ outerHeight \/ canvasWidth/);
      writeFileSync(full, original.replace('2670', '2000'));
      assert.equal(run('--check').status, 1, path);
      writeFileSync(full, original);
    }
  } finally { rmSync(temp, {recursive: true, force: true}); }
});
