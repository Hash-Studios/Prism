import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {onWallRemixWritten, sendRemixNotice, syncRemixCredit} from "../wallRemix";
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

test("a stale approval event after withdrawal cannot restore a credit or send another notice", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  await change(store, "walls/remix", remix({review: false}));

  await fire("remix", remix({review: false}), remix({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.deepEqual(inbox(store), ["notifications/remix_remix"]);
});

test("a stale approval event after deletion cannot restore a credit or send another notice", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  await change(store, "walls/remix", undefined);

  await fire("remix", remix({review: false}), remix({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
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

test("changing only remixCount does not alter ledgers or notices", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));
  const before = [...store.entries()];

  await fire("orig", original({remixCount: 1}), original({remixCount: 4}));

  assert.deepEqual([...store.entries()], before);
});

test("moving an approved remix to another original moves its credit", async (t) => {
  const {store} = setup(t, {"walls/orig2": original({email: "other@example.com"})});
  await change(store, "walls/remix", remix({review: true}));
  await change(store, "walls/remix", remix({review: true, remixOf: "orig2"}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.get("walls/orig2")?.remixCount, 1);
  assert.equal(store.get("wallRemixes/remix")?.originalId, "orig2");
});

test("withdrawing the original removes credits for its approved remixes", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));

  await change(store, "walls/orig", original({review: false}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
});

test("deleting the original clears credits and does not leave them for a recreated wall", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));

  await change(store, "walls/orig", undefined);
  assert.equal(store.has("wallRemixes/remix"), false);

  await change(store, "walls/orig", original());
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.equal(store.get("wallRemixes/remix")?.originalId, "orig");
});

test("recreating the original before its delete event restores its count", async (t) => {
  const {store} = setup(t);
  await change(store, "walls/remix", remix({review: true}));

  store.delete("walls/orig");
  store.set("walls/orig", original());
  await fire("orig", undefined, original());

  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.equal(store.get("wallRemixes/remix")?.originalId, "orig");
});

test("does not credit or notify a remix whose original points back to it", async (t) => {
  const {store} = setup(t, {"walls/orig": original({remixOf: "remix"})});

  await change(store, "walls/remix", remix({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.deepEqual(inbox(store), []);
});

test("does not credit a remix when a longer original chain points back to it", async (t) => {
  const {store} = setup(t, {
    "walls/orig": original({remixOf: "middle"}),
    "walls/middle": original({remixOf: "remix"}),
  });

  await change(store, "walls/remix", remix({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.deepEqual(inbox(store), []);
});

test("does not credit an original with a non-string prompt", async (t) => {
  const {store} = setup(t, {"walls/orig": original({aiPrompt: {text: "neon dunes"}})});

  await change(store, "walls/remix", remix({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.deepEqual(inbox(store), []);
});

test("approving an original reconciles existing remixes and sends their pending notice", async (t) => {
  const {store} = setup(t, {"walls/orig": original({review: false})});
  await change(store, "walls/remix", remix({review: true}));
  assert.equal(store.get("walls/orig")?.remixCount, 0);

  await change(store, "walls/orig", original({review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.deepEqual(inbox(store), ["notifications/remix_remix"]);
});

test("admin retargeting an original reconciles every descendant in a new cycle", async (t) => {
  const {store} = setup(t, {
    "walls/middle": remix({email: "middle@example.com", review: false, remixOf: "orig", title: "Middle", aiPrompt: "middle prompt"}),
    "walls/third": remix({email: "third@example.com", review: false, remixOf: "middle", title: "Third", aiPrompt: "third prompt"}),
  });
  await change(store, "walls/middle", remix({email: "middle@example.com", review: true, remixOf: "orig", title: "Middle", aiPrompt: "middle prompt"}));
  await change(store, "walls/third", remix({email: "third@example.com", review: true, remixOf: "middle", title: "Third", aiPrompt: "third prompt"}));
  assert.equal(store.get("walls/orig")?.remixCount, 1);
  assert.equal(store.get("walls/middle")?.remixCount, 1);

  await change(store, "walls/orig", original({remixOf: "third"}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.get("walls/middle")?.remixCount, 0);
  assert.equal(store.get("walls/third")?.remixCount ?? 0, 0);
  assert.equal(store.has("wallRemixes/middle"), false);
  assert.equal(store.has("wallRemixes/third"), false);
});

test("a whitespace-padded matching owner email is not credited", async (t) => {
  const {store} = setup(t, {"walls/remix": remix({email: " Artist@Example.com ", review: false})});

  await change(store, "walls/remix", remix({email: " Artist@Example.com ", review: true}));

  assert.equal(store.get("walls/orig")?.remixCount, 0);
  assert.equal(store.has("wallRemixes/remix"), false);
  assert.deepEqual(inbox(store), []);
});

test("does not send a pending notice after an admin retargets the remix", async (t) => {
  const {store} = setup(t, {"walls/orig2": original({email: "other@example.com"})});
  store.set("walls/remix", remix({review: true}));
  const notice = await syncRemixCredit("remix");
  assert.ok(notice);
  store.set("walls/remix", remix({review: true, remixOf: "orig2"}));

  await sendRemixNotice(notice);

  assert.deepEqual(inbox(store), []);
  assert.equal(store.get("wallRemixNotices/remix")?.sent, false);
});

test("a failed inbox write leaves the marker ready for retry", async (t) => {
  const {store} = setup(t);
  const set = store.set.bind(store);
  let failInboxWrite = true;
  Object.defineProperty(store, "set", {
    configurable: true,
    writable: true,
    value: (path: string, data: Doc) => {
      if (path.startsWith("notifications/") && failInboxWrite) {
        failInboxWrite = false;
        throw new Error("temporary inbox write failure");
      }
      return set(path, data);
    },
  });

  await assert.rejects(change(store, "walls/remix", remix({review: true})), /temporary inbox write failure/);
  assert.equal(store.get("wallRemixNotices/remix")?.sent, false);
  assert.deepEqual(inbox(store), []);

  await fire("remix", remix(), remix({review: true}));
  assert.equal(store.get("wallRemixNotices/remix")?.sent, true);
  assert.deepEqual(inbox(store), ["notifications/remix_remix"]);
});

test("walls without remixes get no remixCount write", async (t) => {
  const {store} = setup(t, {"walls/plain": {email: "a@example.com", review: false}});
  await change(store, "walls/plain", {email: "a@example.com", review: true});
  assert.equal("remixCount" in (store.get("walls/plain") ?? {}), false);

  const fresh = {email: "a@example.com", review: false, isAiGenerated: true, aiPrompt: "glass koi"};
  await change(store, "walls/fresh", fresh);
  await change(store, "walls/fresh", {...fresh, review: true});
  assert.equal("remixCount" in (store.get("walls/fresh") ?? {}), false);
});
