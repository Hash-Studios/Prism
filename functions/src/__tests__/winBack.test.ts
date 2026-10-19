import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import type {ScheduledEvent} from "firebase-functions/v2/scheduler";
import {offsetsAtEveningLocal, sendWinBackPushes, WIN_BACK_STEPS, winBackStepFor} from "../winBack";

const NOW = 1_700_000_000_000;
const DAY = 24 * 60 * 60 * 1000;
const MIN = 60 * 1000;
const EVENING = offsetsAtEveningLocal(NOW)[0];
const idle = (ms: number) => winBackStepFor(NOW, NOW - ms, undefined);

test("each step fires at exactly N days and just under N+2 days", () => {
  for (const n of WIN_BACK_STEPS) {
    assert.equal(idle(n * DAY), n);
    assert.equal(idle((n + 1) * DAY), n);
    assert.equal(idle((n + 2) * DAY - MIN), n);
  }
});

test("day 3 is not a step", () => {
  assert.equal(idle(3 * DAY), null);
  assert.equal(idle(3.5 * DAY), null);
  assert.equal(idle(4 * DAY), null);
});

test("N days minus 1 minute is outside the window", () => {
  assert.equal(idle(7 * DAY - MIN), null);
  assert.equal(idle(14 * DAY - MIN), null);
  assert.equal(idle(30 * DAY - MIN), null);
  assert.equal(idle(60 * DAY - MIN), null);
});

test("N+2 days is outside the window", () => {
  assert.equal(idle(9 * DAY), null);
  assert.equal(idle(16 * DAY), null);
  assert.equal(idle(32 * DAY), null);
  assert.equal(idle(62 * DAY), null);
});

test("a day the job missed still gets the push on the next run, once", () => {
  const last = NOW - 8 * DAY;
  assert.equal(winBackStepFor(NOW, last, undefined), 7);
  assert.equal(winBackStepFor(NOW, last, {step: 7, openAtMs: last}), null);
});

test("0 to 2 days and over 62 days return null", () => {
  assert.equal(idle(0), null);
  assert.equal(idle(2 * DAY + 23 * 60 * MIN), null);
  assert.equal(idle(62 * DAY), null);
  assert.equal(idle(90 * DAY), null);
});

test("same last open already sent is deduped", () => {
  const last = NOW - 7 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 7, openAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 14, openAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 3, openAtMs: last}), 7);
});

test("newer activity after an earlier send resets dedupe", () => {
  const last = NOW - 7 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 60, openAtMs: NOW - 200 * DAY}), 7);
});

test("every 15 minute slot has an 18:00 offset inside the range", () => {
  for (let slot = 0; slot < 96; slot += 1) {
    const offsets = offsetsAtEveningLocal(Date.UTC(2026, 0, 1, 0, slot * 15));
    assert.ok(offsets.length >= 1, `slot ${slot}`);
    for (const offset of offsets) {
      const utcMinutes = Math.round((Date.UTC(2026, 0, 1, 0, slot * 15) / 60_000 % 1440) / 15) * 15;
      assert.equal((utcMinutes + offset + 1440 * 2) % 1440, 18 * 60);
      // A negative multiple of 15 leaves a remainder of -0, which strict equal rejects.
      assert.equal(((offset % 15) + 15) % 15, 0);
      assert.ok(offset >= -720 && offset <= 840);
    }
  }
});

type User = Record<string, unknown> & {
  id: string;
  uid?: string;
  email?: string;
  loggedIn?: boolean;
  deleted?: boolean;
  lastAppOpenAt?: unknown;
  appOpenTimezoneOffsetMinutes?: unknown;
  coinState: Record<string, unknown>;
  winBack?: Record<string, unknown>;
};
type MockDoc = {
  id: string;
  data: () => User;
  ref: {
    id: string;
    get: () => Promise<{data: () => User | undefined}>;
    update: (value: Record<string, unknown>) => Promise<void>;
  };
};
type MockQuery = {
  where: (field: string, op: string, value: unknown) => MockQuery;
  orderBy: (field: string) => MockQuery;
  startAfter: (cursor: MockDoc) => MockQuery;
  limit: (count: number) => MockQuery;
  get: () => Promise<{docs: MockDoc[]; size: number; empty: boolean}>;
};

const openMs = (user: User) =>
  user.lastAppOpenAt instanceof admin.firestore.Timestamp ? user.lastAppOpenAt.toMillis() : -1;

function matches(user: User, field: string, op: string, value: unknown): boolean {
  if (field === "appOpenTimezoneOffsetMinutes") return op === "==" && user.appOpenTimezoneOffsetMinutes === value;
  if (field !== "lastAppOpenAt") return false;
  if (!(user.lastAppOpenAt instanceof admin.firestore.Timestamp)) return false;
  const ms = user.lastAppOpenAt.toMillis();
  const bound = value instanceof admin.firestore.Timestamp ? value.toMillis() : Number.NaN;
  if (op === ">") return ms > bound;
  if (op === ">=") return ms >= bound;
  if (op === "<") return ms < bound;
  if (op === "<=") return ms <= bound;
  return false;
}

function makeUser(id: string, idleDays: number, extra: Partial<User> & Record<string, unknown> = {}): User {
  const base = {
    id,
    uid: id,
    email: `${id}@example.com`,
    loggedIn: true,
    deleted: false,
    lastAppOpenAt: admin.firestore.Timestamp.fromMillis(NOW - idleDays * DAY),
    appOpenTimezoneOffsetMinutes: EVENING,
    coinState: {},
  };
  return {...base, ...extra, id, coinState: extra.coinState ?? base.coinState};
}

function messageTopic(message: admin.messaging.Message): string | undefined {
  return "topic" in message ? message.topic : undefined;
}

function expectedLocalizedTopicTargets(legacyTopics: string[]): string[] {
  return legacyTopics.flatMap((topic) => [topic, `${topic}_loc_v1`]).sort();
}

async function runJob(users: User[], options: {
  failSend?: boolean;
  wall?: boolean;
  token?: string;
  clock?: number;
  sessions?: Record<string, Record<string, unknown>>;
  activityChanges?: Record<string, number>;
  offsetChanges?: Record<string, number>;
  dedupeChanges?: Record<string, Record<string, unknown>>;
} = {}) {
  const firestore = admin.firestore();
  const messaging = admin.messaging();
  const loggerDescriptors = ["info", "warn", "error"].map((name) => [name,
    Object.getOwnPropertyDescriptor(logger, name)] as const);
  const firestoreCollection = firestore.collection.bind(firestore);
  const firestoreDoc = firestore.doc.bind(firestore);
  const messagingSend = messaging.send.bind(messaging);
  const dateNow = Date.now;
  const state = new Map(users.map((u) => [u.id, u]));
  const sent: admin.messaging.Message[] = [];
  const collections: string[] = [];

  const refFor = (id: string): MockDoc["ref"] => ({
    id,
    get: async () => ({data: () => state.get(id)}),
    update: async (value) => {
      const current = state.get(id);
      if (!current) throw new Error(`Missing test document: ${id}`);
      state.set(id, {...current, ...value});
    },
  });
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
      where(field: string, op: string, value: unknown) {
        const filters: Array<[string, string, unknown]> = [[field, op, value]];
        let cursor: MockDoc | undefined;
        let pageSize = Number.POSITIVE_INFINITY;
        const query = {} as MockQuery;
        Object.assign(query, {
          where(nextField: string, nextOp: string, nextValue: unknown) {
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
            const eligible = users.filter((user) => filters.every(([f, operator, bound]) => matches(user, f, operator, bound)))
              .sort((a, b) => openMs(a) - openMs(b) || a.id.localeCompare(b.id))
              .filter((user) => {
                if (!cursor) return true;
                const cursorTime = openMs(cursor.data());
                const userTime = openMs(user);
                return userTime > cursorTime || (userTime === cursorTime && user.id.localeCompare(cursor.id) > 0);
              });
            const docs = eligible.slice(0, pageSize).map(snapshot);
            return {docs, size: docs.length, empty: docs.length === 0};
          },
        });
        return query;
      },
    };
    return usersCollection as unknown as ReturnType<typeof firestore.collection>;
  };

  Object.defineProperty(firestore, "collection", {configurable: true, value: collection});
  Object.defineProperty(firestore, "doc", {
    configurable: true,
    value: (path: string) => ({get: async () => {
      const uid = path.split("/")[1];
      const changedActivity = options.activityChanges?.[uid];
      const current = state.get(uid);
      if (changedActivity !== undefined && current) {
        state.set(uid, {...current, lastAppOpenAt: admin.firestore.Timestamp.fromMillis(NOW - changedActivity * DAY)});
      }
      const changedOffset = options.offsetChanges?.[uid];
      if (changedOffset !== undefined && current) {
        state.set(uid, {...(state.get(uid) ?? current), appOpenTimezoneOffsetMinutes: changedOffset});
      }
      const changedDedupe = options.dedupeChanges?.[uid];
      if (changedDedupe && current) state.set(uid, {...(state.get(uid) ?? current), winBack: changedDedupe});
      return {data: () => ({
        ...(options.token ? {fcmToken: options.token} : {}),
        ...(options.sessions?.[uid] ?? {}),
      })};
    }}),
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
  Date.now = () => options.clock ?? NOW;
  try {
    const run = sendWinBackPushes.run;
    await run({jobName: "win-back-test", scheduleTime: new Date(NOW).toISOString()} satisfies ScheduledEvent);
    return {sent, users: state, collections};
  } finally {
    Date.now = dateNow;
    Object.defineProperty(firestore, "collection", {configurable: true, value: firestoreCollection});
    Object.defineProperty(firestore, "doc", {configurable: true, value: firestoreDoc});
    Object.defineProperty(messaging, "send", {configurable: true, value: messagingSend});
    for (const [name, descriptor] of loggerDescriptors) {
      if (descriptor) Object.defineProperty(logger, name, descriptor);
    }
  }
}

test("job includes every exact inactivity boundary and excludes its N+2 boundary", async () => {
  const users = WIN_BACK_STEPS.flatMap((step) => [
    makeUser(`exact-${step}`, step),
    makeUser(`missed-${step}`, step + 1.5),
    makeUser(`boundary-${step}`, step + 2),
  ]);
  const {sent} = await runJob(users);
  assert.equal(sent.length, WIN_BACK_STEPS.length * 4);
  const topics = new Set(sent.map(messageTopic));
  for (const step of WIN_BACK_STEPS) {
    assert.ok(topics.has(`u_exact-${step}`));
    assert.ok(topics.has(`u_exact-${step}_loc_v1`));
    assert.ok(topics.has(`u_missed-${step}`));
    assert.ok(topics.has(`u_missed-${step}_loc_v1`));
    assert.ok(!topics.has(`u_boundary-${step}`));
  }
});

test("job sends the feed push on the recommendations channel", async () => {
  const {sent} = await runJob([makeUser("authoritative", 7.5, {uid: "wrong-uid"})]);
  assert.equal(sent.length, 2);
  assert.equal(messageTopic(sent[0]), "u_authoritative");
  assert.equal(messageTopic(sent[1]), "u_authoritative_loc_v1");
  assert.equal(sent[0].data?.route, "home");
  assert.equal(sent[0].data?.push_kind, "win_back");
  assert.equal(sent[0].data?.step, "7");
  assert.equal(sent[0].data?.channel_id, "recommendations");
  assert.equal(sent[0].android?.notification?.channelId, "recommendations");
  assert.equal(sent[0].android?.notification?.tag, "win_back_7");
  assert.equal(sent[0].notification?.title, "Your feed has new walls");
});

test("each step opens the screen its copy names", async () => {
  const {sent} = await runJob([
    makeUser("week", 7.5),
    makeUser("fortnight", 14.5),
    makeUser("month", 30.5),
    makeUser("two-months", 60.5),
  ], {wall: true});
  const byTopic = new Map(sent.map((message) => [messageTopic(message), message]));
  assert.equal(byTopic.get("u_week")?.data?.route, "home");
  assert.equal(byTopic.get("u_fortnight")?.data?.route, "home");
  assert.equal(byTopic.get("u_fortnight")?.notification?.title, "New walls are waiting");
  assert.equal(byTopic.get("u_month")?.data?.route, "ai");
  assert.equal(byTopic.get("u_month")?.data?.step, "30");
  assert.equal(byTopic.get("u_month")?.notification?.title, "New AI styles to try");
  assert.equal(byTopic.get("u_two-months")?.data?.route, "wall_of_the_day");
  assert.equal(byTopic.get("u_two-months")?.data?.wall_id, "wall-1");
  assert.equal(byTopic.get("u_two-months")?.data?.imageUrl, "https://image");
  assert.equal(byTopic.get("u_two-months")?.notification?.title, "Prism misses you");
  assert.equal(byTopic.get("u_week")?.data?.wall_id, undefined);
});

test("a user outside this slot's evening offset is not queried", async () => {
  const {sent} = await runJob([
    makeUser("here", 7.5),
    makeUser("elsewhere", 7.5, {appOpenTimezoneOffsetMinutes: EVENING === 0 ? 15 : 0}),
  ]);
  assert.deepEqual(sent.map(messageTopic).sort(), expectedLocalizedTopicTargets(["u_here"]));
});

test("a late run still uses its scheduled slot", async () => {
  const {sent} = await runJob([makeUser("late", 7.5)], {clock: NOW + 30 * MIN});
  assert.equal(sent.length, 2);
  assert.deepEqual(sent.map(messageTopic).sort(), expectedLocalizedTopicTargets(["u_late"]));
});

test("activity that changes after the query is rechecked before sending", async () => {
  const {sent, users} = await runJob([makeUser("returned", 7.5)], {activityChanges: {returned: 0}});
  assert.equal(sent.length, 0);
  assert.equal(users.get("returned")?.winBack, undefined);
});

test("a dedupe stamp that changes after the query is rechecked before sending", async () => {
  const openAt = admin.firestore.Timestamp.fromMillis(NOW - 7.5 * DAY);
  const {sent, users} = await runJob([makeUser("already-sent", 7.5)], {
    dedupeChanges: {"already-sent": {step: 7, openAt}},
  });
  assert.equal(sent.length, 0);
  assert.equal(users.get("already-sent")?.winBack?.step, 7);
});

test("a timezone offset that changes after the query is rechecked before sending", async () => {
  const changedOffset = EVENING === 0 ? 15 : 0;
  const {sent, users} = await runJob([makeUser("changed-zone", 7.5)], {
    offsetChanges: {"changed-zone": changedOffset},
  });
  assert.equal(sent.length, 0);
  assert.equal(users.get("changed-zone")?.appOpenTimezoneOffsetMinutes, changedOffset);
});

test("job also pushes to the stored token with the same collapse key", async () => {
  const {sent} = await runJob([makeUser("tokened", 7.5)], {token: "tok-1"});
  assert.equal(sent.length, 3);
  assert.equal(messageTopic(sent[0]), "u_tokened");
  assert.equal(messageTopic(sent[1]), "u_tokened_loc_v1");
  assert.equal("token" in sent[2] ? sent[2].token : undefined, "tok-1");
  assert.equal(sent[0].android?.notification?.tag, sent[1].android?.notification?.tag);
  assert.equal(sent[1].android?.notification?.tag, sent[2].android?.notification?.tag);
});

test("fresh activity, day 3, deleted users and logged-out users are skipped", async () => {
  const {sent} = await runJob([
    makeUser("fresh", 2),
    makeUser("day3", 3.5),
    makeUser("deleted", 7.5, {deleted: true}),
    makeUser("logged-out", 7.5, {loggedIn: false}),
  ]);
  assert.equal(sent.length, 0);
});

test("completed sends dedupe reruns", async () => {
  const first = await runJob([makeUser("same", 7.5)]);
  assert.equal(first.sent.length, 2);
  const again = await runJob([...first.users.values()]);
  assert.equal(again.sent.length, 0);
});

test("failed FCM does not leave a completed stamp", async () => {
  const failed = await runJob([makeUser("retry", 7.5)], {failSend: true});
  assert.equal(failed.sent.length, 2);
  const user = failed.users.get("retry");
  assert.ok(user);
  assert.equal(user.winBack?.step, undefined);
  const retry = await runJob([...failed.users.values()]);
  assert.equal(retry.sent.length, 2);
});

test("varied timestamp pages with ties do not skip users after the 300-document boundary", async () => {
  const users = Array.from({length: 307}, (_, i) => makeUser(
    `page-${String(999 - i).padStart(3, "0")}`,
    7.2 + (i % 6) * 0.1,
  ));
  const {sent} = await runJob(users);
  assert.equal(sent.length, 614);
  assert.equal(new Set(sent.map((message) => JSON.stringify(message))).size, 614);
});

test("freshly missing or malformed last opens are skipped", async () => {
  const {sent} = await runJob([
    makeUser("missing-open", 7.5, {lastAppOpenAt: undefined}),
    makeUser("wrong-open", 7.5, {lastAppOpenAt: "not-a-timestamp"}),
  ]);
  assert.equal(sent.length, 0);
});

test("malformed completed dedupe timestamps do not crash or suppress an eligible user", async () => {
  const {sent} = await runJob([makeUser("bad-dedupe", 7.5, {
    winBack: {step: 60, openAt: {toMillis: "not-a-function"}},
  })]);
  assert.equal(sent.length, 2);
});

test("an old streak-claim stamp does not block a last-open sequence", async () => {
  const openAt = admin.firestore.Timestamp.fromMillis(NOW - 7.5 * DAY);
  const {sent} = await runJob([makeUser("legacy", 7.5, {
    lastAppOpenAt: openAt,
    winBack: {step: 60, claimAt: openAt},
  })]);
  assert.equal(sent.length, 2);
});

test("the shared email-prefix topic is never used", async () => {
  const {sent} = await runJob([
    makeUser("uid-only", 7.5, {email: "###@example.com"}),
    makeUser("doc-uid", 7.5, {uid: "wrong", email: "Alice@example.com"}),
  ]);
  assert.deepEqual(sent.map(messageTopic).sort(), expectedLocalizedTopicTargets(["u_doc-uid", "u_uid-only"]));
});

test("day 60 carries the current wall and a shorter step writes no inbox doc", async () => {
  const withWall = await runJob([makeUser("wall", 60.5)], {wall: true});
  assert.equal(withWall.sent[0].data?.route, "wall_of_the_day");
  assert.equal(withWall.sent[0].data?.wall_id, "wall-1");
  assert.equal(withWall.sent[0].data?.channel_id, "recommendations");
  assert.equal(withWall.sent[0].data?.imageUrl, "https://image");

  const fallback = await runJob([makeUser("fallback", 7.5)]);
  assert.equal(fallback.sent[0].data?.route, "home");
  assert.equal(fallback.sent[0].data?.channel_id, "recommendations");
  assert.equal(fallback.sent[0].data?.wall_id, undefined);
  assert.equal(fallback.sent[0].data?.imageUrl, undefined);
  assert.ok(!fallback.collections.includes("notifications"));
  assert.ok(!fallback.collections.includes("wall_of_the_day"));
});

test("failed later-step delivery preserves the earlier completed stamp", async () => {
  const openAt = admin.firestore.Timestamp.fromMillis(NOW - 7.5 * DAY);
  const sentAt = admin.firestore.Timestamp.fromMillis(NOW - DAY);
  const failed = await runJob([makeUser("later-step", 7.5, {
    winBack: {step: 3, openAt, sentAt},
  })], {failSend: true});
  const winBack = failed.users.get("later-step")?.winBack;
  assert.equal(winBack?.step, 3);
  assert.equal(winBack?.openAt, openAt);
  assert.equal(winBack?.sentAt, sentAt);
});

test("a user who turned marketing pushes off gets no win-back push and no stamp", async () => {
  const {sent, users} = await runJob([
    makeUser("muted", 7.5),
    makeUser("on", 7.5),
    makeUser("unset", 7.5),
  ], {token: "tok-1", sessions: {muted: {marketingPushes: false}, on: {marketingPushes: true}}});
  assert.deepEqual(
    sent.map(messageTopic).filter(Boolean).sort(),
    expectedLocalizedTopicTargets(["u_on", "u_unset"]),
  );
  assert.equal(sent.length, 6);
  assert.equal(users.get("muted")?.winBack, undefined);
});
