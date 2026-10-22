import assert from "node:assert/strict";
import test, {beforeEach, mock} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  awardCoins,
  buyStreakFreeze,
  claimProSpin,
  duplicateSpendResponse,
  processReferral,
  isValidRequestId,
  planFreezePurchase,
  refundableDelta,
  restoreStreak,
  rewardedAdAllowed,
  spendBasePrice,
  spendCoins,
  STREAK_RESCUE_COST,
  unlockPremiumPreview,
} from "../coinsCallables";
import {DEFAULT_ECONOMY, ECONOMY_CONFIG_DOC, parseEconomy, resetEconomyCache, weekKey} from "../economy";
import {buildQuestState} from "../questCatalog";
import {installFakeDb} from "./fakeDb";

// No economy config doc unless a test seeds one: callables run on DEFAULT_ECONOMY.
const realDoc = db.doc.bind(db);
mock.method(db, "doc", (path: string) =>
  path === ECONOMY_CONFIG_DOC ? {get: async () => ({exists: false, data: (): undefined => undefined})} : realDoc(path));
beforeEach(() => resetEconomyCache());

const NOW = 1_700_000_000_000;

function debitFixture(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    userId: "user-1",
    type: "debit",
    action: "wallpaperDownload",
    status: "completed",
    delta: -15,
    createdAt: {toMillis: () => NOW - 60_000},
    ...overrides,
  };
}

test("refundableDelta: happy path returns the absolute debited amount", () => {
  assert.equal(refundableDelta(debitFixture(), "user-1", NOW), 15);
});

test("refundableDelta: rejects a missing debit doc", () => {
  assert.throws(() => refundableDelta(undefined, "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects when the caller does not own the debit", () => {
  assert.throws(() => refundableDelta(debitFixture({userId: "someone-else"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects a credit transaction", () => {
  assert.throws(() => refundableDelta(debitFixture({type: "credit"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects an already-refunded debit", () => {
  assert.throws(() => refundableDelta(debitFixture({status: "refunded"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects a debit older than the refund window", () => {
  const old = debitFixture({createdAt: {toMillis: () => NOW - 600_001}});
  assert.throws(() => refundableDelta(old, "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: allows a debit right at the edge of the refund window", () => {
  const edge = debitFixture({createdAt: {toMillis: () => NOW - 600_000}});
  assert.equal(refundableDelta(edge, "user-1", NOW), 15);
});

test("rewardedAdAllowed: allows the 20th claim of the day", () => {
  assert.equal(rewardedAdAllowed({count: 19, lastAt: NOW - 25_000}, NOW), true);
});

test("rewardedAdAllowed: blocks the 21st claim of the day", () => {
  assert.equal(rewardedAdAllowed({count: 20, lastAt: NOW - 25_000}, NOW), false);
});

test("rewardedAdAllowed: blocks a claim only 19s after the last one", () => {
  assert.equal(rewardedAdAllowed({count: 1, lastAt: NOW - 19_000}, NOW), false);
});

test("rewardedAdAllowed: allows a claim 21s after the last one", () => {
  assert.equal(rewardedAdAllowed({count: 1, lastAt: NOW - 21_000}, NOW), true);
});

test("rewardedAdAllowed: allows the first claim with no prior state", () => {
  assert.equal(rewardedAdAllowed({}, NOW), true);
});

test("planFreezePurchase: debits 50 and adds a freeze", () => {
  assert.deepEqual(planFreezePurchase(120, 0), {current: 70, freezes: 1});
});

test("planFreezePurchase: rejects a balance of 49", () => {
  assert.deepEqual(planFreezePurchase(49, 0), {insufficientBalance: true});
});

test("planFreezePurchase: rejects at the cap even with a high balance", () => {
  assert.deepEqual(planFreezePurchase(10_000, 2), {atCap: true});
});

test("planFreezePurchase: buying the last available freeze spends the full balance", () => {
  assert.deepEqual(planFreezePurchase(50, 1), {current: 0, freezes: 2});
});

test("planFreezePurchase: a second purchase on the post-first state at cap is rejected", () => {
  const first = planFreezePurchase(200, 1);
  assert.deepEqual(first, {current: 150, freezes: 2});
  if (!("current" in first)) throw new Error("expected success");
  assert.deepEqual(planFreezePurchase(first.current, first.freezes), {atCap: true});
});

test("isValidRequestId: rejects empty, oversize and bad characters", () => {
  assert.equal(isValidRequestId(""), false);
  assert.equal(isValidRequestId("short"), false);
  assert.equal(isValidRequestId("a".repeat(65)), false);
  assert.equal(isValidRequestId("has space 123"), false);
  assert.equal(isValidRequestId("bad/char_12345"), false);
  assert.equal(isValidRequestId(12345678), false);
  assert.equal(isValidRequestId("abc-DEF_1234"), true);
  assert.equal(isValidRequestId("a".repeat(64)), true);
});

for (const retry of ["duplicate", "cap", "balance"] as const) {
  test(`buyStreakFreeze: retry ending in ${retry} discards the first attempt's purchase`, async (t) => {
    const committedWrites: unknown[] = [];
    const finalFreezes = retry === "cap" ? 2 : 1;
    const finalBalance = retry === "balance" ? 0 : 70;
    t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      for (let attempt = 0; attempt < 2; attempt++) {
        let reads = 0;
        await callback({
          get: async () => reads++ === 0 ? {
            exists: true,
            data: () => ({coins: attempt === 0 ? 120 : finalBalance,
              coinState: {streakFreezes: attempt === 0 ? 0 : finalFreezes}}),
          } : {exists: attempt === 1 && retry === "duplicate"},
          update: (_ref: unknown, data: unknown) => {
            if (attempt === 1) committedWrites.push(data);
          },
          set: (_ref: unknown, data: unknown) => {
            if (attempt === 1) committedWrites.push(data);
          },
        } as unknown as admin.firestore.Transaction);
      }
    });
    const result = await buyStreakFreeze.run({
      auth: {uid: "user-1"}, data: {requestId: "request_123"},
    } as Parameters<typeof buyStreakFreeze.run>[0]);
    assert.equal(result.success, retry === "duplicate");
    assert.equal(result.changed, false);
    assert.equal(result.delta, 0);
    assert.equal(result.atCap, retry === "cap");
    assert.equal(result.insufficientBalance, retry === "balance");
    assert.equal(result.currentBalance, finalBalance);
    assert.equal(result.streakFreezes, finalFreezes);
    assert.deepEqual(committedWrites, []);
  });
}

test("refundableDelta: only the download and AI generation debits are refundable", () => {
  for (const action of ["premiumFilter", "premiumPreview24h", "rewardedAd", undefined]) {
    assert.throws(() => refundableDelta(debitFixture({action}), "user-1", NOW), {code: "failed-precondition"});
  }
  for (const action of ["wallpaperDownload", "premiumWallpaperDownload", "aiGeneration"]) {
    assert.equal(refundableDelta(debitFixture({action}), "user-1", NOW), 15);
  }
});

test("refundableDelta: a streak freeze purchase is never refundable", () => {
  const freeze = debitFixture({action: "streakFreeze", delta: -50});
  assert.throws(() => refundableDelta(freeze, "user-1", NOW), {code: "failed-precondition"});
});

test("buyStreakFreeze validates auth and requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  await assert.rejects(() => buyStreakFreeze.run({
    data: {requestId: "request_123"},
  } as Parameters<typeof buyStreakFreeze.run>[0]), {code: "unauthenticated"});
  for (const requestId of [undefined, null, 12345678, "short", "a".repeat(65), "bad/path_123"]) {
    await assert.rejects(() => buyStreakFreeze.run({
      auth: {uid: "user-1"}, data: {requestId},
    } as Parameters<typeof buyStreakFreeze.run>[0]), {code: "invalid-argument"});
  }
});

test("buyStreakFreeze commits its debit and freeze together and replay cannot debit twice", async (t) => {
  let coins = 120;
  let freezes = 0;
  let ledger: Record<string, unknown> | undefined;
  const writes: string[] = [];
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    let reads = 0;
    await callback({
      get: async () => reads++ === 0 ? {
        exists: true, data: () => ({coins, premium: true, coinState: {streakFreezes: freezes}}),
      } : {exists: ledger != null},
      update: (ref: admin.firestore.DocumentReference, data: Record<string, number>) => {
        writes.push(ref.path);
        coins = data.coins;
        freezes = data["coinState.streakFreezes"];
      },
      set: (ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        writes.push(ref.path);
        ledger = data;
      },
    } as unknown as admin.firestore.Transaction);
  });
  const request = {
    auth: {uid: "user-1"}, data: {requestId: "request_123", amount: 0, freezes: 999, allowPremiumBypass: true},
  } as unknown as Parameters<typeof buyStreakFreeze.run>[0];
  const purchase = await buyStreakFreeze.run(request);
  assert.equal(purchase.changed, true);
  assert.equal(coins, 70);
  assert.equal(freezes, 1);
  assert.deepEqual(writes, ["usersv2/user-1", "coinTransactions/ctx_streakFreeze_user-1_request_123"]);
  assert.ok(ledger);
  assert.deepEqual(ledger, {
    id: "ctx_streakFreeze_user-1_request_123",
    userId: "user-1",
    createdAt: ledger.createdAt,
    updatedAt: ledger.createdAt,
    delta: -50,
    balanceBefore: 120,
    balanceAfter: 70,
    action: "streakFreeze",
    description: "Streak freeze",
    sourceTag: "coins.buy_streak_freeze.callable",
    reason: "streak_freeze_purchase",
    status: "completed",
    type: "debit",
  });
  const replay = await buyStreakFreeze.run(request);
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.delta, 0);
  assert.equal(coins, 70);
  assert.equal(freezes, 1);
  assert.equal(writes.length, 2);
});

interface SpendHarness {
  coins: number;
  premium?: boolean;
  ledger: Map<string, Record<string, unknown>>;
}

function mockSpendTransactions(t: test.TestContext, harness: SpendHarness): void {
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await callback({
      get: async (ref: admin.firestore.DocumentReference) => {
        if (ref.path === "usersv2/user-1") {
          return {exists: true, data: () => ({coins: harness.coins, premium: harness.premium})};
        }
        const doc = harness.ledger.get(ref.id);
        return {exists: doc != null, data: () => doc};
      },
      update: (_ref: admin.firestore.DocumentReference, data: Record<string, number>) => {
        harness.coins = data.coins;
      },
      set: (ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        harness.ledger.set(ref.id, data);
      },
    } as unknown as admin.firestore.Transaction);
  });
}

// premiumFilter costs 5 at legacy and v2 prices and has no grace, so these tests hold on either side of the window.
function spendRequest(data: Record<string, unknown>): Parameters<typeof spendCoins.run>[0] {
  return {
    auth: {uid: "user-1"},
    data: {action: "premiumFilter", sourceTag: "test", ...data},
  } as unknown as Parameters<typeof spendCoins.run>[0];
}

test("spendCoins with a requestId debits once and a repeat returns the original result", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const first = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(first.changed, true);
  assert.equal(first.delta, -5);
  assert.equal(first.transactionId, "spend_user-1_request_123");
  assert.equal(harness.coins, 95);
  const repeat = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(repeat.success, true);
  assert.equal(repeat.changed, true);
  assert.equal(repeat.delta, -5);
  assert.equal(repeat.previousBalance, 100);
  assert.equal(repeat.currentBalance, 95);
  assert.equal(repeat.transactionId, "spend_user-1_request_123");
  assert.equal(harness.coins, 95);
  assert.equal(harness.ledger.size, 1);
  await spendCoins.run(spendRequest({requestId: "request_456"}));
  assert.equal(harness.coins, 90);
});

test("spendCoins without a requestId still works and each call debits", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({}));
  await spendCoins.run(spendRequest({}));
  assert.equal(harness.coins, 90);
});

test("spendCoins rejects a malformed requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const requestId of ["short", "a".repeat(65), "bad/path_123", 12345678]) {
    await assert.rejects(() => spendCoins.run(spendRequest({requestId})), {code: "invalid-argument"});
  }
});

test("spendCoins caps reason at 200 characters", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({reason: "r".repeat(500)}));
  assert.equal(result.reason.length, 200);
  const [entry] = [...harness.ledger.values()];
  assert.equal((entry.reason as string).length, 200);
});

test("awardCoins caps reason at 200 characters", async (t) => {
  let ledger: Record<string, unknown> | undefined;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await callback({
      get: async () => ({exists: true, data: () => ({coins: 0, premium: true, coinState: {}}), id: "x"}),
      update: () => undefined,
      set: (_ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        ledger = data;
      },
    } as unknown as admin.firestore.Transaction);
  });
  const result = await awardCoins.run({
    auth: {uid: "user-1"},
    data: {action: "proDailyBonus", sourceTag: "test", reason: "r".repeat(500)},
  } as unknown as Parameters<typeof awardCoins.run>[0]);
  assert.equal(result.changed, true);
  assert.equal(result.reason.length, 200);
  assert.equal((ledger?.reason as string).length, 200);
});

test("duplicateSpendResponse falls back to the live balance when the ledger lacks balances", () => {
  const result = duplicateSpendResponse({bypassed: false}, {id: "spend_1"}, 40, "why");
  assert.equal(result.currentBalance, 40);
  assert.equal(result.previousBalance, 40);
  assert.equal(result.delta, 0);
  assert.equal(result.transactionId, "spend_1");
});

test("refundableDelta: an unreadable delta is not refundable", () => {
  for (const delta of [undefined, "abc", Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.equal(refundableDelta(debitFixture({delta}), "user-1", NOW), null);
  }
});

test("refundableDelta: a longer window lets an older debit through", () => {
  const old = debitFixture({createdAt: {toMillis: () => NOW - 7_200_000}});
  assert.throws(() => refundableDelta(old, "user-1", NOW), {code: "failed-precondition"});
  assert.equal(refundableDelta(old, "user-1", NOW, 86_400_000), 15);
});

test("spendCoins: a replay of a refunded requestId is refused and never debits again", async (t) => {
  const harness: SpendHarness = {
    coins: 100,
    ledger: new Map([["spend_user-1_request_123", {id: "spend_user-1_request_123", status: "refunded", delta: -5}]]),
  };
  mockSpendTransactions(t, harness);
  const replay = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(replay.success, false);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "spend_refunded");
  assert.equal(replay.currentBalance, 100);
  assert.equal(harness.coins, 100);
});

test("spendCoins: a premium member skips the cost of a filter only when asking to bypass", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const bypassed = await spendCoins.run(spendRequest({allowPremiumBypass: true}));
  assert.equal(bypassed.success, true);
  assert.equal(bypassed.bypassed, true);
  assert.equal(harness.coins, 100);
  assert.equal(harness.ledger.size, 0);
  const charged = await spendCoins.run(spendRequest({}));
  assert.equal(charged.changed, true);
  assert.equal(harness.coins, 95);
});

test("spendCoins: a caller who is not premium is charged even with allowPremiumBypass", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: false, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({allowPremiumBypass: true}));
  assert.equal(result.bypassed, false);
  assert.equal(result.changed, true);
  assert.equal(harness.coins, 95);
  assert.equal(harness.ledger.size, 1);
});

test("spendCoins: allowPremiumBypass is ignored for aiGeneration, so a premium member pays half", async (t) => {
  const harness: SpendHarness = {coins: 200, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({action: "aiGeneration", amount: 75, allowPremiumBypass: true}));
  assert.equal(result.success, true);
  assert.equal(result.bypassed, false);
  assert.equal(result.delta, -38);
  assert.equal(harness.coins, 162);
  assert.equal(harness.ledger.size, 1);
});

test("spendCoins: allowPremiumBypass still works for premiumWallpaperDownload and premiumFilter", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  for (const action of ["premiumWallpaperDownload", "premiumFilter"]) {
    const result = await spendCoins.run(spendRequest({action, allowPremiumBypass: true}));
    assert.equal(result.bypassed, true, action);
  }
  assert.equal(harness.coins, 100);
});

test("spendCoins: aiGeneration accepts only 10, 75 and 100", async (t) => {
  const harness: SpendHarness = {coins: 1000, ledger: new Map()};
  mockSpendTransactions(t, harness);
  for (const amount of [10, 75, 100]) {
    const result = await spendCoins.run(spendRequest({action: "aiGeneration", amount}));
    assert.equal(result.delta, -amount);
  }
  for (const amount of [0, 11, "75", -75, null, undefined]) {
    await assert.rejects(() => spendCoins.run(spendRequest({action: "aiGeneration", amount})),
      {code: "invalid-argument"}, String(amount));
  }
  assert.equal(harness.coins, 1000 - 185);
});

test("spendCoins: label is trimmed, capped at 60 characters and stored as the description", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({reason: "content_abc", label: `  ${"L".repeat(80)}  `}));
  const [entry] = [...harness.ledger.values()];
  assert.equal(entry.description, "L".repeat(60));
  assert.equal(entry.reason, "content_abc");
});

test("spendCoins: without a label the description is the reason; a blank label counts as none", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({reason: "content_abc"}));
  await spendCoins.run(spendRequest({reason: "content_def", label: "   "}));
  await assert.rejects(() => spendCoins.run(spendRequest({reason: "content_ghi", label: 42})),
    {code: "invalid-argument"});
  assert.deepEqual([...harness.ledger.values()].map((entry) => entry.description),
    ["content_abc", "content_def"]);
});

type Store = Map<string, Record<string, unknown>>;

/** An in-memory Firestore for the award and rescue callables: transaction reads, writes and plain doc reads. */
function mockStore(t: test.TestContext, store: Store, options: {wallEvidence?: boolean; candidateReadFails?: boolean} = {}): void {
  const ref = (name: string, id: string) => ({
    id,
    path: `${name}/${id}`,
    get: async () => ({exists: store.has(`${name}/${id}`), data: () => store.get(`${name}/${id}`)}),
  });
  t.mock.method(db, "collection", (name: string) => {
    if (options.wallEvidence && name === "walls") {
      return {where: (_field: string, _operator: string, email: string) => ({get: async () => ({docs: [...store]
        .filter(([path, wall]) => path.startsWith("walls/") && wall.email === email)
        .map(([path, wall]) => ({id: path.split("/").pop(), data: () => wall}))})})};
    }
    if (options.wallEvidence && name === "studioRuns") {
      return {doc: (runId: string) => ({collection: () => ({doc: (candidateId: string) => ({get: async () => {
        if (options.candidateReadFails) throw new Error("candidate read failed");
        const candidate = store.get(`studioRuns/${runId}/candidates/${candidateId}`);
        return {data: () => candidate};
      }})})})};
    }
    return {doc: (id: string) => ref(name, id)};
  });
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const staged = new Map<string, Record<string, unknown>>();
    await callback({
      get: async (r: {path: string}) => ({exists: store.has(r.path), data: () => store.get(r.path)}),
      update: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, {...(staged.get(r.path) ?? store.get(r.path)), ...data});
      },
      set: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, data);
      },
    } as unknown as admin.firestore.Transaction);
    for (const [path, data] of staged) store.set(path, data);
  });
}

const awardRequest = (data: Record<string, unknown>) => ({
  auth: {uid: "user-1"}, data: {sourceTag: "test", ...data},
}) as unknown as Parameters<typeof awardCoins.run>[0];

const userDoc = (extra: Record<string, unknown> = {}): Record<string, unknown> => ({coins: 0, coinState: {}, ...extra});

const firstUploadRequest = (email: string) => ({
  auth: {uid: "user-1", token: {email}},
  data: {sourceTag: "test", action: "firstWallpaperUpload"},
}) as unknown as Parameters<typeof awardCoins.run>[0];

test("awardCoins firstWallpaperUpload: an approved wall with verified Studio provenance is not upload evidence", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["walls/STUDIO1234", {email: "studio@example.com", review: true, origin: "studio",
      studioRunId: "d20261012", studioCandidateId: "d20261012-0"}],
    ["studioRuns/d20261012/candidates/d20261012-0", {wallId: "STUDIO1234"}],
  ]);
  mockStore(t, store, {wallEvidence: true});

  const result = await awardCoins.run(firstUploadRequest("studio@example.com"));
  assert.equal(result.success, false);
  assert.equal(result.reason, "first_upload_no_wall");
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
});

test("awardCoins firstWallpaperUpload: a Studio provenance read failure awards no coins", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["walls/STUDIO1234", {email: "studio@example.com", review: true, origin: "studio",
      studioRunId: "d20261012", studioCandidateId: "d20261012-0"}],
  ]);
  mockStore(t, store, {wallEvidence: true, candidateReadFails: true});

  await assert.rejects(awardCoins.run(firstUploadRequest("studio@example.com")), /candidate read failed/);
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
});

test("awardCoins firstWallpaperUpload: an approved community wall qualifies", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["walls/COMMUNITY1", {email: "artist@example.com", review: true}],
  ]);
  mockStore(t, store, {wallEvidence: true});

  const result = await awardCoins.run(firstUploadRequest("artist@example.com"));
  assert.equal(result.success, true);
  assert.equal(result.delta, 50);
  assert.equal(store.get("usersv2/user-1")?.coins, 50);
});

test("awardCoins firstWallpaperUpload: an unverified origin-studio claim qualifies as a community wall", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["walls/SPOOFED1234", {email: "artist@example.com", review: true, origin: "studio",
      studioRunId: "d20261012", studioCandidateId: "d20261012-0"}],
    ["studioRuns/d20261012/candidates/d20261012-0", {wallId: "OTHERWALL1"}],
  ]);
  mockStore(t, store, {wallEvidence: true});

  const result = await awardCoins.run(firstUploadRequest("artist@example.com"));
  assert.equal(result.success, true);
  assert.equal(result.delta, 50);
  assert.equal(store.get("usersv2/user-1")?.coins, 50);
});

test("awardCoins proDailyBonus: premium gets the lowest spin value once a day, others and repeats get nothing", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc({premium: true})]]);
  mockStore(t, store);
  const first = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(first.success, true);
  assert.equal(first.delta, 20);
  assert.equal(store.get("usersv2/user-1")?.coins, 20);
  const again = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(again.success, false);
  assert.equal(again.reason, "pro_bonus_already_claimed");
  assert.equal(store.get("usersv2/user-1")?.coins, 20);

  const freeStore: Store = new Map([["usersv2/user-1", userDoc({premium: false})]]);
  t.mock.reset();
  mockStore(t, freeStore);
  const free = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(free.success, false);
  assert.equal(free.reason, "pro_bonus_requires_premium");
  assert.equal(freeStore.get("usersv2/user-1")?.coins, 0);
});

test("awardCoins rewardedAd: two calls with one requestId credit the first-ad 20 once and count once", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  const first = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(first.success, true);
  assert.equal(first.delta, 20);
  assert.equal(first.currentBalance, 20);
  assert.equal(first.adsRemaining, 19);
  const replay = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(replay.success, true);
  assert.equal(replay.delta, 20);
  assert.equal(replay.previousBalance, 0);
  assert.equal(replay.currentBalance, 20);
  assert.equal(replay.adsRemaining, 19);
  assert.equal(store.get("usersv2/user-1")?.coins, 20);
  const rateDocs = [...store].filter(([path]) => path.startsWith("coinAdRateDaily/"));
  assert.equal(rateDocs.length, 1);
  assert.equal(rateDocs[0][1].count, 1);
  assert.ok(store.has("coinTransactions/award_user-1_request_123"));
});

test("awardCoins rewardedAd: a replay is not blocked by the 20 second gap and never changes the rate doc", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  const rateBefore = JSON.stringify([...store].filter(([path]) => path.startsWith("coinAdRateDaily/")));
  const blocked = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_456"}));
  assert.equal(blocked.success, false);
  assert.equal(blocked.reason, "rewarded_ad_limit");
  assert.equal(blocked.adsRemaining, 19);
  await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(JSON.stringify([...store].filter(([path]) => path.startsWith("coinAdRateDaily/"))), rateBefore);
});

test("awardCoins rewardedAd: without a requestId it still pays and reports the ads left", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  const result = await awardCoins.run(awardRequest({action: "rewardedAd"}));
  assert.equal(result.success, true);
  assert.equal(result.adsRemaining, 19);
  assert.ok(![...store.keys()].some((path) => path.startsWith("coinTransactions/award_")));
});

test("awardCoins rejects a malformed requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const requestId of ["short", "bad/path_123", 12345678]) {
    await assert.rejects(() => awardCoins.run(awardRequest({action: "rewardedAd", requestId})),
      {code: "invalid-argument"});
  }
});

function refundStore(debit: Record<string, unknown>): Store {
  return new Map([
    ["usersv2/user-1", userDoc({coins: 25})],
    ["coinTransactions/ctx_aiGeneration_1", debit],
  ]);
}

const aiDebit = (ageMs: number, overrides: Record<string, unknown> = {}) => ({
  userId: "user-1", type: "debit", action: "aiGeneration", status: "completed", delta: -75,
  createdAt: {toMillis: () => Date.now() - ageMs},
  ...overrides,
});

const refundRequest = () => ({
  ...awardRequest({action: "refund", transactionId: "ctx_aiGeneration_1"}),
  rawRequest: {headers: {authorization: "Bearer verified-caller-token"}},
} as unknown as Parameters<typeof awardCoins.run>[0]);

/** Stands in for the AI worker; returns the URLs that were asked. */
function mockWorker(t: test.TestContext, answer: () => Promise<Response>): string[] {
  const urls: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string) => {
    urls.push(url);
    return answer();
  });
  return urls;
}

const jsonResponse = (body: unknown, ok = true) => ({ok, status: ok ? 200 : 404, json: async () => body}) as Response;

test("awardCoins refund: an AI debit is refused when the worker says the image was made", async (t) => {
  const store = refundStore(aiDebit(60_000));
  mockStore(t, store);
  const asked = mockWorker(t, async () => jsonResponse({status: "succeeded"}));
  const result = await awardCoins.run(refundRequest());
  assert.equal(result.success, false);
  assert.equal(result.reason, "refund_denied_generation_succeeded");
  assert.equal(store.get("usersv2/user-1")?.coins, 25);
  assert.equal(store.get("coinTransactions/ctx_aiGeneration_1")?.status, "completed");
  assert.equal(asked.length, 1);
  assert.equal(asked[0], "https://prismwalls.com/api/ai/charges/ctx_aiGeneration_1/cancel");
});

test("awardCoins refund: an AI debit 2 hours old is refunded only after atomic cancellation", async (t) => {
  const store = refundStore(aiDebit(7_200_000));
  mockStore(t, store);
  mockWorker(t, async () => jsonResponse({status: "cancelled"}));
  const result = await awardCoins.run(refundRequest());
  assert.equal(result.success, true);
  assert.equal(result.delta, 75);
  assert.equal(store.get("usersv2/user-1")?.coins, 100);
  assert.equal(store.get("coinTransactions/ctx_aiGeneration_1")?.status, "refunded");
});

test("awardCoins refund: the 24 hour window ends after 24 hours", async (t) => {
  const store = refundStore(aiDebit(86_400_000 + 60_000));
  mockStore(t, store);
  mockWorker(t, async () => jsonResponse({status: "cancelled"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
});

test("awardCoins refund: unknown, pending and read-only evidence fail closed even for a young debit", async (t) => {
  const answers: Array<() => Promise<Response>> = [
    async () => {
      throw new Error("network down");
    },
    async () => jsonResponse({}, false),
    async () => jsonResponse({status: "teapot"}),
    async () => jsonResponse(null),
    async () => jsonResponse({status: "in_progress"}),
    async () => jsonResponse({status: "not_started"}),
    async () => jsonResponse({status: "failed"}),
  ];
  for (const answer of answers) {
    t.mock.reset();
    mockStore(t, refundStore(aiDebit(7_200_000)));
    mockWorker(t, answer);
    assert.equal((await awardCoins.run(refundRequest())).success, false);

    t.mock.reset();
    const store = refundStore(aiDebit(60_000));
    mockStore(t, store);
    mockWorker(t, answer);
    const result = await awardCoins.run(refundRequest());
    assert.equal(result.success, false);
    assert.equal(store.get("usersv2/user-1")?.coins, 25);
    assert.equal(store.get("coinTransactions/ctx_aiGeneration_1")?.status, "completed");
  }
});

test("awardCoins refund: AI_WORKER_BASE_URL overrides the worker address", async (t) => {
  const original = process.env.AI_WORKER_BASE_URL;
  process.env.AI_WORKER_BASE_URL = "https://worker.example/";
  t.after(() => {
    if (original === undefined) delete process.env.AI_WORKER_BASE_URL;
    else process.env.AI_WORKER_BASE_URL = original;
  });
  mockStore(t, refundStore(aiDebit(60_000)));
  const asked = mockWorker(t, async () => jsonResponse({status: "cancelled"}));
  await awardCoins.run(refundRequest());
  assert.equal(asked[0], "https://worker.example/api/ai/charges/ctx_aiGeneration_1/cancel");
});

test("awardCoins refund: a download debit never asks the worker", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc({coins: 0})],
    ["coinTransactions/ctx_aiGeneration_1", aiDebit(60_000, {action: "wallpaperDownload", delta: -5})],
  ]);
  mockStore(t, store);
  const asked = mockWorker(t, async () => jsonResponse({status: "succeeded"}));
  const result = await awardCoins.run(refundRequest());
  assert.equal(result.success, true);
  assert.equal(result.delta, 5);
  assert.equal(asked.length, 0);
});

test("AI refunds forward authenticated cancellation and retry safely after a Firestore abort", async (t) => {
  const store = refundStore(aiDebit(60_000));
  mockStore(t, store);
  let calls = 0;
  t.mock.method(globalThis, "fetch", async (_url: string, init: RequestInit) => {
    calls++;
    assert.equal(init.method, "POST");
    assert.equal(new Headers(init.headers).get("authorization"), "Bearer verified-caller-token");
    return jsonResponse({status: "cancelled"});
  });
  const run = db.runTransaction.bind(db);
  let abort = true;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (abort) {
      abort = false;
      await run(async (tx) => {
        const shadow = {get: tx.get.bind(tx), set: () => undefined, update: () => undefined};
        await callback(shadow as unknown as admin.firestore.Transaction);
      });
      throw new Error("Firestore commit aborted");
    }
    return run(callback);
  });
  await assert.rejects(() => awardCoins.run(refundRequest()), /Firestore commit aborted/);
  assert.equal(store.get("usersv2/user-1")?.coins, 25);
  assert.equal((await awardCoins.run(refundRequest())).success, true);
  assert.equal(store.get("usersv2/user-1")?.coins, 100);
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/user-1")?.coins, 100);
  assert.equal(calls, 2);
});

test("optional callable fields reject malformed values before Firestore access", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const data of [{reason: {}}, {label: []}, {amount: 10.5}, {amount: "10"},
    {pricingVersion: "2"}, {allowPremiumBypass: "true"}]) {
    await assert.rejects(() => spendCoins.run(spendRequest(data)), {code: "invalid-argument"});
  }
  await assert.rejects(() => awardCoins.run(awardRequest({reason: []})), {code: "invalid-argument"});
});

test("AI refunds without a forwardable caller token fail closed without contacting the worker", async (t) => {
  const store = refundStore(aiDebit(60_000));
  mockStore(t, store);
  const calls = mockWorker(t, async () => {
    throw new Error("must not contact worker");
  });
  const result = await awardCoins.run(awardRequest({action: "refund", transactionId: "ctx_aiGeneration_1"}));
  assert.equal(result.success, false);
  assert.equal(store.get("usersv2/user-1")?.coins, 25);
  assert.deepEqual(calls, []);
});

test("awardCoins refund: a premium-bypassed spend left no ledger doc, so there is nothing to refund", async (t) => {
  mockStore(t, new Map([["usersv2/user-1", userDoc({coins: 25})]]));
  const asked = mockWorker(t, async () => jsonResponse({status: "failed"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
  assert.equal(asked.length, 0);
});

test("awardCoins refund: an unreadable delta is refused", async (t) => {
  mockStore(t, refundStore(aiDebit(60_000, {delta: "lots"})));
  mockWorker(t, async () => jsonResponse({status: "failed"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
});

test("awardCoins profileCompletion and firstWallpaperUpload: a claimed flag blocks the award", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc({
    coinState: {profileCompletionRewarded: true, firstWallpaperUploadRewarded: true},
  })]]);
  mockStore(t, store);
  const profile = await awardCoins.run(awardRequest({action: "profileCompletion"}));
  assert.equal(profile.success, false);
  assert.equal(profile.reason, "profile_reward_already_claimed");
  const upload = await awardCoins.run(awardRequest({action: "firstWallpaperUpload"}));
  assert.equal(upload.success, false);
  assert.equal(upload.reason, "first_upload_reward_already_claimed");
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
});

// restoreStreak

const RESCUE_NOW = 1_700_000_000_000;

function rescueStore(coinState: Record<string, unknown>, coins = 300): Store {
  return new Map([["usersv2/user-1", {coins, premium: true, coinState: {streakCount: 1, streakDay: 1, streakBest: 20, ...coinState}}]]);
}

const rescueState = (overrides: Record<string, unknown> = {}) => ({
  rescue: {count: 20, expiresAtMs: RESCUE_NOW + 3_600_000, ...overrides},
});

const rescueRequest = (requestId: unknown = "request_123") => ({
  auth: {uid: "user-1"}, data: {requestId},
}) as unknown as Parameters<typeof restoreStreak.run>[0];

function mockStoreAt(t: test.TestContext, store: Store): void {
  mockStore(t, store);
  t.mock.method(Date, "now", () => RESCUE_NOW);
}

test("restoreStreak: restores count + 1, debits 100 and writes one ledger row", async (t) => {
  const store = rescueStore(rescueState());
  mockStoreAt(t, store);
  const result = await restoreStreak.run(rescueRequest());
  assert.equal(result.success, true);
  assert.equal(result.streakCount, 21);
  assert.equal(result.delta, -STREAK_RESCUE_COST);
  assert.equal(result.currentBalance, 200);
  assert.equal(result.transactionId, "ctx_streakRescue_user-1_request_123");
  const user = store.get("usersv2/user-1") ?? {};
  assert.equal(user.coins, 200);
  assert.equal(user["coinState.streakCount"], 21);
  assert.equal(user["coinState.streakDay"], 7);
  assert.equal(user["coinState.streakBest"], 21);
  assert.equal(user["coinState.rescueLastAt"], RESCUE_NOW);
  assert.ok("coinState.rescue" in user);
  const ledger = store.get("coinTransactions/ctx_streakRescue_user-1_request_123");
  assert.equal(ledger?.delta, -100);
  assert.equal(ledger?.type, "debit");
  assert.equal(ledger?.reason, "streak_rescue");
  assert.equal(ledger?.balanceAfter, 200);
});

test("restoreStreak: a replay with the same requestId does not charge again", async (t) => {
  const store = rescueStore(rescueState());
  mockStoreAt(t, store);
  await restoreStreak.run(rescueRequest());
  const coinsAfter = store.get("usersv2/user-1")?.coins;
  const replay = await restoreStreak.run(rescueRequest());
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "duplicate");
  assert.equal(store.get("usersv2/user-1")?.coins, coinsAfter);
});

const refusals: Array<[string, Record<string, unknown>, number, string]> = [
  ["no rescue offer", {}, 300, "streak_rescue_unavailable"],
  ["an expired window", rescueState({expiresAtMs: RESCUE_NOW - 1}), 300, "streak_rescue_expired"],
  ["a streak under 7 days", rescueState({count: 6}), 300, "streak_rescue_too_short"],
  ["a rescue bought 29 days ago", {...rescueState(), rescueLastAt: RESCUE_NOW - 29 * 86_400_000}, 300,
    "streak_rescue_cooldown"],
  ["a streak already past the rescued count", {...rescueState(), streakCount: 25}, 300, "streak_rescue_not_needed"],
  ["too few coins", rescueState(), 99, "streak_rescue_insufficient_balance"],
];

for (const [name, coinState, coins, reason] of refusals) {
  test(`restoreStreak: refuses ${name} and changes nothing`, async (t) => {
    const store = rescueStore(coinState, coins);
    const before = JSON.stringify([...store]);
    mockStoreAt(t, store);
    const result = await restoreStreak.run(rescueRequest());
    assert.equal(result.success, false);
    assert.equal(result.reason, reason);
    assert.equal(result.insufficientBalance, reason === "streak_rescue_insufficient_balance");
    assert.equal(JSON.stringify([...store]), before);
  });
}

test("restoreStreak: a rescue bought 31 days ago is allowed again", async (t) => {
  const store = rescueStore({...rescueState(), rescueLastAt: RESCUE_NOW - 31 * 86_400_000});
  mockStoreAt(t, store);
  const result = await restoreStreak.run(rescueRequest());
  assert.equal(result.success, true);
});

test("restoreStreak validates auth and requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  await assert.rejects(() => restoreStreak.run({data: {requestId: "request_123"}} as
    Parameters<typeof restoreStreak.run>[0]), {code: "unauthenticated"});
  for (const requestId of [null, 12345678, "short", "bad/path_123"]) {
    await assert.rejects(() => restoreStreak.run(rescueRequest(requestId)), {code: "invalid-argument"});
  }
  await assert.rejects(() => restoreStreak.run({auth: {uid: "user-1"}, data: {}} as
    Parameters<typeof restoreStreak.run>[0]), {code: "invalid-argument"});
});

// processReferral

const REFERRAL_NOW = Date.now();
const authUser = (createdMsAgo: number) => ({metadata: {creationTime: new Date(REFERRAL_NOW - createdMsAgo).toUTCString()}});

function mockReferral(t: test.TestContext, store: Store, users: Record<string, unknown>) {
  t.mock.method(admin.auth(), "getUser", async (id: string) => {
    if (!(id in users)) throw Object.assign(new Error("none"), {code: "auth/user-not-found"});
    return users[id];
  });
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const staged = new Map<string, Record<string, unknown>>();
    await callback({
      get: async (r: {path?: string}) => r.path == null ?
        {docs: [], size: 0} :
        {exists: store.has(r.path as string), data: () => store.get(r.path as string)},
      update: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, {...(staged.get(r.path) ?? store.get(r.path)), ...data});
      },
      set: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, data);
      },
    } as unknown as admin.firestore.Transaction);
    for (const [path, data] of staged) store.set(path, data);
  });
}

const referralRequest = (inviter = "inviter-1") => ({
  auth: {uid: "user-1"}, data: {inviterUserId: inviter},
}) as unknown as Parameters<typeof processReferral.run>[0];

test("processReferral: a missing inviter doc is not-found", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  await assert.rejects(() => processReferral.run(referralRequest()), {code: "not-found"});
});

test("processReferral: a caller or inviter missing from Firebase Auth is not-found", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()], ["usersv2/inviter-1", userDoc()]]);
  mockReferral(t, store, {"inviter-1": authUser(86_400_000)});
  await assert.rejects(() => processReferral.run(referralRequest()), {code: "not-found"});
});

test("processReferral: a permanent skip marks the referral processed and pays nobody", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["usersv2/inviter-1", userDoc()],
  ]);
  // The inviter is younger than the caller, so the referral can never pay.
  mockReferral(t, store, {"user-1": authUser(86_400_000), "inviter-1": authUser(1000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.success, false);
  assert.equal(result.reason, "referral_inviter_not_older");
  assert.equal((store.get("usersv2/user-1")?.coinState as Record<string, unknown>).referralRewarded, true);
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
  assert.equal(store.get("usersv2/inviter-1")?.coins, 0);
});

test("processReferral: a daily-limit skip stays retryable", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["usersv2/inviter-1", userDoc()],
    ["referralStats/inviter-1", {day: new Date().toISOString().slice(0, 10), count: 10, total: 10}],
  ]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.reason, "referral_inviter_daily_limit");
  assert.equal((store.get("usersv2/user-1")?.coinState as Record<string, unknown>).referralRewarded, undefined);
});

test("processReferral: a valid referral pays both sides 100", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc({xp: 1000})],
    ["usersv2/inviter-1", userDoc({coins: 5, xp: 2000})]]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.success, true);
  assert.equal(store.get("usersv2/user-1")?.coins, 100);
  assert.equal(store.get("usersv2/inviter-1")?.coins, 105);
  assert.equal(result.xpPolicyVersion, 1);
  assert.equal(result.xpAwarded, 0);
  assert.equal(result.xp, 1000);
  const replay = await processReferral.run(referralRequest());
  assert.equal(replay.xpAwarded, 0);
  assert.equal(replay.xp, 1000);
  assert.equal(store.get("usersv2/inviter-1")?.xp, 2000);
});

// Economy v2 on the in-memory Firestore

type FakeStore = ReturnType<typeof installFakeDb>;
const USER = "usersv2/user-1";
const PRIVATE = `${USER}/private/economy`;
const DAY_MS = 86_400_000;

const v2Spend = (data: Record<string, unknown>) => spendCoins.run({
  auth: {uid: "user-1"}, data: {sourceTag: "test", pricingVersion: 2, ...data},
} as unknown as Parameters<typeof spendCoins.run>[0]);

const legacySpend = (data: Record<string, unknown>) => spendCoins.run({
  auth: {uid: "user-1"}, data: {sourceTag: "test", ...data},
} as unknown as Parameters<typeof spendCoins.run>[0]);

const spinRequest = (requestId = "spin_request_1") => ({
  auth: {uid: "user-1"}, data: {requestId},
}) as unknown as Parameters<typeof claimProSpin.run>[0];

/** Pins Date.now so tests can step past the 20 second ad gap. Returns a setter. */
function clock(t: test.TestContext, start = Date.now()): (ms: number) => void {
  let now = start;
  t.mock.method(Date, "now", () => now);
  return (ms) => {
    now = ms;
  };
}

const ledgerFor = (store: FakeStore, prefix: string) =>
  [...store].filter(([path]) => path.startsWith(`coinTransactions/${prefix}`)).map(([, doc]) => doc);

test("rewardedAd: the first ad pays 20, the next pays 10, neither grants XP", async (t) => {
  const start = Date.now();
  const setNow = clock(t, start);
  const store = installFakeDb(t, {[USER]: {coins: 0}});
  const first = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "ad_request_1"}));
  assert.equal(first.delta, 20);
  assert.equal(first.adsRemaining, 19);
  setNow(start + 21_000);
  const second = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "ad_request_2"}));
  assert.equal(second.delta, 10);
  assert.equal(second.adsRemaining, 18);
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 30);
  assert.equal(user.xp, undefined);
  assert.equal(user.xpWeek, undefined);
  for (const result of [first, second]) {
    assert.equal(result.xpPolicyVersion, 1);
    assert.equal(result.xpAwarded, 0);
    assert.equal(result.xp, 0);
    assert.deepEqual(result.xpWeek, {weekKey: weekKey(start), xp: 0});
  }
  assert.deepEqual((user.coinState as Record<string, unknown>).adsToday,
    {day: new Date(start).toISOString().slice(0, 10), count: 2});
});

test("rewardedAd: later ads also preserve historical XP", async (t) => {
  const now = Date.now();
  const day = new Date(now).toISOString().slice(0, 10);
  const store = installFakeDb(t, {
    [USER]: {coins: 0, xp: 7},
    [`coinAdRateDaily/user-1_${day}`]: {count: 3, lastAt: now - 60_000},
  });
  const result = await awardCoins.run(awardRequest({action: "rewardedAd"}));
  assert.equal(result.delta, 10);
  assert.equal(store.get(USER)?.coins, 10);
  assert.equal(store.get(USER)?.xp, 7);
});

test("rewardedAd: the cap comes from award.rewardedAdMaxPerDay", async (t) => {
  const now = Date.now();
  const day = new Date(now).toISOString().slice(0, 10);
  installFakeDb(t, {
    [USER]: {coins: 0},
    [ECONOMY_CONFIG_DOC]: {award: {rewardedAdMaxPerDay: 2}},
    [`coinAdRateDaily/user-1_${day}`]: {count: 2, lastAt: now - 60_000},
  });
  const result = await awardCoins.run(awardRequest({action: "rewardedAd"}));
  assert.equal(result.success, false);
  assert.equal(result.reason, "rewarded_ad_limit");
  assert.equal(result.adsRemaining, 0);
});

test("rewardedAd: completes today's watch_ad bonus quest and bumps rev", async (t) => {
  const now = Date.now();
  const quests = buildQuestState(undefined, now, false);
  assert.equal(quests.bonus.event, "watch_ad");
  const store = installFakeDb(t, {[USER]: {coins: 0}, [PRIVATE]: {rev: 4, quests}});
  await awardCoins.run(awardRequest({action: "rewardedAd"}));
  const priv = store.get(PRIVATE) ?? {};
  assert.equal(priv.rev, 5);
  const bonus = (priv.quests as {bonus: {progress: number; claimed: boolean}}).bonus;
  assert.equal(bonus.claimed, true);
  assert.equal(bonus.progress, 1);
  assert.equal(store.get(USER)?.coins, 20);
});

test("refund: gives the coins back with no XP", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 0, xp: 5},
    "coinTransactions/tx1": {userId: "user-1", type: "debit", status: "completed", action: "wallpaperDownload",
      delta: -10, createdAt: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
  });
  const result = await awardCoins.run(awardRequest({action: "refund", transactionId: "tx1"}));
  assert.equal(result.delta, 10);
  assert.equal(store.get(USER)?.xp, 5);
});

test("spendCoins v2: the first 3 downloads ever are free, the 4th pays 10", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 100}});
  for (const left of [2, 1, 0]) {
    const free = await v2Spend({action: "wallpaperDownload"});
    assert.equal(free.success, true);
    assert.equal(free.changed, false);
    assert.equal(free.bypassed, true);
    assert.equal(free.reason, "grace_download");
    assert.equal(free.graceDownloadsLeft, left);
  }
  assert.equal(store.get(PRIVATE)?.graceDownloadsUsed, 3);
  assert.equal(store.get(PRIVATE)?.rev, 3);
  const paid = await v2Spend({action: "wallpaperDownload"});
  assert.equal(paid.changed, true);
  assert.equal(paid.delta, -10);
  assert.equal(store.get(USER)?.coins, 90);
});

test("spendCoins v2: grace covers wallpaperDownload only and premium walls cost 25", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 100}});
  const result = await v2Spend({action: "premiumWallpaperDownload"});
  assert.equal(result.delta, -25);
  assert.equal(store.get(USER)?.coins, 75);
  assert.equal(store.get(PRIVATE), undefined);
});

test("spendCoins legacy: no pricingVersion pays 5 with no grace while the legacy window is open", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 100}});
  const result = await legacySpend({action: "wallpaperDownload"});
  assert.equal(result.delta, -5);
  assert.equal(store.get(USER)?.coins, 95);
  assert.equal(store.get(PRIVATE), undefined);
});

test("spendCoins legacy: after flags.legacyPricingUntil a legacy client pays the v2 price", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 100},
    [ECONOMY_CONFIG_DOC]: {flags: {legacyPricingUntil: new Date(Date.now() - 1000).toISOString()}},
  });
  const result = await legacySpend({action: "premiumWallpaperDownload"});
  assert.equal(result.delta, -25);
  assert.equal(store.get(USER)?.coins, 75);
});

test("spendCoins: a price override in economyConfig is charged", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 100},
    [PRIVATE]: {graceDownloadsUsed: 3},
    [ECONOMY_CONFIG_DOC]: {spend: {wallpaperDownload: 12}},
  });
  assert.equal((await v2Spend({action: "wallpaperDownload"})).delta, -12);
  assert.equal(store.get(USER)?.coins, 88);
});

test("spendCoins aiGeneration: Pro pays half rounded up and the ledger records tier and base price", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 200, premium: true}});
  const v2 = await v2Spend({action: "aiGeneration", qualityTier: "balanced", requestId: "ai_request_1"});
  assert.equal(v2.delta, -38);
  const ledger = store.get("coinTransactions/spend_user-1_ai_request_1") ?? {};
  assert.equal(ledger.qualityTier, "balanced");
  assert.equal(ledger.basePrice, 75);
  assert.equal(ledger.delta, -38);
  const legacy = await legacySpend({action: "aiGeneration", amount: 10});
  assert.equal(legacy.delta, -5);
  assert.equal(store.get(USER)?.coins, 157);
});

test("spendCoins aiGeneration: a free user pays the tier price; a bad tier is refused", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 200}});
  assert.equal((await v2Spend({action: "aiGeneration", qualityTier: "quality"})).delta, -100);
  for (const data of [{qualityTier: "ultra"}, {qualityTier: "fast ", amount: 10}, {qualityTier: 10}]) {
    await assert.rejects(() => v2Spend({action: "aiGeneration", ...data}), {code: "invalid-argument"});
  }
  assert.equal(store.get(USER)?.coins, 100);
});

test("spendCoins: an active premium pass opens premium walls and previews without allowPremiumBypass", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 100},
    [PRIVATE]: {passes: {premiumPassUntil: Date.now() + 3_600_000}},
  });
  for (const action of ["premiumWallpaperDownload", "premiumPreview24h"]) {
    const result = await v2Spend({action});
    assert.equal(result.bypassed, true, action);
    assert.equal(result.reason, `${action}_pass_bypass`);
  }
  assert.equal((await v2Spend({action: "premiumFilter"})).delta, -5);
  assert.equal(store.get(USER)?.coins, 95);
});

test("spendCoins: an expired premium pass pays", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 100}, [PRIVATE]: {passes: {premiumPassUntil: Date.now() - 1}}});
  assert.equal((await v2Spend({action: "premiumWallpaperDownload"})).delta, -25);
  assert.equal(store.get(USER)?.coins, 75);
});

test("spendCoins autoRotatePass7d: charges 50 and extends the pass from the later of now and its end", async (t) => {
  const now = Date.now();
  clock(t, now);
  const store = installFakeDb(t, {[USER]: {coins: 120}, [PRIVATE]: {rev: 2, passes: {premiumPassUntil: 5}}});
  const first = await v2Spend({action: "autoRotatePass7d"});
  assert.equal(first.delta, -50);
  assert.equal(first.passUntil, now + 7 * DAY_MS);
  const second = await v2Spend({action: "autoRotatePass7d"});
  assert.equal(second.passUntil, now + 14 * DAY_MS);
  const priv = store.get(PRIVATE) ?? {};
  assert.deepEqual(priv.passes, {premiumPassUntil: 5, autoRotatePassUntil: now + 14 * DAY_MS});
  assert.equal(priv.rev, 4);
  assert.equal(store.get(USER)?.coins, 20);
  const broke = await v2Spend({action: "autoRotatePass7d"});
  assert.equal(broke.insufficientBalance, true);
  assert.equal((store.get(PRIVATE)?.passes as Record<string, number>).autoRotatePassUntil, now + 14 * DAY_MS);
});

test("spendCoins liveWallpaperStyle: unlocks one style for 7 days and a second apply is free", async (t) => {
  const now = Date.now();
  clock(t, now);
  const store = installFakeDb(t, {[USER]: {coins: 50}});
  const paid = await v2Spend({action: "liveWallpaperStyle", styleId: "neon_wave"});
  assert.equal(paid.delta, -20);
  assert.equal(paid.passUntil, now + 7 * DAY_MS);
  const again = await v2Spend({action: "liveWallpaperStyle", styleId: "neon_wave"});
  assert.equal(again.bypassed, true);
  assert.equal(again.reason, "liveWallpaperStyle_already_unlocked");
  assert.equal(again.passUntil, now + 7 * DAY_MS);
  assert.equal((await v2Spend({action: "liveWallpaperStyle", styleId: "aurora"})).delta, -20);
  assert.deepEqual((store.get(PRIVATE)?.passes as Record<string, unknown>).liveStyles,
    {neon_wave: now + 7 * DAY_MS, aurora: now + 7 * DAY_MS});
  assert.equal(store.get(USER)?.coins, 10);
});

test("spendCoins liveWallpaperStyle: needs a valid styleId; Pro with bypass pays nothing", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 50, premium: true}});
  for (const styleId of [undefined, "", "a", "Neon", "__proto__", "x".repeat(41), "bad-id"]) {
    await assert.rejects(() => v2Spend({action: "liveWallpaperStyle", styleId}), {code: "invalid-argument"}, String(styleId));
  }
  const pro = await v2Spend({action: "liveWallpaperStyle", styleId: "neon", allowPremiumBypass: true});
  assert.equal(pro.reason, "liveWallpaperStyle_premium_bypass");
  assert.equal(store.get(USER)?.coins, 50);
});

test("spendCoins: a grace download with a requestId writes a zero receipt and a replay uses no more grace", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 100}});
  const first = await v2Spend({action: "wallpaperDownload", requestId: "grace_request_1"});
  const replay = await v2Spend({action: "wallpaperDownload", requestId: "grace_request_1"});
  for (const result of [first, replay]) {
    assert.equal(result.success, true);
    assert.equal(result.changed, false);
    assert.equal(result.bypassed, true);
    assert.equal(result.reason, "grace_download");
    assert.equal(result.graceDownloadsLeft, 2);
    assert.equal(result.delta, 0);
  }
  assert.equal(store.get(PRIVATE)?.graceDownloadsUsed, 1);
  const receipt = store.get("coinTransactions/spend_user-1_grace_request_1") ?? {};
  assert.equal(receipt.status, "completed");
  assert.equal(receipt.delta, 0);
  assert.equal(receipt.reason, "grace_download");
  assert.equal(receipt.action, "wallpaperDownload");
  assert.equal(store.get(USER)?.coins, 100);
});

test("spendCoins: pass and premium bypasses replay from their receipt after the pass or premium ends", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 100, premium: true},
    [PRIVATE]: {passes: {premiumPassUntil: Date.now() + 3_600_000}},
  });
  const pass = await v2Spend({action: "premiumPreview24h", requestId: "pass_request_1"});
  const bypass = await v2Spend({action: "premiumFilter", allowPremiumBypass: true, requestId: "bypass_request_1"});
  assert.equal(pass.reason, "premiumPreview24h_pass_bypass");
  assert.equal(bypass.reason, "premiumFilter_premium_bypass");
  store.set(USER, {coins: 100, premium: false});
  store.set(PRIVATE, {passes: {}});
  const passReplay = await v2Spend({action: "premiumPreview24h", requestId: "pass_request_1"});
  const bypassReplay = await v2Spend({action: "premiumFilter", allowPremiumBypass: true, requestId: "bypass_request_1"});
  assert.equal(passReplay.bypassed, true);
  assert.equal(passReplay.changed, false);
  assert.equal(passReplay.reason, "premiumPreview24h_pass_bypass");
  assert.equal(bypassReplay.bypassed, true);
  assert.equal(bypassReplay.reason, "premiumFilter_premium_bypass");
  assert.equal(store.get("coinTransactions/spend_user-1_bypass_request_1")?.delta, 0);
  assert.equal(store.get(USER)?.coins, 100);
});

test("spendCoins: a paid replay returns the stored pass, style and AI fields without charging again", async (t) => {
  const now = Date.now();
  const setNow = clock(t, now);
  const store = installFakeDb(t, {[USER]: {coins: 200}});
  const pass = await v2Spend({action: "autoRotatePass7d", requestId: "rotate_request_1"});
  const style = await v2Spend({action: "liveWallpaperStyle", styleId: "neon_wave", requestId: "style_request_1"});
  const ai = await v2Spend({action: "aiGeneration", qualityTier: "fast", requestId: "ai_request_9"});
  assert.equal(ai.qualityTier, "fast");
  assert.equal(ai.basePrice, 10);
  setNow(now + DAY_MS);
  const passReplay = await v2Spend({action: "autoRotatePass7d", requestId: "rotate_request_1"});
  const styleReplay = await v2Spend({action: "liveWallpaperStyle", styleId: "neon_wave", requestId: "style_request_1"});
  const aiReplay = await v2Spend({action: "aiGeneration", qualityTier: "fast", requestId: "ai_request_9"});
  assert.equal(passReplay.passUntil, now + 7 * DAY_MS);
  assert.equal(passReplay.passUntil, pass.passUntil);
  assert.equal(styleReplay.styleId, "neon_wave");
  assert.equal(styleReplay.passUntil, style.passUntil);
  assert.equal(aiReplay.qualityTier, "fast");
  assert.equal(aiReplay.basePrice, 10);
  assert.equal(aiReplay.delta, -10);
  assert.equal(store.get(USER)?.coins, 120);
  assert.equal((store.get(PRIVATE)?.passes as Record<string, number>).autoRotatePassUntil, now + 7 * DAY_MS);
});

test("unlockPremiumPreview: a legacy client pays the legacy 10 inside the window, v2 pays the config price", async (t) => {
  const preview = (data: Record<string, unknown>) => unlockPremiumPreview.run({
    auth: {uid: "user-1"}, data: {collectionKey: `key_${Object.keys(data).length}`, ...data},
  } as unknown as Parameters<typeof unlockPremiumPreview.run>[0]);
  const store = installFakeDb(t, {[USER]: {coins: 100}, [ECONOMY_CONFIG_DOC]: {spend: {premiumPreview24h: 15}}});
  assert.equal((await preview({})).delta, -10);
  assert.equal((await preview({pricingVersion: 2})).delta, -15);
  assert.equal(store.get(USER)?.coins, 75);

  t.mock.reset();
  resetEconomyCache();
  installFakeDb(t, {
    [USER]: {coins: 100},
    [ECONOMY_CONFIG_DOC]: {
      spend: {premiumPreview24h: 15},
      flags: {legacyPricingUntil: new Date(Date.now() - 1000).toISOString()},
    },
  });
  assert.equal((await preview({})).delta, -15);
});

test("spendBasePrice: legacy table only for the four legacy actions and only inside the window", () => {
  const now = Date.parse("2026-10-17T00:00:00Z");
  const config = parseEconomy(null);
  assert.equal(spendBasePrice("premiumFilter", {}, config, now).basePrice, 5);
  assert.equal(spendBasePrice("premiumPreview24h", {}, config, now).basePrice, 10);
  assert.equal(spendBasePrice("wallpaperDownload", {pricingVersion: 2}, config, now).basePrice, 10);
  assert.equal(spendBasePrice("wallpaperDownload", {pricingVersion: 1}, config, now).basePrice, 5);
  assert.equal(spendBasePrice("liveWallpaperStyle", {}, config, now).basePrice, 20);
  assert.equal(spendBasePrice("wallpaperDownload", {}, config, Date.parse("2027-02-01T00:00:00Z")).basePrice, 10);
  assert.deepEqual(spendBasePrice("aiGeneration", {amount: 100}, config, now), {basePrice: 100, qualityTier: "quality"});
  for (const action of ["streakFreeze", "dropWall", "constructor", "toString"]) {
    assert.throws(() => spendBasePrice(action, {}, config, now), {code: "invalid-argument"}, action);
  }
});

test("claimProSpin: Pro spins once a UTC day, earns coins only, and replays the coin result", async (t) => {
  const now = Date.now();
  clock(t, now);
  t.mock.method(Math, "random", () => 0.7);
  const store = installFakeDb(t, {[USER]: {coins: 10, premium: true}});
  const spin = await claimProSpin.run(spinRequest());
  assert.equal(spin.success, true);
  assert.equal(spin.segment, 2);
  assert.equal(spin.coins, 50);
  assert.equal(spin.delta, 50);
  assert.equal(spin.currentBalance, 60);
  assert.equal(spin.transactionId, "ctx_proSpin_user-1_spin_request_1");
  const user = store.get(USER) ?? {};
  const today = new Date(now).toISOString().slice(0, 10);
  assert.equal((user.coinState as Record<string, unknown>).proSpinDate, today);
  assert.equal((user.coinState as Record<string, unknown>).proDailyBonusDate, today);
  assert.equal(user.xp, undefined);
  assert.equal(spin.xpAwarded, 0);
  assert.equal(spin.xp, 0);
  const ledger = store.get("coinTransactions/ctx_proSpin_user-1_spin_request_1") ?? {};
  assert.equal(ledger.action, "proSpin");
  assert.equal(ledger.segment, 2);
  assert.equal(ledger.coins, 50);

  t.mock.method(Math, "random", () => 0.99);
  const replay = await claimProSpin.run(spinRequest());
  assert.equal(replay.success, true);
  assert.equal(replay.coins, 50);
  assert.equal(replay.segment, 2);
  assert.equal(replay.currentBalance, 60);
  const again = await claimProSpin.run(spinRequest("spin_request_2"));
  assert.equal(again.success, false);
  assert.equal(again.reason, "pro_spin_already_claimed");
  assert.equal(store.get(USER)?.coins, 60);
  assert.equal(ledgerFor(store, "ctx_proSpin_").length, 1);
});

test("claimProSpin: free users are refused and the requestId is validated first", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 10}});
  const result = await claimProSpin.run(spinRequest());
  assert.equal(result.success, false);
  assert.equal(result.reason, "pro_spin_requires_premium");
  assert.equal(store.get(USER)?.coins, 10);
  for (const requestId of [undefined, "short", "bad/path_123"]) {
    await assert.rejects(() => claimProSpin.run({auth: {uid: "user-1"}, data: {requestId}} as
      Parameters<typeof claimProSpin.run>[0]), {code: "invalid-argument"});
  }
});

test("claimProSpin and proDailyBonus share one receipt a day in both orders", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 0, premium: true}});
  await claimProSpin.run(spinRequest());
  const bonus = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(bonus.success, false);
  assert.equal(bonus.reason, "pro_bonus_already_claimed");

  t.mock.reset();
  resetEconomyCache();
  const other = installFakeDb(t, {[USER]: {coins: 0, premium: true}});
  const legacy = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(legacy.delta, 20);
  const coinState = other.get(USER)?.coinState as Record<string, unknown>;
  assert.equal(coinState.proSpinDate, coinState.proDailyBonusDate);
  assert.equal((await claimProSpin.run(spinRequest())).reason, "pro_spin_already_claimed");
  assert.equal(other.get(USER)?.coins, 20);
  assert.ok((store.get(USER)?.coins as number) >= 20);
});

test("claimProSpin: completes today's pro_spin bonus quest", async (t) => {
  const quests = buildQuestState(undefined, Date.now(), true);
  assert.equal(quests.bonus.event, "pro_spin");
  const store = installFakeDb(t, {[USER]: {coins: 0, premium: true}, [PRIVATE]: {rev: 1, quests}});
  await claimProSpin.run(spinRequest());
  const priv = store.get(PRIVATE) ?? {};
  assert.equal(priv.rev, 2);
  assert.equal((priv.quests as {bonus: {claimed: boolean}}).bonus.claimed, true);
});

test("ad ordinals and every spin segment preserve XP and rank ownership", async (t) => {
  const now = Date.parse("2026-10-18T12:00:00Z");
  const today = "2026-10-18";
  const historical = {xp: 6001, xpWeek: {weekKey: weekKey(now), xp: 400}};
  const inventory = {owned: {theme_rose: 123, frame_silver: 456}};
  const activities = [
    ...[0, 2, 3].map((count) => ({kind: "ad", count, random: 0})),
    ...[0, 0.4, 0.65, 0.85, 0.95].map((random) => ({kind: "spin", count: 0, random})),
    {kind: "legacy", count: 0, random: 0},
  ];
  for (const [index, activity] of activities.entries()) {
    await t.test(`${activity.kind}/${index}`, async (sub) => {
      resetEconomyCache();
      clock(sub, now);
      sub.mock.method(Math, "random", () => activity.random);
      const store = installFakeDb(sub, {
        [USER]: {coins: 100, premium: true, ...historical},
        [PRIVATE]: {rev: 5, inventory},
        [ECONOMY_CONFIG_DOC]: {xp: {perCoinEarned: 10}},
        [`coinAdRateDaily/user-1_${today}`]: {count: activity.count, lastAt: now - 60_000},
      });
      const result = activity.kind === "spin" ? await claimProSpin.run(spinRequest()) :
        await awardCoins.run(awardRequest({action: activity.kind === "ad" ? "rewardedAd" : "proDailyBonus",
          requestId: "fixed_xp_request"}));
      const expectedCoins = activity.kind === "spin" ? DEFAULT_ECONOMY.award.proSpin[index - 3].coins :
        activity.kind === "ad" && activity.count > 0 ? 10 : 20;
      assert.equal(result.delta, expectedCoins);
      assert.equal(store.get(USER)?.coins, 100 + expectedCoins);
      assert.equal(result.xpPolicyVersion, 1);
      assert.equal(result.xpAwarded, 0);
      assert.equal(result.xp, historical.xp);
      assert.deepEqual(result.xpWeek, historical.xpWeek);
      assert.deepEqual(store.get(PRIVATE)?.inventory, inventory);
      assert.equal(store.get(USER)?.xp, historical.xp);
      assert.deepEqual(store.get(USER)?.xpWeek, historical.xpWeek);
    });
  }
});

test("routine one-time XP ignores coin prices, Pro and legacy conversion, preserves rank ownership", async (t) => {
  for (const premium of [false, true]) {
    for (const coins of [1, 999]) {
      await t.test(`${premium}/${coins}`, async (sub) => {
        resetEconomyCache();
        const now = Date.parse("2026-10-18T12:00:00Z");
        clock(sub, now);
        const store = installFakeDb(sub, {
          [USER]: {coins: 100, premium, xp: 490, username: "artist", bio: "bio", links: {site: "https://test"},
            profilePhoto: "photo", xpWeek: {weekKey: weekKey(now), xp: 10}},
          [PRIVATE]: {rev: 2, inventory: {owned: {theme_rose: 123}}},
          [ECONOMY_CONFIG_DOC]: {award: {firstWallpaperUpload: coins, profileCompletion: coins}, xp: {perCoinEarned: 10}},
          "walls/approved": {email: "artist@example.com", review: true},
        });
        const profile = await awardCoins.run(awardRequest({action: "profileCompletion"}));
        assert.equal(profile.delta, coins);
        assert.equal(profile.xpAwarded, 25);
        assert.equal(profile.xp, 515);
        const upload = await awardCoins.run(firstUploadRequest("artist@example.com"));
        assert.equal(upload.delta, coins);
        assert.equal(upload.xpAwarded, 50);
        assert.equal(upload.xp, 565);
        assert.deepEqual(upload.xpWeek, {weekKey: weekKey(now), xp: 85});
        const owned = (store.get(PRIVATE)?.inventory as {owned: Record<string, number>}).owned;
        assert.equal(owned.theme_rose, 123);
        assert.ok(Object.keys(owned).length > 1);
        store.set(USER, {...store.get(USER), xp: 900, xpWeek: {weekKey: weekKey(now), xp: 300}});
        for (const response of [await awardCoins.run(awardRequest({action: "profileCompletion"})),
          await awardCoins.run(firstUploadRequest("artist@example.com"))]) {
          assert.equal(response.xpAwarded, 0);
          assert.equal(response.xp, 900);
          assert.deepEqual(response.xpWeek, {weekKey: weekKey(now), xp: 300});
        }
        assert.equal(store.get(USER)?.coins, 100 + 2 * coins);
      });
    }
  }
});

test("ad and spin replays report the current XP snapshot, never stored receipt totals", async (t) => {
  const now = Date.parse("2026-10-18T12:00:00Z");
  clock(t, now);
  const store = installFakeDb(t, {[USER]: {coins: 100, premium: true, xp: 10}});
  const adRequest = awardRequest({action: "rewardedAd", requestId: "fixed_xp_replay"});
  await awardCoins.run(adRequest);
  await claimProSpin.run(spinRequest());
  store.set(USER, {...store.get(USER), xp: 1000, xpWeek: {weekKey: weekKey(now), xp: 200}});
  for (const result of [await awardCoins.run(adRequest), await claimProSpin.run(spinRequest()),
    await claimProSpin.run(spinRequest("different_request"))]) {
    assert.equal(result.xpAwarded, 0);
    assert.equal(result.xp, 1000);
    assert.deepEqual(result.xpWeek, {weekKey: weekKey(now), xp: 200});
  }
});

test("buyStreakFreeze and restoreStreak: prices come from the config", async (t) => {
  const store = installFakeDb(t, {
    [USER]: {coins: 100, coinState: {streakCount: 1, rescue: {count: 9, expiresAtMs: Date.now() + 3_600_000}}},
    [ECONOMY_CONFIG_DOC]: {spend: {streakFreeze: 30, streakRescue: 60}},
  });
  const freeze = await buyStreakFreeze.run({auth: {uid: "user-1"}, data: {requestId: "freeze_request"}} as
    Parameters<typeof buyStreakFreeze.run>[0]);
  assert.equal(freeze.delta, -30);
  const rescue = await restoreStreak.run(rescueRequest("rescue_request"));
  assert.equal(rescue.delta, -60);
  assert.equal(store.get(USER)?.coins, 10);
  assert.equal(DEFAULT_ECONOMY.spend.streakFreeze, 50);
});
