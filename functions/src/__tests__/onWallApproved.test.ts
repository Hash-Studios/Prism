import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {onWallApproved} from "../onWallApproved";

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
  assert.equal(inbox.length, 1);
});
