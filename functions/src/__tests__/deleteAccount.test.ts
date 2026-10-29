import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {deleteAccount} from "../deleteAccount";
import {claimUsername} from "../claimUsername";
import * as publicFolders from "../publicFolders";
import {installFakeDb} from "./fakeDb";

type Options = {
  email?: string;
  failDelete?: boolean;
  failFirstDelete?: boolean;
  failUpdate?: boolean;
  failFolderFollows?: boolean;
  slowQueries?: boolean;
  authError?: string;
  authEmail?: string;
  emailVerified?: boolean;
  lookupError?: string;
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
  const docsFor = (collection: string) => [{
    id: "d1", data: () => collection === "boosts" ? {wallId: "w9"} : {},
    ref: {path: `${collection}/d1`, collection: (name: string) => query(`${collection}/d1/${name}`)},
  }];
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
    {...query(name), doc: (id: string) => ({path: `${name}/${id}`, get: async () => ({exists: true}),
      set: async () => {
        log.push(`barrier:${name}/${id}`);
      }})});
  t.mock.method(db, "collectionGroup", (name: string) => query(name));
  t.mock.method(db, "doc", (path: string) => ({
    path,
    collection: (name: string) => ({
      get: async () => ({docs: [], empty: true, size: 0}),
      doc: (id: string) => ({path: `${path}/${name}/${id}`, get: async () => ({exists: false})}),
    }),
  }));
  const transaction = {get: async () => ({data: () => ({})}), delete: () => undefined};
  t.mock.method(db, "runTransaction", async (callback: (tx: typeof transaction) => Promise<unknown>) => callback(transaction));
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    log.push(`recursive:${ref.path}`);
  });
  t.mock.method(db, "batch", () => {
    const batch = {
      delete: (ref: {path: string}) => {
        log.push(`delete:${ref.path}`);
        return batch;
      },
      commit: async () => [],
    };
    return batch;
  });
  let deletes = 0;
  const updates: Array<{path: string; data: Record<string, unknown>}> = [];
  t.mock.method(db, "bulkWriter", () => ({
    set: (ref: {path: string}, data: Record<string, unknown>) => {
      log.push(`close:${ref.path}`);
      updates.push({path: ref.path, data});
      return Promise.resolve();
    },
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
  t.mock.method(publicFolders, "removeOwnerPublicFolders", async (uid: string) => {
    log.push(`publicFolders:${uid}`);
  });
  t.mock.method(publicFolders, "removeAllFolderFollows", async (uid: string) => {
    log.push(`folderFollows:${uid}`);
    if (options.failFolderFollows) throw new Error("folder follow cleanup failed");
  });
  t.mock.method(admin.auth(), "deleteUser", async () => {
    log.push("auth");
    if (options.authError) throw Object.assign(new Error("gone"), {code: options.authError});
  });
  t.mock.method(admin.auth(), "getUser", async () => {
    if (options.lookupError) throw Object.assign(new Error("lookup failed"), {code: options.lookupError});
    return {uid: "u1", email: options.authEmail ?? options.email ?? "sam@example.com",
      emailVerified: options.emailVerified ?? true};
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
    "recursive:usersv2/u1/blockedUsers", "recursive:usersv2/u1/private", "recursive:usersv2/u1/history",
    "delete:referralStats/u1", "delete:subscriptionSync/u1", "delete:githubUploadStats/u1",
    "delete:badgeCheckRate/u1", "delete:coinAdRateDaily/d1", "delete:coinTransactions/d1",
    "delete:aiGenerations/d1", "delete:draftSetups/d1",
  ]) {
    assert.ok(log.includes(path), path);
  }
  assert.ok(log.indexOf("recursive:usersv2/u1/history") < log.indexOf("anonymize"));
  assert.ok(log.indexOf("anonymize") > log.indexOf("delete:draftSetups/d1"));
  assert.equal(log.at(-1), "auth");
  assert.equal(log.at(-2), "anonymize");
});

test("draw tickets and boosts are deleted, the boosted wall is cleared and the economy doc goes with private", async (t) => {
  const log = fake(t);
  await call();
  assert.ok(log.includes("query:drawTickets.uid==u1"));
  assert.ok(log.includes("delete:drawTickets/d1"));
  assert.ok(log.includes("query:boosts.uid==u1"));
  assert.ok(log.includes("delete:boosts/d1"));
  assert.ok(log.includes("update:walls/w9:boostedUntil"));
  assert.ok(log.includes("recursive:usersv2/u1/private"));
  assert.ok(log.indexOf("anonymize") > log.indexOf("update:walls/w9:boostedUntil"));
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
  const log = fake(t, {email: "victim@example.com", authError: "auth/user-not-found", lookupError: "auth/user-not-found"});
  assert.deepEqual(await call(), {ok: true});
  assert.ok(!log.includes("delete:draftSetups/d1"));
  assert.ok(log.includes("anonymize"));
});

test("a legacy forged profile cannot select a victim's email for deletion", async (t) => {
  const log = fake(t, {email: "victim@example.com", authEmail: "Attacker@Example.com"});
  await call();
  assert.ok(!log.some((entry) => entry.includes("victim@example.com")));
  assert.ok(log.includes("query:walls.email==Attacker@Example.com"));
  assert.ok(log.includes("query:walls.email==attacker@example.com"));
});

test("an unverified auth email cannot authorize cross-user cleanup", async (t) => {
  const log = fake(t, {email: "victim@example.com", emailVerified: false});
  await call();
  assert.ok(!log.some((entry) => entry.includes("victim@example.com")));
  assert.ok(log.includes("delete:githubUploads/d1"));
});

test("a transient auth lookup failure stops deletion before any mutation", async (t) => {
  const log = fake(t, {lookupError: "auth/internal-error"});
  await assert.rejects(call, {code: "auth/internal-error"});
  assert.deepEqual([...log], []);
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
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => name === "aiGenerations" ?
    {where: () => ({get: async () => {
      throw new Error("query failed");
    }})} : collection(name));
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
  assert.ok(!log.some((entry) => entry.startsWith("update:") && !entry.startsWith("update:walls/w9")));
  assert.ok(!log.includes("delete:notifications/d1"));
});

test("creator deletion barrier and anonymized wall receipts precede recursive private deletion", async (t) => {
  const log = fake(t);
  await call();
  const barrier = log.indexOf("barrier:creatorDeletionState/u1");
  const receipt = log.indexOf("close:creatorWallCredits/d1");
  const privateDelete = log.indexOf("recursive:usersv2/u1/private");
  assert.ok(barrier >= 0 && receipt > barrier && privateDelete > receipt);
  assert.deepEqual(log.updates.find((update) => update.path === "creatorWallCredits/d1")?.data,
    {closed: true, approvalCredited: true});
  assert.ok(log.includes("query:creatorMembers.memberUid==u1"));
  assert.ok(log.includes("delete:creatorMembers/d1"));
  assert.ok(log.includes("query:creatorMemberRateDaily.memberUid==u1"));
  assert.ok(log.includes("delete:creatorMemberRateDaily/d1"));
});

test("public folders and folder follows go after the deletion barrier and before private state", async (t) => {
  const log = fake(t);
  await call();
  const barrier = log.indexOf("barrier:creatorDeletionState/u1");
  const projections = log.indexOf("publicFolders:u1");
  const follows = log.indexOf("folderFollows:u1");
  assert.ok(barrier >= 0 && projections > barrier && follows > barrier);
  assert.ok(follows < log.indexOf("recursive:usersv2/u1/followedFolders"));
  assert.ok(log.indexOf("recursive:usersv2/u1/private") < log.indexOf("anonymize"));
});

test("failed folder-follow cleanup stops deletion before private state is removed", async (t) => {
  const log = fake(t, {failFolderFollows: true});
  await assert.rejects(call, /folder follow cleanup failed/);
  assert.ok(log.includes("publicFolders:u1"));
  assert.ok(log.includes("folderFollows:u1"));
  assert.ok(!log.includes("recursive:usersv2/u1/followedFolders"));
  assert.ok(!log.includes("anonymize"));
  assert.ok(!log.includes("auth"));
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

test("SV-S12 releases all deleted UID reservations, permits reuse and never removes the new owner's claim on retry", async (t) => {
  fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName", usernameLower: "oldname"},
    "usersv2/u2": {username: "NewUser", usernameLower: "newuser"},
    "usernames/oldname": {uid: "u1"},
    "usernames/stalename": {uid: "u1"},
    "usernames/foreign": {uid: "u2"},
  });
  const empty = {where: () => empty, get: async () => ({docs: []})};
  t.mock.method(db, "collectionGroup", () => empty);
  await call();
  assert.equal(store.has("usernames/oldname"), false);
  assert.equal(store.has("usernames/stalename"), false);
  assert.equal(store.get("usernames/foreign")?.uid, "u2");
  assert.deepEqual(await claimUsername.run({auth: {uid: "u2"}, data: {username: "OldName"}} as
    Parameters<typeof claimUsername.run>[0]), {username: "OldName", usernameLower: "oldname"});
  await call();
  assert.equal(store.get("usernames/oldname")?.uid, "u2");
});

test("SV-S12 rechecks reservation ownership after the cleanup query", async (t) => {
  fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName"}, "usernames/oldname": {uid: "u1"},
  });
  const empty = {where: () => empty, get: async () => ({docs: []})};
  t.mock.method(db, "collectionGroup", () => empty);
  const runTransaction = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    store.set("usernames/oldname", {uid: "u2"});
    return runTransaction(callback);
  });
  await call();
  assert.equal(store.get("usernames/oldname")?.uid, "u2");
});

test("SV-S12 failed reservation cleanup preserves the profile and can be retried", async (t) => {
  const log = fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName"}, "usernames/oldname": {uid: "u1"},
  });
  const empty = {where: () => empty, get: async () => ({docs: []})};
  t.mock.method(db, "collectionGroup", () => empty);
  const runTransaction = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("reservation unavailable");
  });
  await assert.rejects(call, /reservation unavailable/);
  assert.equal(store.get("usersv2/u1")?.username, "OldName");
  assert.equal(log.includes("auth"), false);
  t.mock.method(db, "runTransaction", runTransaction);
  await call();
  assert.equal(store.has("usernames/oldname"), false);
  assert.equal(store.get("usersv2/u1")?.deleted, true);
});

test("deleting an account finds folder items by owner, deletes them first, then the caller's folders", async (t) => {
  const log = fake(t);
  await call();
  assert.ok(log.includes("query:items.ownerId==u1"));
  assert.ok(log.includes("query:folders.ownerId==u1"));
  // items/d1 is not under folders/, so it is not a folder item.
  assert.ok(!log.includes("delete:items/d1"));
  assert.ok(log.indexOf("query:items.ownerId==u1") < log.indexOf("delete:folders/d1"));
  assert.ok(log.indexOf("delete:folders/d1") < log.indexOf("anonymize"));
});

test("folder cleanup retries partial item deletion before deleting any caller folders and preserves other owners", async (t) => {
  const log = fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {name: "Caller"},
    "folders/one": {ownerId: "u1"},
    "folders/one/items/prism_a": {ownerId: "u1"},
    "folders/one/items/pexels_b": {ownerId: "u1"},
    ...Object.fromEntries(Array.from({length: 401}, (_, index) =>
      [`folders/one/items/prism_bulk_${index}`, {ownerId: "u1"}])),
    "folders/two": {ownerId: "u1"},
    "folders/two/items/wallhaven_c": {ownerId: "u1"},
    "folders/two/items/prism_d": {ownerId: "u1"},
    "folders/two/items/prism_previous_owner": {ownerId: "u2"},
    "folders/foreign": {ownerId: "u2"},
    "folders/foreign/items/prism_x": {ownerId: "u2"},
    // Left by a folder deleted offline: no folder doc, so only the owner query finds these.
    "folders/gone/items/prism_orphan": {ownerId: "u1"},
    "folders/gone/items/prism_orphan_u2": {ownerId: "u2"},
    "other/parent/items/prism_unrelated": {ownerId: "u1"},
  });
  let fail = true;
  const operations: string[] = [];
  type Ref = {path: string; set: (data: Record<string, unknown>) => Promise<void>;
    update: (data: Record<string, unknown>) => Promise<void>; delete: () => Promise<void>};
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    const target = collection(name);
    if (name !== "folders") return target;
    return {where: (field: string, op: admin.firestore.WhereFilterOp, value: unknown) => ({
      get: async () => {
        const snap = await target.where(field, op, value).get();
        return {docs: snap.docs.map((doc) => ({...doc, ref: {...doc.ref,
          collection: (sub: string) => ({...doc.ref.collection(sub), path: `${doc.ref.path}/${sub}`}),
        }}))};
      },
    })};
  });
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    for (const path of [...store.keys()].filter((key) => key.startsWith(`${ref.path}/`))) {
      if (fail && path === "folders/two/items/prism_d") {
        fail = false;
        throw new Error("item deletion failed");
      }
      operations.push(`delete:${path}`);
      store.delete(path);
    }
  });
  t.mock.method(db, "batch", () => {
    const queued: Ref[] = [];
    const batch = {
      delete: (ref: Ref) => {
        queued.push(ref);
        return batch;
      },
      commit: async () => {
        assert.ok(queued.length <= 400);
        if (fail && queued.some((ref) => ref.path === "folders/two/items/prism_d")) {
          fail = false;
          throw new Error("item deletion failed");
        }
        for (const ref of queued) {
          operations.push(`delete:${ref.path}`);
          await ref.delete();
        }
        return [];
      },
    };
    return batch;
  });
  t.mock.method(db, "bulkWriter", () => ({
    set: (ref: Ref, data: Record<string, unknown>) => ref.set(data),
    update: (ref: Ref, data: Record<string, unknown>) => ref.update(data),
    delete: (ref: Ref) => {
      operations.push(`delete:${ref.path}`);
      return ref.delete();
    },
    close: async () => undefined,
  }));
  const run = () => deleteAccount.run({auth: {uid: "u1", token: {auth_time: Math.floor(Date.now() / 1000)}},
    data: {uid: "u2"}} as unknown as Parameters<typeof deleteAccount.run>[0]);
  await assert.rejects(run, /item deletion failed/);
  assert.equal(store.has("folders/one/items/prism_a"), false);
  assert.equal(store.has("folders/two/items/prism_d"), true);
  assert.equal(store.has("folders/one"), true);
  assert.equal(store.has("folders/two"), true);
  assert.equal(store.get("creatorDeletionState/u1")?.closed, true);
  assert.equal(store.get("usersv2/u1")?.deleted, undefined);
  assert.ok(!log.includes("auth"));
  const retryStart = operations.length;
  assert.deepEqual(await run(), {ok: true});
  assert.deepEqual([...store.keys()].filter((path) => path.startsWith("folders/")),
    ["folders/two/items/prism_previous_owner", "folders/foreign", "folders/foreign/items/prism_x",
      "folders/gone/items/prism_orphan_u2"]);
  const retry = operations.slice(retryStart);
  for (const folder of ["one", "two"]) {
    const folderDelete = retry.indexOf(`delete:folders/${folder}`);
    assert.ok(folderDelete >= 0);
    for (const [index, operation] of retry.entries()) {
      if (operation.startsWith(`delete:folders/${folder}/items/`)) assert.ok(index < folderDelete);
    }
  }
  assert.equal(store.get("usersv2/u1")?.deleted, true);
  assert.equal(store.has("other/parent/items/prism_unrelated"), true);
  assert.ok(log.includes("auth"));
});

test("folder item replacement by another owner is not deleted after the owner query", async (t) => {
  fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {name: "Caller"},
    "folders/one/items/prism_a": {ownerId: "u1"},
  });
  type Ref = {path: string; get: () => Promise<{updateTime?: {version: number}}>; delete: () => Promise<void>;
    set: (data: Record<string, unknown>) => Promise<void>};
  type Precondition = {lastUpdateTime: {version: number}};
  const folderRef = db.collection("folders").doc("one") as unknown as Ref;
  let raceItem = true;
  t.mock.method(db, "batch", () => {
    const queued: Array<{ref: Ref; precondition?: Precondition}> = [];
    const batch = {
      delete: (ref: Ref, precondition?: Precondition) => {
        queued.push({ref, precondition});
        return batch;
      },
      commit: async () => {
        const item = queued.find(({ref}) => ref.path === "folders/one/items/prism_a");
        if (raceItem && item) {
          raceItem = false;
          await item.ref.delete();
          await folderRef.set({ownerId: "u2"});
          await item.ref.set({ownerId: "u2"});
          const replacement = await item.ref.get();
          if (item.precondition && replacement.updateTime?.version !== item.precondition.lastUpdateTime.version) {
            throw Object.assign(new Error("firestore 9"), {code: 9});
          }
        }
        for (const {ref} of queued) await ref.delete();
        return [];
      },
    };
    return batch;
  });
  t.mock.method(db, "bulkWriter", () => ({
    set: async () => undefined,
    update: async () => undefined,
    delete: (ref: Ref) => ref.delete(),
    close: async () => undefined,
  }));
  const request = {
    auth: {uid: "u1", token: {auth_time: Math.floor(Date.now() / 1000)}},
    data: {},
  } as unknown as Parameters<typeof deleteAccount.run>[0];
  const run = () => deleteAccount.run(request);

  await assert.rejects(run, /firestore 9/);
  assert.deepEqual(await run(), {ok: true});
  assert.equal(store.get("folders/one")?.ownerId, "u2");
  assert.equal(store.get("folders/one/items/prism_a")?.ownerId, "u2");
  assert.equal(store.get("usersv2/u1")?.deleted, true);
});

test("a folder the repair trigger updates after the owner query is still deleted on the first call", async (t) => {
  fake(t, {email: ""});
  const store = installFakeDb(t, {
    "usersv2/u1": {name: "Caller"},
    "folders/one": {ownerId: "u1", itemCount: 1, covers: ["A"]},
  });
  type Ref = {path: string; get: () => Promise<{updateTime?: {version: number}}>; delete: () => Promise<void>;
    update: (data: Record<string, unknown>) => Promise<void>};
  type Precondition = {lastUpdateTime: {version: number}};
  let repaired = false;
  t.mock.method(db, "bulkWriter", () => ({
    set: async () => undefined,
    update: async () => undefined,
    delete: async (ref: Ref, precondition?: Precondition) => {
      if (ref.path === "folders/one" && !repaired) {
        // The item delete above fired onFolderItemWritten, which repaired the folder's count.
        repaired = true;
        await ref.update({itemCount: 0, covers: []});
        const current = await ref.get();
        if (precondition && current.updateTime?.version !== precondition.lastUpdateTime.version) {
          throw Object.assign(new Error("firestore 9"), {code: 9});
        }
      }
      return ref.delete();
    },
    close: async () => undefined,
  }));
  const request = {
    auth: {uid: "u1", token: {auth_time: Math.floor(Date.now() / 1000)}},
    data: {},
  } as unknown as Parameters<typeof deleteAccount.run>[0];

  assert.deepEqual(await deleteAccount.run(request), {ok: true});
  assert.equal(store.has("folders/one"), false);
});
