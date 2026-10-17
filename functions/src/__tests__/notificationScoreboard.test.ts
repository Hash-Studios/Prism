import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import path from "node:path";
import test from "node:test";
import {logger} from "firebase-functions/v2";
import {db, utcDateString} from "../common";
import {
  applyScore,
  NOTIFICATION_KINDS,
  planNotificationSignal,
  recordNotificationSignal,
  recordPushOutcome,
  scoreKindFor,
} from "../notificationScoreboard";

test("client and server notification kinds match", () => {
  const source = readFileSync(path.join(__dirname, "../../../lib/notifications/notification_retention.dart"), "utf8");
  const block = source.match(/notificationScoreboardKinds = <String>\[([\s\S]*?)\];/);
  assert.ok(block);
  const kinds = [...block[1].matchAll(/'([a-z_]+)'/g)].map((match) => match[1]);
  assert.deepEqual(kinds, [...NOTIFICATION_KINDS]);
});

test("score kind prefers an explicit label, then the route", () => {
  assert.equal(scoreKindFor({scoreKind: "wotd_creator", data: {route: "wall_of_the_day"}}), "wotd_creator");
  assert.equal(scoreKindFor({data: {route: "announcement", push_kind: "rejection"}}), "rejection");
  assert.equal(scoreKindFor({data: {route: "wall", report_id: "r1"}}), "moderation");
  assert.equal(scoreKindFor({data: {route: "wall"}}), "post");
  assert.equal(scoreKindFor({data: {route: "streak_reminder"}}), "streak_reminder");
  assert.equal(scoreKindFor({data: {route: "follower"}}), "follower");
  assert.equal(scoreKindFor({data: {route: "wall_of_the_day"}}), "wotd");
  assert.equal(scoreKindFor({data: {route: "content_report"}}), "moderation");
  assert.equal(scoreKindFor({scoreKind: "campaign", data: {route: "announcement"}}), "campaign");
  assert.equal(scoreKindFor({data: {route: "announcement"}}), null);
  assert.equal(scoreKindFor({data: {route: "home", push_kind: "win_back"}}), "win_back");
});

test("a score keeps the other kinds in the same map", () => {
  const sends = applyScore({sends: {wotd: 2, follower: 1}, taps: {wotd: 4}}, "sends", "win_back");
  assert.deepEqual(sends, {wotd: 2, follower: 1, win_back: 1});
});

test("signal plan dedupes taps, returns, and permission by UTC day", () => {
  assert.deepEqual(planNotificationSignal("u1", {type: "tap", kind: "win_back"}, "2026-10-17"), {
    ok: true, signalId: "u1_tap_2026-10-17_win_back", field: "taps", kind: "win_back",
  });
  assert.deepEqual(planNotificationSignal("u1", {type: "returned_next_day", kind: "wotd"}, "2026-10-17"), {
    ok: true, signalId: "u1_return_2026-10-17_wotd", field: "returnedNextDay", kind: "wotd",
  });
  assert.equal(planNotificationSignal(undefined, {type: "tap", kind: "wotd"}, "2026-10-17").ok, false);
  assert.equal(planNotificationSignal("u1", {type: "tap", kind: "nope"}, "2026-10-17").ok, false);
  assert.deepEqual(planNotificationSignal(undefined, {type: "permission", result: "granted", installId: "abcdef12"}, "2026-10-17"), {
    ok: true, signalId: "abcdef12_permission_2026-10-17", field: "permissionGranted",
  });
  assert.equal(planNotificationSignal("u1", {type: "permission", result: "declined", installId: "abcdef12"}, "2026-10-17").ok &&
    (planNotificationSignal("u1", {type: "permission", result: "declined"}, "2026-10-17") as {signalId: string}).signalId,
  "u1_permission_2026-10-17");
  assert.equal(planNotificationSignal(undefined, {type: "permission", result: "granted"}, "2026-10-17").ok, false);
  assert.equal(planNotificationSignal(undefined, {type: "permission", result: "granted", installId: "short"}, "2026-10-17").ok, false);
  assert.equal(planNotificationSignal("u1", {type: "other"}, "2026-10-17").ok, false);
});

test("a live scoreboard ref counts the attempt and a get-only stub does not", async (t) => {
  const days = new Map<string, Record<string, unknown>>();
  const originalDoc = db.doc.bind(db);
  const originalTx = db.runTransaction.bind(db);
  const warn = Object.getOwnPropertyDescriptor(logger, "warn");
  Object.defineProperty(logger, "warn", {configurable: true, value: () => undefined});
  let transactions = 0;
  t.mock.method(db, "doc", (path: string) => {
    if (!path.includes("notificationScoreboard")) return {get: async () => ({data: () => ({})})};
    return {
      firestore: db,
      path,
      async get() {
        return {data: () => days.get(path)};
      },
    };
  });
  t.mock.method(db, "runTransaction", async (fn: (tx: {
    get: (ref: {path: string; get: () => Promise<{data: () => Record<string, unknown> | undefined}>}) => Promise<{data: () => Record<string, unknown> | undefined}>;
    set: (ref: {path: string}, data: Record<string, unknown>, options?: {merge?: boolean}) => void;
  }) => Promise<void>) => {
    transactions += 1;
    await fn({
      get: async (ref) => ref.get(),
      set: (ref, data, options) => {
        const current = options?.merge ? {...days.get(ref.path)} : {};
        days.set(ref.path, {...current, ...data});
      },
    });
  });
  try {
    await recordPushOutcome("win_back", "sends", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("win_back", "accepts", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("wotd", "sends", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("nope", "fails", new Date("2026-10-17T12:00:00Z"));
    const day = days.get("metrics/notificationScoreboard/days/2026-10-17");
    assert.deepEqual(day, {sends: {win_back: 1, wotd: 1}, accepts: {win_back: 1}});
    const before = transactions;
    t.mock.method(db, "doc", () => ({get: async () => ({data: () => ({})})}));
    await recordPushOutcome("win_back", "sends", new Date("2026-10-17T12:00:00Z"));
    assert.equal(transactions, before);
  } finally {
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTx);
    if (warn) Object.defineProperty(logger, "warn", warn);
  }
});

test("the callable atomically dedupes signals and preserves sibling kinds", async (t) => {
  const docs = new Map<string, Record<string, unknown>>();
  const originalDoc = db.doc.bind(db);
  const originalTransaction = db.runTransaction.bind(db);
  t.mock.method(db, "doc", (path: string) => ({path, firestore: db}));
  t.mock.method(db, "runTransaction", async (callback: (tx: {
    get: (ref: {path: string}) => Promise<{exists: boolean; data: () => Record<string, unknown> | undefined}>;
    set: (ref: {path: string}, data: Record<string, unknown>, options?: {merge?: boolean}) => void;
  }) => Promise<unknown>) => {
    const writes: Array<{path: string; data: Record<string, unknown>; merge: boolean}> = [];
    const result = await callback({
      get: async (ref) => {
        const data = docs.get(ref.path);
        return {exists: data !== undefined, data: () => data};
      },
      set: (ref, data, options) => writes.push({path: ref.path, data, merge: options?.merge ?? false}),
    });
    for (const write of writes) {
      const prior = write.merge ? docs.get(write.path) ?? {} : {};
      docs.set(write.path, {...prior, ...write.data});
    }
    return result;
  });
  const call = (data: Record<string, unknown>) => recordNotificationSignal.run({
    data,
    auth: {uid: "uid-1"},
  } as unknown as Parameters<typeof recordNotificationSignal.run>[0]);
  try {
    assert.deepEqual(await call({type: "tap", kind: "wotd"}), {ok: true, counted: true});
    assert.deepEqual(await call({type: "tap", kind: "wotd"}), {ok: true, counted: false});
    assert.deepEqual(await call({type: "tap", kind: "follower"}), {ok: true, counted: true});
    assert.deepEqual(await call({type: "permission", result: "granted"}), {ok: true, counted: true});
    assert.deepEqual(await call({type: "permission", result: "declined"}), {ok: true, counted: false});
    assert.deepEqual(docs.get(`metrics/notificationScoreboard/days/${utcDateString()}`), {
      taps: {wotd: 1, follower: 1},
      permissionGranted: 1,
    });
  } finally {
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTransaction);
  }
});
