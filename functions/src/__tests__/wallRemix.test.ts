import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {onWallRemixWritten} from "../wallRemix";
import {type Doc, installFakeDb} from "./fakeDb";

const original = (extra: Doc = {}): Doc => ({
  email: "artist@example.com", by: "Artist", title: "Dunes", review: true, isAiGenerated: true, aiPrompt: "neon dunes",
  remixCount: 0, wallpaper_thumb: "https://example.com/orig.jpg", ...extra,
});
const remix = (extra: Doc = {}): Doc => ({
  email: "remixer@example.com", by: "Remixer", title: "Dunes remix", review: false, isAiGenerated: true,
  remixOf: "orig", wallpaper_thumb: "https://example.com/remix.jpg", ...extra,
});

function setup(t: TestContext, extra: Record<string, Doc> = {}) {
  const store = installFakeDb(t, {
    "walls/orig": original(),
    "walls/remix": remix(),
    "usersv2/artistUid": {email: "artist@example.com", loggedIn: true},
    "usersv2/artistUid/private/session": {postAlerts: true},
    ...extra,
  });
  const sent: unknown[] = [];
  t.mock.method(admin.messaging(), "send", async (message: unknown) => {
    sent.push(message);
    return "id";
  });
  return {store, sent};
}

const fire = (wallId: string, before: Doc | undefined, after: Doc | undefined) => onWallRemixWritten.run({
  params: {wallId},
  data: {before: {data: () => before}, after: {data: () => after}},
} as unknown as Parameters<typeof onWallRemixWritten.run>[0]);

/** Writes `after` to the store, then fires the trigger with the stored state before the write, like Firestore. */
async function change(store: Map<string, Doc>, path: string, after: Doc | undefined) {
  const before = store.get(path);
  if (after === undefined) store.delete(path);
  else store.set(path, after);
  await fire(path.split("/")[1], before, after);
}

const inbox = (store: Map<string, Doc>) => [...store.keys()].filter((path) => path.startsWith("notifications/"));

test("approving a remix credits the original and writes one inbox notice without a push", async (t) => {
  const {store, sent} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.equal(store.get("wallRemixes/remix")?.originalId, "orig");
  assert.deepEqual(inbox(store), ["notifications/remix_remix"]);
  assert.equal(store.get("notifications/remix_remix")?.modifier, "artist@example.com");
  assert.equal(store.get("wallRemixNotices/remix")?.sent, true);
  assert.deepEqual(sent, []);
});

test("replaying the approval event keeps one credit and one inbox notice", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  await fire("remix", remix(), remix({review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.deepEqual(inbox(store), ["notifications/remix_remix"]);
});

test("withdrawing a remix gives its credit back, and re-approving does not notify again", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  store.delete("notifications/remix_remix");

  await change(store, "walls/remix", remix({review: false}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);

  await change(store, "walls/remix", remix({review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.equal(store.has("wallRemixes/remix"), true);
  assert.deepEqual(inbox(store), []);
});

test("deleting an approved remix gives its credit back", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  await change(store, "walls/remix", undefined);
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
});

test("a remix of your own wall is never credited or notified, whatever the email case", async (t) => {
  const {store} = setup(t, {"walls/remix": remix({email: "  ARTIST@example.com "})});
  await change(store, "walls/remix", remix({email: "  ARTIST@example.com ", review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.equal(store.has("wallRemixNotices/remix"), false);
  assert.deepEqual(inbox(store), []);
});

test("an owner with post alerts off gets no inbox doc, and the notice is still marked sent", async (t) => {
  const {store, sent} = setup(t, {"usersv2/artistUid/private/session": {postAlerts: false}});
  await change(store, "walls/remix", remix({review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.deepEqual(inbox(store), []);
  assert.equal(store.get("wallRemixNotices/remix")?.sent, true);
  assert.deepEqual(sent, []);
});

test("the remix count never goes below zero", async (t) => {
  const {store} = setup(t, {
    "wallRemixes/remix": {originalId: "orig", remixId: "remix"},
    "walls/remix": remix({review: true}),
  });
  await change(store, "walls/remix", remix({review: false}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
});

test("moving an approved remix to another original moves its credit", async (t) => {
  const {store} = setup(t, {"walls/orig2": original({email: "other@example.com"})});
  await change(store, "walls/remix", remix({review: true}));
  await change(store, "walls/remix", remix({review: true, remixOf: "orig2"}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.get("walls/orig2")?.remixCount, 1);
  assert.equal(store.get("wallRemixes/remix")?.originalId, "orig2");
});
