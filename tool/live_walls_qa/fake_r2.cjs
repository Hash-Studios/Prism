'use strict';
// Disk stand-in for functions/lib/r2Storage.js inside the QA runtime only. Mirrors the real R2Storage methods.
// Objects live at <root>/<kind>/<object>, with a sidecar <file>.meta.json. Node built-ins only: the runtime copies this file.
const fs = require('node:fs');
const path = require('node:path');

const MAX_GET_BYTES = 20 * 1024 * 1024;
const KINDS = ['private', 'preview'];
const PUBLIC_BASE = 'https://localhost:19375';

function safeObject(object) {
  if (typeof object !== 'string' || object === '' || object.startsWith('/') || object.includes('..')) {
    throw Error(`Refusing object path: ${object}`);
  }
  return object;
}

function fileFor(root, kind, object) {
  if (!KINDS.includes(kind)) throw Error(`Unknown bucket kind: ${kind}`);
  return path.join(root, kind, safeObject(object));
}

function readMeta(file) {
  try {
    return JSON.parse(fs.readFileSync(`${file}.meta.json`, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

function lowerCaseKeys(metadata) {
  return Object.fromEntries(Object.entries(metadata ?? {}).map(([key, value]) => [key.toLowerCase(), String(value)]));
}

// Returns a class. The constructor ignores its arguments, like the real class.
function makeDiskR2Storage(root) {
  return class DiskR2Storage {
    constructor() {}

    // Returns true when created, false when the object already exists (if-none-match: *). Never overwrites.
    async put(kind, object, bytes, metadata, contentType) {
      const file = fileFor(root, kind, object);
      fs.mkdirSync(path.dirname(file), {recursive: true});
      let fd;
      try {
        fd = fs.openSync(file, 'wx');
      } catch (error) {
        if (error.code === 'EEXIST') return false;
        throw error;
      }
      try {
        fs.writeFileSync(fd, bytes);
      } finally {
        fs.closeSync(fd);
      }
      fs.writeFileSync(`${file}.meta.json`, JSON.stringify({contentType, metadata: lowerCaseKeys(metadata),
        size: bytes.length}));
      return true;
    }

    async head(kind, object) {
      const file = fileFor(root, kind, object);
      const meta = readMeta(file);
      if (!meta) return null;
      const m = meta.metadata ?? {};
      return {size: meta.size, contentType: meta.contentType ?? '', sha256: m.sha256 ?? '', uid: m.uid ?? '',
        objectId: m.objectid ?? '', repo: Buffer.from(m.repo64 ?? '', 'base64url').toString(),
        path: Buffer.from(m.path64 ?? '', 'base64url').toString(), gitSha: m.gitsha ?? '', uploadId: m.uploadid ?? ''};
    }

    async get(kind, object) {
      const file = fileFor(root, kind, object);
      if (!readMeta(file)) throw Error('R2 GET failed (404)');
      if (fs.statSync(file).size > MAX_GET_BYTES) throw Error('R2 object is too large');
      return fs.readFileSync(file);
    }

    async delete(kind, object) {
      const file = fileFor(root, kind, object);
      for (const target of [file, `${file}.meta.json`]) {
        try {
          fs.unlinkSync(target);
        } catch (error) {
          if (error.code !== 'ENOENT') throw error;
        }
      }
    }

    presignGet(object) {
      return `${PUBLIC_BASE}/private/${safeObject(object)}`;
    }
  };
}

module.exports = {makeDiskR2Storage, MAX_GET_BYTES, PUBLIC_BASE};
