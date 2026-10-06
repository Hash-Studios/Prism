import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {deleteAccount} from "../deleteAccount";

type Options = {email?: string; failDelete?: boolean; authError?: string};

function fake(t: TestContext, options: Options = {}) {
  const log: string[] = [];
  const userRef = {
    path: "usersv2/u1",
    collection: (name: string) => ({path: `usersv2/u1/${name}`}),
    get: async () => ({data: () => ({email: options.email ?? "sam@example.com"})}),
    set: async () => {
      log.push("anonymize");
    },
  };
  const docsFor = (collection: string) => [{ref: {path: `${collection}/d1`}}];
  const query = (collection: string) => {
    const q = {where: () => q, get: async () => ({docs: docsFor(collection)})};
    return q;
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ?
    {doc: () => userRef} :
    {...query(name), doc: (id: string) => ({path: `${name}/${id}`})});
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    log.push(`recursive:${ref.path}`);
  });
  t.mock.method(db, "bulkWriter", () => ({
    delete: (ref: {path: string}) => {
      log.push(`delete:${ref.path}`);
      return options.failDelete && ref.path.startsWith("aiGenerations") ?
        Promise.reject(new Error("write failed")) :
        Promise.resolve();
    },
    close: async () => undefined,
  }));
  t.mock.method(admin.auth(), "deleteUser", async () => {
    log.push("auth");
    if (options.authError) throw Object.assign(new Error("gone"), {code: options.authError});
  });
  return log;
}

const call = () => deleteAccount.run({
  auth: {uid: "u1", token: {auth_time: Math.floor(Date.now() / 1000)}}, data: {},
} as unknown as Parameters<typeof deleteAccount.run>[0]);

test("deleting an account removes every per-user doc, anonymizes, then deletes the auth user", async (t) => {
  const log = fake(t);
  await call();
  for (const path of [
    "recursive:usersv2/u1/blockedUsers", "recursive:usersv2/u1/private",
    "delete:referralStats/u1", "delete:subscriptionSync/u1", "delete:githubUploadStats/u1",
    "delete:badgeCheckRate/u1", "delete:coinAdRateDaily/d1", "delete:coinTransactions/d1",
    "delete:aiGenerations/d1", "delete:draftSetups/d1",
  ]) {
    assert.ok(log.includes(path), path);
  }
  assert.ok(log.indexOf("anonymize") > log.indexOf("delete:draftSetups/d1"));
  assert.equal(log.at(-1), "auth");
  assert.equal(log.at(-2), "anonymize");
});

test("a failed delete throws before the profile is anonymized or the auth user removed", async (t) => {
  const log = fake(t, {failDelete: true});
  await assert.rejects(async () => {
    await call();
  }, {code: "internal"});
  assert.ok(!log.includes("anonymize"));
  assert.ok(!log.includes("auth"));
});

test("a retry after the auth user is already gone still succeeds", async (t) => {
  const log = fake(t, {email: "", authError: "auth/user-not-found"});
  assert.deepEqual(await call(), {ok: true});
  assert.ok(!log.includes("delete:draftSetups/d1"));
  assert.ok(log.includes("anonymize"));
});

test("other auth errors still fail the call", async (t) => {
  fake(t, {authError: "auth/internal-error"});
  await assert.rejects(async () => {
    await call();
  }, {code: "auth/internal-error"});
});
