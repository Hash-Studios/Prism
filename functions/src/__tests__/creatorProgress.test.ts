import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {db} from "../common";
import {onCreatorWallWritten, onCreatorFavouriteCreated} from "../creatorProgress";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 18, 12);
const SOURCE = NOW - 1000;
const timestamp = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const uid = "creator";
const privatePath = `usersv2/${uid}/private/economy`;
const wall = (id = "logical"): Doc => ({
  id, review: true, email: "creator@example.com", wallpaper_provider: "Prism",
  wallpaper_url: `https://raw.githubusercontent.com/hash/walls/main/${id}.jpg`,
  wallpaper_thumb: `https://raw.githubusercontent.com/hash/walls/main/thumb_${id}.jpg`,
  wallpaper_path: `${id}.jpg`, wallpaper_sha: "a".repeat(40),
  thumb_path: `thumb_${id}.jpg`, thumb_sha: "b".repeat(40),
});
const uploadId = (path: string, sha: string) => "file_" + createHash("sha256")
  .update(`walls\0${path}\0${sha}`).digest("hex");
const receiptPath = (logical = "logical") => "creatorWallCredits/" + createHash("sha256").update(logical).digest("hex");
const row = (store: Map<string, Doc>, path: string): Doc => {
  const value = store.get(path);
  assert.ok(value);
  return value;
};

function setup(t: TestContext) {
  t.mock.method(Date, "now", () => NOW);
  const previousEnv = {owner: process.env.GH_USERNAME, repo: process.env.GH_REPO_WALLS};
  process.env.GH_USERNAME = "hash";
  process.env.GH_REPO_WALLS = "walls";
  t.after(() => {
    if (previousEnv.owner === undefined) delete process.env.GH_USERNAME;
    else process.env.GH_USERNAME = previousEnv.owner;
    if (previousEnv.repo === undefined) delete process.env.GH_REPO_WALLS;
    else process.env.GH_REPO_WALLS = previousEnv.repo;
  });
  const store = installFakeDb(t, {
    "usersv2/creator": {email: "creator@example.com", xp: 10, coins: 9},
    "usersv2/member": {email: "member@example.com"},
  });
  const baseCollection = db.collection.bind(db);
  const times = new Map<string, number>();
  const addTimes = (snap: Record<string, unknown>) => {
    const ref = snap.ref as {path: string};
    return {...snap, createTime: timestamp(times.get(ref.path) ?? SOURCE), updateTime: timestamp(SOURCE)};
  };
  const wrap = <T extends object>(target: T): T => new Proxy(target, {
    get: (current, property) => {
      const value: unknown = Reflect.get(current, property);
      if (typeof value !== "function") return value;
      if (property === "get") {
        return async () => {
          const result = await Reflect.apply(value, current, []) as Record<string, unknown>;
          return Array.isArray(result.docs) ? {...result, docs: result.docs.map(addTimes)} : addTimes(result);
        };
      }
      if (["doc", "collection", "where", "limit"].includes(String(property))) {
        return (...args: unknown[]) => wrap(Reflect.apply(value, current, args) as object);
      }
      return value;
    },
  });
  t.mock.method(db, "collection", (path: string) => wrap(baseCollection(path)));
  const authUsers = new Map<string, Doc>([
    ["creator", {uid: "creator", email: "creator@example.com", disabled: false}],
    ["member", {uid: "member", email: "member@example.com", disabled: false, emailVerified: true,
      providerData: [{providerId: "password"} as admin.auth.UserInfo],
      metadata: {creationTime: new Date(NOW - 8 * 86400000).toISOString()} as admin.auth.UserMetadata}],
  ]);
  t.mock.method(admin.auth(), "getUser", async (id: string) => {
    const user = authUsers.get(id);
    if (!user) throw Object.assign(new Error("missing"), {code: "auth/user-not-found"});
    return user as unknown as admin.auth.UserRecord;
  });
  function seedWall(id = "logical", docId = `wall_${id}`, owner = uid) {
    const data = wall(id);
    store.set(`walls/${docId}`, data);
    for (const [path, sha] of [[`${id}.jpg`, "a".repeat(40)], [`thumb_${id}.jpg`, "b".repeat(40)]]) {
      store.set(`githubUploads/${uploadId(path, sha)}`, {uid: owner, repo: "walls", path, sha});
      store.set(`githubUploadIntents/path_${createHash("sha256").update(`walls\0${path}`).digest("hex")}`, {
        uid: owner, repo: "walls", path, blobSha: sha, status: "complete",
        response: {content: {path, sha, download_url: `https://raw.githubusercontent.com/hash/walls/main/${path}`}},
      });
    }
    return data;
  }
  return {store, seedWall, times, authUsers};
}

async function approve(data: Doc = wall(), documentId = "wall_logical", before: Doc | undefined = {review: false}) {
  const ref = db.collection("walls").doc(documentId);
  await onCreatorWallWritten.run({params: {wallId: documentId}, data: {
    before: {exists: before !== undefined, data: () => before},
    after: {exists: true, ref, data: () => data, createTime: timestamp(SOURCE), updateTime: timestamp(SOURCE)},
  }} as unknown as Parameters<typeof onCreatorWallWritten.run>[0]);
}

async function favourite(store: Map<string, Doc>, id = "logical", member = "member", sourceMs = SOURCE) {
  const ref = db.collection("usersv2").doc(member).collection("images").doc(id);
  store.set(ref.path, {id, provider: "Prism", email: "forged-recipient@example.com"});
  await onCreatorFavouriteCreated.run({params: {uid: member, wallId: id}, data: {
    exists: true, ref, data: () => store.get(ref.path), createTime: timestamp(sourceMs),
  }} as unknown as Parameters<typeof onCreatorFavouriteCreated.run>[0]);
}

test("approval credits a logical ID distinct from the document ID atomically, once", async (t) => {
  const {store, seedWall} = setup(t);
  seedWall();
  await approve();
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  const creator = store.get(privatePath)?.creator as Doc;
  assert.equal(creator.approvedWalls, 1);
  assert.ok(store.has(receiptPath()));
  await approve();
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  assert.equal(store.get(privatePath)?.rev, 1);
});

function protectWall(store: Map<string, Doc>, data: Doc): void {
  store.set("ownedAssets/logical", {
    status: "ready", canonicalPath: "walls/wall_logical", incarnation: SOURCE,
    incarnationNanos: timestamp(SOURCE).nanoseconds, provenance: {kind: "github", uid},
    originalUrl: data.wallpaper_url, thumbUrl: data.wallpaper_thumb,
    original: {generation: "123", path: data.wallpaper_path, sha: data.wallpaper_sha},
    thumb: {path: data.thumb_path, sha: data.thumb_sha},
  });
  Object.assign(data, {wallpaper_url: "", wallpaper_thumb:
    "https://asia-south1-prism-wallpapers.cloudfunctions.net/ownedThumbnail/logical",
  originalProtected: true, originalGeneration: "123"});
}

test("redacted owned walls preserve strict upload provenance for creator credit", async (t) => {
  const {store, seedWall} = setup(t);
  const data = seedWall();
  protectWall(store, data);
  await approve(data);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
});

test("private-only original receipts earn creator credit without inventing a raw original URL", async (t) => {
  const {store, seedWall} = setup(t);
  const data = seedWall();
  protectWall(store, data);
  const manifest = row(store, "ownedAssets/logical");
  manifest.provenance = {kind: "owned", uid};
  manifest.originalUrl = "";
  (manifest.original as Doc).repo = "walls";
  const upload = row(store, `githubUploads/${uploadId("logical.jpg", "a".repeat(40))}`);
  upload.sourceKind = "owned";
  upload.retainedAsset = {generation: "123"};
  const intent = row(store, `githubUploadIntents/path_${createHash("sha256").update("walls\0logical.jpg").digest("hex")}`);
  intent.sourceKind = "owned";
  intent.retainedAsset = {generation: "123"};
  intent.response = {content: {path: "logical.jpg", sha: "a".repeat(40), download_url: ""}};
  await approve(data);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
});

test("binding after approval credits a private original once and retries do not duplicate rewards", async (t) => {
  const {store, seedWall} = setup(t);
  const data = seedWall();
  data.wallpaper_url = "";
  const unbound = {...data};
  await approve(data);
  assert.equal(store.get("usersv2/creator")?.xp, 10);
  assert.equal(store.has(receiptPath()), false);
  protectWall(store, data);
  const manifest = row(store, "ownedAssets/logical");
  manifest.provenance = {kind: "owned", uid};
  (manifest.original as Doc).repo = "walls";
  const upload = row(store, `githubUploads/${uploadId("logical.jpg", "a".repeat(40))}`);
  upload.sourceKind = "owned";
  upload.retainedAsset = {generation: "123"};
  const intent = row(store, `githubUploadIntents/path_${createHash("sha256").update("walls\0logical.jpg").digest("hex")}`);
  intent.sourceKind = "owned";
  intent.retainedAsset = {generation: "123"};
  intent.response = {content: {path: "logical.jpg", sha: "a".repeat(40), download_url: ""}};
  await approve(data, "wall_logical", unbound);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  assert.equal((store.get(privatePath)?.creator as Doc).approvedWalls, 1);
  await approve(data, "wall_logical", unbound);
  await approve(data, "wall_logical", {...data});
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  assert.equal(store.get(privatePath)?.rev, 1);
});

for (const failure of ["legacy", "generation", "incarnation", "path", "deleted", "missing-receipts"]) {
  test(`owned provenance rejects ${failure} without granting creator credit`, async (t) => {
    const {store, seedWall} = setup(t);
    const data = seedWall();
    protectWall(store, data);
    const manifest = row(store, "ownedAssets/logical");
    if (failure === "legacy") manifest.provenance = {kind: "legacy"};
    if (failure === "generation") data.originalGeneration = "456";
    if (failure === "incarnation") manifest.incarnationNanos = 1;
    if (failure === "path") data.wallpaper_path = "different.jpg";
    if (failure === "deleted") manifest.status = "deleted";
    if (failure === "missing-receipts") store.delete(`githubUploads/${uploadId("logical.jpg", "a".repeat(40))}`);
    await approve(data);
    assert.equal(store.get("usersv2/creator")?.xp, 10);
    assert.equal(store.has(receiptPath()), false);
  });
}

test("first favourite counts a member once across works and gives only milestone XP", async (t) => {
  const {store, seedWall} = setup(t);
  seedWall(); seedWall("second");
  await favourite(store);
  await favourite(store);
  await favourite(store, "second");
  assert.equal(store.get("usersv2/creator")?.xp, 35);
  assert.equal((store.get(privatePath)?.creator as Doc).uniqueMembers, 1);
  assert.equal((store.get(privatePath)?.creator as Doc).approvedWalls, 0);
});

test("missing and conflicting canonical identities never earn", async (t) => {
  const {store, seedWall} = setup(t);
  seedWall();
  store.set("walls/duplicate", wall());
  await approve(); await favourite(store);
  assert.equal(store.get("usersv2/creator")?.xp, 10);
  assert.ok(!store.has(receiptPath()));
});

for (const [name, mutate] of Object.entries<(ctx: ReturnType<typeof setup>) => void>({
  "legacy": ({store}) => {
    delete store.get("walls/wall_logical")?.wallpaper_sha;
  },
  "copied metadata unrelated to asset URL": ({store}) => {
    row(store, "walls/wall_logical").wallpaper_url = "https://example.com/other.jpg";
  },
  "missing evidence": ({store}) => {
    store.delete(`githubUploads/${uploadId("logical.jpg", "a".repeat(40))}`);
  },
  "path evidence query truncation": ({store}) => {
    for (let i = 0; i < 7; i++) store.set(`githubUploads/extra_${i}`, {uid: "creator", repo: "walls", path: "logical.jpg"});
  },
  "different URL branch from protected upload": ({store}) => {
    row(store, "walls/wall_logical").wallpaper_url = "https://raw.githubusercontent.com/hash/walls/master/logical.jpg";
  },
  "missing completed upload intent": ({store}) => {
    store.delete(`githubUploadIntents/path_${createHash("sha256").update("walls\0logical.jpg").digest("hex")}`);
  },
  "conflicting owner": ({store}) => {
    store.set("githubUploads/conflict", {uid: "attacker", repo: "walls", path: "logical.jpg", sha: "a".repeat(40)});
  },
  "two asset owners": ({store}) => {
    row(store, `githubUploads/${uploadId("thumb_logical.jpg", "b".repeat(40))}`).uid = "attacker";
  },
  "forged author email": ({store}) => {
    row(store, "walls/wall_logical").email = "attacker@example.com";
  },
  "unapproved": ({store}) => {
    row(store, "walls/wall_logical").review = false;
  },
  "Studio": ({store}) => {
    row(store, "walls/wall_logical").origin = "studio";
  },
  "deleted profile": ({store}) => {
    row(store, "usersv2/creator").deleted = true;
  },
  "missing profile": ({store}) => {
    store.delete("usersv2/creator");
  },
  "missing creator Auth": ({authUsers}) => {
    authUsers.delete("creator");
  },
  "disabled creator Auth": ({authUsers}) => {
    row(authUsers, "creator").disabled = true;
  },
  "creator deletion barrier": ({store}) => {
    store.set("creatorDeletionState/creator", {});
  },
})) {
  test(`${name} fails closed for approval and favourite`, async (t) => {
    const ctx = setup(t); ctx.seedWall(); mutate(ctx);
    await approve(); await favourite(ctx.store);
    assert.ok(!ctx.store.has(receiptPath()));
    assert.ok(!ctx.store.has(privatePath));
  });
}

for (const [name, mutate] of Object.entries<(ctx: ReturnType<typeof setup>) => void>({
  "unverified email": ({authUsers}) => {
    row(authUsers, "member").emailVerified = false;
  },
  "anonymous provider": ({authUsers}) => {
    row(authUsers, "member").providerData = [];
  },
  "young at source time": ({authUsers}) => {
    row(authUsers, "member").metadata = {creationTime: new Date(SOURCE - 7 * 86400000 + 1).toISOString()};
  },
  "missing member Auth": ({authUsers}) => {
    authUsers.delete("member");
  },
  "disabled member Auth": ({authUsers}) => {
    row(authUsers, "member").disabled = true;
  },
  "deleted member": ({store}) => {
    row(store, "usersv2/member").deleted = true;
  },
  "member deletion barrier": ({store}) => {
    store.set("creatorDeletionState/member", {});
  },
  "member blocked creator": ({store}) => {
    store.set("usersv2/member/blockedUsers/creator", {});
  },
  "creator blocked member": ({store}) => {
    store.set("usersv2/creator/blockedUsers/member", {});
  },
})) {
  test(`${name} favourite does not count`, async (t) => {
    const ctx = setup(t); ctx.seedWall(); mutate(ctx);
    await favourite(ctx.store);
    assert.equal(ctx.store.get("usersv2/creator")?.xp, 10);
    assert.ok(!ctx.store.has(privatePath));
  });
}

test("permanent pair receipt survives unlike/refavourite and later week", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await favourite(store);
  store.delete("usersv2/member/images/logical");
  t.mock.method(Date, "now", () => NOW + 14 * 86400000);
  await favourite(store);
  assert.equal((store.get(privatePath)?.creator as Doc).uniqueMembers, 1);
  assert.equal(store.get("usersv2/creator")?.xp, 35);
});

test("reapproval/recreation preserve immutable logical approval dedupe", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await approve();
  await approve(wall(), "wall_logical", {review: true});
  await approve();
  store.delete("walls/wall_logical");
  seedWall("logical", "recreated");
  await approve(wall(), "recreated", undefined);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  assert.equal((store.get(privatePath)?.creator as Doc).approvedWalls, 1);
});

test("a later approval can credit an already favourite-bound wall only once", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await favourite(store); await approve(); await approve();
  assert.equal(store.get("usersv2/creator")?.xp, 85);
  assert.equal((store.get(privatePath)?.creator as Doc).approvedWalls, 1);
});

test("old favourite incarnation cannot credit a deleted/recreated source", async (t) => {
  const {store, seedWall, times} = setup(t); seedWall();
  times.set("usersv2/member/images/logical", SOURCE + 1);
  await favourite(store);
  assert.ok(!store.has(privatePath));
});

test("self-favourites and mismatched path/payload IDs or providers do not count", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await favourite(store, "logical", "creator");
  for (const payload of [{id: "other", provider: "Prism"}, {id: "logical", provider: "Pexels"}, {id: ["logical"], provider: "Prism"}]) {
    const ref = db.collection("usersv2").doc("member").collection("images").doc("logical");
    store.set(ref.path, payload);
    await onCreatorFavouriteCreated.run({params: {uid: "member", wallId: "logical"}, data: {
      ref, data: () => payload, createTime: timestamp(SOURCE),
    }} as unknown as Parameters<typeof onCreatorFavouriteCreated.run>[0]);
  }
  assert.ok(!store.has(privatePath));
});

test("transient source/Auth failure throws and retries successfully without a partial award", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  const getUser = admin.auth().getUser.bind(admin.auth());
  let failing = true;
  t.mock.method(admin.auth(), "getUser", async (id: string) => {
    if (failing) throw Object.assign(new Error("network"), {code: "auth/internal-error"});
    return getUser(id);
  });
  await assert.rejects(approve, /network/);
  assert.ok(!store.has(privatePath));
  failing = false;
  await approve(); await approve();
  assert.equal(store.get("usersv2/creator")?.xp, 60);
});

test("source age stays in the receipt while XP and weekly counts use processing week", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  row(store, "usersv2/creator").xpWeek = {weekKey: "2026-W01", xp: 800};
  t.mock.method(Date, "now", () => NOW + 86400000);
  await approve();
  assert.deepEqual(store.get("usersv2/creator")?.xpWeek, {weekKey: "2026-W43", xp: 50});
  assert.deepEqual((store.get(privatePath)?.creator as Doc).weeks, [
    {weekKey: "2026-W43", approvedWalls: 1, newMembers: 0, xp: 50},
  ]);
});

test("new relationships cap at20 per member UTC day and pair replays consume no budget", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  store.set("creatorMemberRateDaily/member_2026-10-18", {memberUid: "member", day: "2026-10-18", count: 20});
  await favourite(store);
  assert.ok(!store.has(privatePath));
});

test("transaction failure rolls back every write and the event can retry", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  const run = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const result = await callback(tx);
      if (fail) throw new Error("transaction unavailable");
      return result;
    }));
  await assert.rejects(approve, /transaction unavailable/);
  assert.equal(store.get("usersv2/creator")?.xp, 10);
  assert.ok(!store.has(receiptPath()));
  assert.ok(!store.has(privatePath));
  fail = false;
  await approve();
  assert.equal(store.get("usersv2/creator")?.xp, 60);
});

test("forged profile email cannot choose or transfer the trusted upload recipient", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  store.set("usersv2/attacker", {email: "creator@example.com", xp: 0});
  await approve();
  assert.equal(store.get("usersv2/attacker")?.xp, 0);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
});

test("bound UID survives creator email change and never moves to the new email owner", async (t) => {
  const {store, seedWall, authUsers} = setup(t); seedWall();
  await approve();
  row(authUsers, "creator").email = "new@example.com";
  authUsers.set("attacker", {uid: "attacker", email: "creator@example.com"});
  store.set("usersv2/attacker", {email: "creator@example.com", xp: 0});
  await favourite(store);
  assert.equal(store.get("usersv2/attacker")?.xp, 0);
  assert.equal(store.get("usersv2/creator")?.xp, 85);
});

test("rank inventory and unrelated private state are preserved in the milestone transaction", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  row(store, "usersv2/creator").xp = 490;
  store.set(privatePath, {rev: 6, inventory: {owned: {existing: 12}, equipped: {frame: "existing"}}, quests: {kept: true}});
  await approve();
  const data = store.get(privatePath) as Doc;
  assert.equal(data.rev, 7);
  assert.deepEqual(data.quests, {kept: true});
  const inventory = data.inventory as Doc;
  assert.deepEqual(inventory.equipped, {frame: "existing"});
  assert.equal((inventory.owned as Doc).existing, 12);
  assert.equal((inventory.owned as Doc).glow_aurora, NOW);
  assert.equal(store.get("usersv2/creator")?.coins, 9);
});

for (const crossingRank of [false, true]) {
  for (const [shape, owned] of Object.entries({
    "legacy array": ["frame_ring", "glow_prism"],
    "mixed map": {existing: 12, legacy: "owned", flag: true, metadata: {kept: true}, invalid: Number.NaN},
    "numeric map": {existing: 12},
    "unsupported scalar": "legacy-owned",
  })) {
    test(`creator approval preserves ${shape} ${crossingRank ? "while granting a rank" : "without a new rank"}`, async (t) => {
      const {store, seedWall} = setup(t); seedWall();
      row(store, "usersv2/creator").xp = crossingRank ? 490 : 10;
      const inventory = {owned, equipped: {frame: "frame_ring"}};
      store.set(privatePath, {rev: 6, inventory, quests: {kept: true}});
      await approve();
      const data = row(store, privatePath);
      const updatedInventory = data.inventory as Doc;
      const expectedOwned = crossingRank && typeof owned === "object" ? {
        ...(Array.isArray(owned) ? Object.fromEntries(owned.map((id) => [id, 0])) : owned), glow_aurora: NOW,
      } : owned;
      assert.deepEqual(updatedInventory, {...inventory, owned: expectedOwned});
      assert.deepEqual(data.quests, {kept: true});
      assert.equal(data.rev, 7);
      assert.equal((data.creator as Doc).approvedWalls, 1);
      assert.equal(row(store, "usersv2/creator").xp, crossingRank ? 540 : 60);
      assert.equal(row(store, "usersv2/creator").coins, 9);
      assert.equal(row(store, receiptPath()).approvalCredited, true);
      await approve();
      assert.deepEqual(row(store, privatePath), data);
    });
  }
}

for (const [shape, owned] of Object.entries({
  "legacy array": ["glow_aurora"],
  "legacy map": {glow_aurora: "legacy-owned"},
})) {
  for (const crossingRank of [false, true]) {
    test(`existing rank in ${shape} stays owned ${crossingRank ? "with a new rank" : "without a new rank"}`, async (t) => {
      const {store, seedWall} = setup(t); seedWall();
      row(store, "usersv2/creator").xp = crossingRank ? 1990 : 490;
      const inventory = {owned};
      store.set(privatePath, {inventory});
      await approve();
      const expectedOwned = crossingRank ? {
        ...(Array.isArray(owned) ? {glow_aurora: 0} : owned), frame_gold: NOW,
      } : owned;
      assert.deepEqual(row(store, privatePath).inventory, {owned: expectedOwned});
      assert.equal(row(store, "usersv2/creator").xp, crossingRank ? 2040 : 540);
    });
  }
}

test("creator approval leaves absent inventory absent without a rank reward", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await approve();
  assert.equal(Object.prototype.hasOwnProperty.call(row(store, privatePath), "inventory"), false);
});

test("weekly buckets keep exact current/previous keys and discard older weeks", async (t) => {
  const {store, seedWall} = setup(t); seedWall();
  await approve();
  seedWall("two");
  t.mock.method(Date, "now", () => NOW + 86400000);
  await approve(wall("two"), "wall_two");
  const weeks = (store.get(privatePath)?.creator as Doc).weeks as Doc[];
  assert.deepEqual(weeks.map((week) => week.weekKey), ["2026-W43", "2026-W42"]);
  assert.equal(weeks[1].approvedWalls, 1);
  seedWall("three");
  t.mock.method(Date, "now", () => NOW + 15 * 86400000);
  await approve(wall("three"), "wall_three");
  assert.deepEqual((store.get(privatePath)?.creator as Doc).weeks, [
    {weekKey: "2026-W45", approvedWalls: 1, newMembers: 0, xp: 0},
  ]);
});

test("approved creation qualifies but a source from an old wall incarnation does not", async (t) => {
  const {store, seedWall, times} = setup(t); const data = seedWall();
  const ref = db.collection("walls").doc("wall_logical");
  times.set(ref.path, SOURCE + 1);
  await approve();
  assert.ok(!store.has(privatePath));
  times.delete(ref.path);
  await onCreatorWallWritten.run({params: {wallId: ref.id}, data: {
    before: {exists: false, data: () => undefined},
    after: {exists: true, ref, data: () => data, createTime: timestamp(SOURCE), updateTime: timestamp(NOW)},
  }} as unknown as Parameters<typeof onCreatorWallWritten.run>[0]);
  assert.equal(store.get("usersv2/creator")?.xp, 60);
  assert.equal(store.get(receiptPath())?.approvalSourceTimeMs, NOW);
});
