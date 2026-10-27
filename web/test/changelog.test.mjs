import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseChangelog, versionSlug } from '../lib/changelog.ts';

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
