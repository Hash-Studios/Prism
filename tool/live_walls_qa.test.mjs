// Offline unit test for tool/live_walls_qa. No emulators, no network.
import {test, after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {makeDiskR2Storage, MAX_GET_BYTES} = require('./live_walls_qa/fake_r2.cjs');
const {parseRange} = require('./live_walls_qa/range.cjs');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'live-walls-r2-test-'));
after(() => fs.rmSync(root, {recursive: true, force: true}));
const DiskR2Storage = makeDiskR2Storage(root);
const b64 = (value) => Buffer.from(value).toString('base64url');

test('put, head, get and delete round-trip with the real head shape', async () => {
  const store = new DiskR2Storage('ignored', 'ignored');
  const bytes = Buffer.from('hello');
  const metadata = {sha256: 'ab', uid: 'u1', objectid: 'oid', repo64: b64('qa-walls'), path64: b64('thumb_x.jpg'),
    gitsha: 'sha1value', uploadid: 'up1'};
  assert.equal(await store.put('preview', 'previews/x.img', bytes, metadata, 'image/jpeg'), true);
  assert.deepEqual(await store.head('preview', 'previews/x.img'), {size: 5, contentType: 'image/jpeg', sha256: 'ab',
    uid: 'u1', objectId: 'oid', repo: 'qa-walls', path: 'thumb_x.jpg', gitSha: 'sha1value', uploadId: 'up1'});
  assert.deepEqual(await store.get('preview', 'previews/x.img'), bytes);
  await store.delete('preview', 'previews/x.img');
  assert.equal(await store.head('preview', 'previews/x.img'), null);
  await store.delete('preview', 'previews/x.img'); // missing is ignored
});

test('a second put to the same object does not overwrite', async () => {
  const store = new DiskR2Storage();
  assert.equal(await store.put('private', 'private-originals/one', Buffer.from('first'), {}, 'image/png'), true);
  assert.equal(await store.put('private', 'private-originals/one', Buffer.from('second'), {}, 'image/png'), false);
  assert.equal((await store.get('private', 'private-originals/one')).toString(), 'first');
});

test('get refuses an object larger than 20 MiB', async () => {
  const store = new DiskR2Storage();
  const big = Buffer.alloc(21 * 1024 * 1024);
  assert.equal(MAX_GET_BYTES, 20 * 1024 * 1024);
  assert.equal(await store.put('private', 'retained/big', big, {}, 'video/mp4'), true);
  await assert.rejects(store.get('private', 'retained/big'), /too large/);
  await store.delete('private', 'retained/big');
});

test('object paths with .. or a leading slash are refused', async () => {
  const store = new DiskR2Storage();
  await assert.rejects(store.put('private', '../escape', Buffer.from('x'), {}, 'text/plain'), /Refusing/);
  await assert.rejects(store.head('private', '/absolute'), /Refusing/);
  await assert.rejects(store.get('preview', 'previews/../../x'), /Refusing/);
});

test('presignGet returns the fixture private URL', () => {
  const store = new DiskR2Storage();
  assert.equal(store.presignGet('private-originals/abc', new Date()),
    'https://localhost:19375/private/private-originals/abc');
});

test('Range parser: bounded, open-ended and out-of-range', () => {
  assert.deepEqual(parseRange('bytes=0-99', 1000), {start: 0, end: 99});
  assert.deepEqual(parseRange('bytes=100-', 1000), {start: 100, end: 999});
  assert.deepEqual(parseRange('bytes=-50', 1000), {start: 950, end: 999});
  assert.deepEqual(parseRange('bytes=1000-', 1000), {unsatisfiable: true});
  assert.deepEqual(parseRange('bytes=0-5000', 1000), {start: 0, end: 999});
  assert.equal(parseRange(undefined, 1000), null);
  assert.equal(parseRange('items=0-1', 1000), null);
});
