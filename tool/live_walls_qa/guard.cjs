'use strict';
// Local QA guard for the live walls harness. prepare copies this file into the runtime as backend.cjs.
// Same rules as tool/weekly_challenge_qa/backend.cjs. The ports match the scheduled release harness and the app's
// hard-coded QA ports (lib/core/debug/local_qa_runtime.dart), plus 19380 for the plain HTTP fixture server.
const net = require('node:net');
const PROJECT = 'demo-prism';
const PORTS = [19371, 19372, 19373, 19374, 19375, 19376, 19377, 19378, 19379, 19380];
function guardEnvironment() {
  process.env.METADATA_SERVER_DETECTION = 'none';
  for (const name of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
    if (process.env[name] && process.env[name] !== PROJECT) throw Error(`Refusing ${name} other than ${PROJECT}`);
    process.env[name] = PROJECT;
  }
  for (const [name, value] of Object.entries({FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:19371',
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:19372'})) {
    if (process.env[name] && process.env[name] !== value) throw Error(`Refusing nonlocal ${name}`);
    process.env[name] = value;
  }
  for (const name of ['GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_TOKEN', 'GOOGLE_OAUTH_ACCESS_TOKEN', 'CLOUDSDK_AUTH_ACCESS_TOKEN']) {
    if (process.env[name]) throw Error(`Unset ${name} for local QA`);
  }
  if (process.env.FIREBASE_CONFIG) {
    const config = JSON.parse(process.env.FIREBASE_CONFIG);
    if (config.projectId !== PROJECT) throw Error('Refusing non-demo FIREBASE_CONFIG');
  }
  process.env.FIREBASE_CONFIG = JSON.stringify({projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com`});
  // Stops Admin and Google libraries before any nonlocal TCP connection. This protects this Node process only.
  const original = net.Socket.prototype.connect;
  if (!original.localQaGuard) {
    const localConnect = function (...args) {
      const first = Array.isArray(args[0]) ? args[0][0] : args[0];
      const options = typeof first === 'object' ? first : {port: first, host: typeof args[1] === 'string' ? args[1] : 'localhost'};
      const host = options.host || 'localhost';
      if (options.path || !['127.0.0.1', 'localhost', '::1'].includes(host) || !PORTS.includes(Number(options.port))) {
        throw Error(`Local QA denied TCP ${host}:${options.port}`);
      }
      return original.apply(this, args);
    };
    localConnect.localQaGuard = true;
    net.Socket.prototype.connect = localConnect;
  }
}
module.exports = {PROJECT, PORTS, guardEnvironment};
