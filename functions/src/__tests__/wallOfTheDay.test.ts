import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import type {ScheduledEvent} from "firebase-functions/v2/scheduler";
import {db} from "../common";
import {
  isWotdEligible,
  offsetsAtNineLocal,
  parseCollectionList,
  sendWallOfTheDayBuckets,
  wallOfTheDay,
  wotdBucketTopic,
} from "../wallOfTheDay";

const event = {jobName: "t", scheduleTime: new Date().toISOString()} satisfies ScheduledEvent;
const PREMIUM = ["space", "abstract"];

test("bucket topics name the UTC offset in hours and minutes", () => {
  assert.equal(wotdBucketTopic(330), "wall_of_the_day_utc_p0530");
  assert.equal(wotdBucketTopic(345), "wall_of_the_day_utc_p0545");
  assert.equal(wotdBucketTopic(0), "wall_of_the_day_utc_p0000");
  assert.equal(wotdBucketTopic(-210), "wall_of_the_day_utc_m0330");
  assert.equal(wotdBucketTopic(840), "wall_of_the_day_utc_p1400");
  assert.equal(wotdBucketTopic(-720), "wall_of_the_day_utc_m1200");
});

test("every bucket topic is a valid FCM topic name", () => {
  for (let offset = -720; offset <= 840; offset += 15) {
    assert.match(wotdBucketTopic(offset), /^[a-zA-Z0-9-_.~%]+$/);
  }
});

test("the offsets at 09:00 local follow the UTC clock in 15 minute steps", () => {
  const at = (iso: string) => offsetsAtNineLocal(Date.parse(iso));
  assert.deepEqual(at("2026-01-02T03:30:00Z"), [330]);
  assert.deepEqual(at("2026-01-02T03:30:20Z"), [330]);
  assert.deepEqual(at("2026-01-02T03:29:50Z"), [330]);
  assert.deepEqual(at("2026-01-02T03:15:00Z"), [345]);
  assert.deepEqual(at("2026-01-02T09:00:00Z"), [0]);
  assert.deepEqual(at("2026-01-02T00:00:00Z"), [540].filter((o) => o <= 840));
  assert.deepEqual(at("2026-01-02T14:00:00Z"), [-300]);
  assert.deepEqual(at("2026-01-02T21:00:00Z"), [720, -720]);
  assert.deepEqual(at("2026-01-02T19:00:00Z"), [840, -600]);
});

test("every UTC slot of the day has at least one bucket and every bucket is hit once a day", () => {
  const hits = new Map<number, number>();
  for (let minute = 0; minute < 1440; minute += 15) {
    const offsets = offsetsAtNineLocal(Date.UTC(2026, 0, 2, 0, minute));
    assert.ok(offsets.length >= 1);
    for (const offset of offsets) hits.set(offset, (hits.get(offset) ?? 0) + 1);
  }
  for (let offset = -720; offset <= 840; offset += 15) assert.equal(hits.get(offset), 1, `offset ${offset}`);
});

test("streak-exclusive and premium-collection walls are not eligible", () => {
  assert.equal(isWotdEligible({collections: ["nature"]}, PREMIUM), true);
  assert.equal(isWotdEligible({}, PREMIUM), true);
  assert.equal(isWotdEligible({is_streak_exclusive: true, collections: ["nature"]}, PREMIUM), false);
  assert.equal(isWotdEligible({collections: ["nature", " space "]}, PREMIUM), false);
});

test("the premium list parses the app's remote config format", () => {
  assert.deepEqual(parseCollectionList("[\"space\", \"mesh gradients\"]"), ["space", "mesh gradients"]);
  assert.deepEqual(parseCollectionList("space,abstract"), ["space", "abstract"]);
  assert.deepEqual(parseCollectionList(""), []);
});

function query(docs: Array<{id: string; data: () => Record<string, unknown>}>, count = docs.length) {
  const q = {
    where: () => q,
    orderBy: () => q,
    limit: () => q,
    offset: () => q,
    select: () => q,
    count: () => q,
    get: async () => ({
      docs,
      empty: docs.length === 0,
      size: docs.length,
      data: () => ({count}),
      forEach: (fn: (doc: unknown) => void) => docs.forEach(fn),
    }),
  };
  return q;
}

type Harness = {
  sets: Array<Record<string, unknown>>;
  updates: Array<Record<string, unknown>>;
  topics: string[];
  deliveries: Record<string, string>;
};

function harness(t: TestContext, options: {
  current?: Record<string, unknown>;
  walls?: Array<{id: string; data: () => Record<string, unknown>}>;
  wallDoc?: Record<string, unknown>;
  sendFails?: boolean;
  deliveries?: Record<string, string>;
}): Harness {
  const result: Harness = {sets: [], updates: [], topics: [], deliveries: {...options.deliveries}};
  const state = {current: options.current};
  const deliveriesRef = {path: "wall_of_the_day/bucket_deliveries"};
  t.mock.method(db, "runTransaction", async (fn: (tx: unknown) => Promise<unknown>) => fn({
    get: async () => ({data: () => ({buckets: {...result.deliveries}})}),
    set: (_ref: unknown, data: {buckets: Record<string, unknown>}) => {
      for (const [topic, wallId] of Object.entries(data.buckets)) {
        if (typeof wallId === "string") result.deliveries[topic] = wallId;
        else delete result.deliveries[topic];
      }
    },
  }));
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("no remote config in tests");
  });
  t.mock.method(db, "collection", (name: string) => {
    if (name === "wall_of_the_day") {
      return {doc: (id: string) => id === "bucket_deliveries" ? deliveriesRef : ({
        get: async () => ({data: () => state.current}),
        set: async (data: Record<string, unknown>) => {
          state.current = data;
          return result.sets.push(data);
        },
        update: async (data: Record<string, unknown>) => {
          state.current = {...state.current, ...data};
          return result.updates.push(data);
        },
      })};
    }
    if (name === "past_picks") return {...query([]), doc: () => ({set: async () => undefined})};
    if (name === "walls") {
      return {...query(options.walls ?? []), doc: () => ({get: async () => ({data: () => options.wallDoc})})};
    }
    if (name === "notifications") return {doc: () => ({set: async () => undefined}), add: async () => undefined};
    throw new Error(`Unexpected collection ${name}`);
  });
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    if (options.sendFails) throw new Error("fcm down");
    result.topics.push(message.topic ?? "");
    return "id";
  });
  return result;
}

const wall = (id: string, extra: Record<string, unknown> = {}) => ({
  id,
  data: () => ({title: id, collections: ["nature"], ...extra}),
});

test("a run that finds today's announced pick does nothing", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now(), pushedAt: admin.firestore.Timestamp.now()},
    deliveries: {wall_of_the_day_utc_p0530: "w1"},
  });
  await wallOfTheDay.run(event);
  assert.deepEqual(h.sets, []);
  assert.deepEqual(h.topics, []);
});

test("a retry after the pick was saved but not announced only sends the push", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
    wallDoc: {title: "Dunes"},
    deliveries: {wall_of_the_day_utc_p0530: "w1"},
  });
  await wallOfTheDay.run(event);
  assert.deepEqual(h.sets, []);
  assert.deepEqual(h.topics, ["wall_of_the_day"]);
  assert.equal(h.updates.length, 1);
  assert.ok(h.updates[0].pushedAt);
});

test("the daily pick skips streak-exclusive and premium walls", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const old = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 86_400_000);
  const h = harness(t, {
    current: {wallId: "old", date: old},
    walls: [wall("excl", {is_streak_exclusive: true}), wall("prem", {collections: ["space"]}), wall("ok")],
    wallDoc: {title: "ok"},
  });
  await wallOfTheDay.run(event);
  assert.equal(h.sets.length, 1);
  assert.equal(h.sets[0].wallId, "ok");
  assert.deepEqual(h.topics, ["wall_of_the_day", "wall_of_the_day_utc_p0530"]);
});

test("no eligible wall makes the run fail so the scheduler retries", async (t) => {
  harness(t, {walls: [wall("excl", {is_streak_exclusive: true})]});
  await assert.rejects(async () => {
    await wallOfTheDay.run(event);
  }, /No eligible walls/);
});

test("a failed push makes the run fail and leaves the pick unannounced", async (t) => {
  const h = harness(t, {current: {wallId: "w1", date: admin.firestore.Timestamp.now()}, sendFails: true});
  await assert.rejects(async () => {
    await wallOfTheDay.run(event);
  }, /push failed/);
  assert.deepEqual(h.updates, []);
});

test("the bucket job pushes to the offset where it is 09:00", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(h.topics, ["wall_of_the_day_utc_p0530"]);
});

test("the bucket job sends both ends of the date line at 21:00 UTC", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T21:00:00Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 17 * 3_600_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(h.topics, ["wall_of_the_day_utc_p1200", "wall_of_the_day_utc_m1200"]);
});

test("the bucket job does not push a stale or missing pick", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:00Z")});
  const stale = harness(t, {current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 31 * 3_600_000)}});
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(stale.topics, []);
});

const TODAY_SLOT = new Date("2026-01-02T03:30:05Z");
const bucket = "wall_of_the_day_utc_p0530";

test("same slot, bucket job first: no stale resend, then today's wall reaches +05:30 once", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const yesterday = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 3_600_000);
  const h = harness(t, {
    current: {wallId: "yesterday", date: yesterday, pushedAt: yesterday},
    walls: [wall("today")],
    wallDoc: {title: "t"},
    deliveries: {[bucket]: "yesterday"},
  });
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(h.topics, []);

  await wallOfTheDay.run(event);
  assert.equal(h.sets[0].wallId, "today");
  assert.deepEqual(h.topics, ["wall_of_the_day", bucket]);
  assert.equal(h.deliveries[bucket], "today");

  await sendWallOfTheDayBuckets.run(event);
  await wallOfTheDay.run(event);
  assert.deepEqual(h.topics, ["wall_of_the_day", bucket]);
});

test("same slot, picker first: the bucket job does not resend today's wall", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const yesterday = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 3_600_000);
  const h = harness(t, {
    current: {wallId: "yesterday", date: yesterday, pushedAt: yesterday},
    walls: [wall("today")],
    wallDoc: {title: "t"},
    deliveries: {[bucket]: "yesterday"},
  });
  await wallOfTheDay.run(event);
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(h.topics, ["wall_of_the_day", bucket]);
});

test("repeated bucket runs send one wall once per bucket", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(event);
  await sendWallOfTheDayBuckets.run(event);
  assert.deepEqual(h.topics, [bucket]);
  assert.equal(h.deliveries[bucket], "w1");
});

test("a failed bucket push restores the marker so the retry sends it", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: "w0"},
    sendFails: true,
  });
  await assert.rejects(async () => {
    await sendWallOfTheDayBuckets.run(event);
  }, /bucket push failed/);
  assert.equal(h.deliveries[bucket], "w0");
});
