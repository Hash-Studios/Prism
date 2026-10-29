import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  createWallRequest,
  createWallRequestCallable,
  fillRequestFromWall,
  listWallRequests,
  notifyRequestFilled,
  parseCreateInput,
  publicRequestText,
  removeWallRequestsForAccount,
  requestTokens,
  setWallRequestVoteCallable,
  setWallRequestVote,
  similarity,
  studioRequestPicks,
  wallRequestDeps,
} from "../wallRequests";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

// Accounts in these tests are old enough to request and vote unless a test says otherwise.
const accountCreatedMs = wallRequestDeps.accountCreatedMs;
wallRequestDeps.accountCreatedMs = async () => 0;

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
  const messages: Array<admin.messaging.Message & {token?: string}> = [];
  t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    messages.push(message);
    return "id";
  });
  return messages;
}

test("publicRequestText trims and collapses spaces", () => {
  assert.equal(publicRequestText("  dark   minimal  "), "dark minimal");
  assert.equal(publicRequestText("Valorant Jett"), "Valorant Jett");
});

test("publicRequestText counts visible characters rather than UTF-16 code units", () => {
  const emojiBoundary = "a".repeat(79) + "🌄";
  const decomposedBoundary = "e\u0301".repeat(80);
  assert.equal(publicRequestText(emojiBoundary), emojiBoundary);
  assert.equal(publicRequestText(decomposedBoundary), decomposedBoundary);
  assert.equal(publicRequestText("a".repeat(80) + "🌄"), null);
  assert.equal(publicRequestText("e\u0301".repeat(81)), null);
  assert.equal(publicRequestText("e\u0301".repeat(2)), null);
});

test("publicRequestText rejects length, hidden characters, blocked words and filler-only text", () => {
  assert.equal(publicRequestText("ab"), null);
  assert.equal(publicRequestText("a".repeat(81)), null);
  assert.equal(publicRequestText("dark‮ minimal"), null);
  assert.equal(publicRequestText("dark\tminimal"), null);
  assert.equal(publicRequestText("dark\nminimal"), null);
  assert.equal(publicRequestText("p0rn walls"), null);
  assert.equal(publicRequestText("N1GGA"), null);
  assert.equal(publicRequestText("boooobs walls"), null);
  assert.equal(publicRequestText("fagggot walls"), null);
  assert.equal(publicRequestText("Niger landscape"), "Niger landscape");
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
const accounts = (...uids: string[]): Record<string, Doc> => Object.fromEntries(uids.map((uid) => [`usersv2/${uid}`, {}]));

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

test("concurrent exact creates serialize to one request and one daily charge", async (t) => {
  const store = installFakeDb(t, {
    ...accounts("u1", "u2"),
  });
  const results = await Promise.all([
    createWallRequest("u1", {text: "dark minimal mountains"}, NOW),
    createWallRequest("u2", {text: "Mountains dark minimal"}, NOW),
  ]);
  assert.deepEqual(results.map((result) => result.status).sort(), ["created", "duplicate"]);
  assert.equal([...store.keys()].filter((path) => path.startsWith("wallRequests/") && !path.includes("/votes/")).length, 1);
  assert.equal([...store.values()].filter((doc) => doc.uid === "u1" || doc.uid === "u2")
    .reduce((sum, doc) => sum + (typeof doc.count === "number" ? doc.count : 0), 0), 1);
});

test("an exact match beyond the first 30 close requests still wins", async (t) => {
  const seed: Record<string, Doc> = {...requester};
  for (let i = 0; i < 31; i++) {
    seed[`wallRequests/near${i}`] = request("dark minimal mountains night", `u${i + 2}`, {voteCount: 31 - i});
  }
  seed["wallRequests/exact"] = request("dark minimal mountains", "u99");
  installFakeDb(t, seed);
  const result = await createWallRequest("u1", {text: "dark minimal mountains"}, NOW);
  assert.equal(result.status, "duplicate");
  assert.equal(result.status === "duplicate" && result.exact, true);
  assert.equal(result.request.id, "exact");
});

test("a filled exact request does not block a new open request", async (t) => {
  const store = installFakeDb(t, {
    ...requester,
    "wallRequests/filled": request("dark minimal mountains", "u2", {status: "filled"}),
  });
  const result = await createWallRequest("u1", {text: "dark minimal mountains"}, NOW);
  assert.equal(result.status, "created");
  assert.equal(store.get(`wallRequests/${result.request.id}`)?.status, "open");
});

test("forced requests distinguish different tokens after the twentieth token", async (t) => {
  const common = Array.from({length: 20}, (_, i) => `b${String.fromCharCode(97 + i)}`);
  const store = installFakeDb(t, {
    ...requester,
    "wallRequests/r0": request([...common, "bu"].join(" "), "u2"),
  });
  const result = await createWallRequest("u1", {text: [...common, "bv"].join(" "), force: true}, NOW);
  assert.equal(result.status, "created");
  assert.equal(store.get("wallRequests/r0")?.key, [...common, "bu"].join(" "));
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

test("createWallRequest rejects deletion started after the preflight reads", async (t) => {
  const store = installFakeDb(t, requester);
  const transact = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    store.set("creatorDeletionState/u1", {closed: true});
    return transact(callback);
  });

  await assert.rejects(createWallRequest("u1", {text: "dark minimal mountains"}, NOW), {code: "failed-precondition"});
  assert.equal([...store.keys()].some((path) => path.startsWith("wallRequests/")), false);
});

test("setWallRequestVote sets, repeats and removes one vote", async (t) => {
  const store = installFakeDb(t, {...accounts("u1", "u2"), "wallRequests/r1": request("dark minimal mountains", "u2")});
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
  installFakeDb(t, {...accounts("u1", "u2"), "wallRequests/r1": request("dark minimal mountains", "u2")});
  await assert.rejects(setWallRequestVote("u2", "r1", true, NOW), {code: "failed-precondition"});

  installFakeDb(t, {...accounts("u1", "u2"), "wallRequests/r1": request("dark minimal mountains", "u2", {hidden: true})});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});

  installFakeDb(t, {...accounts("u1", "u2"), "wallRequests/r1": request("dark minimal mountains", "u2", {status: "filled"})});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "failed-precondition"});

  installFakeDb(t, {
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    ...accounts("u1", "u2"),
    "usersv2/u1/blockedUsers/u2": {},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});

  installFakeDb(t, {
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    ...accounts("u1", "u2"),
    "usersv2/u2/blockedUsers/u1": {},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});
});

test("setWallRequestVote keeps the count equal to the vote docs under concurrent votes", async (t) => {
  const voters = Array.from({length: 20}, (_, i) => `v${i}`);
  const newcomers = Array.from({length: 5}, (_, i) => `n${i}`);
  const store = installFakeDb(t, {
    ...accounts("u2", ...voters, ...newcomers),
    "wallRequests/r1": request("dark minimal mountains", "u2"),
  });
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
    ...accounts("u1", "u2"),
    [`wallRequestVoteRateDaily/u1_${TODAY}`]: {day: TODAY, count: 200},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "resource-exhausted"});
  assert.equal(store.has("wallRequests/r1/votes/u1"), false);
  assert.equal(store.get("wallRequests/r1")?.voteCount, 0);
});

test("setWallRequestVote refuses a deleted voter and a requester being deleted", async (t) => {
  installFakeDb(t, {
    ...accounts("u1", "u2"),
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    "usersv2/u1": {deleted: true},
    "creatorDeletionState/u1": {closed: true},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "failed-precondition"});

  installFakeDb(t, {
    ...accounts("u1", "u2"),
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    "creatorDeletionState/u2": {closed: true},
  });
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "not-found"});
});

test("studioRequestPicks scans past 20 ineligible requests", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 20; i++) {
    seed[`wallRequests/stale${i}`] = request("dark minimal mountains", "u1", {
      voteCount: 40 - i,
      createdAt: at(NOW - 31 * DAY),
    });
  }
  seed["wallRequests/zzzEligible"] = request("dark minimal mountains", "u1", {voteCount: 3});
  installFakeDb(t, seed);
  const picks = await db.runTransaction((tx) => studioRequestPicks(tx, 1, NOW));
  assert.deepEqual(picks.map((pick) => pick.requestId), ["zzzEligible"]);
});

test("studioRequestPicks never reads requests below the vote floor", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 60; i++) seed[`wallRequests/low${i}`] = request("neon city rain", "u1", {voteCount: i % 3});
  installFakeDb(t, seed);
  const read: string[] = [];
  const picks = await db.runTransaction(async (tx) => studioRequestPicks({
    get: async (target: Parameters<typeof tx.get>[0]) => {
      const snap = await tx.get(target as never) as unknown as {docs: Array<{id: string}>};
      read.push(...snap.docs.map((d) => d.id));
      return snap;
    },
  } as unknown as typeof tx, 3, NOW));
  assert.deepEqual(picks, []);
  assert.deepEqual(read, []);
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

test("fillRequestFromWall does not fill when the creator blocked the requester", async (t) => {
  const store = installFakeDb(t, {...fillSeed(), "usersv2/c1/blockedUsers/u2": {}});
  assert.equal(await fillRequestFromWall("w1", {requestId: "r1", creatorUid: "c1", by: "Cee"}, false), null);
  assert.equal(store.get("wallRequests/r1")?.status, "open");
});

test("fillRequestFromWall rejects a block added after the precheck", async (t) => {
  const store = installFakeDb(t, fillSeed());
  const transact = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    store.set("usersv2/u2/blockedUsers/c1", {});
    return transact(callback);
  });

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

test("notifyRequestFilled bounds only the push preview for combining-mark request text", async (t) => {
  const text = "a" + "\u0301".repeat(3000) + "bc";
  const preview = "a" + "\u0301".repeat(159);
  const store = installFakeDb(t, {
    ...notifySeed({text}),
    "usersv2/u1/private/session": {
      fcmToken: "tok-u1",
      fcmTokenBindingVersion: 1,
      fcmTokenBindingToken: "tok-u1",
      notificationLocalizationVersion: 2,
      notificationLocalizationToken: "tok-u1",
    },
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);

  assert.equal(messages.length, 2);
  for (const message of messages) {
    const bytes = Buffer.byteLength(JSON.stringify(message), "utf8");
    assert.ok(bytes < 4096, `FCM message is ${bytes} bytes`);
    assert.equal(message.data?.route, "wall");
    assert.equal(message.data?.wall_id, "w1");
    assert.equal(message.data?.request_id, "r1");
    assert.equal(message.data?.notification_kind, "wall_request_filled");
    assert.equal(message.data?.notification_copy_kind, "wallRequestFilled");
    const args = JSON.parse(message.data?.notification_args ?? "{}") as {requestText?: string};
    assert.equal(args.requestText, preview);

    if (message.token === "tok-u1") {
      assert.equal(message.notification, undefined);
      assert.equal(message.android?.notification?.bodyLocArgs?.[0], preview);
      const alert = message.apns?.payload?.aps.alert;
      assert.ok(alert && typeof alert === "object" && "locArgs" in alert);
      if (alert && typeof alert === "object" && "locArgs" in alert) {
        assert.equal(alert.locArgs?.[0], preview);
      }
    } else {
      assert.equal(message.notification?.body, preview);
    }
  }

  assert.equal(store.get("wallRequests/r1")?.text, text);
  const inbox = store.get("notifications/wall_request_r1_u1");
  assert.equal((inbox?.notification as {body?: string} | undefined)?.body, text);
  assert.equal((inbox?.message as {args?: {requestText?: string}} | undefined)?.args?.requestText, text);
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

test("notifyRequestFilled preserves a newer UTC push claim when an older fill resumes late", async (t) => {
  const store = installFakeDb(t, {
    ...notifySeed(),
    "usersv2/u1/private/wallRequestPush": {day: "2026-10-30", requestId: "newer"},
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(store.get("usersv2/u1/private/wallRequestPush")?.day, "2026-10-30");
  assert.equal(store.has("notifications/wall_request_r1_u1"), true);
  assert.equal(messages.some((message) => message.token === "tok-u1"), false);
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

test("notifyRequestFilled refuses text that no longer passes public checks", async (t) => {
  const store = installFakeDb(t, notifySeed({text: "dark\tminimal"}));
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  assert.deepEqual(await notifyRequestFilled("r1", NOW), {sent: 0, inbox: 0, skipped: 0});
  assert.equal(store.get("wallRequests/r1")?.notifiedAt, undefined);
  assert.equal(messages.length, 0);
});

test("notifyRequestFilled skips recipients if the request is hidden during gallery lookup", async (t) => {
  const store = installFakeDb(t, {...notifySeed(), "walls/w1": {id: "w1"}});
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    store.set("wallRequests/r1", {...(store.get("wallRequests/r1") ?? {}), hidden: true});
    return {parameters: {}};
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal([...store.keys()].some((path) => path.startsWith("notifications/wall_request_r1_")), false);
  assert.equal(messages.length, 0);
});

test("notifyRequestFilled rechecks Posts after claiming the daily push slot", async (t) => {
  const store = installFakeDb(t, notifySeed());
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const transact = db.runTransaction.bind(db);
  let calls = 0;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const result = await transact(callback);
    calls++;
    if (calls === 2) {
      store.set("usersv2/u1/private/session", {
        fcmToken: "tok-u1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "tok-u1", postAlerts: false,
      });
    }
    return result;
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(store.get("usersv2/u1/private/wallRequestPush")?.day, TODAY);
  assert.equal(store.has("notifications/wall_request_r1_u1"), true);
  assert.equal(messages.some((message) => message.token === "tok-u1"), false);
});

test("notifyRequestFilled does not recreate a private push claim for an account being deleted", async (t) => {
  const store = installFakeDb(t, {
    ...notifySeed(),
    "creatorDeletionState/u2": {closed: true},
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(store.has("usersv2/u2/private/wallRequestPush"), false);
  assert.equal(store.has("notifications/wall_request_r1_u2"), false);
  assert.equal(messages.some((message) => message.token === "tok-u2"), false);
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

const protectedWall = (id: string, extra: Doc = {}): Doc => ({
  id, review: true, originalProtected: true, wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "", thumb_path: "",
  thumb_sha: "", wallpaper_thumb: `https://img.prismwalls.com/previews/${id}.jpg`, collections: ["community"],
  visionLabels: ["Mountain"], createdAt: at(NOW - DAY), ...extra,
});

test("an upload fills by doc id, but the list and the push gallery use its logical id", async (t) => {
  const previousBase = process.env.R2_PREVIEW_BASE_URL;
  process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";
  t.after(() => {
    if (previousBase === undefined) delete process.env.R2_PREVIEW_BASE_URL;
    else process.env.R2_PREVIEW_BASE_URL = previousBase;
  });
  const store = installFakeDb(t, {
    ...notifySeed({status: "open", filledWallId: admin.firestore.FieldValue.delete()}),
    "walls/wall_up.jpg": protectedWall("LOGIC1"),
    "walls/other_doc.jpg": protectedWall("LOGIC2"),
  });
  delete store.get("wallRequests/r1")?.filledWallId;
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "space"}},
  }}));
  const wall = {...protectedWall("LOGIC1"), requestId: "r1", creatorUid: "c1", by: "Cee"};
  assert.equal(await fillRequestFromWall("wall_up.jpg", wall, false), "r1");
  assert.equal(store.get("wallRequests/r1")?.filledWallId, "wall_up.jpg");
  assert.equal(store.get("wallRequests/r1")?.filledWallLogicalId, "LOGIC1");

  const [row] = await listWallRequests("u2", "filled", false, NOW);
  assert.equal(row.filledWallId, "LOGIC1");

  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.ok(messages.length > 0);
  for (const message of messages) {
    assert.equal(message.data?.wall_id, "wall_up.jpg");
    assert.equal(message.data?.wall_ids, "LOGIC1,LOGIC2");
  }
});

function galleryConfig(t: TestContext) {
  const previousBase = process.env.R2_PREVIEW_BASE_URL;
  process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";
  t.after(() => {
    if (previousBase === undefined) delete process.env.R2_PREVIEW_BASE_URL;
    else process.env.R2_PREVIEW_BASE_URL = previousBase;
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
}

test("filled requests without a cached logical id resolve the existing uploaded wall without writing", async (t) => {
  const store = installFakeDb(t, {
    ...notifySeed({filledWallId: "upload.jpg", filledAt: at(NOW)}),
    "walls/upload.jpg": protectedWall("UPLOAD1"),
  });
  const [row] = await listWallRequests("", "filled", false, NOW);
  assert.equal(row.filledWallId, "UPLOAD1");
  assert.equal(store.get("wallRequests/r1")?.filledWallLogicalId, undefined);
});

test("filled Studio requests resolve when the document and logical ids match", async (t) => {
  installFakeDb(t, {
    ...notifySeed({filledWallId: "studio_1", filledAt: at(NOW), filledBy: "studio"}),
    "walls/studio_1": protectedWall("studio_1"),
  });
  const [row] = await listWallRequests("", "filled", false, NOW);
  assert.equal(row.filledWallId, "studio_1");
  assert.equal(row.filledBy, "studio");
});

for (const id of ["broken,id", "a".repeat(201), ""]) {
  test(`fill and list do not expose an unusable logical id of length ${id.length}`, async (t) => {
    const store = installFakeDb(t, {...fillSeed(), "walls/upload.jpg": protectedWall(id)});
    assert.equal(await fillRequestFromWall("upload.jpg", {id, requestId: "r1"}, false), "r1");
    assert.equal(store.get("wallRequests/r1")?.filledWallId, "upload.jpg");
    assert.equal(store.get("wallRequests/r1")?.filledWallLogicalId, "");
    const [row] = await listWallRequests("", "filled", false, NOW);
    assert.equal(row.filledWallId, "");
  });
}

test("an invalid cached id is resolved from the wall and a 200-character logical id remains valid", async (t) => {
  const id = "a".repeat(200);
  const store = installFakeDb(t, {
    ...notifySeed({filledWallId: "upload.jpg", filledWallLogicalId: "bad,id", filledAt: at(NOW)}),
    "walls/upload.jpg": protectedWall(id),
  });
  const [row] = await listWallRequests("", "filled", false, NOW);
  assert.equal(row.filledWallId, id);
  assert.equal(await fillRequestFromWall("upload.jpg", {id, requestId: "r1"}, false), "r1");
  assert.equal(store.get("wallRequests/r1")?.filledWallLogicalId, id);
});

test("a deleted legacy wall has no gallery identity in the filled list", async (t) => {
  installFakeDb(t, notifySeed({filledWallId: "deleted.jpg", filledAt: at(NOW)}));
  const [row] = await listWallRequests("", "filled", false, NOW);
  assert.equal(row.filledWallId, "");
});

test("open requests and filled requests with valid cached ids do not read walls", async (t) => {
  installFakeDb(t, {
    ...notifySeed({filledWallLogicalId: "CACHED", filledAt: at(NOW)}),
    "wallRequests/open": request("neon city", "u1"),
  });
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (path: string) => {
    assert.notEqual(path, "walls");
    return collection(path);
  });
  assert.equal((await listWallRequests("", "new", false, NOW))[0].filledWallId, "");
  assert.equal((await listWallRequests("", "filled", false, NOW))[0].filledWallId, "CACHED");
});

test("filled pushes omit invalid similar ids", async (t) => {
  galleryConfig(t);
  installFakeDb(t, {
    ...notifySeed({filledWallId: "upload.jpg"}),
    "walls/upload.jpg": protectedWall("LEAD"),
    "walls/a_bad": protectedWall("broken,id"),
    "walls/b_oversize": protectedWall("a".repeat(201)),
    "walls/c_first.jpg": protectedWall("OTHER"),
    "walls/d_duplicate.jpg": protectedWall("OTHER"),
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  for (const message of messages) {
    assert.equal(message.data?.wall_id, "upload.jpg");
    assert.equal(message.data?.wall_ids, "LEAD,OTHER");
  }
});

test("filled push galleries contain each logical id once", async (t) => {
  galleryConfig(t);
  installFakeDb(t, {
    ...notifySeed({filledWallId: "upload.jpg"}),
    "walls/upload.jpg": protectedWall("LEAD"),
    "walls/first.jpg": protectedWall("OTHER"),
    "walls/duplicate.jpg": protectedWall("OTHER"),
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  for (const message of messages) assert.equal(message.data?.wall_ids, "LEAD,OTHER");
});

test("an invalid lead cannot open an unrelated gallery", async (t) => {
  galleryConfig(t);
  installFakeDb(t, {
    ...notifySeed({filledWallId: "upload.jpg"}),
    "walls/upload.jpg": protectedWall("bad,id"),
    "walls/other.jpg": protectedWall("OTHER"),
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  for (const message of messages) {
    assert.equal(message.data?.wall_id, "upload.jpg");
    assert.equal(message.data?.wall_ids, undefined);
  }
});

for (const lead of [undefined, protectedWall("ONLY"), protectedWall("bad,id")]) {
  test(`filled push keeps its document fallback without a gallery for ${lead?.id ?? "missing"} lead`, async (t) => {
    galleryConfig(t);
    const seed = notifySeed({filledWallId: "upload.jpg"});
    if (lead) seed["walls/upload.jpg"] = lead;
    installFakeDb(t, seed);
    const messages = captureMessages(t);
    await notifyRequestFilled("r1", NOW);
    assert.equal(messages.length, 2);
    for (const message of messages) {
      assert.equal(message.data?.wall_id, "upload.jpg");
      assert.equal(message.data?.wall_ids, undefined);
    }
  });
}

test("a failed similar-wall scan keeps the document fallback push", async (t) => {
  galleryConfig(t);
  installFakeDb(t, {...notifySeed({filledWallId: "upload.jpg"}), "walls/upload.jpg": protectedWall("LEAD")});
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (path: string) => {
    const ref = collection(path);
    return path === "walls" ? new Proxy(ref, {get(target, key) {
      if (key === "where") {
        return () => {
          throw new Error("scan unavailable");
        };
      }
      return Reflect.get(target, key);
    }}) : ref;
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  for (const message of messages) {
    assert.equal(message.data?.wall_id, "upload.jpg");
    assert.equal(message.data?.wall_ids, undefined);
  }
});

test("the maximum request text and four 200-character gallery ids stay under the push payload limit", async (t) => {
  galleryConfig(t);
  const ids = ["A", "B", "C", "D"].map((prefix) => prefix + "a".repeat(199));
  installFakeDb(t, {
    ...notifySeed({text: "山".repeat(80), filledWallId: "upload.jpg"}),
    "walls/upload.jpg": protectedWall(ids[0]),
    "walls/b.jpg": protectedWall(ids[1]),
    "walls/c.jpg": protectedWall(ids[2]),
    "walls/d.jpg": protectedWall(ids[3]),
  });
  const messages = captureMessages(t);
  await notifyRequestFilled("r1", NOW);
  assert.equal(messages.length, 2);
  for (const message of messages) {
    assert.equal(message.data?.wall_id, "upload.jpg");
    assert.equal(message.data?.wall_ids, ids.join(","));
    assert.ok(Buffer.byteLength(JSON.stringify(message), "utf8") < 4096);
  }
});

test("accounts younger than 10 days cannot request or vote, and nothing is written", async (t) => {
  const store = installFakeDb(t, {
    ...requester,
    "wallRequests/r1": request("dark minimal mountains", "u2"),
    "wallRequests/r1/votes/u1": {uid: "u1"},
  });
  const existingRequest = store.get("wallRequests/r1");
  assert.ok(existingRequest);
  existingRequest.voteCount = 1;
  const before = [...store.entries()];
  t.mock.method(wallRequestDeps, "accountCreatedMs", async () => NOW - 9 * DAY);
  await assert.rejects(createWallRequest("u1", {text: "dark minimal mountains", tags: []}, NOW),
    {code: "failed-precondition", message: "account-too-new"});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {code: "failed-precondition", message: "account-too-new"});
  await assert.rejects(setWallRequestVote("u1", "r1", false, NOW), {code: "failed-precondition", message: "account-too-new"});
  assert.equal(store.get("wallRequests/r1")?.voteCount, 1);
  assert.equal(store.has("wallRequests/r1/votes/u1"), true);
  assert.deepEqual([...store.entries()], before);
});

test("an account exactly 10 days old can request and vote", async (t) => {
  const store = installFakeDb(t, {...requester, ...accounts("u2"), "wallRequests/r1": request("dark minimal mountains", "u2")});
  t.mock.method(wallRequestDeps, "accountCreatedMs", async () => NOW - 10 * DAY);
  assert.equal((await createWallRequest("u1", {text: "neon city rain", tags: []}, NOW)).status, "created");
  assert.deepEqual(await setWallRequestVote("u1", "r1", true, NOW), {voted: true, voteCount: 1});
  assert.equal(store.has("wallRequests/r1/votes/u1"), true);
});

test("a caller without an Auth user cannot request or vote", async (t) => {
  installFakeDb(t, {...requester, "wallRequests/r1": request("dark minimal mountains", "u2")});
  t.mock.method(wallRequestDeps, "accountCreatedMs", async () => NaN);
  await assert.rejects(createWallRequest("u1", {text: "neon city rain", tags: []}, NOW), {message: "account-too-new"});
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW), {message: "account-too-new"});
});

test("invalid and too-young creation times fail closed for requests and votes", async (t) => {
  installFakeDb(t, {...requester, "wallRequests/r1": request("dark minimal mountains", "u2")});
  const accountAge = t.mock.method(wallRequestDeps, "accountCreatedMs", async () => NaN);
  for (const created of [NaN, Infinity, -Infinity, NOW + 1, NOW - 10 * DAY + 1]) {
    accountAge.mock.mockImplementation(async () => created);
    await assert.rejects(createWallRequest("u1", {text: "neon city rain", tags: []}, NOW),
      {code: "failed-precondition", message: "account-too-new"});
    await assert.rejects(setWallRequestVote("u1", "r1", true, NOW),
      {code: "failed-precondition", message: "account-too-new"});
  }
});

test("Auth user-not-found maps to account-too-new but other Auth failures propagate", async (t) => {
  installFakeDb(t, {...requester, "wallRequests/r1": request("dark minimal mountains", "u2")});
  t.mock.method(wallRequestDeps, "accountCreatedMs", accountCreatedMs);
  const getUser = t.mock.method(admin.auth(), "getUser", async () => {
    throw Object.assign(new Error("missing user"), {code: "auth/user-not-found"});
  });
  await assert.rejects(createWallRequest("u1", {text: "neon city rain", tags: []}, NOW),
    {code: "failed-precondition", message: "account-too-new"});
  assert.equal(getUser.mock.callCount(), 1);
  getUser.mock.mockImplementation(async () => ({metadata: {creationTime: "not a date"}} as never));
  await assert.rejects(setWallRequestVote("u1", "r1", true, NOW),
    {code: "failed-precondition", message: "account-too-new"});
  assert.equal(getUser.mock.callCount(), 2);
  getUser.mock.mockImplementation(async () => {
    throw Object.assign(new Error("Auth unavailable"), {code: "auth/internal-error"});
  });
  await assert.rejects(createWallRequest("u1", {text: "neon city rain", tags: []}, NOW),
    {code: "auth/internal-error", message: "Auth unavailable"});
  assert.equal(getUser.mock.callCount(), 3);
});

test("the callable uses server time and checks account age before Firestore", async (t) => {
  installFakeDb(t, requester);
  t.mock.method(wallRequestDeps, "accountCreatedMs", accountCreatedMs);
  t.mock.method(Date, "now", () => NOW);
  t.mock.method(admin.auth(), "getUser", async () => ({
    metadata: {creationTime: new Date(NOW - 9 * DAY).toISOString()},
  }) as never);
  const collection = t.mock.method(db, "collection", () => {
    throw new Error("Firestore must not be read for an account that is too new");
  });

  await assert.rejects(createWallRequestCallable.run({
    auth: {uid: "u1", token: {}},
    data: {text: "neon city rain", nowMs: NOW + 100 * DAY},
  } as never), {code: "failed-precondition", message: "account-too-new"});
  await assert.rejects(setWallRequestVoteCallable.run({
    auth: {uid: "u1", token: {}},
    data: {requestId: "r1", vote: true, nowMs: NOW + 100 * DAY},
  } as never), {code: "failed-precondition", message: "account-too-new"});
  assert.equal(collection.mock.callCount(), 0);
});
