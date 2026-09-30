import assert from "node:assert/strict";
import {createRequire} from "node:module";
import test from "node:test";

test("Google SDK callers resolve a compatible UUID with buffer bounds checks", () => {
  for (const caller of ["firebase-admin", "@google-cloud/storage", "google-gax", "gaxios", "teeny-request"]) {
    const callerRequire = createRequire(require.resolve(caller));
    const uuid = callerRequire("uuid");
    assert.equal(uuid.version(uuid.v4()), 4, caller);
    assert.throws(() => uuid.v5("prism", uuid.v5.DNS, Buffer.alloc(15)), RangeError, caller);
  }
});
