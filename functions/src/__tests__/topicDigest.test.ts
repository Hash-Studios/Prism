process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import type {GalleryWall, PushGallery} from "../pushGallery";
import * as notificationHelper from "../notificationHelper";
import {nativeNotificationLocalization} from "../notificationCatalog";
import {
  parseFollowedTopics,
  planTopicDigest,
  sendDueTopicDigests,
  TOPICS,
  topicDigestPayload,
  type Topic,
  type TopicDigest,
  type TopicWall,
} from "../topicDigest";
import * as wallOfTheDay from "../wallEligibility";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 10, 5, 10, 30);
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const MARKER = "usersv2/u1/private/topicDigest";
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const CATEGORY_KEYS = [
  "category:Nature", "category:Architecture", "category:Cars", "category:Anime", "category:Gaming",
  "category:Space", "category:Ocean", "category:Flowers", "category:Neon", "category:Dark",
  "category:Abstract", "category:3D Render", "category:Minimal", "category:Gradient", "category:AI Art",
  "category:Cyberpunk", "category:Vintage", "category:Landscape", "category:Galaxy", "category:Pastel",
];

function topic(key: string): Topic {
  const found = TOPICS.get(key);
  assert.ok(found, `unknown topic ${key}`);
  return found;
}

const PASTEL = topic("category:Pastel");
const DREAMY = topic("mood:dreamy");

const gw = (id: string, tags: string[] = ["Pastel"]): GalleryWall => ({
  id, thumb: `https://img.prismwalls.com/previews/${id}.img`, tags,
});

const digestOf = (topics: Array<[Topic, number]>, walls: GalleryWall[]): TopicDigest => ({
  topics: topics.map(([t, count]) => ({topic: t, count})),
  walls,
});

const eight = (tags: string[] = ["Pastel"]) => Array.from({length: 8}, (_, i) => gw(`p${i + 1}`, tags));

const payloadOf = (digest: TopicDigest, gallery: PushGallery | null = null) =>
  topicDigestPayload(digest, "u1", "2026-11-05", gallery);

test("parseFollowedTopics keeps known keys in follow order and drops repeats, unknown ids and wrong case", () => {
  const keys = parseFollowedTopics(
    ["mood:dreamy", "category:Pastel", "mood:dreamy", "category:AMOLED", "free text", 42, "category:pastel"],
  ).map((t) => t.key);
  assert.deepEqual(keys, ["mood:dreamy", "category:Pastel"]);
});

test("parseFollowedTopics keeps at most 20 keys", () => {
  const valid = [...CATEGORY_KEYS, "mood:duo_reveal", "mood:dreamy", "mood:dark_quiet", "mood:bright_bold",
    "mood:minimal"];
  assert.equal(valid.length, 25);
  assert.deepEqual(parseFollowedTopics(valid).map((t) => t.key), CATEGORY_KEYS);
});

test("parseFollowedTopics returns nothing for a value that is not a list", () => {
  assert.deepEqual(parseFollowedTopics("category:Pastel"), []);
  assert.deepEqual(parseFollowedTopics(undefined), []);
});

const tw = (id: string, creatorUid: string, approvedMs: number, topicKeys: string[]): TopicWall => ({
  creatorUid, approvedMs, wall: gw(id), topicKeys,
});

test("planTopicDigest orders topics by count, lists a shared wall once, alternates topics and skips old, blocked walls", () => {
  const walls = [
    tw("w1", "c1", 4000, ["category:Pastel"]),
    tw("w2", "c1", 3000, ["category:Pastel"]),
    tw("w3", "c2", 2000, ["category:Pastel", "mood:dreamy"]),
    tw("w5", "bad", 5000, ["category:Pastel"]),
    tw("w6", "c1", 1000, ["category:Pastel"]),
    tw("w7", "c1", 500, ["category:Pastel"]),
  ];
  const digest = planTopicDigest([PASTEL, DREAMY], walls, 1000, new Set(["bad"]));
  assert.ok(digest);
  assert.deepEqual(digest.topics.map((t) => [t.topic.key, t.count]), [["category:Pastel", 3], ["mood:dreamy", 1]]);
  assert.deepEqual(digest.walls.map((w) => w.id), ["w1", "w3", "w2"]);
});

test("planTopicDigest returns null when nothing is new", () => {
  const walls = [tw("w1", "c1", 4000, ["category:Pastel"]), tw("w5", "bad", 5000, ["category:Pastel"])];
  assert.equal(planTopicDigest([PASTEL], walls, 5000), null);
  assert.equal(planTopicDigest([PASTEL], [tw("w5", "bad", 5000, ["category:Pastel"])], 0, new Set(["bad"])), null);
});

test("topicDigestPayload titles for one wall, one topic, two topics and four topics", () => {
  assert.equal(payloadOf(digestOf([[PASTEL, 1]], [gw("p1")])).title, "A new wall in Pastel");
  assert.equal(payloadOf(digestOf([[PASTEL, 8]], eight())).title, "8 new walls in Pastel");
  assert.equal(payloadOf(digestOf([[PASTEL, 5], [DREAMY, 3]], eight())).title, "8 new walls in Pastel and Dreamy");
  const four = digestOf([[PASTEL, 4], [DREAMY, 2], [topic("category:Nature"), 1], [topic("mood:dark_quiet"), 1]],
    eight());
  assert.equal(payloadOf(four).title, "8 new walls in Pastel and 3 other topics");
});

test("topicDigestPayload opens the lead topic page and carries no wall ids", () => {
  const mood = payloadOf(digestOf([[DREAMY, 1]], eight()));
  assert.deepEqual(mood.data, {
    route: "topic",
    topic_kind: "mood",
    topic_id: "dreamy",
    topic_count: "1",
    url: "https://prismwalls.com/mood/dreamy?source=push",
    notification_kind: "topic_digest",
    push_kind: "post",
  });
  assert.equal("wall_ids" in mood.data, false);

  const category = payloadOf(digestOf([[topic("category:3D Render"), 1]], eight()));
  assert.equal(category.data.url, "https://prismwalls.com/category/3D%20Render");
  assert.equal(category.imageUrl, "https://img.prismwalls.com/previews/p1.img");
  assert.equal(category.collapseKey, "topic_digest_2026-11-05");
  assert.equal(category.docId, "topic_digest_u1_2026-11-05");
  assert.equal("gallery" in category, false);
});

test("topicDigestPayload adds the gallery only when one is passed", () => {
  const gallery: PushGallery = {
    wallIds: ["p1", "p2"],
    stripUrl: "https://img.prismwalls.com/galleries/strip.png",
    heroUrl: "https://img.prismwalls.com/galleries/hero.png",
    count: 2,
    thumbIndex: 0,
    tags: ["Pastel"],
  };
  const digest = digestOf([[PASTEL, 2]], [gw("p1"), gw("p2")]);
  assert.deepEqual(payloadOf(digest, gallery).gallery, gallery);
});

test("nativeNotificationLocalization maps a two-topic digest to the pair keys", () => {
  const message = payloadOf(digestOf([[PASTEL, 5], [DREAMY, 3]], eight([])));
  assert.deepEqual(nativeNotificationLocalization(message.message), {
    titleKey: "notif_push_topic_digest_title_pair",
    titleArgs: ["Pastel", "Dreamy", "8"],
    bodyKey: "notif_push_topic_digest_body_untitled",
    bodyArgs: [],
  });
});

// The fake snapshot has no `ref.parent`. Firestore gives every document one, and the job reads the user id from
// `ref.parent.parent`, which must be usersv2/<uid>.
function withDocParents(query: admin.firestore.Query): admin.firestore.Query {
  const wrapped = {
    where: (field: string, op: admin.firestore.WhereFilterOp, value: unknown) =>
      withDocParents(query.where(field, op, value)),
    get: async () => {
      const snap = await query.get();
      snap.docs.forEach((doc) => {
        const uid = doc.ref.path.split("/")[1];
        Object.assign(doc.ref, {parent: {parent: {id: uid, parent: {id: "usersv2"}}}});
      });
      return snap;
    },
  };
  return wrapped as unknown as admin.firestore.Query;
}

function setup(t: TestContext, seed: Record<string, Doc>) {
  const store = installFakeDb(t, seed);
  const group = db.collectionGroup.bind(db);
  t.mock.method(db, "collectionGroup", (name: string) => withDocParents(group(name)));
  return store;
}

function baseSeed(): Record<string, Doc> {
  const wall = (id: string, approvedMs: number, extra: Doc): Doc => ({
    id, review: true, originalProtected: true, collections: ["nature"], creatorUid: "c1",
    wallpaper_thumb: `https://img.prismwalls.com/previews/${id}.img`, approvedNotifiedAt: ts(approvedMs), ...extra,
  });
  return {
    // Pastel: p1, p2, p3. Dreamy: p1 and d1.
    "walls/p1": wall("p1", NOW - HOUR, {category: "Pastel", colors: ["pink"], visionLabels: ["cloud"]}),
    "walls/p2": wall("p2", NOW - 2 * HOUR, {category: "Pastel", colors: ["black"], visionLabels: ["city"]}),
    "walls/p3": wall("p3", NOW - 3 * HOUR, {category: "Pastel", colors: ["red"], visionLabels: ["food"]}),
    "walls/d1": wall("d1", NOW - HOUR / 2, {category: "Nature", colors: ["blue"], visionLabels: ["sky"]}),
    "usersv2/u1": {email: "u1@x.com", loggedIn: true, lastAppOpenAt: ts(NOW - DAY)},
    "usersv2/u1/private/session": {
      fcmToken: "T1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T1",
      topicAlerts: true, topicAlertsToken: "T1",
      followedTopics: ["category:Pastel", "mood:dreamy"], followedTopicsOffset: 330,
    },
  };
}

function mockDelivery(t: TestContext, delivered = true) {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  return t.mock.method(notificationHelper, "sendToUser", async (payload: Parameters<typeof notificationHelper.sendToUser>[0]) => {
    void payload;
    return delivered;
  });
}

test("sendDueTopicDigests sends one push for Pastel and Dreamy and records the local day", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());

  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  const [payload, recipient] = send.mock.calls[0].arguments;
  assert.equal(payload.title, "4 new walls in Pastel and Dreamy");
  assert.equal(payload.modifier, "u1@x.com");
  assert.deepEqual(recipient, {uid: "u1", email: "u1@x.com", topicAlertsToken: "T1"});
  assert.equal(store.get(MARKER)?.day, "2026-11-05");
  assert.equal(store.get(MARKER)?.atMs, Date.UTC(2026, 10, 5, 10, 30));
});

test("sendDueTopicDigests sends at most one push per local day", async (t) => {
  const send = mockDelivery(t);
  setup(t, baseSeed());

  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(await sendDueTopicDigests(NOW), 0);
  assert.equal(await sendDueTopicDigests(NOW + 15 * 60_000), 0);
  assert.equal(send.mock.callCount(), 1);
});

test("sendDueTopicDigests sends nothing to a user whose local time is not 16:00", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());
  store.set("usersv2/u1/private/session", {
    fcmToken: "T1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T1", topicAlerts: true, topicAlertsToken: "T1",
    followedTopics: ["category:Pastel", "mood:dreamy"], followedTopicsOffset: 0,
  });

  assert.equal(await sendDueTopicDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueTopicDigests respects the topic switch and the token it was switched on for", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());
  const session = {
    fcmToken: "T1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T1",
    followedTopics: ["category:Pastel", "mood:dreamy"], followedTopicsOffset: 330,
  };

  store.set("usersv2/u1/private/session", {...session, topicAlerts: false, topicAlertsToken: "T1"});
  assert.equal(await sendDueTopicDigests(NOW), 0);

  store.set("usersv2/u1/private/session", {...session, topicAlerts: true, topicAlertsToken: "OLD"});
  assert.equal(await sendDueTopicDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueTopicDigests skips users who have not opened the app in 30 days", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());

  store.set("usersv2/u1", {email: "u1@x.com", loggedIn: true, lastAppOpenAt: ts(NOW - 31 * DAY)});
  assert.equal(await sendDueTopicDigests(NOW), 0);

  store.set("usersv2/u1", {email: "u1@x.com", loggedIn: true});
  assert.equal(await sendDueTopicDigests(NOW), 0);

  store.set("usersv2/u1", {email: "u1@x.com", loggedIn: true, lastAppOpenAt: ts(NOW - 29 * DAY)});
  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
});

test("sendDueTopicDigests ignores unknown topic ids, even when new walls match an unknown category", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());
  store.set("walls/a1", {
    id: "a1", review: true, originalProtected: true, collections: ["nature"], creatorUid: "c1", category: "AMOLED",
    colors: ["black"], visionLabels: ["night"], wallpaper_thumb: "https://img.prismwalls.com/previews/a1.img",
    approvedNotifiedAt: ts(NOW - HOUR),
  });
  store.set("usersv2/u1/private/session", {
    fcmToken: "T1", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "T1", topicAlerts: true, topicAlertsToken: "T1",
    followedTopics: ["category:AMOLED", "Pastel walls"], followedTopicsOffset: 330,
  });

  assert.equal(await sendDueTopicDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueTopicDigests counts only walls approved after the last push", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());
  store.set(MARKER, {day: "2026-11-04", atMs: NOW - 2 * HOUR});

  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 1);
  // p2 was approved exactly at the last push and p3 before it, so only p1 and d1 are new.
  assert.equal(send.mock.calls[0].arguments[0].title, "2 new walls in Dreamy and Pastel");
});

test("sendDueTopicDigests sends nothing to a signed-out or deleted user", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());

  store.set("usersv2/u1", {email: "u1@x.com", loggedIn: false, lastAppOpenAt: ts(NOW - DAY)});
  assert.equal(await sendDueTopicDigests(NOW), 0);

  store.set("usersv2/u1", {email: "u1@x.com", deleted: true, lastAppOpenAt: ts(NOW - DAY)});
  assert.equal(await sendDueTopicDigests(NOW), 0);
  assert.equal(send.mock.callCount(), 0);
});

test("sendDueTopicDigests leaves out walls by a creator the user blocked", async (t) => {
  const send = mockDelivery(t);
  const store = setup(t, baseSeed());
  store.set("walls/p2", {...baseSeed()["walls/p2"], creatorUid: "c9"});
  store.set("usersv2/u1/blockedUsers/c9", {});

  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(send.mock.calls[0].arguments[0].title, "3 new walls in Pastel and Dreamy");
});

test("a failed send releases the day, so a later run the same day can send", async (t) => {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  let outcome: boolean | Error = false;
  const send = t.mock.method(notificationHelper, "sendToUser", async () => {
    if (outcome instanceof Error) throw outcome;
    return outcome;
  });
  const store = setup(t, baseSeed());

  await assert.rejects(() => sendDueTopicDigests(NOW), /topicDigest: 1 digest delivery failure/);
  assert.equal(store.has(MARKER), false);

  outcome = true;
  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.equal(send.mock.callCount(), 2);
});

test("a thrown send restores the previous marker", async (t) => {
  t.mock.method(wallOfTheDay, "premiumCollections", async () => []);
  let outcome: boolean | Error = new Error("network down");
  t.mock.method(notificationHelper, "sendToUser", async () => {
    if (outcome instanceof Error) throw outcome;
    return outcome;
  });
  const store = setup(t, baseSeed());
  store.set(MARKER, {day: "2026-11-04", atMs: NOW - 2 * HOUR});

  await assert.rejects(() => sendDueTopicDigests(NOW), /topicDigest: 1 digest delivery failure/);
  assert.deepEqual(store.get(MARKER), {day: "2026-11-04", atMs: NOW - 2 * HOUR});

  outcome = true;
  assert.equal(await sendDueTopicDigests(NOW), 1);
});

test("sendDueTopicDigests stores the newest approval time per topic key", async (t) => {
  mockDelivery(t);
  const store = setup(t, baseSeed());

  assert.equal(await sendDueTopicDigests(NOW), 1);
  assert.deepEqual(store.get("topicNews/current")?.latest, {
    "category:Pastel": Date.UTC(2026, 10, 5, 9, 30),
    "mood:dreamy": Date.UTC(2026, 10, 5, 10, 0),
    "category:Nature": Date.UTC(2026, 10, 5, 10, 0),
  });
});
