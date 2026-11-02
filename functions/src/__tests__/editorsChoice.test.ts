import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {editorsChoiceIo, setEditorsChoice} from "../editorsChoice";
import {type Doc, installFakeDb} from "./fakeDb";

const ADMIN = {uid: "adm", token: {admin: true, email: "a@x.com", email_verified: true}};
const OWNER = {uid: "u1", token: {email: "artist@x.com", email_verified: true}};
const WALL = "walls/w1";

const wallDoc = (overrides: Doc = {}): Doc => ({
  id: "w1",
  email: "artist@x.com",
  title: "Dusk",
  wallpaper_thumb: "https://example.com/t.jpg",
  review: true,
  originalProtected: true,
  collections: ["community"],
  ...overrides,
});

function setup(t: TestContext, seed: Record<string, Doc> = {}, ready = true) {
  t.mock.method(editorsChoiceIo, "premiumCollections", async () => ["space"]);
  t.mock.method(editorsChoiceIo, "readyWall", async () => ready);
  const sent: Array<{payload: Doc; recipient: Doc; pushEnabled: boolean}> = [];
  t.mock.method(editorsChoiceIo, "sendToUser", async (payload: Doc, recipient: Doc, pushEnabled: boolean) => {
    sent.push({payload, recipient, pushEnabled});
    return true;
  });
  const store = installFakeDb(t, {
    [WALL]: wallDoc(),
    "usersv2/u1": {email: "artist@x.com", loggedIn: true},
    ...seed,
  });
  return {store, sent};
}

const call = (data: Doc, auth: unknown = ADMIN) => setEditorsChoice.run({auth, data} as never);

async function refusedWith(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (err: {code?: string}) => err.code === code);
}

test("a caller who is not an admin cannot set or clear a pick", async (t) => {
  const {store, sent} = setup(t);
  await refusedWith(call({wallId: "w1", picked: true, requestId: "request_0001"}, OWNER), "permission-denied");
  await refusedWith(call({wallId: "w1", picked: false, requestId: "request_0002"}, OWNER), "permission-denied");
  await refusedWith(call({wallId: "w1", picked: true, requestId: "request_0003"}, null), "unauthenticated");
  assert.equal(store.get(WALL)?.editorsChoiceAt, undefined);
  assert.equal(store.has("editorsChoiceRequests/request_0001"), false);
  assert.equal(sent.length, 0);
});

test("an unverified email is not an admin, even when it is in admin_users", async (t) => {
  const {store} = setup(t, {"admin_users/a@x.com": {}});
  const unverified = {uid: "adm", token: {email: "a@x.com", email_verified: false}};
  await refusedWith(call({wallId: "w1", picked: true, requestId: "request_0001"}, unverified), "permission-denied");
  assert.equal(store.get(WALL)?.editorsChoiceAt, undefined);
});

test("bad input is refused", async (t) => {
  setup(t);
  await refusedWith(call({wallId: "w/1", picked: true, requestId: "request_0001"}), "invalid-argument");
  await refusedWith(call({wallId: "w1", picked: "yes", requestId: "request_0001"}), "invalid-argument");
  await refusedWith(call({wallId: "w1", picked: true, requestId: "short"}), "invalid-argument");
});

test("an admin picks an eligible wall: the wall gets the pick and the creator one push", async (t) => {
  const {store, sent} = setup(t);
  assert.deepEqual(await call({wallId: "w1", picked: true, requestId: "request_0001"}), {wallId: "w1", picked: true});
  assert.ok(store.get(WALL)?.editorsChoiceAt instanceof admin.firestore.Timestamp);
  assert.equal(store.get(WALL)?.editorsChoiceBy, "adm");
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.title, "Your wallpaper is an Editors' Choice");
  assert.equal(sent[0].payload.body, "Our editors picked Dusk. Everyone can find it on Home.");
  assert.deepEqual(sent[0].payload.data, {route: "wall", wall_id: "w1", notification_kind: "editors_choice"});
  assert.equal(sent[0].payload.docId, "editors_choice_w1");
  assert.deepEqual(sent[0].recipient, {uid: "u1", email: "artist@x.com", loggedOut: false});
  assert.equal(sent[0].pushEnabled, true);
});

for (const [name, overrides] of [
  ["pending", {review: false}],
  ["premium", {collections: ["space"]}],
  ["streak exclusive", {is_streak_exclusive: true}],
  ["reserved for a Drop", {dropReserved: true}],
  ["not protected", {originalProtected: false}],
] as const) {
  test(`a ${name} wall cannot be a pick`, async (t) => {
    const {store, sent} = setup(t, {[WALL]: wallDoc(overrides)});
    await refusedWith(call({wallId: "w1", picked: true, requestId: "request_0001"}), "failed-precondition");
    assert.equal(store.get(WALL)?.editorsChoiceAt, undefined);
    assert.equal(sent.length, 0);
  });
}

test("a wall whose original delivery is not ready cannot be a pick", async (t) => {
  const {store} = setup(t, {}, false);
  await refusedWith(call({wallId: "w1", picked: true, requestId: "request_0001"}), "failed-precondition");
  assert.equal(store.get(WALL)?.editorsChoiceAt, undefined);
});

test("a missing wall is not found", async (t) => {
  setup(t);
  await refusedWith(call({wallId: "w9", picked: false, requestId: "request_0001"}), "not-found");
});

test("a retried requestId replays without a second write or push", async (t) => {
  const {store, sent} = setup(t);
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  const first = store.get(WALL)?.editorsChoiceAt;
  assert.deepEqual(await call({wallId: "w1", picked: true, requestId: "request_0001"}), {wallId: "w1", picked: true});
  assert.equal(store.get(WALL)?.editorsChoiceAt, first);
  assert.equal(sent.length, 1);
});

test("a requestId reused for another change is refused", async (t) => {
  const {store} = setup(t);
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  await refusedWith(call({wallId: "w1", picked: false, requestId: "request_0001"}), "already-exists");
  assert.ok(store.get(WALL)?.editorsChoiceAt);
});

test("pick, clear and pick again pushes once and keeps the newest pick time", async (t) => {
  const {store, sent} = setup(t);
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  await call({wallId: "w1", picked: false, requestId: "request_0002"});
  assert.equal(store.get(WALL)?.editorsChoiceAt, undefined);
  assert.equal(store.get(WALL)?.editorsChoiceBy, undefined);
  await call({wallId: "w1", picked: true, requestId: "request_0003"});
  assert.ok(store.get(WALL)?.editorsChoiceAt instanceof admin.firestore.Timestamp);
  assert.equal(sent.length, 1);
});

test("picking an existing pick again keeps its pick time", async (t) => {
  const at = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
  const {store} = setup(t, {[WALL]: wallDoc({editorsChoiceAt: at, editorsChoiceBy: "other"})});
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  assert.equal(store.get(WALL)?.editorsChoiceAt, at);
  assert.equal(store.get(WALL)?.editorsChoiceBy, "adm");
});

test("a creator who turned post alerts off gets the inbox item without a push", async (t) => {
  const {sent} = setup(t, {"usersv2/u1/private/session": {postAlerts: false}});
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  assert.equal(sent.length, 1);
  assert.equal(sent[0].pushEnabled, false);
});

test("a Studio wall is picked without a creator push", async (t) => {
  const {store, sent} = setup(t, {
    [WALL]: wallDoc({origin: "studio", email: "studio@prismwalls.com", studioRunId: "run1", studioCandidateId: "c1"}),
    "studioRuns/run1/candidates/c1": {wallId: "w1"},
  });
  await call({wallId: "w1", picked: true, requestId: "request_0001"});
  assert.ok(store.get(WALL)?.editorsChoiceAt);
  assert.equal(sent.length, 0);
});

test("a failed push does not fail the pick", async (t) => {
  const {store} = setup(t);
  t.mock.method(editorsChoiceIo, "sendToUser", async () => {
    throw new Error("fcm down");
  });
  assert.deepEqual(await call({wallId: "w1", picked: true, requestId: "request_0001"}), {wallId: "w1", picked: true});
  assert.ok(store.get(WALL)?.editorsChoiceAt);
});
