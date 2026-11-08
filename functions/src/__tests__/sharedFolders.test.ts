import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import "./sharedFoldersDelivery.test";
import {repairFolder} from "../folders";
import {publicFolderDeps} from "../publicFolders";
import {
  cleanupDeletedFolder,
  createFolderInvite,
  folderActivityPayload,
  getFolderInvite,
  joinFolder,
  leaveFolder,
  planActivityPushes,
  recordFolderActivity,
  removeAllFolderMemberships,
  removeFolderMember,
  removeFolderMembershipsBetween,
  sendDueFolderActivity,
} from "../sharedFolders";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const NOW = Date.now();
const CODE = "ABCDEFGHJK";
const INVITE_PATTERN = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{10}$/;
const TEN_EDITORS = ["e0", "e1", "e2", "e3", "e4", "e5", "e6", "e7", "e8", "e9"];

const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const ms = (value: unknown) => (value as admin.firestore.Timestamp).toMillis();

const USERS: Record<string, Doc> = {
  "usersv2/a": {name: "Owen", email: "a@x.com"},
  "usersv2/b": {name: "Ana", email: "b@x.com"},
  "usersv2/c": {name: "Cy", email: "c@x.com"},
  "usersv2/d": {name: "Dee", email: "d@x.com"},
  "usersv2/z": {name: "Zed", email: "z@x.com"},
};

function folder(ownerId: string, editors: string[] = [], extra: Doc = {}): Doc {
  return {
    ownerId,
    name: "Night",
    itemCount: 0,
    covers: [],
    members: Object.fromEntries(editors.map((uid, i) => [uid, {addedBy: ownerId, addedAt: at(1_000 * (i + 1))}])),
    memberIds: [...editors].sort(),
    ...extra,
  };
}

function invite(extra: Doc = {}): Doc {
  return {
    code: CODE,
    folderId: "f1",
    createdBy: "a",
    createdAt: at(NOW - DAY),
    expiresAt: at(NOW + 6 * DAY),
    folderCreatedAt: at(1),
    usedBy: null,
    usedAt: null,
    ...extra,
  };
}

function validInvite(extra: Doc = {}): Record<string, Doc> {
  return {[`folderInvites/${CODE}`]: invite(extra)};
}

function setup(t: TestContext, seed: Record<string, Doc> = {}, authDisabled: () => Promise<boolean> = async () => false) {
  t.mock.method(publicFolderDeps, "authDisabled", authDisabled);
  return installFakeDb(t, {...USERS, "folders/f1": folder("a"), ...seed});
}

function call<R>(fn: {run: (request: never) => Promise<R>}, uid: string | undefined, data: unknown): Promise<R> {
  return fn.run({auth: uid ? {uid} : undefined, data} as never);
}

function stubGetAll(t: TestContext) {
  t.mock.method(db, "getAll", (async (...refs: Array<{get: () => Promise<unknown>}>) =>
    Promise.all(refs.map((ref) => ref.get()))) as unknown as typeof db.getAll);
}

test("createFolderInvite returns a 10-character code and a single-use invite that lasts 7 days", async (t) => {
  const store = setup(t);
  const result = await call(createFolderInvite, "a", {folderId: "f1"});
  assert.equal(result.code.length, 10);
  assert.match(result.code, INVITE_PATTERN);
  const saved = store.get(`folderInvites/${result.code}`);
  assert.equal(saved?.code, result.code);
  assert.equal(saved?.createdBy, "a");
  assert.equal(saved?.folderId, "f1");
  assert.equal(saved?.usedBy, null);
  assert.equal(ms(saved?.expiresAt), ms(saved?.createdAt) + 7 * DAY);
});

test("smart folders refuse invites, invite previews and joins", async (t) => {
  const store = setup(t, {...validInvite(), "folders/f1": folder("a", [], {
    smartRules: [{kind: "colour", value: "blue"}],
  })});
  await assert.rejects(call(createFolderInvite, "a", {folderId: "f1"}),
    {code: "failed-precondition", message: "smart"});
  assert.deepEqual(await call(getFolderInvite, "c", {code: CODE}), {status: "not_found"});
  await assert.rejects(call(joinFolder, "c", {code: CODE}),
    {code: "failed-precondition", message: "not_found"});
  assert.deepEqual(store.get("folders/f1")?.memberIds, []);
  assert.equal(store.get(`folderInvites/${CODE}`)?.usedBy, null);
});

test("createFolderInvite refuses a caller who is not the owner", async (t) => {
  setup(t);
  await assert.rejects(call(createFolderInvite, "b", {folderId: "f1"}),
    {code: "permission-denied", message: "Only the owner can invite people."});
});

test("createFolderInvite refuses when the folder already has 10 editors", async (t) => {
  setup(t, {"folders/f1": folder("a", TEN_EDITORS)});
  await assert.rejects(call(createFolderInvite, "a", {folderId: "f1"}),
    {code: "failed-precondition", message: "full"});
});

test("joinFolder makes the caller an editor and spends the invite", async (t) => {
  const store = setup(t, validInvite());
  assert.deepEqual(await call(joinFolder, "c", {code: CODE}), {folderId: "f1", joined: true});
  const saved = store.get("folders/f1");
  assert.deepEqual(saved?.memberIds, ["c"]);
  assert.equal((saved?.members as Record<string, Doc>).c.addedBy, "a");
  assert.equal(store.get(`folderInvites/${CODE}`)?.usedBy, "c");
});

const refusals: Array<{name: string; seed: Record<string, Doc>; message: string}> = [
  {name: "an expired invite", seed: validInvite({expiresAt: at(NOW - MINUTE)}), message: "expired"},
  {name: "a used invite", seed: validInvite({usedBy: "d", usedAt: at(NOW - MINUTE)}), message: "used"},
  {name: "a folder with 10 editors", seed: {...validInvite(), "folders/f1": folder("a", TEN_EDITORS)}, message: "full"},
  {name: "a joiner the owner blocked", seed: {...validInvite(), "usersv2/a/blockedUsers/c": {}}, message: "blocked"},
  {name: "an owner the joiner blocked", seed: {...validInvite(), "usersv2/c/blockedUsers/a": {}}, message: "blocked"},
  {
    name: "a joiner that an editor blocked",
    seed: {...validInvite(), "folders/f1": folder("a", ["b"]), "usersv2/b/blockedUsers/c": {}},
    message: "blocked",
  },
  {
    name: "an editor the joiner blocked",
    seed: {...validInvite(), "folders/f1": folder("a", ["b"]), "usersv2/c/blockedUsers/b": {}},
    message: "blocked",
  },
  {name: "no invite document", seed: {}, message: "not_found"},
  {name: "an invite not created by the folder owner", seed: validInvite({createdBy: "z"}), message: "not_found"},
  {name: "a joiner whose account is deleted", seed: {...validInvite(), "usersv2/c": {name: "Cy", deleted: true}},
    message: "account"},
];

for (const row of refusals) {
  test(`joinFolder refuses ${row.name} with "${row.message}"`, async (t) => {
    setup(t, row.seed);
    await assert.rejects(call(joinFolder, "c", {code: CODE}), {code: "failed-precondition", message: row.message});
  });
}

test("joinFolder refuses when the caller's auth account is disabled", async (t) => {
  setup(t, validInvite(), async () => true);
  await assert.rejects(call(joinFolder, "c", {code: CODE}), {code: "failed-precondition", message: "account"});
});

test("joinFolder again as a member returns joined:false and changes nothing", async (t) => {
  const store = setup(t, validInvite());
  await call(joinFolder, "c", {code: CODE});
  const before = store.get("folders/f1");
  assert.deepEqual(await call(joinFolder, "c", {code: CODE}), {folderId: "f1", joined: false});
  assert.deepEqual(store.get("folders/f1"), before);
  assert.deepEqual(store.get("folders/f1")?.memberIds, ["c"]);
});

test("joining again as a member is unchanged even if another editor blocked them", async (t) => {
  const store = setup(t, {
    ...validInvite(),
    "folders/f1": folder("a", ["b", "c"]),
    "usersv2/b/blockedUsers/c": {},
  });
  assert.deepEqual(await call(joinFolder, "b", {code: CODE}), {folderId: "f1", joined: false});
  assert.equal(store.get(`folderInvites/${CODE}`)?.usedBy, null);
});

test("a deleted existing editor cannot use an invite to rejoin", async (t) => {
  setup(t, {"folders/f1": folder("a", ["c"]), "usersv2/c": {name: "Cy", deleted: true}, ...validInvite()});
  await assert.rejects(call(joinFolder, "c", {code: CODE}), {code: "failed-precondition", message: "account"});
});

test("getFolderInvite does not reveal a folder when either side has blocked the caller", async (t) => {
  setup(t, {...validInvite(), "usersv2/a/blockedUsers/c": {}});
  assert.deepEqual(await call(getFolderInvite, "c", {code: CODE}), {status: "not_found"});
});

test("getFolderInvite does not reveal an invite to a deleted account", async (t) => {
  setup(t, {...validInvite(), "usersv2/c": {name: "Cy", deleted: true}});
  assert.deepEqual(await call(getFolderInvite, "c", {code: CODE}), {status: "not_found"});
});

test("joinFolder by the owner returns joined:false and leaves the invite unused", async (t) => {
  const store = setup(t, validInvite());
  assert.deepEqual(await call(joinFolder, "a", {code: CODE}), {folderId: "f1", joined: false});
  assert.equal(store.get(`folderInvites/${CODE}`)?.usedBy, null);
  assert.deepEqual(store.get("folders/f1")?.memberIds, []);
});

test("an invite spent by one user cannot be used by another", async (t) => {
  setup(t, validInvite());
  await call(joinFolder, "c", {code: CODE});
  await assert.rejects(call(joinFolder, "d", {code: CODE}), {code: "failed-precondition", message: "used"});
});

test("two callers racing the same single-use invite produce one member", async (t) => {
  const store = setup(t, validInvite());
  const results = await Promise.allSettled([
    call(joinFolder, "c", {code: CODE}),
    call(joinFolder, "d", {code: CODE}),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);
  assert.equal((store.get("folders/f1")?.memberIds as string[]).length, 1);
  assert.ok(["c", "d"].includes(store.get(`folderInvites/${CODE}`)?.usedBy as string));
});

test("two different invites racing for the tenth editor slot cannot overfill the folder", async (t) => {
  const secondCode = "BCDEFGHJKM";
  const store = setup(t, {
    "folders/f1": folder("a", TEN_EDITORS.slice(0, 9)),
    ...validInvite(),
    [`folderInvites/${secondCode}`]: invite({code: secondCode}),
  });
  const results = await Promise.allSettled([
    call(joinFolder, "c", {code: CODE}),
    call(joinFolder, "d", {code: secondCode}),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  const refused = results.find((result) => result.status === "rejected");
  assert.equal((refused as PromiseRejectedResult).reason.message, "full");
  assert.equal((store.get("folders/f1")?.memberIds as string[]).length, 10);
});

test("repairFolder counts only the owner's items and keeps the four newest covers", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", TEN_EDITORS, {itemCount: 0, covers: ["stale"]}),
    "folders/f1/items/prism_1": {ownerId: "a", addedBy: "e0", thumb: "T1", addedAt: at(1_000)},
    "folders/f1/items/prism_2": {ownerId: "a", addedBy: "e1", thumb: "T2", addedAt: at(2_000)},
    "folders/f1/items/prism_3": {ownerId: "a", addedBy: "e2", thumb: "T3", addedAt: at(3_000)},
    "folders/f1/items/prism_4": {ownerId: "a", addedBy: "e3", thumb: "T4", addedAt: at(4_000)},
    "folders/f1/items/prism_5": {ownerId: "a", addedBy: "e4", thumb: "T5", addedAt: at(5_000)},
    "folders/f1/items/prism_6": {ownerId: "a", addedBy: "e5", thumb: "T6", addedAt: at(6_000)},
    "folders/f1/items/prism_x": {ownerId: "x", addedBy: "e6", thumb: "TX", addedAt: at(9_000)},
  });
  await repairFolder("f1");
  assert.equal(store.get("folders/f1")?.itemCount, 6);
  assert.deepEqual(store.get("folders/f1")?.covers, ["T6", "T5", "T4", "T3"]);
});

test("removeFolderMember lets the owner remove an editor and refuses an editor", async (t) => {
  const store = setup(t, {"folders/f1": folder("a", ["b", "c"])});
  await assert.rejects(call(removeFolderMember, "c", {folderId: "f1", uid: "b"}),
    {code: "permission-denied", message: "Only the owner can remove people."});
  assert.deepEqual(await call(removeFolderMember, "a", {folderId: "f1", uid: "b"}), {removed: true});
  assert.deepEqual(store.get("folders/f1")?.memberIds, ["c"]);
  assert.deepEqual(Object.keys(store.get("folders/f1")?.members as Doc), ["c"]);
  assert.deepEqual(await call(removeFolderMember, "a", {folderId: "f1", uid: "x"}), {removed: false});
});

test("leaveFolder removes an editor, refuses the owner, and reports a missing folder as not left", async (t) => {
  const store = setup(t, {"folders/f1": folder("a", ["b", "c"])});
  assert.deepEqual(await call(leaveFolder, "c", {folderId: "f1"}), {left: true});
  assert.deepEqual(store.get("folders/f1")?.memberIds, ["b"]);
  await assert.rejects(call(leaveFolder, "a", {folderId: "f1"}),
    {code: "invalid-argument", message: "The owner cannot leave. Delete the folder instead."});
  assert.deepEqual(await call(leaveFolder, "c", {folderId: "missing"}), {left: false});
});

test("removeAllFolderMemberships takes a user out of every folder they edit and deletes their invites", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b", "c"]),
    "folders/f2": folder("b", ["c"]),
    "folders/f3": folder("d", ["a"]),
    "folderInvites/ABCDEFGHJK": invite({createdBy: "c", folderId: "f1"}),
    "folderInvites/BCDEFGHJKM": invite({code: "BCDEFGHJKM", createdBy: "c", folderId: "f2"}),
    "folderInvites/CDEFGHJKMN": invite({code: "CDEFGHJKMN", createdBy: "a", folderId: "f1"}),
  });
  await removeAllFolderMemberships("c");
  assert.deepEqual(store.get("folders/f1")?.memberIds, ["b"]);
  assert.deepEqual(store.get("folders/f2")?.memberIds, []);
  assert.equal(store.get("folders/f2")?.ownerId, "b");
  assert.deepEqual(store.get("folders/f3")?.memberIds, ["a"]);
  assert.equal(store.has("folderInvites/ABCDEFGHJK"), false);
  assert.equal(store.has("folderInvites/BCDEFGHJKM"), false);
  assert.equal(store.has("folderInvites/CDEFGHJKMN"), true);
});

test("cleanupDeletedFolder removes the folder's invites and its activity doc only", async (t) => {
  const store = setup(t, {
    "folderInvites/ABCDEFGHJK": invite({folderId: "f1"}),
    "folderInvites/BCDEFGHJKM": invite({code: "BCDEFGHJKM", folderId: "f2"}),
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {k1: "b"}, firstPendingAt: at(NOW), dueAt: at(NOW + HOUR),
      lastSentAt: null},
    "folderActivity/f2": {folderId: "f2", folderCreatedAt: at(1), pending: {}, firstPendingAt: null, dueAt: null, lastSentAt: null},
  });
  store.delete("folders/f1");
  await cleanupDeletedFolder("f1");
  assert.equal(store.has("folderInvites/ABCDEFGHJK"), false);
  assert.equal(store.has("folderActivity/f1"), false);
  assert.equal(store.has("folderInvites/BCDEFGHJKM"), true);
  assert.equal(store.has("folderActivity/f2"), true);
});

test("a delayed delete cleanup does not remove invites or activity for a recreated folder id", async (t) => {
  const store = setup(t, {
    "folderInvites/ABCDEFGHJK": invite({folderId: "f1"}),
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {k1: "b"}, firstPendingAt: at(NOW), dueAt: at(NOW + HOUR),
      lastSentAt: null},
  });

  // The old folder's delete trigger can run after Firestore has already reused its id.
  await cleanupDeletedFolder("f1");

  assert.equal(store.has(`folderInvites/${CODE}`), true);
  assert.equal(store.has("folderActivity/f1"), true);
});

test("an invite cannot join a same-owner folder recreated with the same id", async (t) => {
  setup(t, validInvite({folderCreatedAt: at(0)}));
  await assert.rejects(call(joinFolder, "c", {code: CODE}), {code: "failed-precondition", message: "not_found"});
});

test("removeFolderMembershipsBetween removes each side only from the other's folders", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["c"]),
    "folders/f2": folder("x", ["c"]),
    "folders/f3": folder("c", ["a"]),
  });
  await removeFolderMembershipsBetween("a", "c");
  assert.deepEqual(store.get("folders/f1")?.memberIds, []);
  assert.deepEqual(store.get("folders/f2")?.memberIds, ["c"]);
  assert.deepEqual(store.get("folders/f3")?.memberIds, []);
});

test("recordFolderActivity keeps one pending add per item and sets dueAt from the first add or the last push", async (t) => {
  const lastSentMs = NOW - MINUTE;
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folders/f2": folder("a"),
    "folders/f3": folder("a", ["b"]),
    "folders/f4": folder("a", ["b"]),
    "folders/f5": folder("a", ["b"]),
    "folders/f1/items/k1": {ownerId: "a", addedBy: "b"},
    "folders/f2/items/k1": {ownerId: "a", addedBy: "a"},
    "folders/f3/items/k9": {ownerId: "x", addedBy: "b"},
    "folders/f4/items/k1": {ownerId: "a", addedBy: "b"},
    "folders/f5/items/k1": {ownerId: "a", addedBy: "b"},
    "folderActivity/f5": {folderId: "f5", folderCreatedAt: at(1), pending: {}, firstPendingAt: null, dueAt: null, lastSentAt: at(lastSentMs)},
  });
  await recordFolderActivity("f1", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  await recordFolderActivity("f1", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  assert.deepEqual(store.get("folderActivity/f1")?.pending, {k1: "b"});

  await recordFolderActivity("f2", "k1", {ownerId: "a", addedBy: "a"}, at(1));
  assert.equal(store.has("folderActivity/f2"), false);

  await recordFolderActivity("f3", "k9", {ownerId: "x", addedBy: "b"}, at(1));
  assert.equal(store.has("folderActivity/f3"), false);

  await recordFolderActivity("f4", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  const fresh = store.get("folderActivity/f4");
  assert.equal(ms(fresh?.dueAt) - ms(fresh?.firstPendingAt), 10 * MINUTE);

  await recordFolderActivity("f5", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  assert.equal(ms(store.get("folderActivity/f5")?.dueAt), lastSentMs + HOUR);
});

test("deleting and re-adding the same item key by the same editor replaces its pending generation", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folders/f1/items/k1": {ownerId: "a", addedBy: "b"},
  });
  await recordFolderActivity("f1", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  store.delete("folders/f1/items/k1");
  store.set("folders/f1/items/k1", {ownerId: "a", addedBy: "b"});
  await recordFolderActivity("f1", "k1", {ownerId: "a", addedBy: "b"}, at(2));
  assert.deepEqual(store.get("folderActivity/f1")?.pendingCreatedAt, {k1: at(2)});
});

test("a delayed item-created event from the old folder generation is not reported", async (t) => {
  const store = setup(t, {"folders/f1": folder("a", ["b"]), "folders/f1/items/reused-key": {ownerId: "a", addedBy: "b"}});
  await recordFolderActivity("f1", "reused-key", {ownerId: "a", addedBy: "b"}, at(0));
  assert.equal(store.has("folderActivity/f1"), false);
});

test("a retried item-created event after its burst was claimed is not counted twice", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folders/f1/items/k1": {ownerId: "a", addedBy: "b", thumb: "https://img.prismwalls.com/previews/k1.img"},
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {k1: "b"}, pendingCreatedAt: {k1: at(1)},
      firstPendingAt: at(NOW - 20 * MINUTE), dueAt: at(NOW - 1000), lastSentAt: null},
    "folderActivity/f1/items/k1": {createdAt: at(1)},
  });
  stubGetAll(t);
  await sendDueFolderActivity(NOW);
  await recordFolderActivity("f1", "k1", {ownerId: "a", addedBy: "b"}, at(1));
  assert.deepEqual(store.get("folderActivity/f1")?.pending, {});
});

test("planActivityPushes gives each member one push led by the adder with the most walls", () => {
  const adds = {k1: "b", k2: "b", k3: "c"};
  assert.deepEqual(planActivityPushes(["a", "b", "c"], adds, () => false), [
    {uid: "a", adderUid: "b", wallCount: 3, otherAdders: 1},
    {uid: "b", adderUid: "c", wallCount: 1, otherAdders: 0},
    {uid: "c", adderUid: "b", wallCount: 2, otherAdders: 0},
  ]);
  const blocksAB = (x: string, y: string) => [x, y].sort().join("|") === "a|b";
  assert.deepEqual(planActivityPushes(["a", "b", "c"], adds, blocksAB), [
    {uid: "a", adderUid: "c", wallCount: 1, otherAdders: 0},
    {uid: "b", adderUid: "c", wallCount: 1, otherAdders: 0},
    {uid: "c", adderUid: "b", wallCount: 2, otherAdders: 0},
  ]);
});

test("sendDueFolderActivity leaves an activity doc alone until it is due", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {k1: "b"}, firstPendingAt: at(NOW), dueAt: at(NOW + HOUR),
      lastSentAt: null},
  });
  stubGetAll(t);
  assert.equal(await sendDueFolderActivity(NOW), 0);
  assert.deepEqual(store.get("folderActivity/f1")?.pending, {k1: "b"});
});

test("sendDueFolderActivity clears a due burst, and a second run in the same hour sends nothing", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folders/f1/items/k1": {ownerId: "a", addedBy: "b", thumb: "https://img.prismwalls.com/previews/k1.img"},
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {k1: "b"}, firstPendingAt: at(NOW - 20 * MINUTE),
      dueAt: at(NOW - 1000), lastSentAt: null},
  });
  stubGetAll(t);
  assert.equal(await sendDueFolderActivity(NOW), 0);
  assert.deepEqual(store.get("folderActivity/f1")?.pending, {});
  assert.equal(ms(store.get("folderActivity/f1")?.lastSentAt), NOW);
  assert.equal(await sendDueFolderActivity(NOW + 5 * MINUTE), 0);
  assert.deepEqual(store.get("folderActivity/f1")?.pending, {});
});

test("a pending burst from a deleted folder generation is discarded", async (t) => {
  const store = setup(t, {
    "folders/f1": folder("a", ["b"]),
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(0), pending: {k1: "b"},
      firstPendingAt: at(NOW - 20 * MINUTE), dueAt: at(NOW - 1000), lastSentAt: null},
  });
  stubGetAll(t);
  await sendDueFolderActivity(NOW);
  assert.equal(store.has("folderActivity/f1"), false);
});

test("folderActivityPayload titles a burst by its adder and wall count, and routes to the folder", () => {
  const plan = (wallCount: number, otherAdders: number) => ({uid: "a", adderUid: "b", wallCount, otherAdders});
  assert.equal(folderActivityPayload(plan(3, 0), "f1", "Night", "Ana", NOW).title, "Ana added 3 walls to Night");
  assert.equal(folderActivityPayload(plan(1, 0), "f1", "Night", "Ana", NOW).title, "Ana added a wall to Night");
  const crowd = folderActivityPayload(plan(5, 2), "f1", "Night", "Ana", NOW);
  assert.equal(crowd.title, "Ana and 2 more added 5 walls to Night");
  assert.equal(crowd.data.route, "folder");
  assert.equal(crowd.data.folder_id, "f1");
});
