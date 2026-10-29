import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  createWallRequest,
  fillRequestFromWall,
  listWallRequests,
  notifyRequestFilled,
  parseCreateInput,
  publicRequestText,
  removeWallRequestsForAccount,
  requestTokens,
  setWallRequestVote,
  similarity,
} from "../wallRequests";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.parse("2026-10-29T12:00:00Z");
const TODAY = "2026-10-29";
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

/** A request doc as the module writes it: tokens and key from the same text. */
function request(text: string, requester: string, extra: Doc = {}): Doc {
  const tokens = requestTokens(text);
  return {
    text,
    key: tokens.join(" "),
    tokens,
    tags: [],
    requesterUid: requester,
    requesterName: requester,
    requesterPhoto: "",
    status: "open",
    hidden: false,
    voteCount: 0,
    createdAt: at(NOW - DAY),
    ...extra,
  };
}

const votesOf = (store: Map<string, Doc>, requestId: string) =>
  [...store.keys()].filter((key) => key.startsWith(`wallRequests/${requestId}/votes/`));

function captureMessages(t: TestContext) {
  const messages: Array<{token?: string; data?: Record<string, string>}> = [];
  t.mock.method(admin.messaging(), "send", async (message: {token?: string; data?: Record<string, string>}) => {
    messages.push(message);
    return "id";
  });
  return messages;
}

test("publicRequestText trims and collapses spaces", () => {
  assert.equal(publicRequestText("  dark   minimal  "), "dark minimal");
  assert.equal(publicRequestText("Valorant Jett"), "Valorant Jett");
});

test("publicRequestText rejects length, hidden characters, blocked words and filler-only text", () => {
  assert.equal(publicRequestText("ab"), null);
  assert.equal(publicRequestText("a".repeat(81)), null);
  assert.equal(publicRequestText("dark‮ minimal"), null);
  assert.equal(publicRequestText("p0rn walls"), null);
  assert.equal(publicRequestText("N1GGA"), null);
  assert.equal(publicRequestText("wallpaper please"), null);
});

test("requestTokens gives the same sorted meaningful words for reordered text", () => {
  assert.deepEqual(requestTokens("Minimal dark mountains wallpaper"), ["dark", "minimal", "mountains"]);
  assert.deepEqual(requestTokens("dark minimal mountains"), ["dark", "minimal", "mountains"]);
});

test("similarity is the Jaccard overlap of two token lists", () => {
  assert.equal(similarity(["a", "b", "c"], ["a", "b", "c", "d"]), 0.75);
});

test("parseCreateInput rejects more than 3 tags and unknown tags", () => {
  assert.throws(
    () => parseCreateInput({text: "dark minimal", tags: ["Dark", "Minimal", "Nature", "Space"]}),
    {code: "invalid-argument"},
  );
  assert.throws(() => parseCreateInput({text: "dark minimal", tags: ["Pastel"]}), {code: "invalid-argument"});
});

test("parseCreateInput removes duplicate tags and defaults force to false", () => {
  assert.deepEqual(parseCreateInput({text: "dark minimal", tags: ["Dark", "Dark"]}), {
    text: "dark minimal",
    tags: ["Dark"],
    force: false,
  });
});

const requester = {
  "usersv2/u1": {name: "U One", email: "u1@x.com"},
  "profiles/u1": {name: "Una", profilePhoto: "p.jpg"},
};

test("createWallRequest writes the request with the requester's profile", async (t) => {
  const store = installFakeDb(t, requester);
  const result = await createWallRequest("u1", {text: "dark minimal mountains", tags: ["Dark"]}, NOW);
  const ids = [...store.keys()].filter((key) => key.startsWith("wallRequests/"));
  assert.equal(ids.length, 1);
  assert.deepEqual(
    {...store.get(ids[0]), createdAt: undefined},
    {
      text: "dark minimal mountains",
      key: "dark minimal mountains",
      tokens: ["dark", "minimal", "mountains"],
      tags: ["Dark"],
      requesterUid: "u1",
      requesterName: "Una",
      requesterPhoto: "p.jpg",
      status: "open",
      hidden: false,
      voteCount: 0,
      createdAt: undefined,
    },
  );
  assert.equal(result.status, "created");
  assert.equal(result.request.mine, true);
  assert.equal(result.request.text, "dark minimal mountains");
});

test("createWallRequest allows 3 requests a UTC day and resets on the next day", async (t) => {
  installFakeDb(t, requester);
  for (const text of ["neon city lights", "desert dunes sunset", "forest mist morning"]) {
    assert.equal((await createWallRequest("u1", {text}, NOW)).status, "created");
  }
  await assert.rejects(createWallRequest("u1", {text: "dark minimal mountains"}, NOW), {code: "resource-exhausted"});
  assert.equal((await createWallRequest("u1", {text: "dark minimal mountains"}, NOW + DAY)).status, "created");
});

test("createWallRequest returns the exact duplicate and writes nothing, even with force", async (t) => {
  const store = installFakeDb(t, {...requester, "wallRequests/r0": request("dark minimal mountains", "u2")});
  const plain = await createWallRequest("u1", {text: "Minimal dark mountains wallpaper"}, NOW);
  assert.equal(plain.status, "duplicate");
  assert.equal(plain.status === "duplicate" && plain.exact, true);
  assert.equal(plain.request.id, "r0");
  const forced = await createWallRequest("u1", {text: "Minimal dark mountains wallpaper", force: true}, NOW);
  assert.equal(forced.status, "duplicate");
  assert.equal(forced.request.id, "r0");
  assert.equal(forced.status === "duplicate" && forced.exact, true);
  assert.deepEqual([...store.keys()].filter((key) => key.startsWith("wallRequests/")), ["wallRequests/r0"]);
});

test("createWallRequest returns a similar request as a non-exact duplicate unless forced", async (t) => {
  installFakeDb(t, {...requester, "wallRequests/r0": request("dark minimal mountains", "u2")});
  const plain = await createWallRequest("u1", {text: "dark minimal snowy mountains"}, NOW);
  assert.equal(plain.status, "duplicate");
  assert.equal(plain.status === "duplicate" && plain.exact, false);
  assert.equal(plain.request.id, "r0");
});

test("createWallRequest creates a similar request when forced", async (t) => {
  const store = installFakeDb(t, {...requester, "wallRequests/r0": request("dark minimal mountains", "u2")});
  const forced = await createWallRequest("u1", {text: "dark minimal snowy mountains", force: true}, NOW);
  assert.equal(forced.status, "created");
  assert.equal(store.has("wallRequests/r0"), true);
  assert.equal([...store.keys()].filter((key) => key.startsWith("wallRequests/")).length, 2);
});

test("createWallRequest returns the caller's own close request as a duplicate even with force", async (t) => {
  const store = installFakeDb(t, {...requester, "wallRequests/r0": request("dark minimal mountains", "u1")});
  const result = await createWallRequest("u1", {text: "dark minimal snowy mountains", force: true}, NOW);
  assert.equal(result.status, "duplicate");
  assert.equal(result.status === "duplicate" && result.exact, false);
  assert.equal(result.request.id, "r0");
  assert.equal(result.request.mine, true);
  assert.equal([...store.keys()].filter((key) => key.startsWith("wallRequests/")).length, 1);
});

test("createWallRequest ignores a hidden matching request", async (t) => {
  installFakeDb(t, {...requester, "wallRequests/r0": request("dark minimal mountains", "u2", {hidden: true})});
  assert.equal((await createWallRequest("u1", {text: "dark minimal mountains"}, NOW)).status, "created");
});

test("createWallRequest ignores a matching request whose requester blocked the caller", async (t) => {
  installFakeDb(t, {
    ...requester,
    "wallRequests/r0": request("dark minimal mountains", "u2"),
    "usersv2/u2/blockedUsers/u1": {},
  });
  assert.equal((await createWallRequest("u1", {text: "dark minimal mountains"}, NOW)).status, "created");
});

test("createWallRequest refuses a deleted account and an account in deletion", async (t) => {
  installFakeDb(t, {...requester, "usersv2/u1": {name: "U One", email: "u1@x.com", deleted: true}});
  await assert.rejects(createWallRequest("u1", {text: "dark minimal mountains"}, NOW), {code: "failed-precondition"});

  installFakeDb(t, {...requester, "creatorDeletionState/u1": {closed: true}});
  await assert.rejects(createWallRequest("u1", {text: "dark minimal mountains"}, NOW), {code: "failed-precondition"});
});

test("setWallRequestVote sets, repeats and removes one vote", async (t) => {
  const store = installFakeDb(t, {"wallRequests/r1": request("dark minimal mountains", "u2")});
  assert.deepEqual(await setWallRequestVote("u1", "r1", true, NOW), {voted: true, voteCount: 1});
  assert.equal(store.has("wallRequests/r1/votes/u1"), true);

  assert.deepEqual(await setWallRequestVote("u1", "r1", true, NOW), {voted: true, voteCount: 1});
  assert.equal(store.get("wallRequests/r1")?.voteCount, 1);

  assert.deepEqual(await setWallRequestVote("u1", "r1", false, NOW), {voted: false, voteCount: 0});
  assert.equal(store.has("wallRequests/r1/votes/u1"), false);

  assert.deepEqual(await setWallRequestVote("u1", "r1", false, NOW), {voted: false, voteCount: 0});
  assert.equal(store.get("wallRequests/r1")?.voteCount, 0);
});

test("setWallRequestVote refuses own, hidden, filled and blocked requests", async (t) => {
  installFakeDb(t, {"wallRequests/r1": request("dark minimal mountains", "u2")});
  await assert.rejects(setWallRequestVote("u2", "r1", true, NOW), {code: "failed-precondition"});

  installFakeDb(t, {"wallRequests/r1": request("dark minimal mountains", "u2", {hidden: true})});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});

  installFakeDb(t, {"wallRequests/r1": request("dark minimal mountains", "u2", {status: "filled"})});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "failed-precondition"});

  installFakeDb(t, {
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    "usersv2/u1/blockedUsers/u2": {},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});

  installFakeDb(t, {
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    "usersv2/u2/blockedUsers/u1": {},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});
});

test("setWallRequestVote keeps the count equal to the vote docs under concurrent votes", async (t) => {
  const store = installFakeDb(t, {"wallRequests/r1": request("dark minimal mountains", "u2")});
  const voters = Array.from({length: 20}, (_, i) => `v${i}`);
  await Promise.all(voters.map((uid) => setWallRequestVote(uid, "r1", true, NOW)));
  assert.equal(store.get("wallRequests/r1")?.voteCount, 20);
  assert.equal(votesOf(store, "r1").length, 20);

  await Promise.all([
    ...voters.slice(0, 10).map((uid) => setWallRequestVote(uid, "r1", false, NOW)),
    ...Array.from({length: 5}, (_, i) => setWallRequestVote(`n${i}`, "r1", true, NOW)),
  ]);
  assert.equal(store.get("wallRequests/r1")?.voteCount, 15);
  assert.equal(votesOf(store, "r1").length, 15);
});

test("setWallRequestVote allows 200 vote changes a UTC day and refuses the 201st", async (t) => {
  const store = installFakeDb(t, {
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    [`wallRequestVoteRateDaily/u1_${TODAY}`]: {day: TODAY, count: 200},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "resource-exhausted"});
  assert.equal(store.has("wallRequests/r1/votes/u1"), false);
  assert.equal(store.get("wallRequests/r1")?.voteCount, 0);
});

const listSeed: Record<string, Doc> = {
  "wallRequests/a": request("alpha", "u2", {voteCount: 5, createdAt: at(NOW - 2 * DAY)}),
  "wallRequests/b": request("bravo", "u3", {voteCount: 9, createdAt: at(NOW - DAY)}),
  "wallRequests/c": request("charlie", "u4", {voteCount: 1, createdAt: at(NOW - 3 * DAY)}),
  "wallRequests/old": request("oldie", "u5", {voteCount: 50, createdAt: at(NOW - 31 * DAY)}),
  "wallRequests/h1": request("hidden", "u7", {voteCount: 100, hidden: true}),
  "wallRequests/f1": request("filled one", "u6", {
    status: "filled", filledAt: at(NOW - 3600_000), filledBy: "creator",
  }),
  "wallRequests/f2": request("filled two", "u6", {
    status: "filled", filledAt: at(NOW - 2 * 3600_000), filledBy: "studio",
  }),
  "wallRequests/a/votes/u1": {uid: "u1", createdAt: at(NOW)},
};

const ids = (rows: Array<{id: string}>) => rows.map((row) => row.id);

test("listWallRequests top tab keeps open visible requests of 30 days by votes", async (t) => {
  installFakeDb(t, listSeed);
  assert.deepEqual(ids(await listWallRequests("u1", "top", false, NOW)), ["b", "a", "c"]);
});

test("listWallRequests new tab orders open requests by creation, newest first", async (t) => {
  installFakeDb(t, listSeed);
  assert.deepEqual(ids(await listWallRequests("u1", "new", false, NOW)), ["b", "a", "c", "old"]);
});

test("listWallRequests filled tab returns filled requests, newest fill first", async (t) => {
  installFakeDb(t, listSeed);
  assert.deepEqual(ids(await listWallRequests("u1", "filled", false, NOW)), ["f1", "f2"]);
});

test("listWallRequests leaves hidden requests out for users and includes them for admins", async (t) => {
  installFakeDb(t, listSeed);
  assert.deepEqual(ids(await listWallRequests("u1", "top", false, NOW)).includes("h1"), false);
  const admin = await listWallRequests("u1", "top", true, NOW);
  assert.deepEqual(ids(admin), ["h1", "b", "a", "c"]);
  assert.equal(admin[0].hidden, true);
});

test("listWallRequests leaves out requests between the viewer and a blocked user, both ways", async (t) => {
  installFakeDb(t, {
    ...listSeed,
    "wallRequests/bl": request("blocked by viewer", "u8", {voteCount: 20}),
    "wallRequests/bw": request("blocked viewer", "u9", {voteCount: 30}),
    "usersv2/u1/blockedUsers/u8": {},
    "usersv2/u9/blockedUsers/u1": {},
  });
  assert.deepEqual(ids(await listWallRequests("u1", "top", false, NOW)), ["b", "a", "c"]);
  assert.deepEqual(ids(await listWallRequests("u2", "top", false, NOW)), ["bw", "bl", "b", "a", "c"]);
});

test("listWallRequests sets voted only where the viewer has a vote doc", async (t) => {
  installFakeDb(t, listSeed);
  const rows = await listWallRequests("u1", "top", false, NOW);
  assert.deepEqual(rows.map((row) => [row.id, row.voted]), [["b", false], ["a", true], ["c", false]]);

  const author = await listWallRequests("u2", "top", false, NOW);
  assert.equal(author.find((row) => row.id === "a")?.mine, true);
  assert.equal(author.find((row) => row.id === "a")?.voted, false);
});

test("listWallRequests for a guest has no voted or mine flags", async (t) => {
  installFakeDb(t, listSeed);
  const rows = await listWallRequests("", "top", false, NOW);
  assert.deepEqual(rows.map((row) => [row.id, row.voted, row.mine]), [
    ["b", false, false],
    ["a", false, false],
    ["c", false, false],
  ]);
});

const fillSeed = (extra: Doc = {}) => ({
  "wallRequests/r1": request("dark minimal mountains", "u2", {requesterName: "Una", ...extra}),
});

test("fillRequestFromWall fills an open request from the creator's wall", async (t) => {
  const store = installFakeDb(t, fillSeed());
  const wall = {requestId: "r1", creatorUid: "c1", by: "Cee", wallpaper_thumb: "https://img.prismwalls.com/previews/a.jpg"};
  assert.equal(await fillRequestFromWall("w1", wall, false), "r1");
  const filled = store.get("wallRequests/r1");
  assert.equal(filled?.status, "filled");
  assert.equal(filled?.filledWallId, "w1");
  assert.equal(filled?.filledBy, "creator");
  assert.equal(filled?.fillerUid, "c1");
  assert.equal(filled?.fillerName, "Cee");
});

test("fillRequestFromWall updates the thumb for the same wall and ignores another wall", async (t) => {
  const store = installFakeDb(t, fillSeed());
  const wall = {requestId: "r1", creatorUid: "c1", by: "Cee", wallpaper_thumb: "https://img.prismwalls.com/previews/a.jpg"};
  await fillRequestFromWall("w1", wall, false);

  const newThumb = "https://img.prismwalls.com/previews/b.jpg";
  assert.equal(await fillRequestFromWall("w1", {...wall, wallpaper_thumb: newThumb}, false), "r1");
  assert.equal(store.get("wallRequests/r1")?.filledWallThumb, newThumb);

  assert.equal(await fillRequestFromWall("w2", {...wall, wallpaper_thumb: "https://img.prismwalls.com/previews/c.jpg"}, false), null);
  assert.equal(store.get("wallRequests/r1")?.filledWallId, "w1");
});

test("fillRequestFromWall does not fill a hidden request", async (t) => {
  const store = installFakeDb(t, fillSeed({hidden: true}));
  assert.equal(await fillRequestFromWall("w1", {requestId: "r1", creatorUid: "c1", by: "Cee"}, false), null);
  assert.equal(store.get("wallRequests/r1")?.status, "open");
});

test("fillRequestFromWall does not fill when the requester blocked the creator", async (t) => {
  const store = installFakeDb(t, {...fillSeed(), "usersv2/u2/blockedUsers/c1": {}});
  assert.equal(await fillRequestFromWall("w1", {requestId: "r1", creatorUid: "c1", by: "Cee"}, false), null);
  assert.equal(store.get("wallRequests/r1")?.status, "open");
});

test("fillRequestFromWall for a studio wall names Prism Studio as the filler", async (t) => {
  const store = installFakeDb(t, fillSeed());
  assert.equal(await fillRequestFromWall("w1", {requestId: "r1", by: "Cee"}, true), "r1");
  assert.equal(store.get("wallRequests/r1")?.filledBy, "studio");
  assert.equal(store.get("wallRequests/r1")?.fillerName, "Prism Studio");
});

test("fillRequestFromWall returns null for a wall without a request id", async (t) => {
  installFakeDb(t, fillSeed());
  assert.equal(await fillRequestFromWall("w1", {creatorUid: "c1", by: "Cee"}, false), null);
});

test("notifyRequestFilled pushes the requester and a voter once, with the wall data", async (t) => {
  const store = installFakeDb(t, notifySeed());
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "space"}},
  }}));
  const messages = captureMessages(t);
  assert.deepEqual(await notifyRequestFilled("r1", NOW), {sent: 2, inbox: 2, skipped: 1});
  assert.deepEqual(messages.map((m) => m.token).sort(), ["tok-u1", "tok-u2"]);
  for (const message of messages) {
    assert.equal(message.data?.notification_kind, "wall_request_filled");
    assert.equal(message.data?.request_id, "r1");
    assert.equal(message.data?.wall_id, "w1");
  }
  assert.equal(store.has("notifications/wall_request_r1_u1"), true);
});

test("notifyRequestFilled sends nothing on a repeat call", async (t) => {
  installFakeDb(t, notifySeed());
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  assert.deepEqual(await notifyRequestFilled("r1", NOW), {sent: 0, inbox: 0, skipped: 0});
  assert.equal(messages.length, 2);
});

test("notifyRequestFilled keeps the inbox entry without a push when Posts is off or the day is used", async (t) => {
  const store = installFakeDb(t, notifySeed());
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.some((m) => m.token === "tok-u3" || m.token === "tok-u4"), false);
  assert.equal(store.has("notifications/wall_request_r1_u3"), true);
  assert.equal(store.has("notifications/wall_request_r1_u4"), true);
});

test("notifyRequestFilled gives nothing to a user who blocks the requester", async (t) => {
  const store = installFakeDb(t, notifySeed());
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(store.has("notifications/wall_request_r1_u5"), false);
  assert.equal(messages.some((m) => m.token === "tok-u5"), false);
});

test("notifyRequestFilled sends nothing for a hidden filled request", async (t) => {
  installFakeDb(t, notifySeed({hidden: true}));
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  assert.deepEqual(await notifyRequestFilled("r1", NOW), {sent: 0, inbox: 0, skipped: 0});
  assert.equal(messages.length, 0);
});

test("removeWallRequestsForAccount deletes own requests and takes own votes off others", async (t) => {
  const store = installFakeDb(t, {
    "wallRequests/own1": request("own request", "u1"),
    "wallRequests/own1/votes/u2": {uid: "u2"},
    "wallRequests/own1/votes/u3": {uid: "u3"},
    "wallRequests/r2": request("other request", "u2", {voteCount: 3}),
    "wallRequests/r2/votes/u1": {uid: "u1"},
    "wallRequests/r2/votes/u3": {uid: "u3"},
    "wallRequests/r2/votes/u4": {uid: "u4"},
    "polls/p1/votes/x": {uid: "u1"},
  });
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    for (const key of [...store.keys()]) {
      if (key === ref.path || key.startsWith(ref.path + "/")) store.delete(key);
    }
  });
  await removeWallRequestsForAccount("u1");
  assert.deepEqual([...store.keys()].filter((key) => key.startsWith("wallRequests/own1")), []);
  assert.equal(store.has("wallRequests/r2/votes/u1"), false);
  assert.equal(store.get("wallRequests/r2")?.voteCount, 2);
  assert.equal(store.has("wallRequests/r2/votes/u3"), true);
  assert.deepEqual(store.get("polls/p1/votes/x"), {uid: "u1"});
});

/** Seed for the filled push: u1 requested, u2 to u5 voted. */
function notifySeed(extra: Doc = {}): Record<string, Doc> {
  const users: Record<string, Doc> = {};
  for (const uid of ["u1", "u2", "u3", "u4", "u5"]) {
    users[`usersv2/${uid}`] = {name: uid, email: `${uid}@x.com`, loggedIn: true};
    users[`usersv2/${uid}/private/session`] = {
      fcmToken: `tok-${uid}`,
      fcmTokenBindingVersion: 1,
      fcmTokenBindingToken: `tok-${uid}`,
    };
  }
  return {
    "wallRequests/r1": request("dark minimal mountains", "u1", {
      status: "filled",
      filledWallId: "w1",
      filledWallThumb: "https://img.prismwalls.com/previews/a.jpg",
      fillerUid: "c1",
      voteCount: 4,
      ...extra,
    }),
    "wallRequests/r1/votes/u2": {uid: "u2"},
    "wallRequests/r1/votes/u3": {uid: "u3"},
    "wallRequests/r1/votes/u4": {uid: "u4"},
    "wallRequests/r1/votes/u5": {uid: "u5"},
    "walls/w1": {title: "Dune"},
    ...users,
    "usersv2/u3/private/session": {
      fcmToken: "tok-u3",
      fcmTokenBindingVersion: 1,
      fcmTokenBindingToken: "tok-u3",
      postAlerts: false,
    },
    "usersv2/u4/private/wallRequestPush": {day: TODAY},
    "usersv2/u5/blockedUsers/u1": {},
  };
}
