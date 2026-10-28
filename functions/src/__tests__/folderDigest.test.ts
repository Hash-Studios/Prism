process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  folderDigestPayload,
  planFolderDigests,
  sendDueFolderDigests,
  type FolderWall,
  type RecentFolder,
} from "../folderDigest";
import * as notificationHelper from "../notificationHelper";
import {sendToUser, userPushTokens} from "../notificationHelper";
import * as wallOfTheDay from "../wallOfTheDay";
import {publicFolderDeps} from "../publicFolders";
import {db} from "../common";
import {claimDay} from "../followDigest";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 28, 13, 0);
const HOUR = 3_600_000;
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const wall = (id: string, addedMs: number): FolderWall => ({
  itemKey: `prism_${id}`,
  docId: id.toUpperCase(),
  addedMs,
  wall: {id, thumb: `https://img.prismwalls.com/previews/${id}.img`, tags: ["Night"]},
});

const f1: RecentFolder = {folderId: "f1", ownerId: "A", name: "Night", walls: [
  wall("f1a", 30), wall("f1b", 20), wall("f1c", 10),
]};
const f2: RecentFolder = {folderId: "f2", ownerId: "C", name: "Dawn", walls: [wall("f2a", 25)]};
const f3: RecentFolder = {folderId: "f3", ownerId: "D", name: "Empty", walls: []};

test("planFolderDigests interleaves folders, skips own and empty folders", () => {
  const digests = planFolderDigests([f1, f2, f3], new Map([
    ["f1", ["b", "A", "b"]],
    ["f2", ["b", "C"]],
    ["f3", ["b", "c"]],
  ]));

  assert.deepEqual(digests.map((d) => d.uid), ["b"]);
  assert.deepEqual(digests[0].folders.map((f) => f.folderId), ["f1", "f2"]);
  assert.deepEqual(digests[0].walls.map((w) => w.wall.id), ["f1a", "f2a", "f1b", "f1c"]);
});

test("planFolderDigests shows a wall in two followed folders once", () => {
  const dupe: RecentFolder = {folderId: "f4", ownerId: "E", name: "Dusk", walls: [wall("f1a", 30)]};
  const [digest] = planFolderDigests([f1, dupe], new Map([["f1", ["b"]], ["f4", ["b"]]]));
  assert.deepEqual(digest.walls.map((w) => w.wall.id), ["f1a", "f1b", "f1c"]);
});

test("folderDigestPayload titles, data and the single daily image", () => {
  const one = planFolderDigests([f1], new Map([["f1", ["b"]]]))[0];
  const onePayload = folderDigestPayload(one, "2026-10-28");
  assert.equal(onePayload.title, "New in Night");

  const two = planFolderDigests([f1, f2], new Map([["f1", ["b"]], ["f2", ["b"]]]))[0];
  const payload = folderDigestPayload(two, "2026-10-28");
  assert.equal(payload.title, "New in Night and 1 more");
  assert.deepEqual(payload.data, {
    route: "folder",
    folder_id: "f1",
    folder_count: "2",
    url: "https://prismwalls.com/folder/f1",
    notification_kind: "folder_digest",
    push_kind: "post",
  });
  assert.equal(payload.collapseKey, "folder_digest_2026-10-28");
  assert.equal(payload.docId, "folder_digest_b_2026-10-28");
  assert.equal(payload.imageUrl, "https://img.prismwalls.com/previews/f1a.img");
  assert.equal("gallery" in payload, false);
});

function baseSeed(): Record<string, Doc> {
  const approved = (id: string) => ({
    id,
    review: true,
    originalProtected: true,
    collections: ["abstract"],
    visionLabels: ["Night"],
    wallpaper_thumb: `https://img.prismwalls.com/previews/${id}.img`,
  });
  return {
    "walls/W1": approved("w1"),
    "walls/W2": approved("w2"),
    "publicFolders/f1": {ownerId: "a", name: "Night", lastAddedAt: ts(NOW - HOUR)},
    "folders/f1": {ownerId: "a", name: "Night", public: true},
    "folders/f1/items/prism_w1": {ownerId: "a", id: "w1", provider: "Prism", wallpaperDocumentId: "W1"},
    "folders/f1/items/prism_w2": {ownerId: "a", id: "w2", provider: "Prism", wallpaperDocumentId: "W2"},
    "publicFolders/f1/items/prism_w1": {id: "w1", wallpaperDocumentId: "W1", projectedAt: ts(NOW - HOUR)},
    "publicFolders/f1/items/prism_w2": {id: "w2", wallpaperDocumentId: "W2", projectedAt: ts(NOW - HOUR)},
    "publicFolders/f1/followers/b": {uid: "b"},
    "usersv2/a": {},
    "usersv2/b": {email: "b@x.com", appOpenTimezoneOffsetMinutes: 0},
    "usersv2/b/private/session": {
      fcmToken: "T", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T", folderAlerts: true, folderAlertsToken: "T",
    },
    "usersv2/b/followedFolders/f1": {folderId: "f1", ownerId: "a"},
  };
}

function mockDelivery(t: TestContext, delivered = true) {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  t.mock.method(publicFolderDeps, "authDisabled", async () => false);
  return t.mock.method(notificationHelper, "sendToUser", async (payload: Parameters<typeof sendToUser>[0]) => {
    void payload;
    return delivered;
  });
}

test("sendDueFolderDigests sends one digest at 13:00 local and once per local day", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());

  assert.equal(await sendDueFolderDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  assert.equal(store.get("usersv2/b/private/folderDigest")?.day, "2026-10-28");

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 1);
});

test("overlapping folder digest runs claim a follower's local day only once", async (t) => {
  const send = mockDelivery(t);
  installFakeDb(t, baseSeed());

  assert.deepEqual(await Promise.all([sendDueFolderDigests(NOW), sendDueFolderDigests(NOW)]), [1, 0]);
  assert.equal(send.mock.callCount(), 1);
});

test("sendDueFolderDigests respects the folder alert switch, its token, blocks and the offset", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());

  store.set("usersv2/b/private/session", {fcmToken: "T", folderAlerts: false, folderAlertsToken: "T"});
  assert.equal(await sendDueFolderDigests(NOW), 0);

  store.set("usersv2/b/private/session", {fcmToken: "T", folderAlerts: true, folderAlertsToken: "OLD"});
  assert.equal(await sendDueFolderDigests(NOW), 0);

  store.set("usersv2/b/private/session", {fcmToken: "T", folderAlerts: true, folderAlertsToken: "T"});
  store.set("usersv2/b/blockedUsers/a", {});
  assert.equal(await sendDueFolderDigests(NOW), 0);
  store.delete("usersv2/b/blockedUsers/a");
  store.set("usersv2/a/blockedUsers/b", {});
  assert.equal(await sendDueFolderDigests(NOW), 0);
  store.delete("usersv2/a/blockedUsers/b");

  store.set("usersv2/b", {email: "b@x.com", appOpenTimezoneOffsetMinutes: 60});
  assert.equal(await sendDueFolderDigests(NOW), 0);

  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests requires the session token binding", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());
  store.set("usersv2/b/private/session", {fcmToken: "T", folderAlerts: true, folderAlertsToken: "T"});

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests drops a folder made private before its projection is removed", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());
  store.set("folders/f1", {ownerId: "a", name: "Night", public: false});

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests rechecks the live source after it has read the projection", async (t) => {
  const send = t.mock.method(notificationHelper, "sendToUser", async () => true);
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  const store = installFakeDb(t, baseSeed());
  let ownerChecks = 0;
  t.mock.method(publicFolderDeps, "authDisabled", async () => {
    ownerChecks++;
    if (ownerChecks === 1) store.set("folders/f1", {ownerId: "a", name: "Night", public: false});
    return false;
  });

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests stops if the public header disappears after the candidate read", async (t) => {
  const send = t.mock.method(notificationHelper, "sendToUser", async () => true);
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  const store = installFakeDb(t, baseSeed());
  t.mock.method(publicFolderDeps, "authDisabled", async () => {
    store.delete("publicFolders/f1");
    return false;
  });

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests stops for a disabled folder owner", async (t) => {
  const send = t.mock.method(notificationHelper, "sendToUser", async () => true);
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  installFakeDb(t, baseSeed());
  t.mock.method(publicFolderDeps, "authDisabled", async (uid: string) => uid === "a");

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueFolderDigests stops for a disabled recipient", async (t) => {
  const send = t.mock.method(notificationHelper, "sendToUser", async () => true);
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  const store = installFakeDb(t, baseSeed());
  t.mock.method(publicFolderDeps, "authDisabled", async (uid: string) => uid === "b");

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
  assert.equal(store.has("usersv2/b/private/folderDigest"), false);
});

test("sendDueFolderDigests drops a projected item removed from its private source folder", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());
  store.delete("folders/f1/items/prism_w1");
  store.delete("folders/f1/items/prism_w2");

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("folder digest delivery rechecks the exact opted-in token", async (t) => {
  const store = installFakeDb(t, baseSeed());
  store.set("usersv2/b/private/session", {
    fcmToken: "T2", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T2", folderAlerts: false, folderAlertsToken: "T",
  });

  assert.deepEqual(await userPushTokens("b", undefined, undefined, "T"), []);
  store.set("usersv2/b/private/session", {
    fcmToken: "T2", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T2", folderAlerts: true, folderAlertsToken: "T2",
  });
  assert.deepEqual(await userPushTokens("b", undefined, undefined, "T"), []);
});

test("sendToUser does not write a folder digest inbox entry after its token opt-in changed", async (t) => {
  const store = installFakeDb(t, baseSeed());
  store.set("usersv2/b/private/session", {
    fcmToken: "T2", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T2", folderAlerts: false, folderAlertsToken: "T",
  });
  const [digest] = planFolderDigests([f1], new Map([["f1", ["b"]]]));

  assert.equal(await sendToUser({...folderDigestPayload(digest, "2026-10-28"), modifier: "b@x.com"},
    {uid: "b", email: "b@x.com", folderAlertsToken: "T"}), true);
  assert.equal([...store.keys()].some((path) => path.startsWith("notifications/")), false);
});

test("sendDueFolderDigests releases the day claim when the push fails", async (t) => {
  mockDelivery(t, false);
  const store = installFakeDb(t, baseSeed());

  await assert.rejects(() => sendDueFolderDigests(NOW), /folderDigest: 1 digest delivery failure/);
  assert.equal(store.get("usersv2/b/private/folderDigest")?.day, undefined);
});

test("folder digests accept legacy source items and server-canonical wall ids", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());
  store.set("folders/f1/items/prism_w1", {ownerId: "a", id: "w1", provider: "Prism"});
  store.set("folders/f1/items/prism_w2", {
    ownerId: "a", id: "client-id", provider: "Prism", wallpaperDocumentId: "W2",
  });

  assert.equal(await sendDueFolderDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  assert.equal(send.mock.calls[0].arguments[0].message?.args.wallCount, 2);
});

test("folder digests validate the exact source key, not another item for the same wall", async (t) => {
  const send = mockDelivery(t);
  const store = installFakeDb(t, baseSeed());
  for (const id of ["w1", "w2"]) {
    store.delete(`folders/f1/items/prism_${id}`);
    store.set(`folders/f1/items/replacement_${id}`, {
      ownerId: "a", id, provider: "Prism", wallpaperDocumentId: id.toUpperCase(),
    });
  }

  assert.equal(await sendDueFolderDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

for (const uid of ["a", "b"]) {
  test(`folder digests stop at ${uid}'s deletion barrier before a day claim`, async (t) => {
    const send = mockDelivery(t);
    const store = installFakeDb(t, baseSeed());
    store.set(`creatorDeletionState/${uid}`, {closed: true});

    assert.equal(await sendDueFolderDigests(NOW), 0);
    assert.equal(send.mock.callCount(), 0);
    assert.equal(store.has("usersv2/b/private/folderDigest"), false);
  });

  test(`folder day claims do not recreate a marker after ${uid}'s deletion starts`, async (t) => {
    const store = installFakeDb(t, baseSeed());
    store.set(`creatorDeletionState/${uid}`, {closed: true});

    assert.equal(await claimDay("b", "2026-10-28", "folderDigest", ["a"]), null);
    assert.equal(store.has("usersv2/b/private/folderDigest"), false);
  });
}

const staleChanges: Array<[string, (store: Map<string, Doc>) => void]> = [
  ["private folder", (store) => store.set("folders/f1", {ownerId: "a", name: "Night", public: false})],
  ["unfollow", (store) => store.delete("usersv2/b/followedFolders/f1")],
  ["block", (store) => store.set("usersv2/a/blockedUsers/b", {})],
  ["source removal", (store) => {
    store.delete("folders/f1/items/prism_w1");
    store.delete("folders/f1/items/prism_w2");
  }],
  ["recipient deletion", (store) => store.set("creatorDeletionState/b", {closed: true})],
  ["owner deletion", (store) => store.set("creatorDeletionState/a", {closed: true})],
];
for (const [change, mutate] of staleChanges) {
  test(`folder digests revalidate ${change} after the day claim`, async (t) => {
    const send = mockDelivery(t);
    const store = installFakeDb(t, baseSeed());
    const transaction = db.runTransaction.bind(db);
    t.mock.method(db, "runTransaction", async (callback: Parameters<typeof db.runTransaction>[0]) => {
      const result = await transaction(callback);
      mutate(store);
      return result;
    });

    assert.equal(await sendDueFolderDigests(NOW), 0);
    assert.equal(send.mock.callCount(), 0);
    assert.equal(store.get("usersv2/b/private/folderDigest")?.day, undefined);
  });
}

for (const condition of ["loggedOut", "pushDisabled", "deleted", "barrier", "missing", "changedToken"]) {
  test(`real folder sendToUser writes no inbox and sends no FCM when ${condition}`, async (t) => {
    const store = installFakeDb(t, baseSeed());
    const send = t.mock.method(admin.messaging(), "send", async () => "id");
    if (condition === "deleted") store.set("usersv2/b", {deleted: true});
    if (condition === "barrier") store.set("creatorDeletionState/b", {closed: true});
    if (condition === "missing") store.delete("usersv2/b");
    if (condition === "changedToken") {
      store.set("usersv2/b/private/session", {
        fcmToken: "T2", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T2", folderAlerts: true, folderAlertsToken: "T2",
      });
    }
    const [digest] = planFolderDigests([f1], new Map([["f1", ["b"]]]));
    await sendToUser({...folderDigestPayload(digest, "2026-10-28"), modifier: "b@x.com"},
      {uid: "b", email: "b@x.com", folderAlertsToken: "T", loggedOut: condition === "loggedOut"},
      condition !== "pushDisabled");

    assert.equal([...store.keys()].some((path) => path.startsWith("notifications/")), false);
    assert.equal(send.mock.callCount(), 0);
  });
}

test("real folder delivery writes one inbox and sends a token-only single image FCM", async (t) => {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  t.mock.method(publicFolderDeps, "authDisabled", async () => false);
  const store = installFakeDb(t, baseSeed());
  const send = t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    void message;
    return "id";
  });

  assert.equal(await sendDueFolderDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  const message = send.mock.calls[0].arguments[0] as admin.messaging.TokenMessage;
  assert.equal(message.token, "T");
  assert.equal(message.data?.notification_kind, "folder_digest");
  assert.equal(message.data?.gallery, undefined);
  assert.equal(message.android?.notification?.imageUrl, "https://img.prismwalls.com/previews/w1.img");
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 1);
});

for (const change of ["token", "signout", "deletion"]) {
  test(`folder FCM delivery rechecks ${change} after the inbox write`, async (t) => {
    const store = installFakeDb(t, baseSeed());
    const send = t.mock.method(admin.messaging(), "send", async () => "id");
    const set = store.set.bind(store);
    t.mock.method(store, "set", (path: string, data: Doc) => {
      set(path, data);
      if (path.startsWith("notifications/")) {
        if (change === "token") set("usersv2/b/private/session", {fcmToken: "OTHER"});
        if (change === "signout") set("usersv2/b", {loggedIn: false});
        if (change === "deletion") set("creatorDeletionState/b", {closed: true});
      }
      return store;
    });
    const [digest] = planFolderDigests([f1], new Map([["f1", ["b"]]]));
    await sendToUser({...folderDigestPayload(digest, "2026-10-28"), modifier: "b@x.com"},
      {uid: "b", email: "b@x.com", folderAlertsToken: "T"});

    assert.equal(send.mock.callCount(), 0);
  });
}
