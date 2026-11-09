import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {backfillPublishedAt, planPublishedAt} from "../scripts/backfillPublishedAt";
import {type Doc, installFakeDb} from "./fakeDb";

const at = (millis: number) => admin.firestore.Timestamp.fromMillis(millis);

test("planPublishedAt uses reviewedAt when both times are Timestamps", () => {
  const plan = planPublishedAt({reviewedAt: at(1_700_000_100_000), createdAt: at(1_700_000_000_000)});
  assert.ok(plan instanceof admin.firestore.Timestamp);
  assert.equal(plan.toMillis(), 1_700_000_100_000);
});

test("planPublishedAt falls back to createdAt when reviewedAt is missing", () => {
  const plan = planPublishedAt({createdAt: at(1_700_000_000_000)});
  assert.ok(plan instanceof admin.firestore.Timestamp);
  assert.equal(plan.toMillis(), 1_700_000_000_000);
});

test("planPublishedAt returns already when publishedAt is a Timestamp", () => {
  assert.equal(planPublishedAt({publishedAt: at(1_700_000_200_000), reviewedAt: at(1_700_000_100_000)}), "already");
});

test("planPublishedAt returns null when neither time is a Timestamp", () => {
  assert.equal(planPublishedAt({reviewedAt: "2026-01-01", createdAt: 1_700_000_000_000}), null);
  assert.equal(planPublishedAt({}), null);
});

const seed = (): Record<string, Doc> => ({
  "walls/a": {review: true, publishedAt: at(1_700_000_200_000), reviewedAt: at(1_700_000_100_000)},
  "walls/b": {review: true, reviewedAt: at(1_700_000_100_000), createdAt: at(1_700_000_000_000)},
  "walls/c": {review: true, createdAt: at(1_700_000_000_000)},
  "walls/d": {review: true, title: "No time"},
});

test("the publishedAt backfill is a dry run by default and writes nothing", async (t: TestContext) => {
  const store = installFakeDb(t, seed());
  const before = JSON.stringify([...store.entries()]);
  const counts = await backfillPublishedAt(db, {apply: false}, () => undefined);
  assert.deepEqual(counts, {scanned: 4, already: 1, planned: 2, noTime: 1, written: 0});
  assert.equal(JSON.stringify([...store.entries()]), before);
});

test("the backfill writes only approved missing timestamps and is idempotent", async (t) => {
  const store = installFakeDb(t, {...seed(),
    "walls/scheduled": {review: false, releaseApprovedAt: at(1), releaseAt: at(2), createdAt: at(1)},
  });
  t.mock.method(db, "batch", () => {
    const writes: Array<() => Promise<unknown>> = [];
    return {
      update: (ref: admin.firestore.DocumentReference, data: admin.firestore.UpdateData<Doc>,
        precondition: admin.firestore.Precondition) => writes.push(() => ref.update(data, precondition)),
      commit: async () => Promise.all(writes.map((write) => write())),
    };
  });
  const first = await backfillPublishedAt(db, {apply: true}, () => undefined);
  assert.deepEqual(first, {scanned: 4, already: 1, planned: 2, noTime: 1, written: 2});
  assert.equal((store.get("walls/b")?.publishedAt as admin.firestore.Timestamp).toMillis(), 1_700_000_100_000);
  assert.equal((store.get("walls/c")?.publishedAt as admin.firestore.Timestamp).toMillis(), 1_700_000_000_000);
  assert.equal(store.get("walls/scheduled")?.publishedAt, undefined);
  const second = await backfillPublishedAt(db, {apply: true}, () => undefined);
  assert.deepEqual(second, {scanned: 4, already: 3, planned: 0, noTime: 1, written: 0});
});
