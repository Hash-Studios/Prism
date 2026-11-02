process.env.R2_PREVIEW_BASE_URL = "https://img.example.com";

import assert from "node:assert/strict";
import test, {beforeEach, type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  digestPayload,
  localDay,
  offsetsAtDigestTime,
  planDigests,
  sendDueDigests,
  type RecentWall,
} from "../followDigest";
import {db} from "../common";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.parse("2026-10-28T13:30:00Z");
const HOUR = 3600_000;

let store: Map<string, Doc>;
beforeEach((t) => {
  assert.ok("mock" in t);
  store = installFakeDb(t);
});

function rw(docId: string, creatorUid: string, name: string, approvedMs: number): RecentWall {
  return {
    docId,
    creatorUid,
    creatorName: name,
    approvedMs,
    wall: {id: docId.toUpperCase(), thumb: `https://img.example.com/previews/${docId}.img`, tags: ["Night"]},
  };
}

test("offsetsAtDigestTime finds the zone where it is 19:00 local", () => {
  assert.deepEqual(offsetsAtDigestTime(Date.parse("2026-10-28T13:30:00Z")), [330]);
  assert.deepEqual(offsetsAtDigestTime(Date.parse("2026-10-28T19:00:00Z")), [0]);
});

test("localDay uses the follower's offset", () => {
  assert.equal(localDay(Date.parse("2026-10-28T20:00:00Z"), 330), "2026-10-29");
});

const walls = [rw("a1", "A", "Asha", 3), rw("a2", "A", "Asha", 1), rw("b1", "B", "Ben", 2), rw("c1", "C", "Cy", 4)];
const followers = new Map<string, string[]>([
  ["A", ["u1", "u2", "u3", "A"]],
  ["B", ["u1", "u3"]],
  ["C", ["u3"]],
  ["D", ["u9"]],
]);

test("planDigests gives each follower one digest of other creators' walls", () => {
  const digests = planDigests(walls, followers);
  assert.deepEqual(digests.map((d) => d.uid).sort(), ["u1", "u2", "u3"]);

  const u2 = digests.find((d) => d.uid === "u2");
  assert.deepEqual(u2?.creators.map((c) => c.uid), ["A"]);
  assert.deepEqual(u2?.walls.map((w) => w.docId), ["a1", "a2"]);

  const u1 = digests.find((d) => d.uid === "u1");
  assert.deepEqual(u1?.creators.map((c) => c.uid), ["A", "B"]);
  assert.deepEqual(u1?.walls.map((w) => w.docId), ["a1", "b1", "a2"]);
  assert.equal(u1?.wallCount, 3);

  const u3 = digests.find((d) => d.uid === "u3");
  assert.deepEqual(u3?.creators.map((c) => c.uid), ["A", "C", "B"]);
  assert.deepEqual(u3?.walls.map((w) => w.docId), ["a1", "c1", "b1", "a2"]);
});

test("digestPayload titles and data for a two-creator digest keep one image", () => {
  const digest = planDigests(walls, followers).find((d) => d.uid === "u1");
  assert.ok(digest);
  const payload = digestPayload(digest, "2026-10-28");
  assert.equal(payload.title, "Asha and Ben posted 3 new walls");
  assert.equal(payload.body, "Night");
  assert.deepEqual(payload.data, {
    route: "wall",
    wall_id: "a1",
    wall_ids: "A1,B1,A2",
    notification_kind: "follow_digest",
    push_kind: "post",
  });
  assert.equal(payload.imageUrl, "https://img.example.com/previews/a1.img");
  assert.equal(payload.channelId, "posts");
  assert.equal(payload.collapseKey, "follow_digest_2026-10-28");
  assert.equal(payload.docId, "follow_digest_u1_2026-10-28");
  assert.equal("gallery" in payload, false);
});

test("digestPayload titles for one wall, two walls and a group", () => {
  const one = planDigests([rw("a1", "A", "Asha", 1)], new Map([["A", ["u1"]]]))[0];
  const onePayload = digestPayload(one, "2026-10-28");
  assert.equal(onePayload.title, "Asha posted a new wall");
  assert.equal("wall_ids" in onePayload.data, false);

  const two = planDigests([rw("a1", "A", "Asha", 2), rw("a2", "A", "Asha", 1)], new Map([["A", ["u1"]]]))[0];
  assert.equal(digestPayload(two, "2026-10-28").title, "Asha posted 2 new walls");

  const group = planDigests(
    [rw("a1", "A", "Asha", 4), rw("b1", "B", "Ben", 3), rw("c1", "C", "Cy", 2), rw("c2", "C", "Cy", 1)],
    new Map([["A", ["u1"]], ["B", ["u1"]], ["C", ["u1"]]]),
  )[0];
  assert.equal(digestPayload(group, "2026-10-28").title, "Cy and 2 others posted 4 new walls");
});

function seedDay(overrides: Record<string, Doc | null> = {}): void {
  const docs: Record<string, Doc> = {
    "walls/a1": {
      id: "A1",
      review: true,
      originalProtected: true,
      collections: ["abstract"],
      visionLabels: ["Night"],
      creatorUid: "A",
      by: "Asha",
      wallpaper_thumb: "https://img.example.com/previews/a1.img",
      approvedNotifiedAt: admin.firestore.Timestamp.fromMillis(NOW - HOUR),
    },
    "profiles/A/followers/u1": {},
    "usersv2/u1": {email: "u1@example.com", appOpenTimezoneOffsetMinutes: 330, loggedIn: true},
    "usersv2/u1/private/session": {
      fcmToken: "tok1",
      fcmTokenBindingVersion: 1,
      fcmTokenBindingToken: "tok1",
      notificationLocalizationVersion: 2,
      notificationLocalizationToken: "tok1",
      postAlerts: true,
      postAlertsToken: "tok1",
    },
  };
  for (const [path, doc] of Object.entries(overrides)) {
    if (doc === null) store.delete(path);
    else docs[path] = doc;
  }
  for (const [path, doc] of Object.entries(docs)) store.set(path, doc);
}

function mockEnv(t: TestContext) {
  // Remote Config without "abstract", so the seeded wall is free.
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "space"}},
  }}));
  const messages: Array<{token?: string}> = [];
  t.mock.method(admin.messaging(), "send", async (message: {token?: string}) => {
    messages.push(message);
    return "id";
  });
  return messages;
}

test("sendDueDigests sends one digest at 19:00 local and once per local day", async (t) => {
  const messages = mockEnv(t);
  seedDay();
  assert.equal(await sendDueDigests(NOW), 1);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].token, "tok1");
  assert.equal(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 1);
});

test("sendDueDigests does not replace a newer local-day claim with an older slot", async (t) => {
  const messages = mockEnv(t);
  seedDay({"usersv2/u1/private/followDigest": {day: "2026-10-29"}});

  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
  assert.equal(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-29");
});

test("sendDueDigests excludes approvals newer than its scheduled slot", async (t) => {
  const messages = mockEnv(t);
  seedDay({"walls/a1": {
    id: "A1",
    review: true,
    originalProtected: true,
    collections: ["abstract"],
    visionLabels: ["Night"],
    creatorUid: "A",
    by: "Asha",
    wallpaper_thumb: "https://img.example.com/previews/a1.img",
    approvedNotifiedAt: admin.firestore.Timestamp.fromMillis(NOW + 1),
  }});

  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
  assert.equal(store.has("usersv2/u1/private/followDigest"), false);
});

test("sendDueDigests skips a follower without a Posts opt-in or with a stale token", async (t) => {
  const messages = mockEnv(t);
  seedDay({"usersv2/u1/private/session": {
    fcmToken: "tok1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "tok1",
  }});
  assert.equal(await sendDueDigests(NOW), 0);

  seedDay({"usersv2/u1/private/session": {
    fcmToken: "tok1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "tok1", postAlerts: true, postAlertsToken: "old",
  }});
  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
});

test("sendDueDigests skips a same-token session rebound by an older build", async (t) => {
  const messages = mockEnv(t);
  seedDay({"usersv2/u1/private/session": {
    fcmToken: "tok1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "tok1",
    notificationLocalizationVersion: 1, notificationLocalizationToken: "tok1",
    postAlerts: true, postAlertsToken: "tok1",
  }});

  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
  assert.equal(store.has("usersv2/u1/private/followDigest"), false);
});

test("sendDueDigests skips a follower whose local time is not 19:00", async (t) => {
  const messages = mockEnv(t);
  seedDay({"usersv2/u1": {email: "u1@example.com", appOpenTimezoneOffsetMinutes: 0, loggedIn: true}});
  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
});

test("sendDueDigests skips a creator the follower has blocked", async (t) => {
  const messages = mockEnv(t);
  seedDay({"usersv2/u1/blockedUsers/A": {}});
  assert.equal(await sendDueDigests(NOW), 0);
  assert.equal(messages.length, 0);
});

test("sendDueDigests releases the day when the send fails so a later run can retry", async (t) => {
  mockEnv(t);
  let fail = true;
  t.mock.method(admin.messaging(), "send", async () => {
    if (fail) throw new Error("fcm down");
    return "id";
  });
  seedDay();
  await assert.rejects(sendDueDigests(NOW), /1 digest delivery failure/);
  assert.notEqual(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
  fail = false;
  assert.equal(await sendDueDigests(NOW), 1);
  assert.equal(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
});

test("sendDueDigests releases and retries when the session changes during token validation", async (t) => {
  const messages = mockEnv(t);
  seedDay();
  const originalDoc = db.doc.bind(db);
  let sessionReads = 0;
  t.mock.method(db, "doc", (path: string) => {
    const ref = originalDoc(path);
    if (path !== "usersv2/u1/private/session") return ref;
    return {
      ...ref,
      get: async () => {
        sessionReads += 1;
        if (sessionReads === 2) throw new Error("session lookup failed");
        return ref.get();
      },
    } as typeof ref;
  });

  await assert.rejects(sendDueDigests(NOW), /1 digest delivery failure/);
  assert.notEqual(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
  assert.equal(await sendDueDigests(NOW), 1);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].token, "tok1");
  assert.equal(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
});

test("sendDueDigests releases and retries when the account recheck fails", async (t) => {
  const messages = mockEnv(t);
  seedDay();
  const originalDoc = db.doc.bind(db);
  let accountReads = 0;
  t.mock.method(db, "doc", (path: string) => {
    const ref = originalDoc(path);
    if (path !== "usersv2/u1") return ref;
    return {
      ...ref,
      get: async () => {
        accountReads += 1;
        if (accountReads === 2) throw new Error("account lookup failed");
        return ref.get();
      },
    } as typeof ref;
  });

  await assert.rejects(sendDueDigests(NOW), /1 digest delivery failure/);
  assert.notEqual(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
  assert.equal(await sendDueDigests(NOW), 1);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].token, "tok1");
  assert.equal(store.get("usersv2/u1/private/followDigest")?.day, "2026-10-28");
});
