import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sandbox = path.join(repo, 'tool', 'shared_folders_qa', 'safety_sandbox.cjs');

for (const scenario of ['native-ios', 'native-android', 'admin', 'worker', 'path-root', 'path-write', 'path-build', 'redirects', 'evidence', 'push', 'environment']) {
  test(`shared folders QA isolates ${scenario}`, () => {
    const result = spawnSync(process.execPath, [sandbox, repo, scenario], {encoding: 'utf8'});
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  });
}
