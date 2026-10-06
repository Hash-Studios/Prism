import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {
  emailToTopic,
  fcmMessage,
  isLoggedOut,
  pickFcmToken,
  sendNotification,
  sendToUser,
  sendToUserByEmail,
  userIdToTopic,
} from "../notificationHelper";

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

test("a personal payload is never sent to an email-prefix topic, even for a signed-in user", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: false, docs: [{data: () => ({loggedIn: true})}]}),
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : ({add: async () => undefined}));
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")}, pushOnly: true,
  });
  await sendNotification({
    title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
  });

  assert.equal(send.mock.callCount(), 0);
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

type Sent = {topic?: string; token?: string; android?: {notification?: {tag?: string}}};

function personalSetup(t: test.TestContext, sessionToken?: string) {
  const inbox: Array<{id?: string; data: Record<string, unknown>}> = [];
  t.mock.method(db, "collection", () => ({
    add: async (data: Record<string, unknown>) => inbox.push({data}),
    doc: (id: string) => ({set: async (data: Record<string, unknown>) => inbox.push({id, data})}),
  }));
  t.mock.method(db, "doc", () => ({get: async () => ({data: () => sessionToken ? {fcmToken: sessionToken} : {}})}));
  const sent: Sent[] = [];
  t.mock.method(admin.messaging(), "send", async (message: Sent) => {
    sent.push(message);
    return "id";
  });
  return {inbox, sent};
}

const personal = {title: "t", body: "b", data: {route: "r"}, modifier: "sam@example.com", channelId: "c"};

test("a personal push goes to the uid topic and the session token under one collapse key", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  const ok = await sendToUser(personal, {uid: "u1", email: "sam@example.com", legacyToken: "legacy-token"});
  assert.equal(ok, true);
  assert.equal(inbox.length, 1);
  assert.deepEqual(sent.map((m) => m.topic ?? m.token), ["u_u1", "session-token"]);
  assert.ok(sent[0].android?.notification?.tag?.startsWith("p_"));
  assert.equal(sent[0].android?.notification?.tag, sent[1].android?.notification?.tag);
});

test("a personal push falls back to the legacy token and never uses the email-prefix topic", async (t) => {
  const {sent} = personalSetup(t);
  await sendToUser(personal, {uid: "u1", email: "sam@example.com", legacyToken: "legacy-token"});
  assert.deepEqual(sent.map((m) => m.topic ?? m.token), ["u_u1", "legacy-token"]);
});

test("a personal push keeps the caller's collapse key", async (t) => {
  const {sent} = personalSetup(t);
  await sendToUser({...personal, collapseKey: "follow_1"}, {uid: "u1", email: "sam@example.com"});
  assert.equal(sent[0].android?.notification?.tag, "follow_1");
});

test("a signed-out or muted user keeps the inbox doc and gets no push", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  await sendToUser(personal, {uid: "u1", email: "sam@example.com", loggedOut: true});
  await sendToUser(personal, {uid: "u1", email: "sam@example.com"}, false);
  assert.equal(inbox.length, 2);
  assert.equal(sent.length, 0);
});

test("a recipient with no uid gets the inbox doc and no push", async (t) => {
  const {sent, inbox} = personalSetup(t);
  const ok = await sendToUser(personal, {email: "sam@example.com"});
  assert.equal(ok, true);
  assert.deepEqual(sent, []);
  assert.equal(inbox.length, 1);
});

test("a recipient lookup error gives no push and never falls back to the prefix topic", async (t) => {
  const {sent, inbox} = personalSetup(t);
  const failing = {where: () => failing, limit: () => failing, get: async () => {
    throw new Error("lookup failed");
  }};
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ?
    failing :
    ({add: async (data: Record<string, unknown>) => inbox.push({data})}));
  await sendToUserByEmail(personal, "sam@example.com");
  assert.deepEqual(sent, []);
  assert.equal(inbox.length, 1);
});

test("sendToUser reports a failed delivery", async (t) => {
  personalSetup(t);
  t.mock.method(admin.messaging(), "send", async () => {
    throw new Error("fcm down");
  });
  assert.equal(await sendToUser(personal, {uid: "u1", email: "sam@example.com", legacyToken: "x"}), false);
});

test("a fixed docId writes one inbox doc that a retry rewrites", async (t) => {
  const {inbox} = personalSetup(t);
  await sendToUser({...personal, docId: "streak_u1_2026-01-02"}, {uid: "u1", email: "sam@example.com"}, false);
  await sendToUser({...personal, docId: "streak_u1_2026-01-02"}, {uid: "u1", email: "sam@example.com"}, false);
  assert.deepEqual(inbox.map((d) => d.id), ["streak_u1_2026-01-02", "streak_u1_2026-01-02"]);
});

test("sendNotification returns false when the push fails and true when none was asked for", async (t) => {
  t.mock.method(db, "collection", () => ({add: async () => undefined}));
  t.mock.method(admin.messaging(), "send", async () => {
    throw new Error("fcm down");
  });
  assert.equal(await sendNotification({...personal, fcmTarget: {topic: "x"}}), false);
  assert.equal(await sendNotification(personal), true);
});

test("pushes carry no app icon badge", () => {
  const message = fcmMessage({...personal, fcmTarget: {topic: "x"}});
  assert.equal(message.apns?.payload?.aps.badge, undefined);
  assert.equal(message.apns?.payload?.aps.sound, "default");
});

test("session token wins over the legacy one", () => {
  assert.equal(pickFcmToken(" s ", "l"), "s");
  assert.equal(pickFcmToken("", "l"), "l");
});
