import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { parseChangelog, readChangelog, versionSlug } from '../lib/changelog.ts';
import { shareLink } from '../lib/share-link.ts';

test('parses versions with bullets in file order', () => {
  const markdown =
    '## Changelog\n\n### v3.12.0\n- Swipe between wallpapers\n- Security and stability fixes\n\n### v3.11.0\n- A free Spooky Halloween theme\n';
  assert.deepEqual(parseChangelog(markdown), [
    {
      version: 'v3.12.0',
      slug: 'v3-12-0',
      bullets: ['Swipe between wallpapers', 'Security and stability fixes'],
    },
    {
      version: 'v3.11.0',
      slug: 'v3-11-0',
      bullets: ['A free Spooky Halloween theme'],
    },
  ]);
});

test('drops versions with no bullets', () => {
  assert.deepEqual(parseChangelog('### v3.12.0\n\n### v3.11.0\n- Fix\n'), [
    { version: 'v3.11.0', slug: 'v3-11-0', bullets: ['Fix'] },
  ]);
  assert.deepEqual(parseChangelog('### v3.11.0\n- Fix\n### v3.12.0\n'), [
    { version: 'v3.11.0', slug: 'v3-11-0', bullets: ['Fix'] },
  ]);
});

test('ignores orphan bullets, prose and empty bullets, and trims CRLF input', () => {
  assert.deepEqual(parseChangelog('- orphan\r\n### v1.0.0 \r\n  - Padded bullet  \r\nSome prose\r\n- \r\n'), [
    { version: 'v1.0.0', slug: 'v1-0-0', bullets: ['Padded bullet'] },
  ]);
});

test('empty input gives no releases', () => {
  assert.deepEqual(parseChangelog(''), []);
});

test('versionSlug lowercases and replaces non-alphanumerics with dashes', () => {
  assert.deepEqual(versionSlug('v3.12.0'), 'v3-12-0');
  assert.deepEqual(versionSlug('v2.6.0+1'), 'v2-6-0-1');
});

test('the real CHANGELOG.md parses', () => {
  const markdown = readFileSync(fileURLToPath(new URL('../../CHANGELOG.md', import.meta.url)), 'utf8');
  const releases = parseChangelog(markdown);
  assert.match(releases[0].version, /^v\d+\.\d+\.\d+$/);
  for (const release of releases) {
    assert.ok(release.bullets.length > 0, `${release.version} has no bullets`);
  }
  const slugs = releases.map((release) => release.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('the CI web filter includes changelog and consumed Proxima fonts', () => {
  const workflow = readFileSync(fileURLToPath(new URL('../../.github/workflows/ci.yml', import.meta.url)), 'utf8');
  const webFilter = workflow.split('            web:\n')[1].split('            rules:\n')[0];
  const patterns = [...webFilter.matchAll(/^\s+- '([^']+)'$/gm)].map((match) => match[1]);
  const picomatch = createRequire(import.meta.url)('next/dist/compiled/picomatch');
  const matches = (path) => patterns.some((pattern) => picomatch(pattern)(path));
  for (const path of ['CHANGELOG.md', 'assets/fonts/ProximaNova-Regular.otf',
    'assets/fonts/Proxima Nova Bold.otf', 'assets/fonts/Proxima Nova Extrabold.otf']) {
    assert.equal(matches(path), true, `${path} should trigger web CI`);
  }
  assert.equal(matches('assets/fonts/Unrelated.otf'), false);
});

test('readChangelog retains six ordered releases from an explicit file', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'changelog-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, 'CHANGELOG.md');
  const markdown = Array.from({ length: 6 }, (_, index) => `### v1.0.${6 - index}\n- Release ${6 - index}`).join('\n\n');
  writeFileSync(path, markdown);
  assert.deepEqual(readChangelog(path).map(({ version }) => version),
    ['v1.0.6', 'v1.0.5', 'v1.0.4', 'v1.0.3', 'v1.0.2', 'v1.0.1']);
});

test('readChangelog defaults to the complete repository changelog', () => {
  const markdown = readFileSync(fileURLToPath(new URL('../../CHANGELOG.md', import.meta.url)), 'utf8');
  assert.deepEqual(readChangelog(), parseChangelog(markdown));
});

test('readChangelog rejects empty files and headers without bullets', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'changelog-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, 'CHANGELOG.md');
  for (const contents of ['', '## Changelog\n\n### v1.0.0\n']) {
    writeFileSync(path, contents);
    assert.throws(() => readChangelog(path), /has no releases with bullets/);
  }
});

test('shareLink uses the native receiver and does not copy on success or cancel', async () => {
  const data = { title: 'Prism v1.0.0', url: 'https://prismwalls.com/changelog/v1-0-0' };
  const copied = [];
  const target = {
    clipboard: { writeText: async (text) => { copied.push(text); } },
    share: async function (sent) {
      assert.equal(this, target);
      assert.deepEqual(sent, data);
    },
  };
  assert.equal(await shareLink(target, data), 'shared');
  const cancel = Object.assign(new Error('cancelled'), { name: 'AbortError' });
  target.share = async function () { assert.equal(this, target); throw cancel; };
  assert.equal(await shareLink(target, data), 'cancelled');
  assert.deepEqual(copied, []);
});

test('shareLink copies the link when native share fails or is missing', async () => {
  const data = { title: 'Prism v1.0.0', url: 'https://prismwalls.com/changelog/v1-0-0' };
  const copied = [];
  const clipboard = { writeText: async (text) => { copied.push(text); } };
  const broken = { share: async () => { throw new TypeError('not allowed'); }, clipboard };
  assert.equal(await shareLink(broken, data), 'copied');
  assert.equal(await shareLink({ clipboard }, data), 'copied');
  assert.deepEqual(copied, [data.url, data.url]);
});

test('shareLink reports a failure when the clipboard is missing or refuses', async () => {
  const data = { title: 'Prism v1.0.0', url: 'https://prismwalls.com/changelog/v1-0-0' };
  assert.equal(await shareLink({}, data), 'failed');
  assert.equal(await shareLink({ clipboard: {} }, data), 'failed');
  const refused = { clipboard: { writeText: async () => { throw new Error('denied'); } } };
  assert.equal(await shareLink(refused, data), 'failed');
});
