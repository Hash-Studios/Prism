import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {DuoGallery} from '../lib/duo-gallery.ts';
import {approvedDuoWalls, duoWalls, duoIsIndexable, duoRoute} from '../lib/duo-wallpapers.ts';

const fixture = {id: 'TEST1', title: 'Local fixture only', review: true, width: 2670, height: 1878,
  duoPresetId: 'prism-right-v1', imageUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/fixture.jpg'};

test('empty production manifest stays unindexed with useful SSR empty state', () => {
  assert.deepEqual(duoWalls, []);
  assert.equal(duoIsIndexable(duoWalls), false);
  assert.equal(duoRoute, '/iphone-duo-wallpapers');
  const html = renderToStaticMarkup(createElement(DuoGallery, {walls: []}));
  assert.match(html, /first Duo collection is in review/);
  assert.doesNotMatch(html, /<img/);
});

test('local approved fixture SSR includes both views and real Prism link', () => {
  const walls = approvedDuoWalls([fixture]);
  assert.equal(duoIsIndexable(walls), true);
  const html = renderToStaticMarkup(createElement(DuoGallery, {walls}));
  assert.equal((html.match(/<img/g) ?? []).length, 2);
  assert.match(html, /Folded preview/);
  assert.match(html, /Unfolded original/);
  assert.match(html, /https:\/\/prismwalls.com\/share\?id=TEST1&amp;source=prism/);
  assert.match(html, /right:0/);
  assert.match(html, /width="2670" height="1878"/);
});

test('manifest fails closed for unreviewed, small or external content', () => {
  for (const patch of [{review: false}, {width: 2000}, {imageUrl: 'https://example.com/fake.jpg'}, {duoPresetId: 'apple-auto'}]) {
    assert.throws(() => approvedDuoWalls([{...fixture, ...patch}]), /approved canonical/);
  }
  assert.throws(() => approvedDuoWalls([fixture, fixture]), /approved canonical/);
});
