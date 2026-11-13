import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onCampaignNotificationRequested} from "../onCampaignNotificationRequested";
import {onContentReportCreated} from "../onContentReportCreated";
import {onUidFollowCreated} from "../onUidFollowCreated";
import {onWallApproved} from "../onWallApproved";
import {onWallSubmitted} from "../onWallSubmitted";
import {installFakeDb} from "./fakeDb";

function setup(t: TestContext, users: Record<string, Record<string, unknown>>, adminEmails = ["admin@example.com"]) {
  installFakeDb(t);
  const document = db.doc.bind(db);
  const inbox: unknown[] = [];
  const topics: string[] = [];
  const messages: Array<{topic?: string; token?: string; condition?: string}> = [];
  let userLookups = 0;
  const usersCollection = {
    where: (_field: string, _op: string, email: string) => {
      userLookups += 1;
      const query = {
        limit: () => query,
        get: async () => {
          const user = users[email] ?? users[email.toLowerCase()];
          return user ? {empty: false, docs: [{id: `uid-${email.split("@")[0]}`, data: () => user}]} : {empty: true, docs: []};
        },
      };
      return query;
    },
  };
  t.mock.method(db, "collection", (name: string) => {
    if (name === "usersv2") return usersCollection;
    if (name === "notifications") {
      return {add: async (data: unknown) => inbox.push(data), doc: () => ({set: async (data: unknown) => inbox.push(data)})};
    }
    if (name === "notificationRequests") return {doc: () => ({update: async () => undefined})};
    if (name === "config") return {doc: () => ({get: async () => ({exists: true, data: () => ({emails: adminEmails})})})};
    if (name === "walls") return {doc: () => ({get: async () => ({data: () => ({})})})};
    throw new Error(`Unexpected collection ${name}`);
  });
  t.mock.method(db, "doc", (path: string) => {
    if (path.startsWith("metrics/")) return document(path);
    if (path.endsWith("/private/session")) {
      const uid = path.split("/")[1];
      const email = uid.startsWith("uid-") ? `${uid.slice(4)}@example.com` : "";
      const user = users[email] ?? users[email.toLowerCase()];
      const token = user?.sessionToken;
      return {get: async () => ({data: () => token ? {
        fcmToken: token,
        fcmTokenBindingVersion: 1,
        fcmTokenBindingToken: token,
      } : {}})};
    }
    const email = path.split("/")[1]?.replace(/^uid-/, "");
    const user = users[`${email}@example.com`] ?? users[`${email}@example.com`.toLowerCase()];
    return {get: async () => ({data: () => path === "usersv2/artist-1" ? {loggedIn: false} :
      user ? {loggedIn: user.loggedIn} : undefined})};
  });
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; token?: string}) => {
    messages.push(message);
    if (message.topic) topics.push(message.topic);
    return "id";
  });
  return {inbox, topics, messages, userLookups: () => userLookups};
}

test("campaign email target skips signed-out users and keeps inbox", async (t) => {
  const {inbox, topics} = setup(t, {"out@example.com": {loggedIn: false}});
  await onCampaignNotificationRequested.run({
    params: {requestId: "r1"},
    data: {data: () => ({title: "t", body: "b", modifier: "out@example.com"})},
  } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
});

for (const [email, user, topic, state] of [
  ["in@example.com", {loggedIn: true, sessionToken: "signed-in-token"}, "signed-in-token", "signed-in"],
  ["old@example.com", {}, "'u_uid-old' in topics || 'u_uid-old_loc_v1' in topics", "legacy"],
] as const) {
  test(`campaign email target for ${state} user uses only an available bound token or the inbox nudge`, async (t) => {
    const {inbox, topics, messages} = setup(t, user ? {[email]: user} : {});
    await onCampaignNotificationRequested.run({
      params: {requestId: "r1"},
      data: {data: () => ({title: "t", body: "b", modifier: email})},
    } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
    assert.equal(inbox.length, 1);
    assert.deepEqual(topics, []);
    assert.deepEqual(messages.map((message) => message.topic ?? message.token ?? message.condition), [topic]);
  });
}

test("campaign email target for an unmatched address keeps the inbox and sends no push", async (t) => {
  const {inbox, topics} = setup(t, {});
  await onCampaignNotificationRequested.run({
    params: {requestId: "r1"},
    data: {data: () => ({title: "t", body: "b", modifier: "missing@example.com"})},
  } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
});

test("campaign email target pushes only to the bound private session token", async (t) => {
  const {topics, messages} = setup(t, {"in@example.com": {loggedIn: true, sessionToken: "session-token", fcmToken: "legacy-token"}});
  await onCampaignNotificationRequested.run({
    params: {requestId: "r1"},
    data: {data: () => ({title: "t", body: "b", modifier: "in@example.com"})},
  } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
  assert.deepEqual(
    messages.map((m) => m.topic ?? m.token).sort(),
    ["session-token"],
  );
  assert.deepEqual(topics, []);
});

for (const [modifier, expectedTopic] of [["all", "recommendations"], ["premium", "premium"], ["free", "free"]]) {
  test(`campaign ${modifier} broadcast sends without a user lookup`, async (t) => {
    const {inbox, topics, userLookups} = setup(t, {});
    await onCampaignNotificationRequested.run({
      params: {requestId: "r1"},
      data: {data: () => ({title: "t", body: "b", modifier})},
    } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
    assert.equal(inbox.length, 1);
    assert.deepEqual(topics.sort(), [expectedTopic, `${expectedTopic}_loc_v1`]);
    assert.equal(userLookups(), 0);
  });
}

test("a stale follow event cannot push to a user who has since signed out", async (t) => {
  const store = installFakeDb(t, {
    "profiles/artist/followers/follower": {followerUid: "follower", notify: true},
    "usersv2/artist": {email: "artist@example.com", username: "Artist", loggedIn: false},
    "profiles/follower": {username: "Follower"},
  });
  await onUidFollowCreated.run({
    params: {targetUid: "artist", followerUid: "follower"},
    data: {data: () => ({notify: true, targetLoggedIn: true})},
  } as unknown as Parameters<typeof onUidFollowCreated.run>[0]);
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 1);
});

test("signed-out admins keep report inbox entries without report pushes", async (t) => {
  const {inbox, topics} = setup(t, {"admin@example.com": {loggedIn: false}});
  await onContentReportCreated.run({
    params: {reportId: "r1"},
    data: {data: () => ({contentType: "profile", reason: "spam"})},
  } as unknown as Parameters<typeof onContentReportCreated.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
});

test("signed-out admins keep wall-submission inbox entries without admin pushes", async (t) => {
  const previous = {GH_REPO_WALLS: process.env.GH_REPO_WALLS, GH_USERNAME: process.env.GH_USERNAME};
  delete process.env.GH_REPO_WALLS;
  delete process.env.GH_USERNAME;
  t.after(() => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const {inbox, topics} = setup(t, {"admin@example.com": {loggedIn: false}, "artist@example.com": {premium: true}});
  const wall: Record<string, unknown> = {
    email: "artist@example.com", review: false,
    wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.jpg", wallpaper_path: "a.jpg",
    wallpaper_sha: "a".repeat(40), wallpaper_source_kind: "github",
    wallpaper_thumb: "https://raw.githubusercontent.com/o/r/main/t.jpg", thumb_path: "t.jpg",
    thumb_sha: "b".repeat(40), thumb_source_kind: "github",
  };
  const snapshot: {
    id: string;
    createTime: admin.firestore.Timestamp;
    ref: {id: string; path: string; get: () => Promise<unknown>; update: (data: Record<string, unknown>) => Promise<void>};
    data: () => Record<string, unknown>;
  } = {
    id: "w1",
    createTime: admin.firestore.Timestamp.fromMillis(1),
    ref: {
      id: "w1", path: "walls/w1", get: async () => snapshot,
      update: async (data) => {
        for (const [key, value] of Object.entries(data)) {
          if (value && typeof value === "object" && "__op" in value && (value as {__op: string}).__op === "delete") {
            delete wall[key];
          } else wall[key] = value;
        }
      },
    },
    data: () => wall,
  };
  await onWallSubmitted.run({
    params: {wallId: "w1"},
    data: snapshot,
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
  assert.equal((inbox[0] as {data?: {imageUrl?: string}}).data?.imageUrl, "");
  assert.equal(wall.wallpaper_url, "");
  assert.equal(wall.wallpaper_path, "");
  assert.equal(wall.wallpaper_sha, "");
  assert.equal(wall.wallpaper_thumb, "");
  assert.equal(wall.thumb_path, "");
  assert.equal(wall.thumb_sha, "");
  assert.equal(wall.wallpaper_source_kind, undefined);
  assert.equal(wall.thumb_source_kind, undefined);
});

test("signed-out artist and admins keep inbox entries while artist followers still get the posts push", async (t) => {
  const {inbox, topics} = setup(t, {
    "artist@example.com": {loggedIn: false},
    "admin@example.com": {loggedIn: false},
  });
  const wall: Record<string, unknown> = {id: "w1", review: true, email: "artist@example.com", by: "Artist", title: "Dunes"};
  const ref: {path: string; get: () => Promise<unknown>; update: (data: Record<string, unknown>) => Promise<void>} = {
    path: "walls/w1", get: async () => snapshot, update: async (data) => {
      Object.assign(wall, data);
    }};
  const snapshot = {ref, createTime: admin.firestore.Timestamp.fromMillis(1), data: () => wall};
  const transaction = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    transaction(async (tx) => callback({
      get: async (target: admin.firestore.DocumentReference) => target.path === ref.path ? snapshot : tx.get(target),
      update: (target: admin.firestore.DocumentReference, data: Record<string, unknown>) =>
        target.path === ref.path ? Object.assign(wall, data) : tx.update(target, data),
      set: tx.set.bind(tx),
    } as unknown as admin.firestore.Transaction)));
  await onWallApproved.run({
    params: {wallId: "w1"},
    data: {
      before: {data: () => ({review: false})},
      after: snapshot,
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  assert.equal(inbox.length, 2);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1", "posts_uid-artist", "posts_uid-artist_loc_v1"]);
});
