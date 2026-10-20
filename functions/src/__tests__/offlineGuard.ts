import net = require("node:net");
import tls = require("node:tls");
import dns = require("node:dns");

let blocked = false;

function blockedConnection(): never {
  blocked = true;
  process.exitCode = 1;
  const error = new Error("Blocked outbound access during offline tests");
  Error.captureStackTrace(error, blockedConnection);
  process.stderr.write(`${error.stack ?? error.message}\n`);
  throw error;
}

Object.defineProperty(net.Socket.prototype, "connect", {configurable: true, writable: true, value: blockedConnection});
Object.defineProperty(tls, "connect", {configurable: true, writable: true, value: blockedConnection});

for (const target of [dns, dns.promises, dns.Resolver.prototype, dns.promises.Resolver.prototype]) {
  for (const method of ["lookup", "lookupService", "resolve", "resolve4", "resolve6", "resolveAny", "resolveCaa",
    "resolveCname", "resolveMx", "resolveNaptr", "resolveNs", "resolvePtr", "resolveSoa", "resolveSrv", "resolveTlsa",
    "resolveTxt", "reverse"]) {
    if (typeof Reflect.get(target, method) === "function") {
      Object.defineProperty(target, method, {configurable: true, writable: true, value: blockedConnection});
    }
  }
}

process.on("exit", () => {
  if (blocked) process.exitCode = 1;
});
