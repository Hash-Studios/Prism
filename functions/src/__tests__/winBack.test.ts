import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import type {ScheduledEvent} from "firebase-functions/v2/scheduler";
import {sendWinBackPushes, WIN_BACK_STEPS, winBackStepFor} from "../winBack";

const NOW = 1_700_000_000_000;
const DAY = 24 * 60 * 60 * 1000;
const MIN = 60 * 1000;
const idle = (ms: number) => winBackStepFor(NOW, NOW - ms, undefined);

test("each step fires at exactly N days and just under N+1 days", () => {
  for (const n of WIN_BACK_STEPS) {
    assert.equal(idle(n * DAY), n);
    assert.equal(idle((n + 1) * DAY - MIN), n);
  }
});

test("N days minus 1 minute is the previous step or none", () => {
  assert.equal(idle(3 * DAY - MIN), null);
  assert.equal(idle(7 * DAY - MIN), null);
  assert.equal(idle(30 * DAY - MIN), null);
});

test("N+1 days is outside the window", () => {
  assert.equal(idle(4 * DAY), null);
  assert.equal(idle(8 * DAY), null);
  assert.equal(idle(15 * DAY), null);
  assert.equal(idle(31 * DAY), null);
});

test("0 to 2 days and over 61 days return null", () => {
  assert.equal(idle(0), null);
  assert.equal(idle(2 * DAY + 23 * 60 * MIN), null);
  assert.equal(idle(61 * DAY), null);
  assert.equal(idle(90 * DAY), null);
});

test("same inactivity period already sent is deduped", () => {
  const last = NOW - 7 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 7, claimAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 14, claimAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 3, claimAtMs: last}), 7);
});

test("newer activity after an earlier send resets dedupe", () => {
  const last = NOW - 3 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 60, claimAtMs: NOW - 200 * DAY}), 3);
});

type User = Record<string, unknown> & {
  id: string;
  uid?: string;
  email?: string;
  loggedIn?: boolean;
  deleted?: boolean;
  coinState: Record<string, unknown>;
  winBack?: Record<string, unknown>;
};
type MockDoc = {id: string; data: () => User; ref: {id: string}};
type MockQuery = {
  where: (field: string, op: string, value: admin.firestore.Timestamp) => MockQuery;
  orderBy: (field: string) => MockQuery;
  startAfter: (cursor: MockDoc) => MockQuery;
  limit: (count: number) => MockQuery;
  get: () => Promise<{docs: MockDoc[]; size: number; empty: boolean}>;
};
type MockTransaction = {
  get: (ref: {id: string}) => Promise<{exists: boolean; data: () => User | undefined}>;
  update: (ref: {id: string}, value: Record<string, unknown>) => void;
};

const activityMs = (user: User) => {
  const timestamp = user.coinState.streakLastClaimServerAt;
  return timestamp instanceof admin.firestore.Timestamp ? timestamp.toMillis() : -1;
};

function makeUser(id: string, idleDays: number, extra: Partial<User> & Record<string, unknown> = {}): User {
  const base = {
    id,
    uid: id,
    email: `${id}@example.com`,
    loggedIn: true,
    deleted: false,
    coinState: {streakLastClaimServerAt: admin.firestore.Timestamp.fromMillis(NOW - idleDays * DAY)},
  };
  return {...base, ...extra, id, coinState: extra.coinState ?? base.coinState};
}

function messageCondition(message: admin.messaging.Message): string | undefined {
  return "condition" in message ? message.condition : undefined;
}

async function runJob(users: User[], options: {
  beforeTransactions?: (state: Map<string, User>) => void;
  failSend?: boolean;
  concurrentRuns?: number;
  wall?: boolean;
  failTransactionAt?: number;
  nowMs?: number;
  afterSend?: (state: Map<string, User>) => void;
} = {}) {
  const firestore = admin.firestore();
  const messaging = admin.messaging();
  const loggerDescriptors = ["info", "warn", "error"].map((name) => [name,
    Object.getOwnPropertyDescriptor(logger, name)] as const);
  const firestoreCollection = firestore.collection.bind(firestore);
  const firestoreTransaction = firestore.runTransaction.bind(firestore);
  const messagingSend = messaging.send.bind(messaging);
  const dateNow = Date.now;
  const state = new Map(users.map((u) => [u.id, u]));
  const sent: admin.messaging.Message[] = [];
  const collections: string[] = [];
  let transactionTail = Promise.resolve();
  let transactionCount = 0;

  const refFor = (id: string): MockDoc["ref"] => ({id});
  const snapshot = (user: User): MockDoc => {
    const data = {...user, coinState: {...user.coinState}, winBack: user.winBack && {...user.winBack}};
    return {id: user.id, data: () => data, ref: refFor(user.id)};
  };

  const collection = (name: string): ReturnType<typeof firestore.collection> => {
    collections.push(name);
    if (name === "wall_of_the_day") {
      return {doc: () => ({get: async () => ({data: () => options.wall ? {wallId: "wall-1"} : {}})})} as
        unknown as ReturnType<typeof firestore.collection>;
    }
    if (name === "walls") {
      return {doc: () => ({get: async () => ({data: () => options.wall ? {title: "Wall title", wallpaper_thumb: "https://image"} : undefined})})} as
        unknown as ReturnType<typeof firestore.collection>;
    }
    assert.equal(name, "usersv2");
    const usersCollection = {
      where(field: string, op: string, value: admin.firestore.Timestamp) {
        const filters: Array<[string, string, admin.firestore.Timestamp]> = [[field, op, value]];
        let cursor: MockDoc | undefined;
        let pageSize = Number.POSITIVE_INFINITY;
        const query = {} as MockQuery;
        Object.assign(query, {
          where(nextField: string, nextOp: string, nextValue: admin.firestore.Timestamp) {
            filters.push([nextField, nextOp, nextValue]);
            return query;
          },
          orderBy: () => query,
          startAfter: (after: MockDoc) => {
            cursor = after;
            return query;
          },
          limit: (count: number) => {
            pageSize = count;
            return query;
          },
          async get() {
            const eligible = users.filter((user) => {
              const timestamp = user.coinState?.streakLastClaimServerAt;
              if (!(timestamp instanceof admin.firestore.Timestamp)) return false;
              const ms = timestamp.toMillis();
              return filters.every(([f, operator, bound]) => {
                if (f !== "coinState.streakLastClaimServerAt") return true;
                return operator === ">=" ? ms >= bound.toMillis() : operator === ">" ? ms > bound.toMillis() :
                  operator === "<=" ? ms <= bound.toMillis() : operator === "<" ? ms < bound.toMillis() : true;
              });
            }).sort((a, b) => {
              const t = activityMs(a) - activityMs(b);
              return t || a.id.localeCompare(b.id);
            }).filter((user) => {
              if (!cursor) return true;
              const cursorTime = activityMs(cursor.data());
              const userTime = activityMs(user);
              return userTime > cursorTime || (userTime === cursorTime && user.id.localeCompare(cursor.id) > 0);
            });
            const docs = eligible.slice(0, pageSize).map(snapshot);
            options.beforeTransactions?.(state);
            return {docs, size: docs.length, empty: docs.length === 0};
          },
        });
        return query;
      },
    };
    return usersCollection as unknown as ReturnType<typeof firestore.collection>;
  };

  Object.defineProperty(firestore, "collection", {configurable: true, value: collection});
  Object.defineProperty(firestore, "runTransaction", {
    configurable: true,
    value: async (callback: (tx: MockTransaction) => Promise<unknown>) => {
      let release: (() => void) | undefined;
      const previous = transactionTail;
      transactionTail = new Promise<void>((resolve) => {
        release = resolve;
      });
      await previous;
      const changes = new Map<string, User>();
      let committed = false;
      transactionCount += 1;
      try {
        const result = await callback({
          get: async (ref: {id: string}) => ({exists: state.has(ref.id), data: () => state.get(ref.id)}),
          update: (ref: {id: string}, value: Record<string, unknown>) => {
            const current = state.get(ref.id);
            if (!current) throw new Error(`Missing test document: ${ref.id}`);
            const updated = {...current};
            Object.assign(updated, value);
            changes.set(ref.id, updated);
          },
        });
        if (transactionCount === options.failTransactionAt) throw new Error("Firestore commit failed");
        committed = true;
        return result;
      } finally {
        if (committed) for (const [id, value] of changes) state.set(id, value);
        release?.();
      }
    },
  });
  Object.defineProperty(messaging, "send", {
    configurable: true,
    value: async (message: admin.messaging.Message) => {
      sent.push(message);
      if (options.failSend) throw new Error("FCM unavailable");
      options.afterSend?.(state);
      return `message-${sent.length}`;
    },
  });
  for (const name of ["info", "warn", "error"] as const) {
    Object.defineProperty(logger, name, {configurable: true, value: () => undefined});
  }
  Date.now = () => options.nowMs ?? NOW;
  try {
    const run = sendWinBackPushes.run;
    let failure: unknown;
    try {
      await Promise.all(Array.from({length: options.concurrentRuns ?? 1}, () => run({
        jobName: "win-back-test",
        scheduleTime: new Date(NOW).toISOString(),
      } satisfies ScheduledEvent)));
    } catch (err) {
      failure = err;
    }
    if (failure) return {sent, users: state, collections, failure};
    return {sent, users: state, collections};
  } finally {
    Date.now = dateNow;
    Object.defineProperty(firestore, "collection", {configurable: true, value: firestoreCollection});
    Object.defineProperty(firestore, "runTransaction", {configurable: true, value: firestoreTransaction});
    Object.defineProperty(messaging, "send", {configurable: true, value: messagingSend});
    for (const [name, descriptor] of loggerDescriptors) {
      if (descriptor) Object.defineProperty(logger, name, descriptor);
    }
  }
}

test("job includes every exact inactivity boundary and excludes its N+1 boundary", async () => {
  const users = WIN_BACK_STEPS.flatMap((step) => [
    makeUser(`exact-${step}`, step),
    makeUser(`boundary-${step}`, step + 1),
  ]);
  const {sent} = await runJob(users);
  assert.equal(sent.length, WIN_BACK_STEPS.length);
  const conditions = new Set(sent.map(messageCondition));
  for (const step of WIN_BACK_STEPS) {
    assert.ok(conditions.has(`'u_exact-${step}' in topics || 'exact-${step}' in topics`));
    assert.ok(!conditions.has(`'u_boundary-${step}' in topics || 'boundary-${step}' in topics`));
  }
});

test("job sends one push using the uid/email condition and app payload", async () => {
  const {sent} = await runJob([makeUser("authoritative", 3.5, {uid: "wrong-uid"})]);
  assert.equal(sent.length, 1);
  const condition = messageCondition(sent[0]);
  assert.equal(condition, "'u_authoritative' in topics || 'authoritative' in topics");
  assert.equal(sent[0].data?.route, "wall_of_the_day");
  assert.equal(sent[0].data?.channel_id, "wall_of_the_day");
  assert.ok(sent[0].android?.notification?.channelId === "wall_of_the_day");
  assert.equal(sent[0].android?.collapseKey, "win_back_3");
});

test("scheduled handler exposes bounded retry configuration", () => {
  const endpoint = (sendWinBackPushes as unknown as {
    __endpoint?: {scheduleTrigger?: {retryConfig?: {retryCount?: number; minBackoffSeconds?: number}}};
  }).__endpoint;
  assert.equal(endpoint?.scheduleTrigger?.retryConfig?.retryCount, 3);
  assert.equal(endpoint?.scheduleTrigger?.retryConfig?.minBackoffSeconds, 600);
});

test("fresh activity, deleted users and logged-out users are skipped", async () => {
  const {sent} = await runJob([
    makeUser("fresh", 3.5),
    makeUser("missing-doc", 3.5),
    makeUser("deleted", 3.5),
    makeUser("logged-out", 3.5),
  ], {beforeTransactions: (state) => {
    const fresh = state.get("fresh");
    const deleted = state.get("deleted");
    const loggedOut = state.get("logged-out");
    assert.ok(fresh);
    assert.ok(deleted && loggedOut);
    fresh.coinState.streakLastClaimServerAt = admin.firestore.Timestamp.fromMillis(NOW - 2 * DAY);
    deleted.deleted = true;
    loggedOut.loggedIn = false;
    state.delete("missing-doc");
  }});
  assert.equal(sent.length, 0);
});

test("completed sends dedupe reruns", async () => {
  const first = await runJob([makeUser("same", 3.5)]);
  assert.equal(first.sent.length, 1);
  const again = await runJob([...first.users.values()]);
  assert.equal(again.sent.length, 0);
});

test("concurrent invocations claim a user only once", async () => {
  const racing = await runJob([makeUser("racing", 3.5)], {concurrentRuns: 2});
  assert.equal(racing.sent.length, 1);
});

test("failed FCM does not leave a completed stamp or owned pending lease", async () => {
  const failed = await runJob([makeUser("retry", 3.5)], {failSend: true});
  assert.ok(failed.failure);
  const user = failed.users.get("retry");
  assert.ok(user);
  assert.equal(user.winBack?.step, undefined);
  assert.equal(user.winBack?.pending, undefined);
  const retry = await runJob([...failed.users.values()]);
  assert.equal(retry.sent.length, 1);
});

test("failed FCM cleanup failure retains a lease until the first configured retry is safe", async () => {
  const failed = await runJob([makeUser("cleanup-retry", 3.5)], {failSend: true, failTransactionAt: 2});
  assert.ok(failed.failure);
  assert.equal(failed.sent.length, 1);
  const expiry = failed.users.get("cleanup-retry")?.winBack?.pending as {expiresAt?: admin.firestore.Timestamp};
  assert.ok(expiry.expiresAt instanceof admin.firestore.Timestamp);
  const retry = await runJob([...failed.users.values()], {nowMs: expiry.expiresAt.toMillis()});
  assert.equal(retry.sent.length, 1);
  assert.equal(retry.users.get("cleanup-retry")?.winBack?.step, 3);
});

test("varied timestamp pages with ties do not skip users after the 300-document boundary", async () => {
  const users = Array.from({length: 307}, (_, i) => makeUser(
    `page-${String(999 - i).padStart(3, "0")}`,
    3.2 + (i % 6) * 0.1,
  ));
  const {sent} = await runJob(users);
  assert.equal(sent.length, 307);
  assert.equal(new Set(sent.map((message) => JSON.stringify(message))).size, 307);
});

test("freshly missing or malformed activity timestamps are skipped", async () => {
  const {sent} = await runJob([
    makeUser("missing-claim", 3.5, {coinState: {}}),
    makeUser("wrong-claim", 3.5, {coinState: {streakLastClaimServerAt: "not-a-timestamp"}}),
  ]);
  assert.equal(sent.length, 0);
});

test("malformed completed dedupe timestamps do not crash or suppress an eligible user", async () => {
  const {sent} = await runJob([makeUser("bad-dedupe", 3.5, {
    winBack: {step: 60, claimAt: {toMillis: "not-a-function"}},
  })]);
  assert.equal(sent.length, 1);
});

test("an active pending lease blocks a later step, but an expired lease can retry", async () => {
  const lastClaim = admin.firestore.Timestamp.fromMillis(NOW - 7.5 * DAY);
  const active = await runJob([makeUser("leased", 7.5, {
    winBack: {pending: {id: "old-attempt", step: 3, claimAt: lastClaim,
      expiresAt: admin.firestore.Timestamp.fromMillis(NOW + DAY)}},
  })]);
  assert.equal(active.sent.length, 0);

  const expired = await runJob([makeUser("leased", 7.5, {
    winBack: {pending: {id: "expired-attempt", step: 3, claimAt: lastClaim,
      expiresAt: admin.firestore.Timestamp.fromMillis(NOW - 1)}},
  })]);
  assert.equal(expired.sent.length, 1);
});

test("empty or invalid email topic falls back to only the authoritative uid topic", async () => {
  const {sent} = await runJob([makeUser("uid-only", 3.5, {email: "###@example.com"})]);
  assert.equal(sent.length, 1);
  const condition = messageCondition(sent[0]);
  assert.equal(condition, "'u_uid-only' in topics");
});

test("legacy topic preserves email case and uses the canonical document uid", async () => {
  const {sent} = await runJob([makeUser("doc-uid", 3.5, {uid: "wrong", email: "Alice@example.com"})]);
  assert.equal(sent.length, 1);
  const condition = messageCondition(sent[0]);
  assert.equal(condition, "'u_doc-uid' in topics || 'Alice' in topics");
});

test("the email topic comes from the fresh reservation document, not a stale query snapshot", async () => {
  const {sent} = await runJob([makeUser("fresh-email", 3.5, {email: "old@example.com"})], {
    beforeTransactions: (state) => {
      const user = state.get("fresh-email");
      assert.ok(user);
      user.email = "Alice@example.com";
    },
  });
  const condition = messageCondition(sent[0]);
  assert.equal(condition, "'u_fresh-email' in topics || 'Alice' in topics");
});

test("payload carries the current wall details and falls back cleanly without one", async () => {
  const withWall = await runJob([makeUser("wall", 3.5)], {wall: true});
  assert.equal(withWall.sent[0].data?.route, "wall_of_the_day");
  assert.equal(withWall.sent[0].data?.wall_id, "wall-1");
  assert.equal(withWall.sent[0].data?.channel_id, "wall_of_the_day");
  assert.equal(withWall.sent[0].data?.imageUrl, "https://image");

  const fallback = await runJob([makeUser("fallback", 3.5)]);
  assert.equal(fallback.sent[0].data?.route, "wall_of_the_day");
  assert.equal(fallback.sent[0].data?.channel_id, "wall_of_the_day");
  assert.equal(fallback.sent[0].data?.wall_id, undefined);
  assert.equal(fallback.sent[0].data?.imageUrl, undefined);
  assert.ok(!fallback.collections.includes("notifications"));
});

test("state changes after push acceptance are not marked as sent", async () => {
  const cases: Array<{id: string; change: (user: User) => void}> = [
    {id: "activity-after-send", change: (user) => {
      user.coinState.streakLastClaimServerAt = admin.firestore.Timestamp.fromMillis(NOW - 2 * DAY);
    }},
    {id: "deleted-after-send", change: (user) => {
      user.deleted = true;
    }},
    {id: "signed-out-after-send", change: (user) => {
      user.loggedIn = false;
    }},
  ];
  for (const {id, change} of cases) {
    const result = await runJob([makeUser(id, 3.5)], {afterSend: (state) => {
      const user = state.get(id);
      assert.ok(user);
      change(user);
    }});
    assert.equal(result.sent.length, 1);
    assert.equal(result.users.get(id)?.winBack?.step, undefined);
  }
});

test("completion does not overwrite a lease replaced after push acceptance", async () => {
  const result = await runJob([makeUser("lease-owner", 3.5)], {afterSend: (state) => {
    const user = state.get("lease-owner");
    assert.ok(user);
    const pending = user.winBack?.pending;
    assert.ok(pending && typeof pending === "object");
    user.winBack = {...user.winBack, pending: {...pending, id: "new-owner"}};
  }});
  assert.equal(result.users.get("lease-owner")?.winBack?.step, undefined);
  const pending = result.users.get("lease-owner")?.winBack?.pending as Record<string, unknown>;
  assert.equal(pending.id, "new-owner");
});

test("accepted push with a failed final transaction retains its lease and blocks immediate resend", async () => {
  const first = await runJob([makeUser("finalize-retry", 3.5)], {failTransactionAt: 2});
  assert.ok(first.failure);
  assert.equal(first.sent.length, 1);
  assert.ok(first.users.get("finalize-retry")?.winBack?.pending);
  const rerun = await runJob([...first.users.values()]);
  assert.equal(rerun.sent.length, 0);
});

test("failed later-step delivery preserves the earlier completed stamp", async () => {
  const claimAt = admin.firestore.Timestamp.fromMillis(NOW - 7.5 * DAY);
  const sentAt = admin.firestore.Timestamp.fromMillis(NOW - DAY);
  const failed = await runJob([makeUser("later-step", 7.5, {
    winBack: {step: 3, claimAt, sentAt},
  })], {failSend: true});
  assert.ok(failed.failure);
  const winBack = failed.users.get("later-step")?.winBack;
  assert.equal(winBack?.step, 3);
  assert.equal(winBack?.claimAt, claimAt);
  assert.equal(winBack?.sentAt, sentAt);
});
