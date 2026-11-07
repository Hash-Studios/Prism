'use strict';
// CLI/discovery children use ephemeral local ports. Backend modules install a stricter port allowlist.
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');
const original = net.Socket.prototype.connect;
const originalSpawn = childProcess.spawn;
const originalListen = net.Server.prototype.listen;
const attestationType = 'local-qa-emulator-socket';
const real = (dir) => { try { return fs.realpathSync(dir); } catch { return dir; } };
// The emulator's own IPC socket. macOS puts it in os.tmpdir() (/var/folders/...), not /tmp.
const socketDirs = new Set(['/tmp', os.tmpdir()].flatMap((dir) => [path.resolve(dir), real(dir)]));
const emulatorSockets = new Map();
const pendingSockets = new Map();
const isEmulatorSocketPath = (socket) => typeof socket === 'string' && path.normalize(socket) === socket &&
  /^fire_emu_[a-f0-9]{16}\.sock$/.test(path.basename(socket)) && socketDirs.has(path.dirname(socket));
const socketAttestation = (socket) => {
  if (!isEmulatorSocketPath(socket)) return false;
  const directory = real(path.dirname(socket));
  if (!socketDirs.has(directory)) return false;
  try {
    const stat = fs.lstatSync(socket);
    if (!stat.isSocket()) return false;
    const canonicalPath = fs.realpathSync(socket);
    if (canonicalPath !== path.join(directory, path.basename(socket))) return false;
    return {path: socket, canonicalPath, dev: stat.dev, ino: stat.ino};
  } catch { return false; }
};
const isEmulatorSocket = (socket) => {
  const registered = emulatorSockets.get(socket);
  if (!registered || !isEmulatorSocketPath(socket)) return false;
  try {
    const stat = fs.lstatSync(socket);
    return stat.isSocket() && socketDirs.has(real(path.dirname(socket))) &&
      fs.realpathSync(socket) === registered.canonicalPath && stat.dev === registered.dev && stat.ino === registered.ino;
  } catch { return false; }
};
net.Server.prototype.listen = function (...args) {
  if (isEmulatorSocketPath(process.env.PORT) && typeof process.send === 'function') {
    this.once('listening', () => {
      if (this.address() !== process.env.PORT) return;
      const attestation = socketAttestation(process.env.PORT);
      if (attestation) {
        try { process.send({type: attestationType, ...attestation}, () => {}); } catch {}
      }
    });
  }
  return originalListen.apply(this, args);
};
const optionsForSpawn = (args) => args.find((arg) => arg && typeof arg === 'object' && !Array.isArray(arg) && arg.env);
childProcess.spawn = function (...args) {
  const spawnOptions = optionsForSpawn(args);
  const port = spawnOptions?.env?.PORT;
  const hasIpc = Array.isArray(spawnOptions?.stdio) && spawnOptions.stdio.includes('ipc');
  let pending;
  if (hasIpc && isEmulatorSocketPath(port)) {
    try { fs.lstatSync(port); } catch (error) {
      if (error.code === 'ENOENT' && !pendingSockets.has(port)) {
        pending = new Map();
        pendingSockets.set(port, pending);
      }
    }
  }
  let child;
  try { child = originalSpawn.apply(this, args); } catch (error) {
    if (pending) pendingSockets.delete(port);
    throw error;
  }
  if (pending) {
    const release = () => {
      emulatorSockets.delete(port);
      pendingSockets.delete(port);
      for (const socket of pending.keys()) socket.destroy(Error('Local QA emulator socket closed before attestation'));
    };
    child.on('message', (message) => {
      if (message?.type !== attestationType || message.path !== port) return;
      const actual = socketAttestation(port);
      if (!actual || actual.canonicalPath !== message.canonicalPath || actual.dev !== message.dev || actual.ino !== message.ino) return;
      emulatorSockets.set(port, actual);
      pendingSockets.delete(port);
      for (const [socket, connectArgs] of pending) {
        if (socket.destroyed) continue;
        try { original.apply(socket, connectArgs); } catch (error) { socket.destroy(error); }
      }
      pending.clear();
    });
    child.once('error', release);
    child.once('exit', release);
    child.once('disconnect', release);
  }
  return child;
};
net.Socket.prototype.connect = function (...args) {
  const first = Array.isArray(args[0]) ? args[0][0] : args[0];
  const options = typeof first === 'object' ? first
    : typeof first === 'string' && !Number.isFinite(Number(first)) ? {path: first}
      : {port: first, host: typeof args[1] === 'string' ? args[1] : 'localhost'};
  const host = options.host || 'localhost';
  if (options.path && isEmulatorSocket(options.path)) {
    return original.apply(this, args);
  }
  if (options.path && pendingSockets.has(options.path)) {
    const pending = pendingSockets.get(options.path);
    pending.set(this, args);
    this.connecting = true;
    // A child that never attests its socket must not leave this connection waiting forever.
    const timer = setTimeout(() => this.destroy(Error('Local QA emulator socket was not attested in time')), 30000);
    timer.unref();
    this.once('connect', () => clearTimeout(timer));
    this.once('close', () => {
      clearTimeout(timer);
      pending.delete(this);
    });
    return this;
  }
  if (options.path || !['127.0.0.1', 'localhost', '::1'].includes(host)) {
    throw Error(`Local QA CLI denied nonlocal TCP ${host}:${options.port}`);
  }
  return original.apply(this, args);
};
