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
import * as wallOfTheDay from "../wallOfTheDay";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 28, 13, 0);
const HOUR = 3_600_000;
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const wall = (id: string, addedMs: number): FolderWall => ({
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
    "publicFolders/f1/items/prism_w1": {id: "w1", wallpaperDocumentId: "W1", projectedAt: ts(NOW - HOUR)},
    "publicFolders/f1/items/prism_w2": {id: "w2", wallpaperDocumentId: "W2", projectedAt: ts(NOW - HOUR)},
    "publicFolders/f1/followers/b": {uid: "b"},
    "usersv2/b": {email: "b@x.com", appOpenTimezoneOffsetMinutes: 0},
    "usersv2/b/private/session": {fcmToken: "T", folderAlerts: true, folderAlertsToken: "T"},
    "usersv2/b/followedFolders/f1": {folderId: "f1", ownerId: "a"},
  };
}

function mockDelivery(t: TestContext, delivered = true) {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  return t.mock.method(notificationHelper, "sendToUser", async () => delivered);
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

test("sendDueFolderDigests releases the day claim when the push fails", async (t) => {
  mockDelivery(t, false);
  const store = installFakeDb(t, baseSeed());

  await assert.rejects(() => sendDueFolderDigests(NOW), /folderDigest: 1 digest delivery failure/);
  assert.equal(store.get("usersv2/b/private/folderDigest")?.day, undefined);
});
