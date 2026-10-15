import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {deleteAccount} from "../deleteAccount";

type Options = {
  email?: string;
  failDelete?: boolean;
  failFirstDelete?: boolean;
  failUpdate?: boolean;
  slowQueries?: boolean;
  authError?: string;
};

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
  const docsFor = (collection: string) => [{id: "d1", data: () => ({}), ref: {path: `${collection}/d1`}}];
  const query = (collection: string) => {
    const q = {
      where: (field: string, op: string, value: unknown) => {
        log.push(`query:${collection}.${field}${op}${value}`);
        return q;
      },
      get: async () => {
        if (options.slowQueries) await new Promise((resolve) => setTimeout(resolve, 20));
        return {docs: docsFor(collection)};
      },
    };
    return q;
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ?
    {...query(name), doc: () => userRef} :
    {...query(name), doc: (id: string) => ({path: `${name}/${id}`})});
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    log.push(`recursive:${ref.path}`);
  });
  let deletes = 0;
  const updates: Array<{path: string; data: Record<string, unknown>}> = [];
  t.mock.method(db, "bulkWriter", () => ({
    delete: (ref: {path: string}) => {
      log.push(`delete:${ref.path}`);
      deletes += 1;
      return (options.failDelete && ref.path.startsWith("aiGenerations")) || (options.failFirstDelete && deletes === 1) ?
        Promise.reject(new Error("write failed")) :
        Promise.resolve();
    },
    update: (ref: {path: string}, data: Record<string, unknown>) => {
      log.push(`update:${ref.path}:${Object.keys(data).join(",")}`);
      updates.push({path: ref.path, data});
      return options.failUpdate ? Promise.reject(new Error("write failed")) : Promise.resolve();
    },
    close: async () => {
      log.push("close");
    },
  }));
  t.mock.method(admin.auth(), "deleteUser", async () => {
    log.push("auth");
    if (options.authError) throw Object.assign(new Error("gone"), {code: options.authError});
  });
  return Object.assign(log, {updates});
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

test("an early failed delete is handled at once, never as an unhandled rejection", async (t) => {
  const log = fake(t, {failFirstDelete: true, slowQueries: true});
  const unhandled: unknown[] = [];
  const listener = (reason: unknown) => unhandled.push(reason);
  process.on("unhandledRejection", listener);
  try {
    await assert.rejects(async () => {
      await call();
    }, {code: "internal"});
    await new Promise((resolve) => setTimeout(resolve, 10));
  } finally {
    process.off("unhandledRejection", listener);
  }
  assert.deepEqual(unhandled, []);
  assert.ok(log.includes("close"));
  assert.ok(!log.includes("anonymize"));
});

test("the writer closes even when queueing a delete throws", async (t) => {
  const log = fake(t);
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ?
    {doc: () => ({
      path: "usersv2/u1",
      collection: (sub: string) => ({path: `usersv2/u1/${sub}`}),
      get: async () => ({data: () => ({email: "sam@example.com"})}),
    })} :
    {where: () => ({get: async () => {
      throw new Error("query failed");
    }})});
  await assert.rejects(async () => {
    await call();
  }, /query failed/);
  assert.ok(log.includes("close"));
});

test("public records that carry the email are scrubbed or deleted before the profile is anonymized", async (t) => {
  const log = fake(t);
  await call();
  assert.ok(log.includes("update:walls/d1:by,userPhoto,email"));
  assert.ok(log.includes("update:setups/d1:by,userPhoto,email"));
  for (const path of [
    "delete:rejectedWalls/d1", "delete:rejectedSetups/d1", "delete:notifications/d1", "delete:githubUploads/d1",
    "delete:users/u1", "delete:tokens/u1", "delete:coinRefundDaily/d1", "delete:contentReportRateDaily/d1",
    "delete:userBlockRateDaily/d1",
  ]) {
    assert.ok(log.includes(path), path);
  }
  assert.ok(log.includes("update:contentReports/d1:reporterEmail"));
  assert.ok(log.includes("query:notifications.modifier==sam@example.com"));
  assert.ok(log.includes("query:githubUploads.uid==u1"));
  for (const path of ["update:walls/d1", "update:setups/d1", "update:contentReports/d1", "delete:rejectedWalls/d1"]) {
    assert.ok(log.indexOf("anonymize") > log.findIndex((entry) => entry.startsWith(path)), path);
  }
  assert.equal(log.at(-2), "anonymize");
});

test("the walls scrub writes the placeholder name and blank photo and email", async (t) => {
  const log = fake(t);
  await call();
  const wall = log.updates.find((entry) => entry.path === "walls/d1");
  assert.deepEqual(wall?.data, {by: "Deleted Account", userPhoto: "", email: ""});
  const report = log.updates.find((entry) => entry.path === "contentReports/d1");
  assert.deepEqual(report?.data, {reporterEmail: null});
});

test("the email is removed from other users' follower and following lists, raw and lower case", async (t) => {
  const log = fake(t, {email: "Sam@Example.com"});
  await call();
  for (const address of ["Sam@Example.com", "sam@example.com"]) {
    assert.ok(log.includes(`query:usersv2.followersarray-contains${address}`), address);
    assert.ok(log.includes(`query:usersv2.followingarray-contains${address}`), address);
    assert.ok(log.includes(`query:walls.email==${address}`), address);
  }
  const followerUpdates = log.updates.filter((entry) => entry.path === "usersv2/d1");
  assert.equal(followerUpdates.length, 4);
  const keys = followerUpdates.map((entry) => Object.keys(entry.data)[0]).sort();
  assert.deepEqual(keys, ["followers", "followers", "following", "following"]);
});

test("a user without an email still has uid-keyed records deleted and nothing is queried by email", async (t) => {
  const log = fake(t, {email: ""});
  await call();
  assert.ok(log.includes("delete:githubUploads/d1"));
  assert.ok(log.includes("delete:users/u1"));
  assert.ok(!log.some((entry) => entry.startsWith("update:")));
  assert.ok(!log.includes("delete:notifications/d1"));
});

test("a failed update throws before the profile is anonymized or the auth user removed", async (t) => {
  const log = fake(t, {failUpdate: true});
  await assert.rejects(async () => {
    await call();
  }, {code: "internal"});
  assert.ok(log.includes("close"));
  assert.ok(!log.includes("anonymize"));
  assert.ok(!log.includes("auth"));
});

test("a stale sign-in is refused before anything is read or deleted", async (t) => {
  const log = fake(t);
  const stale = Math.floor(Date.now() / 1000) - 301;
  await assert.rejects(async () => {
    await deleteAccount.run({auth: {uid: "u1", token: {auth_time: stale}}, data: {}} as unknown as
      Parameters<typeof deleteAccount.run>[0]);
  }, {code: "failed-precondition", message: "requires-recent-login"});
  assert.deepEqual([...log], []);
});

test("a sign-in with no auth_time is refused", async (t) => {
  const log = fake(t);
  await assert.rejects(async () => {
    await deleteAccount.run({auth: {uid: "u1", token: {}}, data: {}} as unknown as
      Parameters<typeof deleteAccount.run>[0]);
  }, {code: "failed-precondition", message: "requires-recent-login"});
  assert.deepEqual([...log], []);
});

test("a call with no auth is refused", async () => {
  await assert.rejects(async () => {
    await deleteAccount.run({data: {}} as unknown as Parameters<typeof deleteAccount.run>[0]);
  }, {code: "unauthenticated"});
});
