import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {onWallApproved, postsCollapseKey} from "../onWallApproved";

test("a signed-out artist keeps the approval in the inbox but gets no push; followers still do", async (t) => {
  const inbox: unknown[] = [];
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: false, docs: [{id: "artist1", data: () => ({loggedIn: false})}]}),
    doc: () => ({get: async () => ({exists: false})}),
    add: async (data: unknown) => inbox.push(data),
  };
  t.mock.method(db, "collection", () => query);
  const topics: string[] = [];
  const tags: Array<string | undefined> = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; android?: {notification?: {tag?: string}}}) => {
    topics.push(message.topic ?? "");
    tags.push(message.android?.notification?.tag);
    return "id";
  });
  await onWallApproved.run({
    params: {wallId: "w1"},
    data: {
      before: {data: () => ({review: false})},
      after: {data: () => ({review: true, email: "artist@example.com", by: "Artist", title: "Dunes"})},
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  assert.deepEqual(topics, ["artist_posts", "posts_artist1"]);
  assert.equal(tags[0], tags[1]);
  assert.equal(tags[0], postsCollapseKey("Artist@Example.com"));
  assert.match(tags[0] ?? "", /^posts_[0-9a-f]{16}$/);
  assert.equal(inbox.length, 1);
});

test("a repeated approval event sends no second set of pushes", async (t) => {
  const inbox: unknown[] = [];
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: true, docs: []}),
    doc: () => ({get: async () => ({exists: false}), set: async (data: unknown) => inbox.push(data)}),
    add: async (data: unknown) => inbox.push(data),
  };
  t.mock.method(db, "collection", () => query);
  let stamped = false;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<boolean>) =>
    callback({
      get: async () => ({data: () => stamped ? {approvedNotifiedAt: 1} : {}}),
      update: () => {
        stamped = true;
      },
    } as unknown as admin.firestore.Transaction));
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  const event = {
    params: {wallId: "w1"},
    data: {
      before: {data: () => ({review: false})},
      after: {
        ref: {},
        data: () => ({review: true, email: "artist@example.com", by: "Artist", title: "Dunes"}),
      },
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0];
  await onWallApproved.run(event);
  const firstInbox = inbox.length;
  const firstSends = send.mock.callCount();
  assert.ok(firstInbox >= 1);
  assert.ok(firstSends >= 1);
  await onWallApproved.run(event);
  assert.equal(inbox.length, firstInbox);
  assert.equal(send.mock.callCount(), firstSends);
});

test("followers of an artist with no profile doc still get the legacy topic push", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: true, docs: []}),
    doc: () => ({get: async () => ({exists: false}), set: async () => undefined}),
    add: async () => undefined,
  };
  t.mock.method(db, "collection", () => query);
  const topics: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    topics.push(message.topic ?? "");
    return "id";
  });
  await onWallApproved.run({
    params: {wallId: "w1"},
    data: {
      before: {data: () => ({review: false})},
      after: {data: () => ({review: true, email: "artist@example.com", by: "Artist", title: "Dunes"})},
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  assert.deepEqual(topics, ["artist_posts"]);
});
