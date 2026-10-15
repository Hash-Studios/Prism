import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {sendNotification} from "../notificationHelper";

import {onNotificationCreated, topicForModifier} from "../onNotificationCreated";

type Sent = {
  topic?: string;
  token?: string;
  notification?: {title?: string};
  data?: Record<string, string>;
  android?: {notification?: {tag?: string}};
};

async function run(
  doc: Record<string, unknown>, t: test.TestContext,
  {deliveries = 1, loggedIn = true, retryClaim = false, token = ""} = {},
): Promise<Sent[]> {
  const users = {
    where: () => users,
    limit: () => users,
    get: async () => ({empty: false, docs: [{id: "u1", data: () => ({loggedIn})}]}),
  };
  const inbox: unknown[] = [];
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? users : ({add: async (d: unknown) => inbox.push(d)}));
  const sent: Sent[] = [];
  t.mock.method(admin.messaging(), "send", async (message: Sent) => {
    sent.push(message);
    return "id";
  });
  const ref = db.doc("notifications/n1");
  t.mock.method(db, "doc", () => ({get: async () => ({data: () => (token ? {fcmToken: token} : {})})}));
  let stored = {...doc};
  let transactions = Promise.resolve();
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<boolean>) => {
    const result = transactions.then(async () => {
      let update: Record<string, unknown> = {};
      const tx = {
        get: async (target: unknown) => {
          assert.equal(target, ref);
          return {exists: true, data: () => stored};
        },
        update: (target: unknown, data: Record<string, unknown>) => {
          assert.equal(target, ref);
          update = data;
        },
      } as unknown as admin.firestore.Transaction;
      if (retryClaim) {
        await callback(tx);
        // A competing invocation committed while this transaction was retried.
        stored = {...stored, pushHandled: true};
        update = {};
      }
      const claimed = await callback(tx);
      stored = {...stored, ...update};
      return claimed;
    });
    transactions = result.then(() => undefined);
    return result;
  });
  const event = {
    params: {notificationId: "n1"},
    data: {data: () => doc, ref},
  } as unknown as Parameters<typeof onNotificationCreated.run>[0];
  await Promise.all(Array.from({length: deliveries}, () => onNotificationCreated.run(event)));
  if (deliveries > 1) await onNotificationCreated.run(event);
  assert.equal(inbox.length, 0, "a push for an existing entry must not add another inbox entry");
  return sent;
}

test("inbox audiences map to the topics the app subscribes to", () => {
  assert.equal(topicForModifier("all"), "recommendations");
  assert.equal(topicForModifier("premium"), "premium");
  assert.equal(topicForModifier("free"), "free");
  assert.equal(topicForModifier("sam+one@example.com"), "samone");
  assert.equal(topicForModifier("3.1.0"), undefined);
});

test("an admin-written inbox entry also goes out as a push", async (t) => {
  const sent = await run({
    modifier: "artist@example.com",
    notification: {title: "Wallpaper Rejected", body: "Low quality"},
    data: {route: "announcement", imageUrl: "", arguments: []},
  }, t);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].topic, "u_u1");
  assert.equal(sent[0].notification?.title, "Wallpaper Rejected");
  assert.equal(sent[0].data?.route, "announcement");
});

test("an admin-written inbox entry reaches the user's uid topic and token once per device", async (t) => {
  const sent = await run({
    modifier: "artist@example.com",
    notification: {title: "Wallpaper Rejected", body: "Low quality"},
  }, t, {token: "tok-1"});
  assert.deepEqual(sent.map((m) => m.topic ?? "token"), ["u_u1", "token"]);
  assert.equal(sent[1].token, "tok-1");
  assert.equal(sent[0].android?.notification?.tag, sent[1].android?.notification?.tag);
  assert.ok(sent[0].android?.notification?.tag);
});

test("entries written by sendNotification are not pushed twice", async (t) => {
  const sent = await run({
    modifier: "all",
    notification: {title: "t", body: "b"},
    data: {route: "announcement"},
    pushHandled: true,
  }, t);
  assert.equal(sent.length, 0);
});

test("concurrent and redelivered create events attempt only one push", async (t) => {
  const sent = await run({
    modifier: "all",
    notification: {title: "t", body: "b"},
  }, t, {deliveries: 2});
  assert.equal(sent.length, 1);
});

test("a transaction retried after another invocation claims the entry does not push", async (t) => {
  const sent = await run({
    modifier: "all",
    notification: {title: "t", body: "b"},
  }, t, {retryClaim: true});
  assert.equal(sent.length, 0);
});

test("a direct inbox entry does not push to a logged-out artist", async (t) => {
  const sent = await run({
    modifier: "artist@example.com",
    notification: {title: "Wallpaper Rejected", body: "Low quality"},
  }, t, {loggedIn: false});
  assert.equal(sent.length, 0);
});

test("sendNotification marks its inbox entries so the trigger skips them", async (t) => {
  const inbox: Array<{pushHandled?: boolean}> = [];
  t.mock.method(db, "collection", () => ({add: async (d: {pushHandled?: boolean}) => inbox.push(d)}));
  await sendNotification({title: "t", body: "b", data: {route: "announcement"}, modifier: "all", channelId: "c"});
  assert.equal(inbox[0]?.pushHandled, true);
});
