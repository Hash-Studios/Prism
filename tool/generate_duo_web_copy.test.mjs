import assert from 'node:assert/strict';
import {test} from 'node:test';
import {copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
test('web copy comes only from English ARB and checks stale output without scratch files', () => {
  const temp = mkdtempSync(join(tmpdir(), 'prism-duo-copy-'));
  try {
    for (const path of ['tool', 'lib/l10n', 'web/lib']) mkdirSync(join(temp, path), {recursive: true});
    const script = join(temp, 'tool/generate_duo_web_copy.mjs');
    copyFileSync(join(root, 'tool/generate_duo_web_copy.mjs'), script);
    const arb = join(temp, 'lib/l10n/app_en.arb');
    writeFileSync(arb, JSON.stringify({duoWebTitle: 'Duo walls', '@duoWebTitle': {}, unrelated: 'Not exported'}));
    const run = (...args) => spawnSync(process.execPath, [script, ...args]);
    assert.equal(run().status, 0);
    const output = readFileSync(join(temp, 'web/lib/duo-copy.generated.ts'), 'utf8');
    assert.match(output, /Duo walls/);
    assert.doesNotMatch(output, /Not exported|@duoWebTitle/);
    assert.equal(run('--check').status, 0);
    writeFileSync(arb, JSON.stringify({duoWebTitle: 'Updated title'}));
    assert.equal(run('--check').status, 1);
    assert.equal(run().status, 0);
    assert.equal(run('--check').status, 0);
    writeFileSync(arb, '{}');
    assert.equal(run().status, 1);
  } finally {
    rmSync(temp, {recursive: true, force: true});
  }
});
