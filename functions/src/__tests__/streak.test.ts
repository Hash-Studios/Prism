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
  shouldRelockTimezone,
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

test("a signed-out user gets no streak reminder and the stored token is not read", async (t) => {
  const yesterday = localDateKeyFromUtc(new Date(Date.now() - 86_400_000), 0);
  const updates: Record<string, unknown>[] = [];
  let tokenReads = 0;
  const userDoc = {
    data: () => ({email: "sam@example.com", loggedIn: false, coinState: {
      streakDay: 3,
      streakCount: 3,
      streakFreezes: 0,
      lastDailyClaimDate: yesterday,
      streakTimezoneOffsetMinutes: 0,
      streakClaimTimezoneOffsetMinutes: 0,
    }}),
    ref: {
      id: "u1",
      update: async (data: Record<string, unknown>) => updates.push(data),
    },
  };
  t.mock.method(db, "doc", () => {
    tokenReads += 1;
    return {get: async () => ({data: () => ({fcmToken: "stale-token"})})};
  });
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => ({empty: false, size: 1, docs: [userDoc]}),
  };
  t.mock.method(db, "collection", () => query);
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 0);
  assert.equal(tokenReads, 0);
  assert.equal(updates.length, 1);
  assert.ok(!("coinState.streakReminderLastSentDate" in updates[0]));
  assert.ok(updates[0]["coinState.streakReminderNextAtUtc"] instanceof admin.firestore.Timestamp);
});

test("a signed-out reminder retries after 15 minutes and sends after sign-in", async (t) => {
  const start = new Date("2026-01-02T20:00:00Z");
  t.mock.timers.enable({apis: ["Date"], now: start});
  let loggedIn = false;
  let tokenReads = 0;
  let nextAt = admin.firestore.Timestamp.fromDate(start);
  let lastSentDate = "";
  const state = {
    streakDay: 3,
    streakCount: 3,
    streakFreezes: 0,
    streakReminderEnabled: true,
    lastDailyClaimDate: "2026-01-01",
    streakTimezoneOffsetMinutes: 0,
    streakClaimTimezoneOffsetMinutes: 0,
  };
  const userDoc = {
    data: () => ({email: "sam@example.com", loggedIn, coinState: {
      ...state,
      streakReminderLastSentDate: lastSentDate,
      streakReminderNextAtUtc: nextAt,
    }}),
    ref: {
      id: "u1",
      update: async (updates: Record<string, unknown>) => {
        const updatedNextAt = updates["coinState.streakReminderNextAtUtc"];
        if (updatedNextAt instanceof admin.firestore.Timestamp) nextAt = updatedNextAt;
        const updatedLastSentDate = updates["coinState.streakReminderLastSentDate"];
        if (typeof updatedLastSentDate === "string") lastSentDate = updatedLastSentDate;
      },
    },
  };
  t.mock.method(db, "doc", () => {
    tokenReads += 1;
    return {get: async () => ({data: () => ({fcmToken: "session-token"})})};
  });
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => {
      const due = nextAt.toMillis() <= Date.now();
      return {empty: !due, size: due ? 1 : 0, docs: due ? [userDoc] : []};
    },
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : {add: async () => undefined});
  const sentMessages: admin.messaging.Message[] = [];
  const send = t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    sentMessages.push(message);
    return "id";
  });

  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 0);
  assert.equal(tokenReads, 0);
  assert.equal(nextAt.toMillis(), start.getTime() + 15 * 60_000);

  t.mock.timers.setTime(start.getTime() + 15 * 60_000);
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 0);
  assert.equal(tokenReads, 0);
  assert.equal(nextAt.toMillis(), start.getTime() + 30 * 60_000);

  loggedIn = true;
  t.mock.timers.setTime(start.getTime() + 30 * 60_000);
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 1);
  assert.equal("token" in sentMessages[0] ? sentMessages[0].token : undefined, "session-token");
  assert.equal(tokenReads, 1);
  assert.equal(lastSentDate, "2026-01-02");
  assert.equal(nextAt.toDate().toISOString(), "2026-01-03T20:00:00.000Z");
});

test("a legacy streak user without loggedIn still gets a reminder", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T20:00:00Z")});
  const yesterday = "2026-01-01";
  const now = admin.firestore.Timestamp.now();
  const userDoc = {
    data: () => ({email: "legacy@example.com", coinState: {
      streakDay: 3,
      streakCount: 3,
      streakFreezes: 0,
      streakReminderEnabled: true,
      lastDailyClaimDate: yesterday,
      streakTimezoneOffsetMinutes: 0,
      streakClaimTimezoneOffsetMinutes: 0,
      streakReminderNextAtUtc: now,
    }}),
    ref: {
      id: "legacy-user",
      update: async () => undefined,
    },
  };
  t.mock.method(db, "doc", () => ({get: async () => ({data: () => ({fcmToken: "legacy-token"})})}));
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => ({empty: false, size: 1, docs: [userDoc]}),
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : {add: async () => undefined});
  const sentMessages: admin.messaging.Message[] = [];
  const send = t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    sentMessages.push(message);
    return "id";
  });

  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 1);
  assert.equal("token" in sentMessages[0] ? sentMessages[0].token : undefined, "legacy-token");
});

const DAY_MS = 86_400_000;

test("the timezone lock moves only for a different device offset after 24 hours", () => {
  const nowMs = Date.parse("2026-01-10T00:00:00Z");
  const base = {locked: -720, requested: 330, lastClaimAtMs: nowMs - DAY_MS, nowMs};
  assert.equal(shouldRelockTimezone(base), true);
  assert.equal(shouldRelockTimezone({...base, lastClaimAtMs: nowMs - DAY_MS + 1}), false);
  assert.equal(shouldRelockTimezone({...base, requested: -720}), false);
  assert.equal(shouldRelockTimezone({...base, requested: undefined}), false);
  assert.equal(shouldRelockTimezone({...base, locked: undefined}), false);
  assert.equal(shouldRelockTimezone({...base, lastClaimAtMs: undefined}), false);
});

test("a claim re-locks to the new device offset after 24 hours and keeps the streak", async (t) => {
  const now = new Date();
  const lastClaimAt = new Date(now.getTime() - 25 * 60 * 60 * 1000);
  let storedState: Record<string, unknown> = {};
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await callback({
      get: async () => ({exists: true, data: () => ({coins: 100, coinState: {
        lastDailyClaimDate: localDateKeyFromUtc(lastClaimAt, -720),
        streakDay: 3,
        streakCount: 3,
        streakTimezoneOffsetMinutes: -720,
        streakClaimTimezoneOffsetMinutes: -720,
        streakLastClaimServerAt: admin.firestore.Timestamp.fromDate(lastClaimAt),
      }})}),
      update: (_ref: unknown, data: {coinState: Record<string, unknown>}) => {
        storedState = data.coinState;
      },
      set: () => undefined,
    } as unknown as admin.firestore.Transaction);
  });
  const result = await claimDailyStreak.run({
    auth: {uid: "user-1"}, data: {timezoneOffsetMinutes: 330, reminderEnabled: false},
  } as Parameters<typeof claimDailyStreak.run>[0]);
  assert.equal(result.timezoneOffsetMinutes, 330);
  assert.equal(storedState.streakClaimTimezoneOffsetMinutes, 330);
  assert.equal(result.claimed, true);
  assert.equal(result.streakCount, 4);
});

type ReminderDoc = {
  data: () => Record<string, unknown>;
  ref: {id: string; update: (data: Record<string, unknown>) => Promise<void>};
};

function reminderDoc(id: string, updates: Record<string, unknown>[], failUpdate = false): ReminderDoc {
  return {
    data: () => ({email: `${id}@Example.com`, fcmToken: `token-${id}`, coinState: {
      streakDay: 3,
      streakCount: 3,
      streakFreezes: 0,
      streakReminderEnabled: true,
      lastDailyClaimDate: "2026-01-01",
      streakTimezoneOffsetMinutes: 0,
      streakClaimTimezoneOffsetMinutes: 0,
      streakReminderNextAtUtc: admin.firestore.Timestamp.now(),
    }}),
    ref: {
      id,
      update: async (data) => {
        if (failUpdate) throw new Error("write failed");
        updates.push(data);
      },
    },
  };
}

function mockReminderRun(t: test.TestContext, docs: ReminderDoc[], inbox: Array<{id?: string; data: unknown}> = []) {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T20:00:00Z")});
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => ({empty: docs.length === 0, size: docs.length, docs}),
  };
  t.mock.method(db, "collection", (name: string) => name === "usersv2" ? query : {
    add: async (data: unknown) => inbox.push({data}),
    doc: (id: string) => ({set: async (data: unknown) => inbox.push({id, data})}),
  });
  t.mock.method(db, "doc", () => ({get: async () => ({data: () => ({})})}));
}

test("the reminder marker is written before the push and the inbox doc uses the stored email casing", async (t) => {
  const updates: Record<string, unknown>[] = [];
  const inbox: Array<{id?: string; data: unknown}> = [];
  const order: string[] = [];
  const doc = reminderDoc("u1", updates);
  const update = doc.ref.update;
  doc.ref.update = async (data) => {
    order.push("update");
    await update(data);
  };
  mockReminderRun(t, [doc], inbox);
  t.mock.method(admin.messaging(), "send", async () => {
    order.push("send");
    return "id";
  });
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.deepEqual(order, ["update", "send"]);
  assert.equal(updates[0]["coinState.streakReminderLastSentDate"], "2026-01-02");
  assert.equal(inbox[0].id, "streak_u1_2026-01-02");
  assert.equal((inbox[0].data as {modifier: string}).modifier, "u1@Example.com");
});

test("a failed reminder push rolls the sent marker back and retries in 15 minutes", async (t) => {
  const updates: Record<string, unknown>[] = [];
  mockReminderRun(t, [reminderDoc("u1", updates)]);
  t.mock.method(admin.messaging(), "send", async () => {
    throw new Error("fcm down");
  });
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(updates.length, 2);
  assert.equal(updates[0]["coinState.streakReminderLastSentDate"], "2026-01-02");
  assert.equal(updates[1]["coinState.streakReminderLastSentDate"], "");
  const retryAt = updates[1]["coinState.streakReminderNextAtUtc"] as admin.firestore.Timestamp;
  assert.equal(retryAt.toMillis(), Date.parse("2026-01-02T20:15:00Z"));
});

test("one failing user does not stop the rest of a 60 user batch", async (t) => {
  const updates: Record<string, unknown>[] = [];
  const docs = Array.from({length: 60}, (_, i) => reminderDoc(`u${i}`, updates, i === 7));
  mockReminderRun(t, docs);
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 59);
});

test("a page that comes back unchanged ends the run instead of looping", async (t) => {
  const updates: Record<string, unknown>[] = [];
  const docs = Array.from({length: 200}, (_, i) => reminderDoc(`u${i}`, updates));
  mockReminderRun(t, docs);
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  await sendStreakReminders.run({} as Parameters<typeof sendStreakReminders.run>[0]);
  assert.equal(send.mock.callCount(), 200);
});
