import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import type {ScheduledEvent} from "firebase-functions/v2/scheduler";
import {db} from "../common";
import * as delivery from "../ownedAssetDelivery";
import * as drops from "../drops";
import * as pushGallery from "../pushGallery";
import {resetEconomyCache} from "../economy";
import {installFakeDb} from "./fakeDb";
import {
  commitWotdPick,
  isWotdEligible,
  offsetsAtNineLocal,
  parseCollectionList,
  sendWallOfTheDayBuckets,
  wallOfTheDay,
  wotdBucketTopic,
  wallShareUrl,
} from "../wallOfTheDay";

const scheduled = (at = new Date()) => ({jobName: "t", scheduleTime: at.toISOString()}) satisfies ScheduledEvent;
const PREMIUM = ["space", "abstract"];
const PREVIEW = "https://img.example.com/previews/w1.img";
process.env.R2_PREVIEW_BASE_URL = "https://img.example.com";

test("wall shares contain identity and preview only", () => {
  const link = new URL(wallShareUrl({wallId: "w1", thumbnailUrl: "https://example.com/thumb.jpg"}));
  assert.equal(link.searchParams.get("id"), "w1");
  assert.equal(link.searchParams.get("thumb"), "https://example.com/thumb.jpg");
  assert.equal(link.searchParams.has("url"), false);
  assert.equal(new URL(wallShareUrl({wallId: "w1", thumbnailUrl: ""})).searchParams.get("thumb"), "");
});

function assertLocalizedTopicFanout(actual: string[], legacyTopics: string[]): void {
  assert.deepEqual(
    [...actual].sort(),
    legacyTopics.flatMap((topic) => [topic, `${topic}_loc_v1`]).sort(),
  );
}

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
  assert.equal(isWotdEligible({originalProtected: true, collections: ["nature"]}, PREMIUM), true);
  assert.equal(isWotdEligible({originalProtected: true}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: true, collections: [123]}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: true, collections: []}, PREMIUM), true);
  assert.equal(isWotdEligible({originalProtected: true, is_streak_exclusive: true, collections: ["nature"]}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: true, collections: ["nature", " space "]}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: true, collections: ["nature"], dropReserved: true}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: true, collections: ["nature"], dropWeek: "2026-W42"}, PREMIUM), false);
});

test("walls with a public original are not eligible because 3.8.0 clients cannot set them", () => {
  assert.equal(isWotdEligible({collections: ["nature"]}, PREMIUM), false);
  assert.equal(isWotdEligible({originalProtected: false, collections: ["nature"]}, PREMIUM), false);
});

test("the premium list parses the app's remote config format", () => {
  assert.deepEqual(parseCollectionList("[\"space\", \"mesh gradients\"]"), ["space", "mesh gradients"]);
  assert.deepEqual(parseCollectionList("space,abstract"), ["space", "abstract"]);
  assert.deepEqual(parseCollectionList(""), []);
});

function query(docs: Array<{id: string; data: () => Record<string, unknown>}>, count = docs.length, filters?: string[]) {
  const q = {
    where: (field: string, op: string, value: unknown) => {
      filters?.push(`${field}${op}${JSON.stringify(value)}`);
      return q;
    },
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
  tokens: string[];
  deliveries: Record<string, unknown>;
  inboxIds: string[];
  messages: Array<Record<string, unknown>>;
  merges: Array<Record<string, unknown>>;
  state: {current?: Record<string, unknown>};
  gateFirstTransaction: () => () => void;
};

const entry = (wallId: string, date: string, claimId = `claim-${wallId}`) => ({wallId, date, claimId});
const deliveredWall = (h: Harness, topic: string) => (h.deliveries[topic] as {wallId?: string} | undefined)?.wallId;

function harness(t: TestContext, options: {
  current?: Record<string, unknown>;
  walls?: Array<{id: string; data: () => Record<string, unknown>}>;
  wallFilters?: string[];
  wallDoc?: Record<string, unknown>;
  sendFails?: boolean;
  deliveries?: Record<string, unknown>;
  creator?: {id: string; data: Record<string, unknown>};
  drops?: Array<{id: string; data: () => Record<string, unknown>}>;
  onSend?: (h: Harness) => void;
}): Harness {
  const state: {current?: Record<string, unknown>} = {current: options.current};
  const result: Harness = {
    sets: [],
    updates: [],
    topics: [],
    tokens: [],
    deliveries: {...options.deliveries},
    inboxIds: [],
    messages: [],
    merges: [],
    state,
    gateFirstTransaction: () => () => undefined,
  };
  const deliveriesRef = {path: "wall_of_the_day/bucket_deliveries"};
  const currentRef = {
    path: "wall_of_the_day/current",
    get: async () => ({data: () => state.current}),
    set: async (data: Record<string, unknown>, options?: {merge?: boolean}) => {
      if (options?.merge) {
        state.current = {...state.current, ...data};
        return result.merges.push(data);
      }
      state.current = data;
      return result.sets.push(data);
    },
    update: async (data: Record<string, unknown>) => {
      state.current = {...state.current, ...data};
      return result.updates.push(data);
    },
  };
  let gate: Promise<void> | undefined;
  result.gateFirstTransaction = () => {
    let open = () => undefined as void;
    gate = new Promise<void>((resolve) => {
      open = resolve;
    });
    return open;
  };
  t.mock.method(db, "runTransaction", async (fn: (tx: unknown) => Promise<unknown>) => {
    const wait = gate;
    gate = undefined;
    await wait;
    return fn({
      get: async (ref: {path: string; get: () => Promise<unknown>}) => ref.path === deliveriesRef.path ?
        {data: () => ({buckets: {...result.deliveries}})} :
        ref.get(),
      update: (_ref: unknown, data: Record<string, unknown>) => currentRef.update(data),
      set: (ref: {path: string}, data: {buckets: Record<string, unknown>}) => {
        if (ref.path === currentRef.path) {
          currentRef.set(data); return;
        }
        for (const [topic, value] of Object.entries(data.buckets)) {
          if (typeof value === "string" || (typeof value === "object" && value !== null && "claimId" in value)) {
            result.deliveries[topic] = value;
          } else {
            delete result.deliveries[topic];
          }
        }
      },
    });
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("no remote config in tests");
  });
  t.mock.method(delivery, "getOwnedWallDelivery", async () => ({}));
  t.mock.method(db, "collection", (name: string) => {
    if (name === "wall_of_the_day") {
      return {doc: (id: string) => id === "bucket_deliveries" ? deliveriesRef : currentRef};
    }
    if (name === "past_picks") return {...query([]), doc: () => ({set: async () => undefined})};
    if (name === "drops") {
      const filters: Array<[string, string, unknown]> = [];
      const rows = options.drops ?? [];
      const q = {
        where: (field: string, op: string, value: unknown) => {
          filters.push([field, op, value]);
          return q;
        },
        limit: () => q,
        get: async () => {
          const docs = rows.filter((doc) => filters.every(([field, op, value]) => {
            const actual = doc.data()[field];
            return op === ">=" ? Number(actual) >= Number(value) : op === "<" && Number(actual) < Number(value);
          }));
          return {docs, empty: docs.length === 0};
        },
      };
      return q;
    }
    if (name === "walls") {
      return {...query(options.walls ?? [], undefined, options.wallFilters), doc: (id: string) => ({get: async () => ({
        data: () => ({id, review: true, originalProtected: true, collections: ["nature"], ...options.wallDoc}),
      })})};
    }
    if (name === "notifications") {
      return {
        doc: (id: string) => ({set: async () => result.inboxIds.push(id)}),
        add: async () => undefined,
      };
    }
    if (name === "usersv2") {
      const users = options.creator ? [{id: options.creator.id, data: () => options.creator?.data}] : [];
      const rows = {limit: () => rows, get: async () => ({empty: users.length === 0, docs: users})};
      return {where: () => rows};
    }
    throw new Error(`Unexpected collection ${name}`);
  });
  t.mock.method(db, "doc", (path: string) => ({path, get: async () => ({data: () => {
    const uid = path.split("/")[1];
    if (path.endsWith("/private/session")) {
      return options.creator && uid === options.creator.id ? {
        fcmToken: `token-${uid}`, fcmTokenBindingVersion: 1, fcmTokenBindingToken: `token-${uid}`,
      } : undefined;
    }
    if (options.creator && uid === options.creator.id) return options.creator.data;
    return {};
  }})}));
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; token?: string}) => {
    result.messages.push(message as unknown as Record<string, unknown>);
    options.onSend?.(result);
    if (options.sendFails) throw new Error("fcm down");
    if (message.topic) {
      result.topics.push(message.topic);
    }
    if (message.token) result.tokens.push(message.token);
    return "id";
  });
  return result;
}

const wall = (id: string, extra: Record<string, unknown> = {}) => ({
  id,
  data: () => ({id, review: true, title: id, collections: ["nature"], originalProtected: true, ...extra}),
});

test("a run that finds today's announced pick does nothing", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now(), pushedAt: admin.firestore.Timestamp.now()},
    deliveries: {wall_of_the_day_utc_p0530: entry("w1", "2026-01-02")},
  });
  await wallOfTheDay.run(scheduled());
  assert.deepEqual(h.sets, []);
  assert.deepEqual(h.topics, []);
});

test("a retry after the pick was saved but not announced only sends the push", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
    wallDoc: {title: "Dunes"},
    deliveries: {wall_of_the_day_utc_p0530: entry("w1", "2026-01-02")},
  });
  await wallOfTheDay.run(scheduled());
  assert.deepEqual(h.sets, []);
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day"]);
  assert.equal(h.updates.filter((u) => u.pushedAt).length, 1);
  assert.ok(h.updates.some((u) => u.pushedAt));
});

test("the daily pick skips streak-exclusive and premium walls", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const old = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 86_400_000);
  const h = harness(t, {
    current: {wallId: "old", date: old},
    walls: [wall("excl", {is_streak_exclusive: true}), wall("prem", {collections: ["space"]}), wall("ok")],
    wallDoc: {title: "ok"},
  });
  await wallOfTheDay.run(scheduled());
  assert.equal(h.sets.length, 1);
  assert.equal(h.sets[0].wallId, "ok");
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", "wall_of_the_day_utc_p0530"]);
});

test("the daily pick ignores unprotected walls and queries only protected rows", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const old = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 86_400_000);
  const filters: string[] = [];
  const h = harness(t, {
    current: {wallId: "old", date: old},
    walls: [wall("legacy", {originalProtected: undefined}), wall("ok")],
    wallDoc: {title: "ok"},
    wallFilters: filters,
  });
  await wallOfTheDay.run(scheduled());
  assert.equal(h.sets[0].wallId, "ok");
  assert.ok(filters.includes("originalProtected==true"));
  assert.ok(filters.includes("wallpaper_url==\"\""));
});

test("no eligible wall leaves the pointer and audience unchanged", async (t) => {
  const h = harness(t, {walls: [wall("excl", {is_streak_exclusive: true})]});
  await wallOfTheDay.run(scheduled());
  assert.deepEqual(h.sets, []);
  assert.deepEqual(h.topics, []);
});

test("an empty protected corpus logs the cutover gap without saving or pushing a legacy wall", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {});
  const errors: unknown[][] = [];
  t.mock.method(logger, "error", (...args: unknown[]) => errors.push(args));
  await wallOfTheDay.run(scheduled());
  assert.deepEqual(h.sets, []);
  assert.deepEqual(h.topics, []);
  assert.match(JSON.stringify(errors), /no ready eligible wall/i);
});

for (const currentWall of [{review: false}, {originalProtected: false}, {collections: ["space"]}]) {
  test(`a current pointer whose wall is no longer eligible cannot be announced: ${JSON.stringify(currentWall)}`, async (t) => {
    t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
    const h = harness(t, {
      current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
      wallDoc: currentWall,
    });
    await wallOfTheDay.run(scheduled());
    await sendWallOfTheDayBuckets.run(scheduled());
    assert.deepEqual(h.sets, []);
    assert.deepEqual(h.topics, []);
    assert.equal(h.updates.some((u) => u.pushedAt), false);
    assert.deepEqual(h.deliveries, {});
  });
}

test("a protected marker without a ready manifest cannot become the daily pick or reach a bucket", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const store = installFakeDb(t, {
    "walls/invalid": {id: "invalid", review: true, originalProtected: true, collections: ["nature"], createdAt: 1,
      wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""},
    "wall_of_the_day/current": {wallId: "invalid", date: admin.firestore.Timestamp.now()},
  });
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));
  const errors: unknown[][] = [];
  t.mock.method(logger, "error", (...args: unknown[]) => errors.push(args));
  let pushes = 0;
  t.mock.method(admin.messaging(), "send", async () => {
    pushes++;
    return "id";
  });
  await wallOfTheDay.run(scheduled());
  await sendWallOfTheDayBuckets.run(scheduled());
  assert.equal(pushes, 0);
  assert.equal(store.get("wall_of_the_day/current")?.pushedAt, undefined);
  const buckets = store.get("wall_of_the_day/bucket_deliveries")?.buckets as Record<string, Record<string, unknown>>;
  assert.equal(buckets[wotdBucketTopic(330)]?.wallId, undefined);
  assert.equal(buckets[wotdBucketTopic(330)]?.claimId, undefined);
  assert.deepEqual(buckets[wotdBucketTopic(330)], {__op: "delete"});
  assert.match(JSON.stringify(errors), /no ready eligible wall/i);
});

test("a failed push makes the run fail and leaves the pick unannounced", async (t) => {
  const h = harness(t, {current: {wallId: "w1", date: admin.firestore.Timestamp.now()}, sendFails: true});
  await assert.rejects(async () => {
    await wallOfTheDay.run(scheduled());
  }, /push failed/);
  assert.equal(h.updates.some((u) => u.pushedAt), false);
});

test("the bucket job pushes to the offset where it is 09:00", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day_utc_p0530"]);
});

test("the bucket job sends both ends of the date line at 21:00 UTC", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T21:00:00Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 17 * 3_600_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day_utc_p1200", "wall_of_the_day_utc_m1200"]);
});

test("the WOTD gallery gate uses each bucket's local delivery day", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T19:00:00Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  const days: string[] = [];
  t.mock.method(drops, "dropOwnsGallery", async (day: string, offsetMinutes: number) => {
    days.push(`${day}|${offsetMinutes}`);
    return false;
  });

  await sendWallOfTheDayBuckets.run(scheduled());

  assert.deepEqual(days, ["2026-01-03|840", "2026-01-02|-600"]);
  assert.equal(h.topics.length, 4);
});

test("the WOTD gallery is suppressed only for a bucket whose local drop day matches", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-10-18T21:00:00Z")});
  const gallery = {
    wallIds: ["w1", "w2"],
    stripUrl: "https://img.example.com/push-gallery/strip.jpg",
    heroUrl: "https://img.example.com/push-gallery/hero.jpg",
    count: 2,
    thumbIndex: 0,
    tags: ["Night"],
  };
  const wallDoc = {
    title: "Dunes",
    review: true,
    originalProtected: true,
    collections: ["nature"],
    visionLabels: ["Night"],
    wallpaper_thumb: PREVIEW,
  };
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc,
    walls: [
      {id: "w1", data: () => ({...wallDoc, id: "w1", createdAt: 2})},
      {id: "w2", data: () => ({...wallDoc, id: "w2", createdAt: 1})},
    ],
    drops: [{id: "2026-W43", data: () => ({startsAt: Date.parse("2026-10-19T00:30:00Z")})}],
  });
  t.mock.method(pushGallery, "buildPushGallery", async () => gallery);
  resetEconomyCache();

  await sendWallOfTheDayBuckets.run(scheduled());

  const messages = h.messages.map((message) => ({
    topic: String(message.topic),
    gallery: (message.data as Record<string, string>).gallery,
  }));
  const west = messages.filter((m) => m.topic.startsWith("wall_of_the_day_utc_m1200"));
  const east = messages.filter((m) => m.topic.startsWith("wall_of_the_day_utc_p1200"));
  assert.ok(west.length > 0);
  assert.ok(east.length > 0);
  assert.ok(west.every((m) => m.gallery === undefined));
  assert.ok(east.every((m) => m.gallery === undefined));
});

test("WOTD gallery remains enabled for both date-line buckets when no drop owns the day", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-10-18T21:00:00Z")});
  const gallery = {
    wallIds: ["w1", "w2"],
    stripUrl: "https://img.example.com/push-gallery/strip.jpg",
    heroUrl: "https://img.example.com/push-gallery/hero.jpg",
    count: 2,
    thumbIndex: 0,
    tags: ["Night"],
  };
  const wallDoc = {
    title: "Dunes",
    review: true,
    originalProtected: true,
    collections: ["nature"],
    visionLabels: ["Night"],
    wallpaper_thumb: PREVIEW,
  };
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc,
    walls: [
      {id: "w1", data: () => ({...wallDoc, id: "w1", createdAt: 2})},
      {id: "w2", data: () => ({...wallDoc, id: "w2", createdAt: 1})},
    ],
  });
  t.mock.method(pushGallery, "buildPushGallery", async () => gallery);
  resetEconomyCache();

  await sendWallOfTheDayBuckets.run(scheduled());

  const messages = h.messages.map((message) => ({
    topic: String(message.topic),
    gallery: (message.data as Record<string, string>).gallery,
  }));
  const west = messages.filter((m) => m.topic.startsWith("wall_of_the_day_utc_m1200"));
  const east = messages.filter((m) => m.topic.startsWith("wall_of_the_day_utc_p1200"));
  assert.ok(west.length > 0);
  assert.ok(east.length > 0);
  assert.ok(west.every((m) => m.gallery === "1"));
  assert.ok(east.every((m) => m.gallery === "1"));
});

test("WOTD omits a non-preview thumb instead of using it as a single-image fallback", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:05Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes", wallpaper_thumb: "https://evil.example.com/private.jpg"},
  });
  t.mock.method(drops, "dropOwnsGallery", async () => false);

  await sendWallOfTheDayBuckets.run(scheduled());

  assert.ok(h.messages.length > 0);
  assert.ok(h.messages.every((message) => (message.data as Record<string, string>).imageUrl === undefined));
});

test("the bucket job does not push a stale or missing pick", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:30:00Z")});
  const stale = harness(t, {current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 31 * 3_600_000)}});
  await sendWallOfTheDayBuckets.run(scheduled());
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
    deliveries: {[bucket]: entry("yesterday", "2026-01-01")},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assert.deepEqual(h.topics, []);

  await wallOfTheDay.run(scheduled());
  assert.equal(h.sets[0].wallId, "today");
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", bucket]);
  assert.equal(deliveredWall(h, bucket), "today");

  await sendWallOfTheDayBuckets.run(scheduled());
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", bucket]);
});

test("same slot, picker first: the bucket job does not resend today's wall", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const yesterday = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 3_600_000);
  const h = harness(t, {
    current: {wallId: "yesterday", date: yesterday, pushedAt: yesterday},
    walls: [wall("today")],
    wallDoc: {title: "t"},
    deliveries: {[bucket]: entry("yesterday", "2026-01-01")},
  });
  await wallOfTheDay.run(scheduled());
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", bucket]);
});

test("yesterday's delivery of a wall does not block today's pick of the same wall", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "x", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: entry("x", "2026-01-01")},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, [bucket]);
  assert.equal((h.deliveries[bucket] as {date?: string}).date, "2026-01-02");
});

test("a legacy undated marker for the same wall still blocks a resend", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "x", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: "x"},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assert.deepEqual(h.topics, []);
});

test("repeated bucket runs send one wall once per bucket", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, [bucket]);
  assert.equal(deliveredWall(h, bucket), "w1");
});

test("a failed bucket push restores the marker so the retry sends it", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: entry("w0", "2026-01-01")},
    sendFails: true,
  });
  await assert.rejects(async () => {
    await sendWallOfTheDayBuckets.run(scheduled());
  }, /bucket push failed/);
  assert.equal(deliveredWall(h, bucket), "w0");
});

test("a bucket claim started before the picker committed never resends yesterday's wall", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const yesterday = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 3_600_000);
  const h = harness(t, {
    current: {wallId: "yesterday", date: yesterday, pushedAt: yesterday},
    walls: [wall("today")],
    wallDoc: {title: "t"},
    deliveries: {[bucket]: entry("yesterday", "2026-01-01")},
  });
  const release = h.gateFirstTransaction();
  const bucketJob = sendWallOfTheDayBuckets.run(scheduled());
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", bucket]);
  release();
  await bucketJob;
  await sendWallOfTheDayBuckets.run(scheduled());
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day", bucket]);
  assert.equal(deliveredWall(h, bucket), "today");
});

test("a bucket never moves back to an older pick date", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: entry("w2", "2026-01-03")},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assert.deepEqual(h.topics, []);
  assert.equal(deliveredWall(h, bucket), "w2");
});

test("a legacy string marker for another wall is replaced by the current pick", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: "old"},
  });
  await sendWallOfTheDayBuckets.run(scheduled());
  assertLocalizedTopicFanout(h.topics, [bucket]);
  assert.equal(deliveredWall(h, bucket), "w1");
});

test("a failed send does not roll back a claim that another run has replaced", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const newer = entry("w2", "2026-01-02", "other-run");
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: entry("w0", "2026-01-01")},
    sendFails: true,
    onSend: (state) => {
      state.deliveries[bucket] = newer;
    },
  });
  await assert.rejects(async () => {
    await sendWallOfTheDayBuckets.run(scheduled());
  }, /bucket push failed/);
  assert.deepEqual(h.deliveries[bucket], newer);
});

test("the creator gets one personal notice with a fixed inbox id when their wall is the pick", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
    wallDoc: {title: "Dunes", email: "maker@example.com"},
    creator: {id: "maker1", data: {email: "maker@example.com"}},
    deliveries: {[bucket]: entry("w1", "2026-01-02")},
  });
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day"]);
  assert.deepEqual(h.tokens, ["token-maker1"]);
  assert.deepEqual(h.inboxIds, ["wotd_2026-01-02", "wotd_creator_2026-01-02"]);
});

test("a pick without a creator email sends no personal notice", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
    wallDoc: {title: "Dunes"},
    deliveries: {[bucket]: entry("w1", "2026-01-02")},
  });
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day"]);
  assert.deepEqual(h.inboxIds, ["wotd_2026-01-02"]);
});

test("a creator notice that cannot be delivered does not fail the public push", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: TODAY_SLOT});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.now()},
    wallDoc: {title: "Dunes", email: "maker@example.com"},
    creator: {id: "maker1", data: {email: "maker@example.com"}},
    deliveries: {[bucket]: entry("w1", "2026-01-02")},
    onSend: (state) => {
      if (state.topics.length >= 2) throw new Error("fcm down for the creator");
    },
  });
  await wallOfTheDay.run(scheduled());
  assertLocalizedTopicFanout(h.topics, ["wall_of_the_day"]);
  assert.equal(h.updates.filter((u) => u.pushedAt).length, 1);
});

test("a run that starts late still sends to the bucket of its scheduled slot", async (t) => {
  // The scheduler meant 03:30. The run starts at 03:38, which would round to the 03:45 slot (+05:15).
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T03:38:00Z")});
  const h = harness(t, {
    current: {wallId: "w1", date: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000)},
    wallDoc: {title: "Dunes"},
  });
  await sendWallOfTheDayBuckets.run(scheduled(new Date("2026-01-02T03:30:00Z")));
  assertLocalizedTopicFanout(h.topics, [bucket]);
});


test("an unavailable same-day WOTD can be replaced once, but a stale replacement cannot overwrite it", async (t) => {
  const slot = Date.parse("2026-11-03T03:30:00Z");
  const store = installFakeDb(t, {
    "wall_of_the_day/current": {wallId: "withdrawn", date: admin.firestore.Timestamp.fromMillis(slot)},
  });
  const observed = await db.doc("wall_of_the_day/current").get();
  assert.equal(await commitWotdPick(slot, "replacement", [], false), false);
  assert.equal(await commitWotdPick(slot, "replacement", [], false, observed), true);
  assert.equal(await commitWotdPick(slot, "stale", [], false, observed), false);
  assert.equal(store.get("wall_of_the_day/current")?.wallId, "replacement");
});
