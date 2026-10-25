import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {resolve} from "node:path";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {grantTestCoins, parseGrantTestCoinsArgs} from "../scripts/grantTestCoins";
import {type Doc, installFakeDb} from "./fakeDb";

const PROJECT = "prism-qa-test";
const UID = "test-user";
const GRANT = "qa-20261025-001";
const USER = `usersv2/${UID}`;
const PRIVATE = `${USER}/private/economy`;
const RECEIPT = `coinTransactions/ctx_adminTestCoins_${GRANT}`;
const ARGS = ["--project", PROJECT, "--uid", UID, "--grant-id", GRANT];
const app = admin.initializeApp({projectId: PROJECT}, "grant-test-coins-tests");

const authUser = (uid = UID): admin.auth.UserRecord => ({
  uid, email: "qa@example.test", displayName: "QA operator", disabled: false, emailVerified: true,
  metadata: {creationTime: "2026-10-25T00:00:00Z", lastSignInTime: "2026-10-25T00:00:00Z", toJSON: () => ({})},
  providerData: [], toJSON: () => ({}),
});

const user = (): Doc => ({
  coins: 75, email: "qa@example.test", username: "qa_test", xp: 499, xpWeek: {key: "2026-W43", xp: 98},
  premium: false, subscriptionTier: "free", coinState: {dailyClaimDate: "2026-10-25", rewardedAdsToday: 3},
  rank: "explorer", cosmetics: {frame: "frame_1"}, badges: [{id: "early"}],
});
const economy = (): Doc => ({
  rev: 4, quests: {dayKey: "2026-10-25", watch_ad: 2}, inventory: {owned: {frame_1: 123}},
  passes: {premiumPassUntil: 1234}, spinWheel: {paid: 1}, graceDownloadsUsed: 2,
});

function setup(t: TestContext, seed: Record<string, Doc> = {[USER]: user(), [PRIVATE]: economy()}) {
  const store = installFakeDb(t, seed);
  t.mock.method(app, "firestore", () => db);
  t.mock.method(app.auth(), "getUser", async (uid: string) => authUser(uid));
  return store;
}

const run = (apply = false, args = ARGS) => grantTestCoins(app,
  parseGrantTestCoinsArgs([...args, ...(apply ? ["--apply"] : [])]));

test("dry-run returns the exact verified target and proposed grant without writing", async (t) => {
  const store = setup(t);
  const before = new Map(store);
  assert.deepEqual(await run(), {
    projectId: "prism-qa-test",
    identity: {uid: "test-user", authEmail: "qa@example.test", authDisplayName: "QA operator",
      profileEmail: "qa@example.test", profileUsername: "qa_test"},
    grantId: "qa-20261025-001", transactionId: "ctx_adminTestCoins_qa-20261025-001",
    outcome: "would-apply", dryRun: true, delta: 1000, balanceBefore: 75, balanceAfter: 1075, revBefore: 4, revAfter: 5,
  });
  assert.deepEqual(store, before);
  assert.equal((await run(true)).outcome, "applied");
  assert.equal(store.get(USER)?.coins, 1075);
});

test("apply credits exactly 1000 with a valid receipt and changes no other economic fields", async (t) => {
  const store = setup(t);
  const now = admin.firestore.Timestamp.fromMillis(1_793_000_000_000);
  t.mock.method(admin.firestore.Timestamp, "now", () => now);
  const result = await run(true);
  assert.equal(result.outcome, "applied");
  assert.equal(result.delta, 1000);
  assert.deepEqual(new Map(store), new Map([
    [USER, {...user(), coins: 1075}],
    [PRIVATE, {...economy(), rev: 5}],
    [RECEIPT, {
      id: "ctx_adminTestCoins_qa-20261025-001", userId: "test-user", createdAt: now, updatedAt: now,
      delta: 1000, balanceBefore: 75, balanceAfter: 1075, action: "adminTestCoins",
      description: "Operator test coins (+1000)", sourceTag: "coins.admin_test_grant.cli", reason: "qa_test_grant",
      status: "completed", type: "credit", projectId: "prism-qa-test", grantId: "qa-20261025-001",
      revBefore: 4, revAfter: 5,
    }],
  ]));
});

test("simultaneous calls and later retries credit once, even after the user spends coins", async (t) => {
  const store = setup(t);
  const results = await Promise.all([run(true), run(true)]);
  assert.deepEqual(results.map((result) => result.outcome), ["applied", "already-applied"]);
  const receipt = store.get(RECEIPT);
  store.set(USER, {...user(), coins: 25});
  store.set(PRIVATE, {...economy(), rev: 7});
  const beforeRetry = new Map(store);
  assert.deepEqual(await run(true), {
    projectId: "prism-qa-test",
    identity: {uid: "test-user", authEmail: "qa@example.test", authDisplayName: "QA operator",
      profileEmail: "qa@example.test", profileUsername: "qa_test"},
    grantId: "qa-20261025-001", transactionId: "ctx_adminTestCoins_qa-20261025-001",
    outcome: "already-applied", dryRun: false, delta: 0, currentBalance: 25, currentRev: 7,
    grantBalanceBefore: 75, grantBalanceAfter: 1075,
  });
  assert.equal((await run()).outcome, "already-applied");
  assert.deepEqual(store, beforeRetry);
  assert.equal(store.get(RECEIPT), receipt);
});

test("a retried Firestore callback discards the failed attempt and uses the new balance and revision", async (t) => {
  const store = setup(t);
  const transact = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await assert.rejects(transact(async (tx) => {
      await callback(tx);
      throw new Error("simulated contention");
    }), /simulated contention/);
    assert.deepEqual(store, new Map([[USER, user()], [PRIVATE, economy()]]));
    store.set(USER, {...user(), coins: 90});
    store.set(PRIVATE, {...economy(), rev: 6});
    return transact(callback);
  });
  const result = await run(true);
  assert.ok("balanceBefore" in result && "balanceAfter" in result);
  assert.equal(result.balanceBefore, 90);
  assert.equal(result.balanceAfter, 1090);
  assert.deepEqual(store.get(PRIVATE), {...economy(), rev: 7});
  assert.equal(store.get(RECEIPT)?.balanceBefore, 90);
  assert.equal(store.get(USER)?.coins, 1090);
});

test("a missing private economy document or revision starts at zero without resetting other fields", async (t) => {
  for (const privateData of [undefined, {quests: {kept: true}}]) {
    await t.test(JSON.stringify(privateData) ?? "missing", async (st) => {
      const seed: Record<string, Doc> = {[USER]: {...user(), coins: 0}};
      if (privateData) seed[PRIVATE] = privateData;
      const store = setup(st, seed);
      const result = await run(true);
      assert.ok("revAfter" in result);
      assert.equal(result.revAfter, 1);
      assert.deepEqual(store.get(PRIVATE), {...privateData, rev: 1});
      assert.equal(store.get(USER)?.coins, 1000);
    });
  }
});

test("each failed transaction write leaves balance, revision and receipt unchanged and can be retried", async (t) => {
  for (const [path, method] of [[USER, "update"], [PRIVATE, "set"], [RECEIPT, "create"]] as const) {
    await t.test(method, async (st) => {
      const store = setup(st);
      const before = new Map(store);
      const doc = db.doc.bind(db);
      let fail = true;
      st.mock.method(db, "doc", (target: string) => {
        const ref = doc(target);
        if (target === path && fail) {
          st.mock.method(ref, method, async () => {
            throw new Error("simulated write rejection");
          });
        }
        return ref;
      });
      await assert.rejects(run(true), /simulated write rejection/);
      assert.deepEqual(store, before);
      fail = false;
      assert.equal((await run(true)).outcome, "applied");
      assert.equal(store.get(USER)?.coins, 1075);
      assert.equal(store.get(PRIVATE)?.rev, 5);
      assert.equal(store.get(RECEIPT)?.delta, 1000);
    });
  }
});

test("grant ID reuse for another user and altered receipts fail without writes", async (t) => {
  const store = setup(t);
  await run(true);
  const valid = store.get(RECEIPT);
  assert.ok(valid);
  store.set("usersv2/other-user", {coins: 80});
  const before = new Map(store);
  await assert.rejects(run(true, ["--project", PROJECT, "--uid", "other-user", "--grant-id", GRANT]), /receipt mismatch/);
  assert.deepEqual(store, before);
  for (const patch of [
    {userId: "other-user"}, {projectId: "other-project"}, {grantId: "other-grant"}, {id: "other-id"},
    {delta: 999}, {action: "rewardedAd"}, {sourceTag: "other"}, {reason: "other"},
    {status: "refunded"}, {type: "debit"}, {createdAt: "today"}, {updatedAt: null},
    {balanceBefore: "75"}, {balanceAfter: 1076}, {revBefore: -1}, {revAfter: 6},
  ]) {
    store.set(RECEIPT, {...valid, ...patch});
    const snapshot = new Map(store);
    for (const apply of [false, true]) await assert.rejects(run(apply), /receipt/);
    assert.deepEqual(store, snapshot);
  }
});

test("malformed or overflowing balances and revisions are rejected rather than repaired", async (t) => {
  for (const field of ["coins", "rev"]) {
    for (const value of [null, "75", -1, 1.5, NaN, Infinity, {}, Number.MAX_SAFE_INTEGER + 1,
      Number.MAX_SAFE_INTEGER, ...(field === "coins" ? [undefined, Number.MAX_SAFE_INTEGER - 999] : [])]) {
      await t.test(`${field}=${String(value)}`, async (st) => {
        const seed = {[USER]: {...user(), ...(field === "coins" ? {coins: value} : {})},
          [PRIVATE]: {...economy(), ...(field === "rev" ? {rev: value} : {})}};
        const store = setup(st, seed);
        const before = new Map(store);
        for (const apply of [false, true]) await assert.rejects(run(apply), /safe integer/);
        assert.deepEqual(store, before);
      });
    }
  }
});

test("safe integer boundary values can be granted and replayed without another increment", async (t) => {
  const store = setup(t, {[USER]: {...user(), coins: Number.MAX_SAFE_INTEGER - 1000},
    [PRIVATE]: {...economy(), rev: Number.MAX_SAFE_INTEGER - 1}});
  assert.equal((await run(true)).outcome, "applied");
  assert.equal(store.get(USER)?.coins, 9007199254740991);
  assert.equal(store.get(PRIVATE)?.rev, 9007199254740991);
  assert.equal((await run(true)).outcome, "already-applied");
  assert.equal(store.get(USER)?.coins, 9007199254740991);
  assert.equal(store.get(PRIVATE)?.rev, 9007199254740991);
});

test("missing or deleted profile, absent or disabled Auth user, and project mismatch fail closed", async (t) => {
  for (const failure of ["profile-missing", "profile-deleted", "auth-missing", "auth-disabled", "auth-mismatch", "project"]) {
    await t.test(failure, async (st) => {
      const store = setup(st, failure === "profile-missing" ? {} : {[USER]: {...user(), deleted: failure === "profile-deleted"}});
      if (failure.startsWith("auth-")) {
        st.mock.method(app.auth(), "getUser", async () => {
          if (failure === "auth-missing") throw new Error("Auth user not found");
          return {...authUser(), uid: failure === "auth-mismatch" ? "other-user" : UID,
            disabled: failure === "auth-disabled"};
        });
      }
      const args = failure === "project" ? ["--project", "other-project", "--uid", UID, "--grant-id", GRANT] : ARGS;
      const before = new Map(store);
      for (const apply of [false, true]) await assert.rejects(run(apply, args), /not found|disabled|match/);
      assert.deepEqual(store, before);
    });
  }
});

test("CLI rejects missing, unsafe, unknown, duplicate, positional and amount arguments", () => {
  assert.deepEqual(parseGrantTestCoinsArgs(ARGS), {projectId: PROJECT, uid: UID, grantId: GRANT, apply: false});
  assert.equal(parseGrantTestCoinsArgs([...ARGS, "--apply"]).apply, true);
  const badArgs = [[], ARGS.slice(2), ARGS.slice(0, 4), [...ARGS, "--apply", "--apply"],
    [...ARGS, "--uid", UID], [...ARGS, "--amount", "2000"], [...ARGS, "--aply"], [...ARGS, "extra"],
    ["--project"], ["--project", "--uid", UID]];
  for (const [flag, value] of [
    ["--project", "prism/qa"], ["--project", " prism-qa-test"], ["--project", "prism-qa-test\n"],
    ["--project", "a".repeat(31)], ["--project", "UPPERCASE"], ["--project", "project-"],
    ["--uid", ""], ["--uid", ".."], ["--uid", "a/b"], ["--uid", "has space"], ["--uid", "a\n"],
    ["--uid", "a".repeat(129)], ["--grant-id", "short"], ["--grant-id", "a/bcdefgh"],
    ["--grant-id", "a".repeat(65)], ["--grant-id", "qa\n123456"],
  ]) {
    const args = [...ARGS];
    args[args.indexOf(flag) + 1] = value;
    badArgs.push(args);
  }
  for (const args of badArgs) assert.throws(() => parseGrantTestCoinsArgs(args), /required|argument|Missing/);
});

test("compiled CLI help and invalid apply exit locally before Firebase credentials are needed", () => {
  const script = resolve(__dirname, "../scripts/grantTestCoins.js");
  const env = {...process.env, GOOGLE_APPLICATION_CREDENTIALS: "/nonexistent/prism-test-credentials.json"};
  const help = spawnSync(process.execPath, [script, "--help"], {encoding: "utf8", env});
  assert.equal(help.status, 0);
  assert.match(help.stdout, /^Usage: node lib\/scripts\/grantTestCoins.js --project/);
  const invalid = spawnSync(process.execPath, [script, "--apply"], {encoding: "utf8", env});
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /explicit 6-30 character project ID is required/);
  assert.equal(invalid.stdout, "");
});
