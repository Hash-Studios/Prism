'use strict';
// CLI/discovery children use ephemeral local ports. Backend modules install a stricter port allowlist.
const net = require('node:net');
const original = net.Socket.prototype.connect;
net.Socket.prototype.connect = function (...args) {
  const first = Array.isArray(args[0]) ? args[0][0] : args[0];
  const options = typeof first === 'object' ? first
    : typeof first === 'string' && !Number.isFinite(Number(first)) ? {path: first}
      : {port: first, host: typeof args[1] === 'string' ? args[1] : 'localhost'};
  const host = options.host || 'localhost';
  if (options.path && /^\/tmp\/fire_emu_[a-f0-9]{16}\.sock$/.test(options.path)) {
    return original.apply(this, args);
  }
  if (options.path || !['127.0.0.1', 'localhost', '::1'].includes(host)) {
    throw Error(`Local QA CLI denied nonlocal TCP ${host}:${options.port}`);
  }
  return original.apply(this, args);
};
