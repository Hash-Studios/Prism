import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {syncAuthoredContentUid} from "../authoredContentUid";
import {installFakeDb} from "./fakeDb";

test("uses verified Auth ownership, not forged usersv2.email", async (t) => {
  const store = installFakeDb(t, {
    "walls/w1": {email: "owner@example.com"},
    "usersv2/attacker": {email: "owner@example.com"},
    "usersv2/auth-owner": {email: "different@example.com"},
  });
  t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "auth-owner", emailVerified: true} as admin.auth.UserRecord));

  await syncAuthoredContentUid("walls", "w1", "owner@example.com");

  assert.equal(store.get("walls/w1")?.creatorUid, "auth-owner");
});

test("does not apply stale snapshots or unverified identities, and clears unresolved stale UIDs", async (t) => {
  const store = installFakeDb(t, {
    "setups/current": {email: "new@example.com", creatorUid: "old"},
    "setups/unverified": {email: "unverified@example.com", creatorUid: "old"},
    "setups/missing": {email: "gone@example.com", creatorUid: "old"},
    "usersv2/new-owner": {},
  });
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    if (email === "gone@example.com") throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
    return {uid: "new-owner", emailVerified: email !== "unverified@example.com"} as admin.auth.UserRecord;
  });

  await syncAuthoredContentUid("setups", "current", "old@example.com");
  await syncAuthoredContentUid("setups", "unverified", "unverified@example.com");
  await syncAuthoredContentUid("setups", "missing", "gone@example.com");

  assert.equal(store.get("setups/current")?.creatorUid, "old");
  assert.equal(store.get("setups/unverified")?.creatorUid, undefined);
  assert.equal(store.get("setups/missing")?.creatorUid, undefined);
});

test("deleted and deletion-barrier identities cannot retain or gain creatorUid", async (t) => {
  const store = installFakeDb(t, {
    "walls/deleted": {email: "deleted@example.com", creatorUid: "deleted"},
    "walls/barrier": {email: "barrier@example.com", creatorUid: "barrier"},
    "usersv2/deleted": {deleted: true},
    "usersv2/barrier": {},
    "creatorDeletionState/barrier": {closed: true},
  });
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => ({
    uid: email.startsWith("deleted") ? "deleted" : "barrier", emailVerified: true,
  } as admin.auth.UserRecord));

  await syncAuthoredContentUid("walls", "deleted", "deleted@example.com");
  await syncAuthoredContentUid("walls", "barrier", "barrier@example.com");

  assert.equal(store.get("walls/deleted")?.creatorUid, undefined);
  assert.equal(store.get("walls/barrier")?.creatorUid, undefined);
});

test("re-reads content after Auth resolution and does not write when ownership email changed", async (t) => {
  const store = installFakeDb(t, {"walls/race": {email: "old@example.com", creatorUid: "old"}, "usersv2/owner": {}});
  t.mock.method(admin.auth(), "getUserByEmail", async () => {
    store.set("walls/race", {email: "new@example.com", creatorUid: "old"});
    return {uid: "owner", emailVerified: true} as admin.auth.UserRecord;
  });

  await syncAuthoredContentUid("walls", "race", "old@example.com");

  assert.equal(store.get("walls/race")?.creatorUid, "old");
});

test("maps Prism Studio walls to the Studio profile, which has no Auth user", async (t) => {
  const store = installFakeDb(t, {
    "walls/studio": {email: "studio@prismwalls.com"},
    "usersv2/prism-studio": {email: "studio@prismwalls.com"},
  });
  t.mock.method(admin.auth(), "getUserByEmail", async () => {
    throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
  });

  assert.equal(await syncAuthoredContentUid("walls", "studio", "studio@prismwalls.com"), "assigned");
  assert.equal(store.get("walls/studio")?.creatorUid, "prism-studio");
});
