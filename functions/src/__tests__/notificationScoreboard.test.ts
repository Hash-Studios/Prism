import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import path from "node:path";
import test from "node:test";
import {logger} from "firebase-functions/v2";
import {db, utcDateString} from "../common";
import {installFakeDb} from "./fakeDb";
import {
  applyScore,
  galleryField,
  NOTIFICATION_KINDS,
  planNotificationSignal,
  recordNotificationSignal,
  recordPushOutcome,
  SCOREBOARD_SHARD_COUNT,
  scoreboardShardDocId,
  scoreKindFor,
} from "../notificationScoreboard";

test("client and server notification kinds match", () => {
  const source = readFileSync(path.join(__dirname, "../../../lib/notifications/notification_retention.dart"), "utf8");
  const block = source.match(/notificationScoreboardKinds = <String>\[([\s\S]*?)\];/);
  assert.ok(block);
  const kinds = [...block[1].matchAll(/'([a-z_]+)'/g)].map((match) => match[1]);
  assert.deepEqual(kinds, [...NOTIFICATION_KINDS]);
  const row = readFileSync(path.join(__dirname, "../../../lib/notifications/scoreboard_row.dart"), "utf8");
  const shards = row.match(/notificationScoreboardShardCount = (\d+);/);
  assert.ok(shards);
  assert.equal(Number(shards[1]), SCOREBOARD_SHARD_COUNT);
});

test("shard ids stay inside one UTC day and sort with that day", () => {
  assert.equal(scoreboardShardDocId("2026-10-17", 0), "2026-10-17_00");
  assert.equal(scoreboardShardDocId("2026-10-17", 31), "2026-10-17_31");
  assert.equal(scoreboardShardDocId("2026-10-17", 32), "2026-10-17_00");
  assert.deepEqual([
    "2026-10-18",
    scoreboardShardDocId("2026-10-17", 31),
    "2026-10-04",
    scoreboardShardDocId("2026-10-03", 31),
    scoreboardShardDocId("2026-10-17", 0),
  ].sort(), [
    "2026-10-03_31",
    "2026-10-04",
    "2026-10-17_00",
    "2026-10-17_31",
    "2026-10-18",
  ]);
});

test("score kind prefers an explicit label, then the route", () => {
  assert.equal(scoreKindFor({scoreKind: "wotd_creator", data: {route: "wall_of_the_day"}}), "wotd_creator");
  assert.equal(scoreKindFor({data: {route: "announcement", push_kind: "rejection"}}), "rejection");
  assert.equal(scoreKindFor({data: {route: "wall", report_id: "r1"}}), "moderation");
  assert.equal(scoreKindFor({data: {route: "wall"}}), "post");
  assert.equal(scoreKindFor({data: {route: "streak_reminder"}}), "streak_reminder");
  assert.equal(scoreKindFor({data: {route: "follower"}}), "follower");
  assert.equal(scoreKindFor({data: {route: "wall_of_the_day"}}), "wotd");
  assert.equal(scoreKindFor({data: {route: "drops"}}), "drop");
  assert.equal(scoreKindFor({scoreKind: "drop", data: {route: "wall"}}), "drop");
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

test("scoreboard refs count attempts, accepts and failures without requiring a firestore marker", async (t) => {
  const days = new Map<string, Record<string, unknown>>();
  const originalDoc = db.doc.bind(db);
  const originalTx = db.runTransaction.bind(db);
  const originalRandom = Math.random;
  const warn = Object.getOwnPropertyDescriptor(logger, "warn");
  Object.defineProperty(logger, "warn", {configurable: true, value: () => undefined});
  let transactions = 0;
  t.mock.method(db, "doc", (path: string) => {
    if (!path.includes("notificationScoreboard")) return {get: async () => ({data: () => ({})})};
    return {
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
    Math.random = () => 0;
    await recordPushOutcome("win_back", "sends", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("win_back", "accepts", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("wotd", "sends", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("wotd", "fails", new Date("2026-10-17T12:00:00Z"));
    await recordPushOutcome("nope", "fails", new Date("2026-10-17T12:00:00Z"));
    const first = "metrics/notificationScoreboard/days/2026-10-17_00";
    assert.deepEqual(days.get(first), {sends: {win_back: 1, wotd: 1}, accepts: {win_back: 1}, fails: {wotd: 1}});
    Math.random = () => 0.5;
    await recordPushOutcome("follower", "sends", new Date("2026-10-17T12:00:00Z"));
    assert.deepEqual(days.get(first), {sends: {win_back: 1, wotd: 1}, accepts: {win_back: 1}, fails: {wotd: 1}});
    assert.deepEqual(days.get("metrics/notificationScoreboard/days/2026-10-17_16"), {sends: {follower: 1}});
    assert.equal(days.has("metrics/notificationScoreboard/days/2026-10-17"), false);
    assert.equal(transactions, 5);
  } finally {
    Math.random = originalRandom;
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTx);
    if (warn) Object.defineProperty(logger, "warn", warn);
  }
});

test("real push outcomes accumulate through the shared database fake and unknown kinds write nothing", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(Math, "random", () => 0);
  const at = new Date("2026-10-17T12:00:00Z");
  for (const outcome of ["sends", "accepts", "fails"] as const) {
    await recordPushOutcome("follower", outcome, at);
    await recordPushOutcome("follower", outcome, at);
  }
  await recordPushOutcome("unknown", "sends", at);
  assert.deepEqual(store.get("metrics/notificationScoreboard/days/2026-10-17_00"), {
    sends: {follower: 2}, accepts: {follower: 2}, fails: {follower: 2},
  });
  assert.equal(store.size, 1);
});

test("push outcome database failures are logged and remain fail-open", async (t) => {
  installFakeDb(t);
  const warn = t.mock.method(logger, "warn", () => undefined);
  t.mock.method(db, "runTransaction", async () => {
    throw new Error("unavailable");
  });
  await assert.doesNotReject(() => recordPushOutcome("wotd", "sends"));
  assert.equal(warn.mock.callCount(), 1);
  assert.equal(warn.mock.calls[0].arguments[0], "notification scoreboard write failed");
});

test("push retry reuses the shard selected before the transaction", async (t) => {
  const originalDoc = db.doc.bind(db);
  const originalTransaction = db.runTransaction.bind(db);
  const originalRandom = Math.random;
  const documents = new Map<string, Record<string, unknown>>();
  const counterPaths: string[] = [];
  let transactions = 0;
  t.mock.method(db, "doc", (path: string) => ({path, firestore: db}));
  t.mock.method(db, "runTransaction", async (callback: (tx: {
    get: (ref: {path: string}) => Promise<{data: () => Record<string, unknown> | undefined}>;
    set: (ref: {path: string}, data: Record<string, unknown>, options?: {merge?: boolean}) => void;
  }) => Promise<void>) => {
    transactions += 1;
    for (let attempt = 0; attempt < 2; attempt++) {
      const writes: Array<{path: string; data: Record<string, unknown>; merge: boolean}> = [];
      await callback({
        get: async (ref) => {
          counterPaths.push(ref.path);
          return {data: () => documents.get(ref.path)};
        },
        set: (ref, data, options) => writes.push({path: ref.path, data, merge: options?.merge ?? false}),
      });
      if (attempt === 0) {
        Math.random = () => 0.75;
        continue;
      }
      for (const write of writes) {
        const prior = write.merge ? documents.get(write.path) ?? {} : {};
        documents.set(write.path, {...prior, ...write.data});
      }
    }
  });
  try {
    Math.random = () => 0;
    await recordPushOutcome("post", "sends", new Date("2026-10-17T12:00:00Z"));
    assert.equal(transactions, 1);
    assert.deepEqual(counterPaths, [
      "metrics/notificationScoreboard/days/2026-10-17_00",
      "metrics/notificationScoreboard/days/2026-10-17_00",
    ]);
    assert.deepEqual(documents.get(counterPaths[0]), {sends: {post: 1}});
  } finally {
    Math.random = originalRandom;
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTransaction);
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
    assert.deepEqual(await call({type: "tap", kind: "win_back"}), {ok: true, counted: true});
    assert.deepEqual(await call({type: "permission", result: "granted"}), {ok: true, counted: true});
    assert.deepEqual(await call({type: "permission", result: "declined"}), {ok: true, counted: false});
    const day = utcDateString();
    const counters = [...docs.entries()].filter(([path]) => path.startsWith(`metrics/notificationScoreboard/days/${day}_`));
    assert.equal(docs.has(`metrics/notificationScoreboard/signals/uid-1_tap_${day}_wotd`), true);
    assert.equal(docs.has(`metrics/notificationScoreboard/days/${day}`), false);
    const taps: Record<string, number> = {};
    let granted = 0;
    for (const [, data] of counters) {
      const bucket = data.taps as Record<string, number> | undefined;
      for (const [kind, count] of Object.entries(bucket ?? {})) taps[kind] = (taps[kind] ?? 0) + count;
      if (typeof data.permissionGranted === "number") granted += data.permissionGranted;
    }
    assert.deepEqual(taps, {wotd: 1, follower: 1, win_back: 1});
    assert.equal(counters.filter(([, data]) => {
      const bucket = data.taps as Record<string, number> | undefined;
      return bucket?.wotd === 1 && bucket.win_back === 1;
    }).length, 1);
    assert.equal(granted, 1);
  } finally {
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTransaction);
  }
});

test("signal retries keep the dedupe and counter document paths stable", async (t) => {
  const originalDoc = db.doc.bind(db);
  const originalTransaction = db.runTransaction.bind(db);
  const documents = new Map<string, Record<string, unknown>>();
  const counterPaths: string[] = [];
  const signalPaths: string[] = [];
  let transactions = 0;
  t.mock.method(db, "doc", (path: string) => ({path, firestore: db}));
  t.mock.method(db, "runTransaction", async (callback: (tx: {
    get: (ref: {path: string}) => Promise<{exists: boolean; data: () => Record<string, unknown> | undefined}>;
    set: (ref: {path: string}, data: Record<string, unknown>, options?: {merge?: boolean}) => void;
  }) => Promise<unknown>) => {
    transactions += 1;
    const invoke = async () => {
      const writes: Array<{path: string; data: Record<string, unknown>; merge: boolean}> = [];
      const result = await callback({
        get: async (ref) => {
          if (ref.path.includes("/signals/")) signalPaths.push(ref.path);
          else counterPaths.push(ref.path);
          const data = documents.get(ref.path);
          return {exists: data !== undefined, data: () => data};
        },
        set: (ref, data, options) => writes.push({path: ref.path, data, merge: options?.merge ?? false}),
      });
      return {result, writes};
    };
    const commit = (writes: Array<{path: string; data: Record<string, unknown>; merge: boolean}>) => {
      for (const write of writes) {
        const prior = write.merge ? documents.get(write.path) ?? {} : {};
        documents.set(write.path, {...prior, ...write.data});
      }
    };
    if (transactions > 1) {
      const attempt = await invoke();
      commit(attempt.writes);
      return attempt.result;
    }
    // Discard the first staged attempt as Firestore does on a conflict, then commit the retry.
    await invoke();
    const retryAttempt = await invoke();
    commit(retryAttempt.writes);
    return retryAttempt.result;
  });
  try {
    const result = await recordNotificationSignal.run({
      data: {type: "tap", kind: "win_back"},
      auth: {uid: "uid-1"},
    } as unknown as Parameters<typeof recordNotificationSignal.run>[0]);
    assert.deepEqual(result, {ok: true, counted: true});
    assert.equal(signalPaths.length, 2);
    assert.equal(signalPaths[0], signalPaths[1]);
    assert.equal(counterPaths.length, 2);
    assert.equal(counterPaths[0], counterPaths[1]);
    assert.match(counterPaths[0], /\/days\/\d{4}-\d{2}-\d{2}_\d{2}$/);
    assert.equal(documents.size, 2);
    assert.equal(documents.has(signalPaths[1]), true);
    assert.deepEqual(documents.get(counterPaths[0]), {taps: {win_back: 1}});
    assert.deepEqual(await recordNotificationSignal.run({
      data: {type: "tap", kind: "win_back"},
      auth: {uid: "uid-1"},
    } as unknown as Parameters<typeof recordNotificationSignal.run>[0]), {ok: true, counted: false});
    assert.deepEqual(documents.get(counterPaths[0]), {taps: {win_back: 1}});
  } finally {
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTransaction);
  }
});

test("a gallery tap plan carries the gallery flag only when asked", () => {
  assert.deepEqual(planNotificationSignal("u1", {type: "tap", kind: "wotd", gallery: true}, "2026-10-28"), {
    ok: true, signalId: "u1_tap_2026-10-28_wotd", field: "taps", kind: "wotd", gallery: true,
  });
  const plain = planNotificationSignal("u1", {type: "tap", kind: "wotd"}, "2026-10-28");
  assert.equal("gallery" in plain, false);
  assert.equal(galleryField("taps"), "gallery_taps");
});

test("gallery push outcomes count under gallery fields beside the plain kind", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(Math, "random", () => 0);
  const at = new Date("2026-10-28T00:00:00Z");
  await recordPushOutcome("wotd", "sends", at, true);
  await recordPushOutcome("wotd", "sends", at);
  const sums: Record<string, number> = {};
  for (const [path, data] of store) {
    if (!path.startsWith("metrics/notificationScoreboard/days/2026-10-28_")) continue;
    for (const [field, bucket] of Object.entries(data)) {
      for (const [kind, count] of Object.entries(bucket as Record<string, number>)) {
        sums[`${field}.${kind}`] = (sums[`${field}.${kind}`] ?? 0) + count;
      }
    }
  }
  assert.equal(sums["sends.wotd"], 2);
  assert.equal(sums["gallery_sends.wotd"], 1);
});

test("the callable counts a gallery tap once per day under the gallery taps field", async (t) => {
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
  const call = () => recordNotificationSignal.run({
    data: {type: "tap", kind: "wotd", gallery: true},
    auth: {uid: "uid-1"},
  } as unknown as Parameters<typeof recordNotificationSignal.run>[0]);
  try {
    assert.deepEqual(await call(), {ok: true, counted: true});
    assert.deepEqual(await call(), {ok: true, counted: false});
    const day = utcDateString();
    const sums: Record<string, number> = {};
    for (const [path, data] of docs) {
      if (!path.startsWith(`metrics/notificationScoreboard/days/${day}_`)) continue;
      for (const field of ["taps", "gallery_taps"]) {
        const bucket = data[field] as Record<string, number> | undefined;
        sums[field] = (sums[field] ?? 0) + (bucket?.wotd ?? 0);
      }
    }
    assert.deepEqual(sums, {taps: 1, gallery_taps: 1});
  } finally {
    t.mock.method(db, "doc", originalDoc);
    t.mock.method(db, "runTransaction", originalTransaction);
  }
});
