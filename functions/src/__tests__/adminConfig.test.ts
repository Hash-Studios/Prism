import assert from "node:assert/strict";
import test from "node:test";
import {isAdminCaller} from "../adminConfig";
import {installFakeDb} from "./fakeDb";

const seed = {
  "admin_users/rules@x.com": {ok: true},
  "config/adminNotifications": {emails: [" Config@X.com "]},
};
const caller = (token: Record<string, unknown>) => ({token});

test("the admin claim is enough and needs no read", async (t) => {
  installFakeDb(t);
  assert.equal(await isAdminCaller(caller({admin: true})), true);
});

test("a verified email in admin_users is an admin, an unverified one is not", async (t) => {
  installFakeDb(t, seed);
  assert.equal(await isAdminCaller(caller({email: "rules@x.com", email_verified: true})), true);
  assert.equal(await isAdminCaller(caller({email: "rules@x.com", email_verified: false})), false);
  assert.equal(await isAdminCaller(caller({email: "rules@x.com"})), false);
});

test("only a verified recipient email is an admin, in any letter case", async (t) => {
  installFakeDb(t, seed);
  assert.equal(await isAdminCaller(caller({email: "CONFIG@x.com", email_verified: true})), true);
  assert.equal(await isAdminCaller(caller({email: "CONFIG@x.com", email_verified: false})), false);
  assert.equal(await isAdminCaller(caller({email: "CONFIG@x.com"})), false);
});

test("anyone else, and a caller without auth or email, is not an admin", async (t) => {
  installFakeDb(t, seed);
  assert.equal(await isAdminCaller(caller({email: "user@x.com", email_verified: true})), false);
  assert.equal(await isAdminCaller(caller({})), false);
  assert.equal(await isAdminCaller(caller({admin: "yes"})), false);
  assert.equal(await isAdminCaller(undefined), false);
});
