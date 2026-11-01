import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  clientIp,
  createPromoCode,
  generatePromoCode,
  listPromoCodes,
  normalizePromoCode,
  PROMO_ALPHABET,
  promoCodeId,
  promoIo,
  redeemCode,
  setPromoCodeDisabled,
} from "../promoCodes";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const NOW_MS = NOW.getTime();
const DAY = 86_400_000;
const HOUR = 3_600_000;
const CODE = "ABCDEFGH23";
const CODE_PATH = `promoCodes/${promoCodeId(CODE)}`;
const LEDGER = `coinTransactions/ctx_promo_${promoCodeId(CODE)}_u1`;
const REQ = "request_0001";
const IP = "203.0.113.9";
const ADMIN = {uid: "adm", token: {admin: true, email: "a@x.com"}};

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const callerOf = (uid: string) => ({
  uid,
  token: {email: `${uid}@example.com`, email_verified: true, firebase: {sign_in_provider: "google.com"}},
});

const codeDoc = (overrides: Doc = {}): Doc => ({
  code: CODE,
  reward: {type: "coins", coins: 100},
  maxRedemptions: 1000,
  redemptionCount: 0,
  expiresAt: ts(NOW_MS + 30 * DAY),
  minAccountAgeDays: 0,
  newUsersOnlyDays: null,
  disabled: false,
  ...overrides,
});

function setup(t: TestContext, seed: Record<string, Doc> = {}, createdMs = NOW_MS - 365 * DAY) {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  t.mock.method(promoIo, "accountCreatedMs", async () => createdMs);
  return installFakeDb(t, {[CODE_PATH]: codeDoc(), "usersv2/u1": {coins: 50}, ...seed});
}

const redeem = (data: Doc = {}, uid = "u1", ip = IP) =>
  redeemCode.run({
    auth: callerOf(uid),
    data: {code: CODE, requestId: REQ, platform: "android", ...data},
    rawRequest: {headers: {"x-forwarded-for": ip}},
  } as never);

// Eight letters plus two alphabet characters: never the real code, and distinct for these test indices.
const missCode = (i: number) => `JKLMNPQR${PROMO_ALPHABET[Math.floor(i / PROMO_ALPHABET.length)]}${PROMO_ALPHABET[i % PROMO_ALPHABET.length]}`;

const passUntil = (store: Map<string, Doc>) =>
  (store.get("usersv2/u1/private/economy")?.passes as Doc | undefined)?.premiumPassUntil;

async function refused(t: TestContext, code: Doc, reason: string, createdMs?: number) {
  const store = setup(t, {[CODE_PATH]: codeDoc(code)}, createdMs);
  assert.deepEqual(await redeem(), {ok: false, reason});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
  assert.deepEqual(store.get(CODE_PATH), codeDoc(code));
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
}

test("redeem refuses callers who are not signed in with a verified, non-anonymous account", async (t) => {
  setup(t);
  const data = {code: CODE, requestId: REQ, platform: "android"};
  await assert.rejects(redeemCode.run({data} as never), {code: "unauthenticated"});
  await assert.rejects(redeemCode.run({
    auth: {uid: "u1", token: {email_verified: true, firebase: {sign_in_provider: "anonymous"}}}, data,
  } as never), {code: "unauthenticated"});
  await assert.rejects(redeemCode.run({
    auth: {uid: "u1", token: {email: "u1@example.com", email_verified: false, firebase: {sign_in_provider: "google.com"}}},
    data,
  } as never), {code: "unauthenticated"});
});

test("redeem rejects a bad requestId and an unknown platform", async (t) => {
  setup(t);
  await assert.rejects(redeem({requestId: "x"}), {code: "invalid-argument"});
  await assert.rejects(redeem({platform: "web"}), {code: "invalid-argument"});
});

test("normalizePromoCode folds case, spaces and dashes, and rejects codes that cannot exist", () => {
  assert.equal(normalizePromoCode(" abcd-efgh 23 "), "ABCDEFGH23");
  assert.equal(normalizePromoCode("abcdefghl2"), "ABCDEFGHL2");
  for (const bad of ["ABCDEFGHI2", "ABCDEFGHO2", "ABCDEFGH02", "ABCDEFGH12", "ABCDEFGH2", "A".repeat(33), 12345, null, undefined]) {
    assert.equal(normalizePromoCode(bad), null, String(bad));
  }
});

test("generatePromoCode draws 10 characters from the alphabet and maps bytes to it", () => {
  assert.equal(PROMO_ALPHABET, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789");
  for (let i = 0; i < 200; i++) {
    const code = generatePromoCode();
    assert.equal(code.length, 10);
    for (const ch of code) assert.ok(PROMO_ALPHABET.includes(ch), code);
  }
  // Bytes mod 32: 0 A, 31 9, 32 A, 255 9, 0 A, 1 B, 2 C, 3 D, 4 E, 5 F.
  assert.equal(generatePromoCode(() => Uint8Array.from([0, 31, 32, 255, 0, 1, 2, 3, 4, 5])), "A9A9ABCDEF");
});

test("a coin code credits once, writes a ledger row and a redemption, and the code appears only in its own doc", async (t) => {
  const store = setup(t);
  assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: false});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  const ledger = store.get(LEDGER);
  assert.equal(ledger?.delta, 100);
  assert.equal(ledger?.balanceBefore, 50);
  assert.equal(ledger?.balanceAfter, 150);
  assert.equal(ledger?.action, "promoCode");
  assert.equal(ledger?.type, "credit");
  assert.equal(ledger?.userId, "u1");
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
  assert.equal(store.get(`${CODE_PATH}/redemptions/u1`)?.requestId, REQ);
  for (const [path, doc] of store) {
    // Only the code doc's own code field may hold the code; ledger ids, paths and redemptions must not.
    const haystack = path === CODE_PATH ? JSON.stringify({...doc, code: undefined}) : JSON.stringify([path, doc]);
    assert.equal(haystack.includes(CODE), false, path);
  }
});

test("a malformed code and an unknown code are refused with a reason", async (t) => {
  setup(t);
  assert.deepEqual(await redeem({code: "ABCDEFGHI2"}), {ok: false, reason: "invalid_code"});
  assert.deepEqual(await redeem({code: "ZZZZZZZZZZ"}), {ok: false, reason: "not_found"});
});

test("a disabled code is refused and changes nothing", async (t) => {
  await refused(t, {disabled: true}, "disabled");
});

test("an expired code is refused and changes nothing", async (t) => {
  await refused(t, {expiresAt: ts(NOW_MS - 1)}, "expired");
});

test("a code at its total redemption limit is refused and changes nothing", async (t) => {
  await refused(t, {maxRedemptions: 5, redemptionCount: 5}, "limit_reached");
});

test("an account younger than the minimum age is refused and changes nothing", async (t) => {
  await refused(t, {minAccountAgeDays: 3}, "account_too_new", NOW_MS - 2 * DAY);
});

test("an account at least the minimum age is accepted", async (t) => {
  setup(t, {[CODE_PATH]: codeDoc({minAccountAgeDays: 3})}, NOW_MS - 4 * DAY);
  assert.equal((await redeem()).ok, true);
});

test("a code for new users only refuses an older account and changes nothing", async (t) => {
  await refused(t, {newUsersOnlyDays: 7}, "new_users_only", NOW_MS - 8 * DAY);
});

test("a code for new users only accepts an account inside the window", async (t) => {
  setup(t, {[CODE_PATH]: codeDoc({newUsersOnlyDays: 7})}, NOW_MS - 6 * DAY);
  assert.equal((await redeem()).ok, true);
});

test("a user redeems a code once, even under a new requestId", async (t) => {
  const store = setup(t);
  assert.equal((await redeem({requestId: "request_0001"})).ok, true);
  assert.deepEqual(await redeem({requestId: "request_0002"}), {ok: false, reason: "already_redeemed"});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
});

test("only one caller takes the last redemption slot", async (t) => {
  const store = setup(t, {
    [CODE_PATH]: codeDoc({maxRedemptions: 1}),
    "usersv2/u2": {coins: 50},
  });
  const results = await Promise.all([
    redeem({requestId: "request_0001"}, "u1"),
    redeem({requestId: "request_0002"}, "u2"),
  ]);
  assert.equal(results.filter((result) => result.ok).length, 1);
  assert.equal(results.filter((result) => !result.ok && result.reason === "limit_reached").length, 1);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

for (const sameRequest of [true, false]) {
  test(`a late lookup after the last slot ${sameRequest ? "replays the same request" : "refuses another request"}`, async (t) => {
    const store = setup(t, {[CODE_PATH]: codeDoc({maxRedemptions: 1})});
    const real = db.runTransaction.bind(db);
    let resume!: () => void;
    let entered!: () => void;
    const paused = new Promise<void>((resolve) => {
      entered = resolve;
    });
    const released = new Promise<void>((resolve) => {
      resume = resolve;
    });
    let first = true;
    t.mock.method(db, "runTransaction", async (callback: Parameters<typeof real>[0]) => {
      const shouldPause = first;
      first = false;
      const result = await real(callback);
      if (shouldPause) {
        entered();
        await released;
      }
      return result;
    });
    // The retry already saw no redemption, but cannot look up the code until the winner exhausts it.
    const delayed = redeem({requestId: sameRequest ? REQ : "request_0002"});
    await paused;
    try {
      assert.equal((await redeem()).ok, true);
    } finally {
      resume();
    }
    assert.deepEqual(await delayed, sameRequest ?
      {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true} :
      {ok: false, reason: "already_redeemed"});
    assert.equal(store.get("usersv2/u1")?.coins, 150);
    assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
    assert.equal([...store.keys()].filter((path) => path.startsWith("coinTransactions/")).length, 1);
  });
}

test("different concurrent requestIds for one code grant only one redemption", async (t) => {
  const store = setup(t);
  const results = await Promise.all([
    redeem({requestId: "request_0001"}),
    redeem({requestId: "request_0002"}),
  ]);
  assert.equal(results.filter((result) => result.ok).length, 1);
  assert.equal(results.filter((result) => !result.ok && result.reason === "already_redeemed").length, 1);
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

test("a retry with the same requestId replays the result without a second credit", async (t) => {
  const store = setup(t);
  await redeem();
  assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

test("an iOS retry does not replay a Pro grant", async (t) => {
  setup(t, {
    [CODE_PATH]: codeDoc(PREMIUM_3),
    [`${CODE_PATH}/redemptions/u1`]: {
      uid: "u1", requestId: REQ, reward: {type: "premiumDays", days: 3}, premiumUntil: NOW_MS + 3 * DAY,
    },
  });
  assert.deepEqual(await redeem({platform: "ios"}), {ok: false, reason: "premium_not_on_ios"});
});

test("a replay is checked before the code's limits", async (t) => {
  const store = setup(t);
  await redeem();
  store.set(CODE_PATH, {...store.get(CODE_PATH), expiresAt: ts(NOW_MS - 1), maxRedemptions: 1});
  assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

test("a deleted account cannot replay a previous redemption", async (t) => {
  const store = setup(t, {
    "usersv2/u1": {coins: 150, deleted: true},
    [`${CODE_PATH}/redemptions/u1`]: {
      uid: "u1", requestId: REQ, reward: {type: "coins", coins: 100}, coinBalance: 150,
    },
  });
  await assert.rejects(redeem(), {code: "not-found"});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
});

test("an account with a deletion barrier cannot replay a previous redemption", async (t) => {
  const store = setup(t, {
    [`${CODE_PATH}/redemptions/u1`]: {
      uid: "u1", requestId: REQ, reward: {type: "coins", coins: 100}, coinBalance: 150,
    },
    "creatorDeletionState/u1": {closed: true},
  });
  await assert.rejects(redeem(), {code: "not-found"});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
});

test("a user gets 10 attempts an hour, and the next hour starts fresh", async (t) => {
  setup(t);
  for (let i = 0; i < 10; i++) {
    assert.deepEqual(await redeem({code: missCode(i)}), {ok: false, reason: "not_found"});
  }
  assert.deepEqual(await redeem({code: missCode(10)}), {ok: false, reason: "rate_limited"});
  assert.deepEqual(await redeem({code: CODE}), {ok: false, reason: "rate_limited"});
  t.mock.timers.tick(HOUR);
  assert.equal((await redeem()).ok, true);
});

test("parallel attempts by one user cannot exceed the hourly cap", async (t) => {
  const store = setup(t);
  const results = await Promise.all(Array.from({length: 25}, (_, i) => redeem({code: missCode(i)})));
  assert.equal(results.filter((result) => !result.ok && result.reason === "not_found").length, 10);
  assert.equal(results.filter((result) => !result.ok && result.reason === "rate_limited").length, 15);
  assert.equal(store.get(`promoRedeemRate/u_u1_${Math.floor(NOW_MS / HOUR)}`)?.count, 10);
  assert.equal(store.has(LEDGER), false);
});

test("an IP gets 30 misses an hour across accounts, and a different IP is unaffected", async (t) => {
  const store = setup(t, {
    "usersv2/u2": {coins: 50}, "usersv2/u3": {coins: 50}, "usersv2/u4": {coins: 50}, "usersv2/u5": {coins: 50},
  });
  for (const [group, uid] of ["u1", "u2", "u3"].entries()) {
    for (let i = 0; i < 10; i++) {
      assert.deepEqual(await redeem({code: missCode(group * 10 + i)}, uid), {ok: false, reason: "not_found"});
    }
  }
  assert.deepEqual(await redeem({}, "u4"), {ok: false, reason: "rate_limited"});
  assert.deepEqual(await redeem({}, "u5", "198.51.100.7"), {ok: true, reward: {type: "coins", coins: 100},
    coinBalance: 150, replayed: false});
  assert.equal(store.get("usersv2/u5")?.coins, 150);
});

test("parallel misses from many accounts cannot exceed the IP limit", async (t) => {
  const users = Object.fromEntries(Array.from({length: 60}, (_, i) => [`usersv2/u${i}`, {coins: 0}]));
  const store = setup(t, {...users, "usersv2/valid": {coins: 50}});
  const collection = db.collection.bind(db);
  let codeReads = 0;
  t.mock.method(db, "collection", (path: string) => {
    const result = collection(path);
    if (path !== "promoCodes") return result;
    const doc = result.doc.bind(result);
    t.mock.method(result, "doc", (id: string) => {
      const ref = doc(id);
      const get = ref.get.bind(ref);
      t.mock.method(ref, "get", () => {
        codeReads++;
        return get();
      });
      return ref;
    });
    return result;
  });
  const results = await Promise.all(Array.from({length: 60}, (_, i) => redeem({code: missCode(i)}, `u${i}`)));
  assert.equal(results.filter((result) => !result.ok && result.reason === "not_found").length, 30);
  assert.equal(results.filter((result) => !result.ok && result.reason === "rate_limited").length, 30);
  assert.equal(codeReads, 30);
  assert.equal([...store.entries()].find(([path]) => path.startsWith("promoRedeemRate/ip_"))?.[1].count, 30);
  assert.deepEqual(await redeem({}, "valid"), {ok: false, reason: "rate_limited"});
  assert.equal(codeReads, 30, "an exhausted IP cannot look up even a valid code");
  assert.equal(store.get("usersv2/valid")?.coins, 50);
});

test("clientIp trusts the last X-Forwarded-For hop", () => {
  assert.equal(clientIp({headers: {"x-forwarded-for": "1.1.1.1, 203.0.113.9"}}), "203.0.113.9");
  assert.equal(clientIp({ip: "10.0.0.1"}), "10.0.0.1");
});

const PREMIUM_3 = {reward: {type: "premiumDays", days: 3}};

test("a premium code extends from the later of now and the current pass", async (t) => {
  const store = setup(t, {
    [CODE_PATH]: codeDoc(PREMIUM_3),
    "usersv2/u1/private/economy": {rev: 2, passes: {premiumPassUntil: NOW_MS + 10 * DAY}},
  });
  assert.deepEqual(await redeem(), {
    ok: true, reward: {type: "premiumDays", days: 3}, premiumUntil: NOW_MS + 13 * DAY, replayed: false,
  });
  assert.equal(passUntil(store), NOW_MS + 13 * DAY);
});

test("a premium code with no existing pass runs 3 days from now", async (t) => {
  const store = setup(t, {[CODE_PATH]: codeDoc(PREMIUM_3)});
  assert.deepEqual(await redeem(), {
    ok: true, reward: {type: "premiumDays", days: 3}, premiumUntil: NOW_MS + 3 * DAY, replayed: false,
  });
  assert.equal(passUntil(store), NOW_MS + 3 * DAY);
});

test("a premium code over an expired pass runs 3 days from now", async (t) => {
  const store = setup(t, {
    [CODE_PATH]: codeDoc(PREMIUM_3),
    "usersv2/u1/private/economy": {passes: {premiumPassUntil: NOW_MS - 5 * DAY}},
  });
  assert.deepEqual(await redeem(), {
    ok: true, reward: {type: "premiumDays", days: 3}, premiumUntil: NOW_MS + 3 * DAY, replayed: false,
  });
  assert.equal(passUntil(store), NOW_MS + 3 * DAY);
});

test("a paying subscriber cannot take a premium code", async (t) => {
  const store = setup(t, {[CODE_PATH]: codeDoc(PREMIUM_3), "usersv2/u1": {coins: 50, premium: true}});
  assert.deepEqual(await redeem(), {ok: false, reason: "already_premium"});
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 0);
});

test("iOS refuses a premium code", async (t) => {
  const store = setup(t, {[CODE_PATH]: codeDoc(PREMIUM_3)});
  assert.deepEqual(await redeem({platform: "ios"}), {ok: false, reason: "premium_not_on_ios"});
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
});

test("iOS accepts a coin code", async (t) => {
  const store = setup(t);
  assert.deepEqual(await redeem({platform: "ios"}), {ok: true, reward: {type: "coins", coins: 100},
    coinBalance: 150, replayed: false});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
});

test("a deleted account is rejected as not found", async (t) => {
  setup(t, {"usersv2/u1": {coins: 50, deleted: true}});
  await assert.rejects(redeem(), {code: "not-found"});
});

test("a deleted Auth user cannot redeem a code with no account-age rule", async (t) => {
  const store = setup(t);
  t.mock.method(promoIo, "accountCreatedMs", async () => {
    throw Object.assign(new Error("User not found"), {code: "auth/user-not-found"});
  });
  await assert.rejects(redeem(), {code: "not-found"});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
});

test("a deleted Auth user cannot replay a previous redemption", async (t) => {
  const store = setup(t);
  await redeem();
  t.mock.method(promoIo, "accountCreatedMs", async () => {
    throw Object.assign(new Error("User not found"), {code: "auth/user-not-found"});
  });
  await assert.rejects(redeem(), {code: "not-found"});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

for (const [stage, abortAt] of [["lookup", 2], ["grant", 3]] as const) {
  test(`an aborted ${stage} transaction reports busy and grants nothing`, async (t) => {
    const store = setup(t);
    const real = db.runTransaction.bind(db);
    let calls = 0;
    t.mock.method(db, "runTransaction", (callback: Parameters<typeof real>[0]) => {
      if (++calls === abortAt) return Promise.reject(Object.assign(new Error("aborted"), {code: 10}));
      return real(callback);
    });
    assert.deepEqual(await redeem(), {ok: false, reason: "busy"});
    assert.equal(calls, abortAt);
    assert.equal(store.get("usersv2/u1")?.coins, 50);
    assert.equal(store.get(CODE_PATH)?.redemptionCount, 0);
    assert.equal(store.has(LEDGER), false);
    assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
  });
}

test("an aborted replay transaction reports busy without another credit", async (t) => {
  const store = setup(t);
  await redeem();
  t.mock.method(db, "runTransaction", () => Promise.reject(Object.assign(new Error("aborted"), {code: "aborted"})));
  assert.deepEqual(await redeem(), {ok: false, reason: "busy"});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

test("an existing ledger create collision never credits or counts a second grant", async (t) => {
  const ledger = {delta: 100, balanceBefore: 50, balanceAfter: 150};
  const store = setup(t, {[LEDGER]: ledger});
  assert.deepEqual(await redeem(), {ok: false, reason: "already_redeemed"});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 0);
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
  assert.deepEqual(store.get(LEDGER), ledger);
});

for (const mode of ["replay", "deletion", "aborted"]) {
  const outcome = mode === "deletion" ? "checks the deletion barrier before replay" :
    mode === "aborted" ? "reports busy when replay aborts" : "replays only the winning grant";
  test(`a redemption create collision ${outcome}`, async (t) => {
    const store = setup(t);
    const real = db.runTransaction.bind(db);
    let collisions = 0;
    t.mock.method(db, "runTransaction", (callback: Parameters<typeof real>[0]) => {
      if (collisions && mode === "aborted") return Promise.reject(Object.assign(new Error("aborted"), {code: 10}));
      return real(async (tx) => {
        const create = tx.create.bind(tx);
        t.mock.method(tx, "create", (ref: admin.firestore.DocumentReference, data: admin.firestore.DocumentData) => {
          if (ref.path === `${CODE_PATH}/redemptions/u1`) {
            // Another writer commits after our reads. The real fake-DB create precondition rejects this transaction.
            collisions++;
            store.set(ref.path, {...data});
            store.set("usersv2/u1", {coins: 150});
            store.set(CODE_PATH, codeDoc({redemptionCount: 1}));
            store.set(LEDGER, {delta: 100, balanceBefore: 50, balanceAfter: 150});
            if (mode === "deletion") store.set("creatorDeletionState/u1", {closed: true});
          }
          return create(ref, data);
        });
        return callback(tx);
      });
    });
    if (mode === "deletion") await assert.rejects(redeem(), {code: "not-found"});
    else if (mode === "aborted") assert.deepEqual(await redeem(), {ok: false, reason: "busy"});
    else assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true});
    assert.equal(collisions, 1);
    assert.equal(store.get("usersv2/u1")?.coins, 150);
    assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
    assert.equal(store.get(LEDGER)?.balanceAfter, 150);
  });
}

test("a rate-limit transaction that gives up reports busy and redeems nothing", async (t) => {
  const store = setup(t);
  t.mock.method(db, "runTransaction", () => Promise.reject(Object.assign(new Error("aborted"), {code: 10})));
  assert.deepEqual(await redeem(), {ok: false, reason: "busy"});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
});

const ADMIN_VALID = {type: "coins", amount: 100, maxRedemptions: 10, expiresAtMs: NOW_MS + 7 * DAY};
const adminCreate = (data: Doc, auth: unknown = ADMIN) => createPromoCode.run({auth, data} as never);

test("createPromoCode is admin only", async (t) => {
  setup(t);
  await assert.rejects(createPromoCode.run({data: ADMIN_VALID} as never), {code: "unauthenticated"});
  await assert.rejects(adminCreate(ADMIN_VALID, callerOf("u1")), {code: "permission-denied"});
});

test("an admin creates a random code with no redemptions yet", async (t) => {
  const store = setup(t);
  const {code} = await adminCreate(ADMIN_VALID) as {code: string};
  assert.match(code, /^[A-HJ-NP-Z2-9]{10}$/);
  assert.equal(store.get(`promoCodes/${promoCodeId(code)}`)?.redemptionCount, 0);
});

test("createPromoCode refuses a chosen code with a confusable character", async (t) => {
  setup(t);
  await assert.rejects(adminCreate({...ADMIN_VALID, code: "PRISMDAY25"}), {code: "invalid-argument"});
});

test("createPromoCode refuses a chosen code that already exists", async (t) => {
  setup(t);
  await adminCreate({...ADMIN_VALID, code: "WATCHDAY25"});
  await assert.rejects(adminCreate({...ADMIN_VALID, code: "WATCHDAY25"}), {code: "already-exists"});
});

test("createPromoCode refuses out-of-range rules", async (t) => {
  setup(t);
  const bad: Array<[string, Doc]> = [
    ["zero coins", {amount: 0}],
    ["over 1000 coins", {amount: 1001}],
    ["over 90 premium days", {type: "premiumDays", amount: 91}],
    ["expiry in the past", {expiresAtMs: NOW_MS - 1}],
    ["new-users window not after the minimum age", {minAccountAgeDays: 5, newUsersOnlyDays: 5}],
  ];
  for (const [name, patch] of bad) {
    await assert.rejects(adminCreate({...ADMIN_VALID, ...patch}), {code: "invalid-argument"}, name);
  }
});

test("listPromoCodes is admin only and shows each code's redemption count", async (t) => {
  setup(t);
  const {code} = await adminCreate(ADMIN_VALID) as {code: string};
  const listed = await listPromoCodes.run({auth: ADMIN} as never) as {codes: Array<Doc>};
  assert.equal(listed.codes.find((row) => row.code === code)?.redemptionCount, 0);
  await assert.rejects(listPromoCodes.run({auth: callerOf("u1")} as never), {code: "permission-denied"});
});

test("setPromoCodeDisabled turns a created code off, and a later redeem says disabled", async (t) => {
  setup(t);
  const {code} = await adminCreate(ADMIN_VALID) as {code: string};
  await setPromoCodeDisabled.run({auth: ADMIN, data: {code, disabled: true}} as never);
  assert.deepEqual(await redeem({code}), {ok: false, reason: "disabled"});
});
