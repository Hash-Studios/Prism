import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import * as notificationHelper from "../notificationHelper";
import {sendDueFolderActivity} from "../sharedFolders";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = 1_800_000_000_000;
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

function fixture() {
  const createTimes = {
    "folders/f1": at(1),
    "folders/f1/items/own": at(2),
    "folders/f1/items/a": at(3),
    "folders/f1/items/b": at(4),
    "folders/f1/items/c": at(5),
  };
  const seed: Record<string, Doc> = {
    "folders/f1": {ownerId: "owner", name: "Night", members: {editor: {addedBy: "owner", addedAt: at(1)}}},
    "folders/f1/items/own": {ownerId: "owner", addedBy: "editor"},
    "folders/f1/items/a": {ownerId: "owner", addedBy: "adder"},
    "folders/f1/items/b": {ownerId: "owner", addedBy: "adder"},
    "folders/f1/items/c": {ownerId: "owner", addedBy: "other"},
    "folderActivity/f1": {folderId: "f1", folderCreatedAt: at(1), pending: {own: "editor", a: "adder", b: "adder", c: "other"},
      pendingCreatedAt: {own: at(2), a: at(3), b: at(4), c: at(5)}, firstPendingAt: at(0), dueAt: at(1), lastSentAt: null},
    "usersv2/owner": {name: "Owner"},
    "usersv2/editor": {name: "Editor", email: "editor@example.com"},
    "usersv2/editor/private/session": {folderAlerts: true, folderAlertsToken: "token", fcmToken: "token"},
    "usersv2/adder": {name: "Ana"},
    "usersv2/other": {name: "Bea"},
  };
  return {seed, createTimes};
}

function mockSend(t: TestContext) {
  const send = t.mock.method(notificationHelper, "sendToUser", async () => true);
  return send;
}

function mockGetAll(t: TestContext) {
  t.mock.method(db, "getAll", async (...refs: Array<{get: () => Promise<unknown>}>) =>
    Promise.all(refs.map((ref) => ref.get())) as unknown as ReturnType<typeof db.getAll>);
}

test("sendDueFolderActivity delivers one title/count excluding the recipient's own add", async (t) => {
  const send = mockSend(t);
  const {seed, createTimes} = fixture();
  installFakeDb(t, seed, undefined, {createTimes});
  mockGetAll(t);

  assert.equal(await sendDueFolderActivity(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  const [payload] = send.mock.calls[0].arguments;
  assert.ok(payload);
  assert.equal(payload.title, "Ana and 1 more added 3 walls to Night");
});

test("sendDueFolderActivity skips a recipient removed before transactional delivery", async (t) => {
  const send = mockSend(t);
  const {seed, createTimes} = fixture();
  const store = installFakeDb(t, seed, undefined, {createTimes});
  mockGetAll(t);
  const realDoc = db.doc.bind(db);
  t.mock.method(db, "doc", (path: string) => {
    const ref = realDoc(path);
    return path === "usersv2/editor/private/session" ? {...ref, get: async () => {
      store.set("folders/f1", {ownerId: "owner", name: "Night", members: {}});
      return ref.get();
    }} : ref;
  });
  assert.equal(await sendDueFolderActivity(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

for (const [direction, path] of [
  ["recipient blocks secondary adder", "usersv2/editor/blockedUsers/other"],
  ["secondary adder blocks recipient", "usersv2/other/blockedUsers/editor"],
] as const) {
  test(`sendDueFolderActivity excludes an add when ${direction} during session read`, async (t) => {
    const send = mockSend(t);
    const {seed, createTimes} = fixture();
    const store = installFakeDb(t, seed, undefined, {createTimes});
    mockGetAll(t);
    const realDoc = db.doc.bind(db);
    t.mock.method(db, "doc", (docPath: string) => {
      const ref = realDoc(docPath);
      return docPath === "usersv2/editor/private/session" ? {...ref, get: async () => {
        store.set(path, {});
        return ref.get();
      }} : ref;
    });

    assert.equal(await sendDueFolderActivity(NOW), 1);
    assert.equal(send.mock.callCount(), 1);
    const [payload] = send.mock.calls[0].arguments;
    assert.ok(payload);
    assert.equal(payload.title, "Ana added 2 walls to Night");
  });
}

test("sendDueFolderActivity does not attribute a deleted and re-added item incarnation", async (t) => {
  const send = mockSend(t);
  const {seed, createTimes} = fixture();
  const store = installFakeDb(t, seed, undefined, {createTimes});
  mockGetAll(t);
  const realDoc = db.doc.bind(db);
  t.mock.method(db, "doc", (path: string) => {
    const ref = realDoc(path);
    return path === "usersv2/editor/private/session" ? {...ref, get: async () => {
      store.delete("folders/f1/items/a");
      store.set("folders/f1/items/a", {ownerId: "owner", addedBy: "adder"});
      createTimes["folders/f1/items/a"] = at(6);
      return ref.get();
    }} : ref;
  });

  assert.equal(await sendDueFolderActivity(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  const [payload] = send.mock.calls[0].arguments;
  assert.ok(payload);
  assert.equal(payload.title, "Ana and 1 more added 2 walls to Night");
});

test("sendDueFolderActivity drops a deleted adder but delivers the surviving contribution", async (t) => {
  const send = mockSend(t);
  const {seed, createTimes} = fixture();
  delete seed["usersv2/adder"];
  installFakeDb(t, seed, undefined, {createTimes});
  mockGetAll(t);

  assert.equal(await sendDueFolderActivity(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  const [payload] = send.mock.calls[0].arguments;
  assert.ok(payload);
  assert.equal(payload.title, "Bea added a wall to Night");
});
