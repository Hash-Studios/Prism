import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onFollowCreated} from "../onFollowCreated";
import {backfillWallAuthors} from "../scripts/backfillWallAuthors";
import {authorUpdate} from "../wallAuthor";
import {type Doc, installFakeDb} from "./fakeDb";

/** A fake bulkWriter that applies each update to the fake store. */
function installBulkWriter(t: TestContext) {
  const pending: Array<Promise<unknown>> = [];
  type Ref = {update: (data: Doc) => Promise<void>};
  t.mock.method(db, "bulkWriter", () => ({
    update: (ref: Ref, data: Doc) => {
      const write = ref.update(data);
      pending.push(write);
      return write;
    },
    flush: async () => {
      await Promise.allSettled(pending);
    },
    close: async () => {
      await Promise.allSettled(pending);
    },
  }));
}

const OLD = {name: "Old Name", username: "sam", profilePhoto: "https://p/old.png"};
const NEW = {name: "New Name", username: "sam", profilePhoto: "https://p/new.png"};
const upload = (email: string, extra: Doc = {}): Doc => ({email, by: OLD.name, userPhoto: OLD.profilePhoto, ...extra});

const profileEvent = (before: Doc, after: Doc) => ({
  params: {userId: "sam"},
  data: {
    before: {data: () => ({followers: [], ...before})},
    after: {data: () => ({followers: [], ...after}), ref: {update: async () => undefined}},
  },
} as unknown as Parameters<typeof onFollowCreated.run>[0]);

test("the username fills in for an empty name, and an empty name or photo is not copied", () => {
  assert.deepEqual(authorUpdate({by: "A", userPhoto: "p"}, {username: "sam", profilePhoto: "q"}), {by: "sam", userPhoto: "q"});
  assert.deepEqual(authorUpdate({by: "A", userPhoto: "p"}, {name: "", username: "", profilePhoto: ""}), {});
  assert.deepEqual(authorUpdate({by: "A", userPhoto: "p"}, {name: "A", profilePhoto: "p"}), {});
});

test("a profile edit writes the new name and photo to every wall and setup of the user", async (t) => {
  t.mock.method(admin.auth(), "getUser", async () => ({uid: "sam", email: "Sam@Example.com", emailVerified: true}));
  const store = installFakeDb(t, {
    "walls/typed": upload("Sam@Example.com"),
    "walls/lower": upload("sam@example.com"),
    "walls/other": upload("kim@example.com"),
    "setups/s1": upload("Sam@Example.com"),
  });
  installBulkWriter(t);
  await onFollowCreated.run(profileEvent({email: "Sam@Example.com", ...OLD}, {email: "Sam@Example.com", ...NEW}));
  for (const path of ["walls/typed", "walls/lower", "setups/s1"]) {
    assert.equal(store.get(path)?.by, NEW.name, path);
    assert.equal(store.get(path)?.userPhoto, NEW.profilePhoto, path);
  }
  assert.equal(store.get("walls/other")?.by, OLD.name);
});

test("a legacy forged profile cannot propagate its author onto a victim's uploads", async (t) => {
  const store = installFakeDb(t, {
    "walls/victim": upload("victim@example.com"),
    "walls/own": upload("Sam@Example.com"),
  });
  t.mock.method(admin.auth(), "getUser", async () => ({uid: "sam", email: "Sam@Example.com", emailVerified: true}));
  installBulkWriter(t);
  await onFollowCreated.run(profileEvent({email: "victim@example.com", ...OLD}, {email: "victim@example.com", ...NEW}));
  assert.equal(store.get("walls/victim")?.by, OLD.name);
  assert.equal(store.get("walls/own")?.by, NEW.name);
});

test("unverified and missing auth identities never propagate author fields", async (t) => {
  const store = installFakeDb(t, {"walls/victim": upload("victim@example.com")});
  installBulkWriter(t);
  t.mock.method(admin.auth(), "getUser", async () => ({uid: "sam", email: "victim@example.com", emailVerified: false}));
  await onFollowCreated.run(profileEvent(OLD, {email: "victim@example.com", ...NEW}));
  assert.equal(store.get("walls/victim")?.by, OLD.name);
  t.mock.method(admin.auth(), "getUser", async () => {
    throw Object.assign(new Error("gone"), {code: "auth/user-not-found"});
  });
  await onFollowCreated.run(profileEvent(OLD, {email: "victim@example.com", ...NEW}));
  assert.equal(store.get("walls/victim")?.by, OLD.name);
});

test("a profile update that keeps the name and photo writes no walls", async (t) => {
  const store = installFakeDb(t, {"walls/w1": upload("sam@example.com", {by: "Stale"})});
  installBulkWriter(t);
  await onFollowCreated.run(profileEvent(
    {email: "sam@example.com", ...OLD, bio: "a"},
    {email: "sam@example.com", ...OLD, bio: "b", username: "sam2"},
  ));
  assert.equal(store.get("walls/w1")?.by, "Stale");
});

test("the backfill dry run writes nothing, and --apply fixes stale walls of known owners", async (t) => {
  const seed: Record<string, Doc> = {
    "usersv2/sam": {email: "sam@example.com", ...NEW},
    "walls/stale": upload("Sam@example.com"),
    "walls/fresh": upload("sam@example.com", {by: NEW.name, userPhoto: NEW.profilePhoto}),
    "walls/orphan": upload("gone@example.com"),
    "walls/noEmail": upload(""),
    "setups/s1": upload("sam@example.com"),
  };
  const dry = installFakeDb(t, seed);
  installBulkWriter(t);
  const dryCounts = await backfillWallAuthors({apply: false}, () => undefined);
  assert.deepEqual(dryCounts, {scanned: 5, noOwner: 2, changed: 2, written: 0, failed: 0});
  assert.equal(dry.get("walls/stale")?.by, OLD.name);

  const live = installFakeDb(t, seed);
  const counts = await backfillWallAuthors({apply: true}, () => undefined);
  assert.deepEqual(counts, {scanned: 5, noOwner: 2, changed: 2, written: 2, failed: 0});
  for (const path of ["walls/stale", "setups/s1"]) {
    assert.equal(live.get(path)?.by, NEW.name, path);
    assert.equal(live.get(path)?.userPhoto, NEW.profilePhoto, path);
  }
  assert.equal(live.get("walls/orphan")?.by, OLD.name);
});
