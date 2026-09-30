import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {emailToTopic, fcmMessage, isLoggedOut, sendNotification, userIdToTopic} from "../notificationHelper";

test("notification topics match the names the app subscribes to", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "samone");
  assert.equal(emailToTopic("john+alerts.test@example.com"), "johnalerts.test");
  assert.equal(emailToTopic("Az-_.~%09@example.com"), "Az-_.~%09");
  assert.equal(userIdToTopic("abc/123"), "u_abc123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});

test("fcmMessage puts a condition target on the message and no topic or token", () => {
  const message = fcmMessage({
    title: "t", body: "b", data: {route: "r"}, modifier: "m", channelId: "c",
    fcmTarget: {condition: "'a' in topics || 'b' in topics"},
  });
  assert.equal("condition" in message && message.condition, "'a' in topics || 'b' in topics");
  assert.ok(!("topic" in message));
  assert.ok(!("token" in message));
});

test("only an explicit loggedIn false counts as signed out", () => {
  assert.equal(isLoggedOut({loggedIn: false}), true);
  assert.equal(isLoggedOut({loggedIn: true}), false);
  assert.equal(isLoggedOut({}), false);
  assert.equal(isLoggedOut(undefined), false);
});

test("signed-out personal pushOnly email fallbacks are skipped", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: false, docs: [{data: () => ({loggedIn: false})}]}),
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : ({add: async () => undefined}));
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")}, pushOnly: true,
  });

  assert.equal(send.mock.callCount(), 0);
});

test("signed-in personal pushOnly email fallbacks still send", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: false, docs: [{data: () => ({loggedIn: true})}]}),
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : ({add: async () => undefined}));
  const topics: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    topics.push(message.topic ?? "");
    return "id";
  });

  await sendNotification({
    title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")}, pushOnly: true,
  });

  assert.deepEqual(topics, ["sam"]);
});

test("personal topic lookup failure prevents FCM delivery", async (t) => {
  const inbox: Record<string, unknown>[] = [];
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? {
    where: () => ({
      limit: () => ({
        get: async () => {
          throw new Error("lookup failed");
        },
      }),
    }),
  } : ({add: async (data: Record<string, unknown>) => inbox.push(data)}));
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
  });

  assert.equal(send.mock.callCount(), 0);
  assert.equal(inbox.length, 1);
  assert.equal(inbox[0].modifier, "sam@example.com");
});
