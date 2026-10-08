import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onCampaignNotificationRequested} from "../onCampaignNotificationRequested";
import {onContentReportCreated} from "../onContentReportCreated";
import {onFollowCreated} from "../onFollowCreated";
import {onWallApproved} from "../onWallApproved";
import {onWallSubmitted} from "../onWallSubmitted";

function setup(t: TestContext, users: Record<string, Record<string, unknown>>, adminEmails = ["admin@example.com"]) {
  const inbox: unknown[] = [];
  const topics: string[] = [];
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
  t.mock.method(db, "doc", (path: string) => ({
    get: async () => ({data: () => path === "usersv2/artist-1" ? {loggedIn: false} : {}}),
  }));
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    topics.push(message.topic ?? "");
    return "id";
  });
  return {inbox, topics, userLookups: () => userLookups};
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
  ["in@example.com", {loggedIn: true}, "u_uid-in", "signed-in"],
  ["old@example.com", {}, "u_uid-old", "legacy"],
] as const) {
  test(`campaign email target still sends for ${state} user`, async (t) => {
    const {inbox, topics} = setup(t, user ? {[email]: user} : {});
    await onCampaignNotificationRequested.run({
      params: {requestId: "r1"},
      data: {data: () => ({title: "t", body: "b", modifier: email})},
    } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
    assert.equal(inbox.length, 1);
    assert.deepEqual(topics, [topic]);
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

test("campaign email target also pushes to the stored token, once per device", async (t) => {
  const {topics} = setup(t, {"in@example.com": {loggedIn: true, fcmToken: "legacy-token"}});
  const messages: Array<{topic?: string; token?: string}> = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; token?: string}) => {
    messages.push(message);
    return "id";
  });
  await onCampaignNotificationRequested.run({
    params: {requestId: "r1"},
    data: {data: () => ({title: "t", body: "b", modifier: "in@example.com"})},
  } as unknown as Parameters<typeof onCampaignNotificationRequested.run>[0]);
  assert.deepEqual(messages.map((m) => m.topic ?? m.token), ["u_uid-in", "legacy-token"]);
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
    assert.deepEqual(topics, [expectedTopic]);
    assert.equal(userLookups(), 0);
  });
}

test("a stale follow event cannot push to a user who has since signed out", async (t) => {
  const {inbox, topics} = setup(t, {"artist@example.com": {loggedIn: false}});
  const followed = {email: "artist@example.com", username: "Artist", usernameLower: "artist"};
  await onFollowCreated.run({
    params: {userId: "artist-1"},
    data: {
      before: {data: () => ({...followed, followers: []})},
      after: {
        data: () => ({...followed, loggedIn: true, followers: ["new@example.com"]}),
        ref: {update: async () => undefined},
      },
    },
  } as unknown as Parameters<typeof onFollowCreated.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
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
  const {inbox, topics} = setup(t, {"admin@example.com": {loggedIn: false}, "artist@example.com": {premium: true}});
  await onWallSubmitted.run({
    params: {wallId: "w1"},
    data: {data: () => ({email: "artist@example.com", review: false})},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.equal(inbox.length, 1);
  assert.deepEqual(topics, []);
});

test("signed-out artist and admins keep inbox entries while artist followers still get the posts push", async (t) => {
  const {inbox, topics} = setup(t, {
    "artist@example.com": {loggedIn: false},
    "admin@example.com": {loggedIn: false},
  });
  await onWallApproved.run({
    params: {wallId: "w1"},
    data: {
      before: {data: () => ({review: false})},
      after: {data: () => ({review: true, email: "artist@example.com", by: "Artist", title: "Dunes"})},
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  assert.equal(inbox.length, 2);
  assert.deepEqual(topics, ["artist_posts", "posts_uid-artist"]);
});
