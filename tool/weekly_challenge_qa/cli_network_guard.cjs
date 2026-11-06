'use strict';
// CLI/discovery children use ephemeral local ports. Backend modules install a stricter port allowlist.
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const original = net.Socket.prototype.connect;
const real = (dir) => { try { return fs.realpathSync(dir); } catch { return dir; } };
// The emulator's own IPC socket. macOS puts it in os.tmpdir() (/var/folders/...), not /tmp.
const socketDirs = new Set(['/tmp', os.tmpdir()].flatMap((dir) => [path.resolve(dir), real(dir)]));
const isEmulatorSocket = (socket) => /^fire_emu_[a-f0-9]{16}\.sock$/.test(path.basename(socket)) &&
  (socketDirs.has(path.dirname(socket)) || socketDirs.has(real(path.dirname(socket))));
net.Socket.prototype.connect = function (...args) {
  const first = Array.isArray(args[0]) ? args[0][0] : args[0];
  const options = typeof first === 'object' ? first
    : typeof first === 'string' && !Number.isFinite(Number(first)) ? {path: first}
      : {port: first, host: typeof args[1] === 'string' ? args[1] : 'localhost'};
  const host = options.host || 'localhost';
  if (options.path && isEmulatorSocket(options.path)) {
    return original.apply(this, args);
  }
  if (options.path || !['127.0.0.1', 'localhost', '::1'].includes(host)) {
    throw Error(`Local QA CLI denied nonlocal TCP ${host}:${options.port}`);
  }
  return original.apply(this, args);
};
