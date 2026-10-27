import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
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

test('readChangelog fails the build when no release has bullets', () => {
  const dir = mkdtempSync(join(tmpdir(), 'changelog-'));
  const path = join(dir, 'CHANGELOG.md');
  writeFileSync(path, '## Changelog\n\n### v1.0.0\n');
  assert.throws(() => readChangelog(path), /has no releases with bullets/);
});

test('shareLink uses native share, and treats a cancel as a cancel', async () => {
  const data = { title: 'Prism v1.0.0', url: 'https://prismwalls.com/changelog/v1-0-0' };
  assert.equal(await shareLink({ share: async () => {} }, data), 'shared');
  const cancel = Object.assign(new Error('cancelled'), { name: 'AbortError' });
  const copied = [];
  const target = { share: async () => { throw cancel; }, clipboard: { writeText: async (text) => { copied.push(text); } } };
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
