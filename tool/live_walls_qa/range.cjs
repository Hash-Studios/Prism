'use strict';
// Parses one HTTP Range header for a file of `size` bytes. Used by the fixture server in ../live_walls_qa.cjs.
// Returns null when there is no usable Range (send the whole file), {unsatisfiable: true} (reply 416),
// or {start, end} with inclusive byte offsets (reply 206).
function parseRange(header, size) {
  if (!header) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(String(header).trim());
  if (!match || (match[1] === '' && match[2] === '')) return null;
  if (size === 0) return {unsatisfiable: true};
  if (match[1] === '') {
    // Suffix range: the last N bytes.
    const suffix = Number(match[2]);
    if (suffix === 0) return {unsatisfiable: true};
    return {start: Math.max(0, size - suffix), end: size - 1};
  }
  const start = Number(match[1]);
  const end = match[2] === '' ? size - 1 : Math.min(Number(match[2]), size - 1);
  if (start >= size || end < start) return {unsatisfiable: true};
  return {start, end};
}
module.exports = {parseRange};
