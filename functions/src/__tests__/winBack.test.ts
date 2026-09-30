import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
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
  coinState: {streakLastClaimServerAt: admin.firestore.Timestamp; [key: string]: unknown};
  winBack?: Record<string, unknown>;
};
type MockDoc = {
  id: string;
  data: () => User;
  ref: {id: string; get: () => Promise<MockSnapshot>; update: (value: Record<string, unknown>) => Promise<void>};
};
type MockSnapshot = {exists: boolean; data: () => User | undefined; ref?: MockDoc["ref"]};
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
  set: (ref: {id: string}, value: Record<string, unknown>, opts?: {merge?: boolean}) => void;
};

function makeUser(id: string, idleDays: number, extra: Partial<User> & Record<string, unknown> = {}): User {
  return {
    id,
    uid: id,
    email: `${id}@example.com`,
    loggedIn: true,
    deleted: false,
    coinState: {streakLastClaimServerAt: admin.firestore.Timestamp.fromMillis(NOW - idleDays * DAY)},
    ...extra,
  } as User;
}

/** Run the exported scheduler against an in-memory Firestore/FCM boundary. */
async function runJob(users: User[], options: {
  beforeTransactions?: (state: Map<string, User>) => void;
  failSend?: boolean;
  concurrentRuns?: number;
  wall?: boolean;
  onComplete?: (state: Map<string, User>) => void;
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
  let transactionTail = Promise.resolve();

  const refFor = (id: string): MockDoc["ref"] => ({
    id,
    get: async () => ({exists: state.has(id), data: () => state.get(id), ref: refFor(id)}),
    update: async (value) => {
      const user = state.get(id);
      if (user) Object.assign(user, value);
    },
  });
  const snapshot = (user: User): MockDoc => {
    const data = {...user, coinState: {...user.coinState}, winBack: user.winBack && {...user.winBack}};
    return {id: user.id, data: () => data, ref: refFor(user.id)};
  };

  const collection = (name: string): ReturnType<typeof firestore.collection> => {
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
              const t = a.coinState.streakLastClaimServerAt.toMillis() - b.coinState.streakLastClaimServerAt.toMillis();
              return t || a.id.localeCompare(b.id);
            }).filter((user) => {
              if (!cursor) return true;
              const cursorTime = cursor.data().coinState.streakLastClaimServerAt.toMillis();
              const userTime = user.coinState.streakLastClaimServerAt.toMillis();
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
      let release!: () => void;
      const previous = transactionTail;
      transactionTail = new Promise<void>((resolve) => {
        release = resolve;
      });
      await previous;
      const changes = new Map<string, User>();
      let committed = false;
      try {
        const result = await callback({
          get: async (ref: {id: string}) => ({exists: state.has(ref.id), data: () => state.get(ref.id)}),
          update: (ref: {id: string}, value: Record<string, unknown>) => changes.set(ref.id, {...state.get(ref.id), ...value} as User),
          set: (ref: {id: string}, value: Record<string, unknown>, opts?: {merge?: boolean}) => changes.set(
            ref.id,
            (opts?.merge ? {...state.get(ref.id), ...value} : value) as User,
          ),
        });
        committed = true;
        return result;
      } finally {
        if (committed) for (const [id, value] of changes) state.set(id, value);
        release();
      }
    },
  });
  Object.defineProperty(messaging, "send", {
    configurable: true,
    value: async (message: admin.messaging.Message) => {
      sent.push(message);
      if (options.failSend) throw new Error("FCM unavailable");
      return `message-${sent.length}`;
    },
  });
  for (const name of ["info", "warn", "error"] as const) {
    Object.defineProperty(logger, name, {configurable: true, value: () => undefined});
  }
  Date.now = () => NOW;
  try {
    const run = (sendWinBackPushes as unknown as {run: () => Promise<void>}).run;
    let failure: unknown;
    try {
      await Promise.all(Array.from({length: options.concurrentRuns ?? 1}, () => run()));
    } catch (err) {
      failure = err;
    }
    options.onComplete?.(state);
    if (failure) return {sent, users: state, failure};
    return {sent, users: state};
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

test("job includes exactly N idle days and excludes the N+1 boundary", async () => {
  const {sent} = await runJob([makeUser("exact", 3), makeUser("next-boundary", 4)]);
  assert.equal(sent.length, 1);
  assert.match(sent[0].data?.route ?? "", /wall_of_the_day/);
});

test("job sends one push using the uid/email condition and app payload", async () => {
  const {sent} = await runJob([makeUser("authoritative", 3.5, {uid: "wrong-uid"})]);
  assert.equal(sent.length, 1);
  const condition = "condition" in sent[0] ? sent[0].condition : undefined;
  assert.ok(condition?.includes("||"));
  assert.ok(condition?.includes("u_authoritative"));
  assert.ok(condition?.includes("authoritative"));
  assert.equal(sent[0].data?.route, "wall_of_the_day");
  assert.equal(sent[0].data?.channel_id, "wall_of_the_day");
  assert.ok(sent[0].android?.notification?.channelId === "wall_of_the_day");
});

test("fresh activity, deleted users and logged-out users are skipped", async () => {
  const {sent} = await runJob([
    makeUser("fresh", 3.5),
    makeUser("deleted", 3.5, {deleted: true}),
    makeUser("logged-out", 3.5, {loggedIn: false}),
  ], {beforeTransactions: (state) => {
    const fresh = state.get("fresh");
    assert.ok(fresh);
    fresh.coinState.streakLastClaimServerAt = admin.firestore.Timestamp.fromMillis(NOW - 2 * DAY);
  }});
  assert.equal(sent.length, 0);
});

test("completed sends dedupe reruns and concurrent invocations", async () => {
  const first = await runJob([makeUser("same", 3.5)]);
  assert.equal(first.sent.length, 1);
  const again = await runJob([...first.users.values()]);
  assert.equal(again.sent.length, 0);

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

test("same-timestamp pages do not skip users after the 300-document boundary", async () => {
  const users = Array.from({length: 301}, (_, i) => makeUser(`page-${String(i).padStart(3, "0")}`, 3.5));
  const {sent} = await runJob(users);
  assert.equal(sent.length, 301);
  assert.equal(new Set(sent.map((message) => JSON.stringify(message))).size, 301);
});
