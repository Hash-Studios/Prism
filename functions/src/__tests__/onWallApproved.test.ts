import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onWallApproved, postsCollapseKey} from "../onWallApproved";
import {r2ObjectId} from "../r2Storage";
import {installFakeDb} from "./fakeDb";

function fixture(t: TestContext, owned = false, artist = false) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  for (const key of ["R2_ACCOUNT_ID", "R2_PRIVATE_BUCKET", "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"]) delete process.env[key];
  process.env.GH_REPO_WALLS = "walls";
  if (owned) {
    process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
    process.env.R2_PRIVATE_BUCKET = "private-assets";
  }
  const wall = {id: "w1", review: true, email: "artist@example.com", by: "Artist", title: "Dunes",
    wallpaper_url: "https://example.com/original.jpg", wallpaper_thumb: "https://example.com/thumb.jpg"};
  const store = installFakeDb(t, {"walls/w1": wall,
    ...(artist ? {"usersv2/artist1": {email: "artist@example.com", loggedIn: false}} : {})});
  const topics: string[] = [];
  const tags: Array<string | undefined> = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; android?: {notification?: {tag?: string}}}) => {
    topics.push(message.topic ?? "");
    tags.push(message.android?.notification?.tag);
    return "id";
  });
  const event = async (before: Record<string, unknown> = {review: false}) => ({params: {wallId: "w1"},
    data: {before: {data: () => before}, after: await db.doc("walls/w1").get()},
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  const inbox = () => [...store.keys()].filter((path) => path.startsWith("notifications/"));
  const protect = () => {
    const asset = (path: string, digest: string) => {
      const identity = {repo: "walls", path, sha: "a".repeat(40), uid: "owner", sourceKind: "owned" as const};
      const objectId = r2ObjectId(identity, digest);
      return {...identity, bucket: "private-assets", objectId, object: `private-originals/${objectId}`, sha256: digest};
    };
    const original = asset("original.jpg", "b".repeat(64));
    const thumbAsset = asset("thumb_original.jpg", "c".repeat(64));
    const thumb = {...thumbAsset, previewObjectId: thumbAsset.objectId};
    store.set("walls/w1", {...store.get("walls/w1"), originalProtected: true, originalObjectId: original.objectId,
      wallpaper_url: "", wallpaper_thumb: `https://images.example.com/previews/${thumb.objectId}.img`,
      wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""});
    store.set("ownedAssets/w1", {status: "ready", canonicalPath: "walls/w1", incarnation: 1, incarnationNanos: 1_000_000,
      original, thumb, provenance: {kind: "owned", uid: "owner"}});
  };
  return {store, topics, tags, event, inbox, protect};
}

test("approval notices retry transient failures", () => {
  assert.equal(onWallApproved.__endpoint.eventTrigger?.retry, true);
});

test("approving a wall fills the open request it was made for, and the filled push is sent", async (t) => {
  const {store, event} = fixture(t);
  store.set("walls/w1", {...store.get("walls/w1"), requestId: "r1"});
  store.set("wallRequests/r1", {status: "open", hidden: false, text: "Valorant Jett", tags: [], tokens: ["jett", "valorant"],
    requesterUid: "requester", voteCount: 3, createdAt: admin.firestore.Timestamp.fromMillis(Date.now())});
  await onWallApproved.run(await event());
  assert.equal(store.get("wallRequests/r1")?.status, "filled");
  assert.equal(store.get("wallRequests/r1")?.filledWallId, "w1");
  assert.ok(store.get("wallRequests/r1")?.notifiedAt);
});

test("a signed-out artist keeps the approval in the inbox but gets no push; followers still do", async (t) => {
  const {topics, tags, inbox, event} = fixture(t, false, true);
  await onWallApproved.run(await event());
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1", "posts_artist1", "posts_artist1_loc_v1"]);
  assert.equal(tags[0], tags[1]);
  assert.equal(tags[2], tags[3]);
  assert.equal(tags[0], postsCollapseKey("Artist@Example.com"));
  assert.match(tags[0] ?? "", /^posts_[0-9a-f]{16}$/);
  assert.equal(inbox().length, 1);
});

test("a repeated approval event sends no second set of pushes", async (t) => {
  const {topics, inbox, event} = fixture(t);
  const approval = await event();
  await onWallApproved.run(approval);
  assert.equal(inbox().length, 1);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
  await onWallApproved.run(approval);
  assert.equal(inbox().length, 1);
  assert.equal(topics.length, 2);
});

test("followers of an artist with no profile doc still get the legacy topic push", async (t) => {
  const {topics, event} = fixture(t);
  await onWallApproved.run(await event());
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
});

test("an approved community-only wall is filed into the collection of its category", async (t) => {
  const {store, event} = fixture(t, true);
  store.set("walls/w1", {...store.get("walls/w1"), collections: ["community"], category: "Anime"});
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("no remote config in tests");
  });
  await onWallApproved.run(await event());
  assert.deepEqual(store.get("walls/w1")?.collections, ["community", "illustrations"]);
});

test("R2 approval does not announce an unconverted wall or consume its notice claim", async (t) => {
  const {store, topics, inbox, event, protect} = fixture(t, true);
  await onWallApproved.run(await event());
  assert.equal(topics.length, 0);
  assert.equal(inbox().length, 0);
  assert.equal(store.get("walls/w1")?.approvedNotifiedAt, undefined);
  protect();
  await onWallApproved.run(await event({review: true, originalProtected: false}));
  assert.equal(inbox().length, 1);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
});

test("the protected transition announces a ready wall once and retains category filing", async (t) => {
  const {store, topics, inbox, event, protect} = fixture(t, true);
  protect();
  store.set("walls/w1", {...store.get("walls/w1"), category: "Anime", collections: ["community", "illustrations"]});
  const converted = await event({review: true, originalProtected: false});
  await onWallApproved.run(converted);
  await onWallApproved.run(converted);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
  assert.equal(inbox().length, 1);
  assert.ok(store.get("walls/w1")?.approvedNotifiedAt);
  assert.deepEqual(store.get("walls/w1")?.collections, ["community", "illustrations"]);
});

test("an approval event for an older wall incarnation cannot announce its replacement", async (t) => {
  const {store, topics, inbox, event, protect} = fixture(t, true);
  protect();
  const approval = await event();
  const after = approval.data?.after;
  assert.ok(after);
  Object.assign(after, {createTime: new admin.firestore.Timestamp(0, 1_000_001)});
  await onWallApproved.run(approval);
  assert.equal(topics.length, 0);
  assert.equal(inbox().length, 0);
  assert.equal(store.get("walls/w1")?.approvedNotifiedAt, undefined);
});

test("failed notice claims retry without sending and announce once after recovery", async (t) => {
  const {topics, inbox, event, protect} = fixture(t, true);
  protect();
  const approval = await event();
  const transaction = t.mock.method(db, "runTransaction", async () => {
    throw new Error("Firestore unavailable");
  });
  await assert.rejects(onWallApproved.run(approval), /Firestore unavailable/);
  assert.equal(topics.length, 0);
  assert.equal(inbox().length, 0);
  transaction.mock.restore();
  await onWallApproved.run(approval);
  await onWallApproved.run(approval);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
  assert.equal(inbox().length, 1);
});

test("a protected marker without a matching ready manifest does not announce", async (t) => {
  const {store, topics, inbox, event, protect} = fixture(t, true);
  protect();
  store.set("ownedAssets/w1", {...store.get("ownedAssets/w1"), incarnationNanos: 1_000_001});
  await onWallApproved.run(await event());
  assert.equal(topics.length, 0);
  assert.equal(inbox().length, 0);
  assert.equal(store.get("walls/w1")?.approvedNotifiedAt, undefined);
});

test("a current wall read failure retries before making any claim or sending", async (t) => {
  const {topics, inbox, event, protect} = fixture(t, true);
  protect();
  const converted = await event({review: true, originalProtected: false});
  const ref = converted.data?.after.ref;
  assert.ok(ref);
  const read = t.mock.method(ref, "get", async () => {
    throw new Error("wall read unavailable");
  });
  await assert.rejects(onWallApproved.run(converted), /wall read unavailable/);
  assert.equal(topics.length, 0);
  assert.equal(inbox().length, 0);
  read.mock.restore();
  await onWallApproved.run(converted);
  assert.equal(inbox().length, 1);
  assert.deepEqual(topics.sort(), ["artist_posts", "artist_posts_loc_v1"]);
});
