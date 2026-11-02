'use strict';
const {createServer} = require('node:http');
const {deflateSync} = require('node:zlib');
const assert = require('node:assert/strict');
assert.equal(process.argv.length, 3);
assert.equal(process.argv[2], 'demo-prism');
function crc32(data) {
  let c = 0xffffffff;
  for (const byte of data) {
    c ^= byte;
    for (let bit = 0; bit < 8; bit++) c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0);
  }
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const payload = Buffer.concat([Buffer.from(type), data]);
  const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(payload));
  return Buffer.concat([size, payload, crc]);
}
function image(variant) {
  const width = 540, height = 960;
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 2;
  const pixels = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const offset = y * (width * 3 + 1) + 1 + x * 3;
    const wave = Math.sin(x / 100 + y / 180) * 35;
    pixels[offset] = 35 + variant * 45 + y / 15;
    pixels[offset + 1] = 80 + wave + x / 8;
    pixels[offset + 2] = 160 + wave;
  }
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', header),
    chunk('IDAT', deflateSync(pixels)), chunk('IEND', Buffer.alloc(0))]);
}
const images = new Map(['creator', 'other', 'avatar'].map((name, i) => [`/${name}.png`, image(i)]));
createServer((req, res) => {
  const body = images.get(req.url);
  res.writeHead(body ? 200 : 404, {'Content-Type': 'image/png', 'Cache-Control': 'no-store'});
  res.end(body);
}).listen(9198, '127.0.0.1', () => console.log('Demo PNG assets: http://127.0.0.1:9198. Ctrl-C to stop.'));
