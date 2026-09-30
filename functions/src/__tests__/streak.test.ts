import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {
  claimDailyStreak,
  dayGap,
  isStreakAlive,
  localDateKeyFromUtc,
  pickFcmToken,
  planStreakClaim,
  resolveTimezoneOffset,
  sendStreakReminders,
  streakMilestone,
} from "../streak";

test("streak reminders use the session token, then the legacy field", () => {
  assert.equal(pickFcmToken("session-token", "legacy-token"), "session-token");
  assert.equal(pickFcmToken(undefined, "legacy-token"), "legacy-token");
  assert.equal(pickFcmToken(undefined, undefined), "");
});

test("streak timezone is fixed after first use", () => {
  assert.equal(resolveTimezoneOffset(undefined, 330), 330);
  assert.equal(resolveTimezoneOffset(330, 330), 330);
  assert.equal(resolveTimezoneOffset(330, -720), 330);
});

const st = (o: Partial<Parameters<typeof planStreakClaim>[0]> = {}) => ({
  lastKey: "2026-01-01",
  streakDay: 3,
  streakCount: 3,
  streakBest: 3,
  freezes: 0,
  ...o,
});

test("dayGap crosses month, year and leap boundaries", () => {
  assert.equal(dayGap("2024-02-28", "2024-03-01"), 2);
  assert.equal(dayGap("2025-12-31", "2026-01-01"), 1);
});

test("impossible and unparseable legacy dates reset without using freezes", () => {
  for (const lastKey of ["garbage", "2026-02-30", "2026-00-01", "2026-01-00", "2026-13-01"]) {
    assert.equal(Number.isNaN(dayGap(lastKey, "2026-03-03")), true);
    assert.equal(isStreakAlive(lastKey, "2026-03-03", 2), false);
    const plan = planStreakClaim(st({lastKey, freezes: 2}), "2026-03-03", false);
    assert.equal(plan.count, 1);
    assert.equal(plan.streakBroken, true);
    assert.equal(plan.freezesUsed, 0);
    assert.equal(plan.freezesLeft, 2);
  }
});

test("a retried claim that another call already committed returns no reward", async (t) => {
  const today = localDateKeyFromUtc(new Date(), 330);
  const yesterday = localDateKeyFromUtc(new Date(Date.now() - 86_400_000), 330);
  const attempts = [
    {coins: 100, premium: true, coinState: {lastDailyClaimDate: yesterday, streakDay: 6, streakCount: 6}},
    {coins: 175, premium: true, coinState: {lastDailyClaimDate: today, streakDay: 7, streakCount: 7}},
  ];
  const committedLedger: unknown[] = [];
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    for (let attempt = 0; attempt < attempts.length; attempt++) {
      await callback({
        get: async () => ({exists: true, data: () => attempts[attempt]}),
        update: () => undefined,
        set: (_ref: unknown, data: unknown) => {
          if (attempt === attempts.length - 1) committedLedger.push(data);
        },
      } as unknown as admin.firestore.Transaction);
    }
  });
  const result = await claimDailyStreak.run({
    auth: {uid: "user-1"}, data: {timezoneOffsetMinutes: 330, reminderEnabled: false},
  } as Parameters<typeof claimDailyStreak.run>[0]);
  assert.equal(result.claimed, false);
  assert.equal(result.alreadyClaimedToday, true);
  assert.equal(result.totalReward, 0);
  assert.equal(result.dailyReward, 0);
  assert.equal(result.streakBonusReward, 0);
  assert.equal(result.proBonusReward, 0);
  assert.equal(result.milestone, null);
  assert.equal(result.newBalance, 175);
  assert.deepEqual(committedLedger, []);
});

test("claim validates supplied inputs before reading the user", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const data of [
    {timezoneOffsetMinutes: "330"}, {timezoneOffsetMinutes: 330.5},
    {timezoneOffsetMinutes: -721}, {timezoneOffsetMinutes: 841}, {timezoneOffsetMinutes: null},
    {reminderEnabled: "false"}, {reminderEnabled: 1}, {reminderEnabled: null},
  ]) {
    await assert.rejects(() => claimDailyStreak.run({
      auth: {uid: "user-1"}, data,
    } as unknown as Parameters<typeof claimDailyStreak.run>[0]), {code: "invalid-argument"});
  }
});

for (const migrating of [false, true]) {
  test(`client-written timezone cannot grant another reward${migrating ? " during legacy backfill" : ""}`, async (t) => {
    const now = new Date();
    const lastKey = localDateKeyFromUtc(now, -720);
    let storedState: Record<string, unknown> = {};
    t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      await callback({
        get: async () => ({exists: true, data: () => ({coins: 100, coinState: {
          lastDailyClaimDate: lastKey,
          streakDay: 3,
          streakCount: 3,
          streakTimezoneOffsetMinutes: 840,
          ...(!migrating ? {streakClaimTimezoneOffsetMinutes: -720} : {}),
          streakLastClaimServerAt: admin.firestore.Timestamp.fromDate(now),
        }})}),
        update: (_ref: unknown, data: {coinState: Record<string, unknown>}) => {
          storedState = data.coinState;
        },
        set: () => {
          throw new Error("must not grant coins");
        },
      } as unknown as admin.firestore.Transaction);
    });
    const result = await claimDailyStreak.run({
      auth: {uid: "user-1"}, data: {timezoneOffsetMinutes: 840, reminderEnabled: false},
    } as Parameters<typeof claimDailyStreak.run>[0]);
    assert.equal(result.claimed, false);
    assert.equal(result.totalReward, 0);
    assert.equal(result.newBalance, 100);
    assert.equal(result.timezoneOffsetMinutes, migrating ? 840 : -720);
    assert.equal(storedState.streakClaimTimezoneOffsetMinutes, migrating ? 840 : -720);
    assert.equal(storedState.lastDailyClaimDate, result.todayLocalKey);
  });
}

test("reminders use the server-owned timezone after the client changes the legacy field", async (t) => {
  const today = localDateKeyFromUtc(new Date(), -720);
  const updates: Record<string, unknown>[] = [];
  const userDoc = {
    data: () => ({email: "", coinState: {
      streakDay: 3,
      streakCount: 3,
      streakFreezes: 0,
      lastDailyClaimDate: today,
      streakTimezoneOffsetMinutes: 840,
      streakClaimTimezoneOffsetMinutes: -720,
    }}),
    ref: {update: async (data: Record<string, unknown>) => updates.push(data)},
  };
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => ({empty: false, size: 1, docs: [userDoc]}),
  };
  t.mock.method(db, "collection", () => query);
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(updates.length, 1);
  const next = updates[0]["coinState.streakReminderNextAtUtc"] as admin.firestore.Timestamp;
  const localNext = new Date(next.toMillis() - 720 * 60_000);
  assert.equal(localNext.getUTCHours(), 20);
  assert.equal(dayGap(today, localDateKeyFromUtc(next.toDate(), -720)), 1);
});

test("local day key flips at the offset boundary", () => {
  assert.notEqual(
    localDateKeyFromUtc(new Date("2026-01-01T18:29:59Z"), 330),
    localDateKeyFromUtc(new Date("2026-01-01T18:30:00Z"), 330),
  );
  assert.notEqual(
    localDateKeyFromUtc(new Date("2026-01-01T11:59:59Z"), -720),
    localDateKeyFromUtc(new Date("2026-01-01T12:00:00Z"), -720),
  );
});

test("gap 1 continues; count 7 to 8 wraps to cycle day 1 with the base reward", () => {
  const p = planStreakClaim(st({streakCount: 7, streakDay: 7, lastKey: "2026-01-01"}), "2026-01-02", false);
  assert.equal(p.count, 8);
  assert.equal(p.cycleDay, 1);
  assert.equal(p.dailyReward, 5);
  assert.equal(p.streakBonusReward, 0);
  assert.equal(p.freezesUsed, 0);
});

test("count 14 pays cycle day 7 rewards; Pro adds 20", () => {
  const s = st({streakCount: 13, streakDay: 6});
  const p = planStreakClaim(s, "2026-01-02", false);
  assert.equal(p.cycleDay, 7);
  assert.equal(p.dailyReward, 15);
  assert.equal(p.streakBonusReward, 40);
  assert.equal(p.proBonusReward, 0);
  assert.equal(planStreakClaim(s, "2026-01-02", true).proBonusReward, 20);
});

test("gap 2 with 1 freeze saves the streak and pays nothing for the missed day", () => {
  const p = planStreakClaim(st({freezes: 1}), "2026-01-03", false);
  assert.equal(p.count, 4);
  assert.equal(p.freezesUsed, 1);
  assert.equal(p.freezesLeft, 0);
  assert.equal(p.streakBroken, false);
  assert.equal(p.dailyReward, 8);
  assert.equal(p.cycleDay, 4);
});

test("gap 3 with 1 freeze resets to 1 and keeps the freeze", () => {
  const p = planStreakClaim(st({freezes: 1}), "2026-01-04", false);
  assert.equal(p.count, 1);
  assert.equal(p.freezesUsed, 0);
  assert.equal(p.freezesLeft, 1);
  assert.equal(p.streakBroken, true);
});

test("gap 3 with 2 freezes saves and uses 2", () => {
  const p = planStreakClaim(st({freezes: 2}), "2026-01-04", false);
  assert.equal(p.count, 4);
  assert.equal(p.freezesUsed, 2);
  assert.equal(p.freezesLeft, 0);
});

test("gap <= 0 is already claimed with no reward", () => {
  for (const today of ["2026-01-01", "2025-12-31"]) {
    const p = planStreakClaim(st({freezes: 1}), today, true);
    assert.equal(p.alreadyClaimed, true);
    assert.equal(p.dailyReward + p.streakBonusReward + p.proBonusReward, 0);
    assert.equal(p.streakBroken, false);
    assert.equal(p.freezesLeft, 1);
  }
});

test("legacy state derives streakCount from streakDay and streakBest is the max", () => {
  const p = planStreakClaim({lastKey: "2026-01-01", streakDay: 5, freezes: 0}, "2026-01-02", false);
  assert.equal(p.previousCount, 5);
  assert.equal(p.count, 6);
  assert.equal(p.best, 6);
  const q = planStreakClaim(st({streakBest: 40, streakCount: 3}), "2026-01-02", false);
  assert.equal(q.best, 40);
});

test("first claim with no last key starts at 1", () => {
  const p = planStreakClaim(st({lastKey: "", streakCount: 0, streakDay: 0}), "2026-01-02", false);
  assert.equal(p.count, 1);
  assert.equal(p.streakBroken, false);
});

test("isStreakAlive honours freezes", () => {
  assert.equal(isStreakAlive("2026-01-01", "2026-01-02", 0), true);
  assert.equal(isStreakAlive("2026-01-01", "2026-01-03", 0), false);
  assert.equal(isStreakAlive("2026-01-01", "2026-01-03", 1), true);
  assert.equal(isStreakAlive("", "2026-01-03", 2), false);
});

test("milestone only at 7, 30, 100, 365; week completes on cycle day 7", () => {
  for (const n of [7, 30, 100, 365]) assert.equal(streakMilestone(n), n);
  for (const n of [1, 6, 8, 29, 31, 364]) assert.equal(streakMilestone(n), null);
  const p = planStreakClaim(st({streakCount: 6, streakDay: 6}), "2026-01-02", false);
  assert.equal(p.cycleDay === 7, true);
  assert.equal(planStreakClaim(st(), "2026-01-02", false).cycleDay === 7, false);
});

test("planStreakClaim: a doc with no streak to protect never burns freezes", () => {
  const plan = planStreakClaim(
    st({lastKey: "2026-01-01", streakDay: 0, streakCount: 0, freezes: 2}),
    "2026-01-03",
    false,
  );
  assert.equal(plan.count, 1);
  assert.equal(plan.freezesUsed, 0);
  assert.equal(plan.freezesLeft, 2);
});
