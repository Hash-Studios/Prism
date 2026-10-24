import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {backfillCreatorUids, parseArgs} from "../scripts/backfillCreatorUids";
import {installFakeDb} from "./fakeDb";

test("dry-run is the default and never writes, while ignoring forged legacy email ownership", async (t) => {
  const store = installFakeDb(t, {
    "walls/w1": {email: "owner@example.com"},
    "setups/s1": {email: "unverified@example.com", creatorUid: "stale"},
    "usersv2/attacker": {email: "owner@example.com"},
    "usersv2/verified-owner": {},
  });
  const lookedUp: string[] = [];
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    lookedUp.push(email);
    if (email === "unverified@example.com") return {uid: "wrong", emailVerified: false} as admin.auth.UserRecord;
    return {uid: "verified-owner", emailVerified: true} as admin.auth.UserRecord;
  });

  const counts = await backfillCreatorUids({apply: false}, () => undefined);

  assert.deepEqual(counts, {scanned: 2, assigned: 1, cleared: 1, skipped: 0});
  assert.deepEqual(lookedUp.sort(), ["owner@example.com", "unverified@example.com"]);
  assert.equal(store.has("walls/w1"), true);
  assert.equal(store.get("walls/w1")?.creatorUid, undefined);
  assert.equal(store.get("setups/s1")?.creatorUid, "stale");
});

test("apply reconciles verified owners and removes stale UIDs for missing, deleted, or blocked identities", async (t) => {
  const store = installFakeDb(t, {
    "walls/w1": {email: "owner@example.com"},
    "walls/deleted": {email: "deleted@example.com", creatorUid: "deleted"},
    "walls/barrier": {email: "barrier@example.com", creatorUid: "barrier"},
    "setups/missing": {email: "missing@example.com", creatorUid: "stale"},
    "usersv2/owner": {},
    "usersv2/deleted": {deleted: true},
    "usersv2/barrier": {},
    "creatorDeletionState/barrier": {closed: true},
  });
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    if (email.startsWith("missing")) throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
    const uid = email.split("@")[0];
    return {uid, emailVerified: true} as admin.auth.UserRecord;
  });

  const counts = await backfillCreatorUids({apply: true}, () => undefined);

  assert.deepEqual(counts, {scanned: 4, assigned: 1, cleared: 3, skipped: 0});
  assert.equal(store.get("walls/w1")?.creatorUid, "owner");
  for (const path of ["walls/deleted", "walls/barrier", "setups/missing"]) {
    assert.equal(store.get(path)?.creatorUid, undefined, path);
  }
});

test("argument parsing rejects unknown and duplicate flags", () => {
  assert.deepEqual(parseArgs([]), {help: false, apply: false, concurrency: 1});
  assert.deepEqual(parseArgs(["--apply"]), {help: false, apply: true, concurrency: 1});
  assert.deepEqual(parseArgs(["--help"]), {help: true, apply: false, concurrency: 1});
  assert.throws(() => parseArgs(["--apply", "--apply"]));
  assert.throws(() => parseArgs(["--other"]));
  assert.throws(() => parseArgs(["--help", "--apply"]));
  assert.equal(parseArgs(["--apply", "--concurrency=8"]).concurrency, 8);
  for (const bad of ["--concurrency", "--concurrency=0", "--concurrency=51", "--concurrency=x", "--concurrencyx=2"]) {
    assert.throws(() => parseArgs(["--apply", bad]), bad);
  }
  assert.throws(() => parseArgs(["--concurrency=2", "--concurrency=3"]));
});
