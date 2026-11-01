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

// Eight letters plus two alphabet characters: never the real code, and distinct for every index below 31.
const missCode = (i: number) => `JKLMNPQR${PROMO_ALPHABET.slice(i, i + 2)}`;

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

test("a retry with the same requestId replays the result without a second credit", async (t) => {
  const store = setup(t);
  await redeem();
  assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
});

test("a replay is checked before the code's limits", async (t) => {
  const store = setup(t);
  await redeem();
  store.set(CODE_PATH, {...store.get(CODE_PATH), expiresAt: ts(NOW_MS - 1), maxRedemptions: 1});
  assert.deepEqual(await redeem(), {ok: true, reward: {type: "coins", coins: 100}, coinBalance: 150, replayed: true});
  assert.equal(store.get("usersv2/u1")?.coins, 150);
  assert.equal(store.get(CODE_PATH)?.redemptionCount, 1);
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

test("a transaction that gives up reports busy and writes nothing", async (t) => {
  const store = setup(t);
  const real = db.runTransaction.bind(db);
  let calls = 0;
  t.mock.method(db, "runTransaction", (callback: Parameters<typeof real>[0]) => {
    calls += 1;
    // The first transaction is the rate-limit attempt; the second is the redemption itself.
    if (calls === 1) return real(callback);
    return Promise.reject(Object.assign(new Error("aborted"), {code: 10}));
  });
  assert.deepEqual(await redeem(), {ok: false, reason: "busy"});
  assert.equal(store.get("usersv2/u1")?.coins, 50);
  assert.equal(store.has(`${CODE_PATH}/redemptions/u1`), false);
});

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
