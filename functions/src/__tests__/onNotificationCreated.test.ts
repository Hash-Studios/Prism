import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {sendNotification} from "../notificationHelper";

import {onNotificationCreated, topicForModifier} from "../onNotificationCreated";

type Sent = {topic?: string; notification?: {title?: string}; data?: Record<string, string>};

async function run(doc: Record<string, unknown>, t: test.TestContext): Promise<Sent[]> {
  const users = {
    where: () => users,
    limit: () => users,
    get: async () => ({empty: false, docs: [{id: "u1", data: () => ({loggedIn: true})}]}),
  };
  const inbox: unknown[] = [];
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? users : ({add: async (d: unknown) => inbox.push(d)}));
  const sent: Sent[] = [];
  t.mock.method(admin.messaging(), "send", async (message: Sent) => {
    sent.push(message);
    return "id";
  });
  await onNotificationCreated.run({
    params: {notificationId: "n1"},
    data: {data: () => doc},
  } as unknown as Parameters<typeof onNotificationCreated.run>[0]);
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
  assert.equal(sent[0].topic, "artist");
  assert.equal(sent[0].notification?.title, "Wallpaper Rejected");
  assert.equal(sent[0].data?.route, "announcement");
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

test("sendNotification marks its inbox entries so the trigger skips them", async (t) => {
  const inbox: Array<{pushHandled?: boolean}> = [];
  t.mock.method(db, "collection", () => ({add: async (d: {pushHandled?: boolean}) => inbox.push(d)}));
  await sendNotification({title: "t", body: "b", data: {route: "announcement"}, modifier: "all", channelId: "c"});
  assert.equal(inbox[0]?.pushHandled, true);
});
