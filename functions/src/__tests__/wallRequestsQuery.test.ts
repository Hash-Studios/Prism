import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {MIN_STUDIO_VOTES, studioRequestPicks, WALL_REQUESTS} from "../wallRequests";

type QueryProto = {
  structuredQuery: {
    where: unknown;
    orderBy: unknown;
    startAt?: {before?: boolean; values: Array<{integerValue?: string | number; referenceValue?: string}>};
  };
};

test("Studio uses an indexed vote floor and a full SDK snapshot cursor across tied votes", async (t) => {
  const firestore = new admin.firestore.Firestore({projectId: "demo-prism"});
  const collection = firestore.collection(WALL_REQUESTS);
  t.mock.method(db, "collection", () => collection);
  const snapshots = admin.firestore.DocumentSnapshot as unknown as {
    fromObject(ref: admin.firestore.DocumentReference, data: admin.firestore.DocumentData):
      admin.firestore.QueryDocumentSnapshot;
  };
  const now = Date.parse("2026-10-29T12:00:00Z");
  const day = 24 * 60 * 60 * 1000;
  const snapshot = (id: string, voteCount: number, age: number) => snapshots.fromObject(collection.doc(id), {
    text: "dark minimal mountains",
    tags: ["Dark"],
    status: "open",
    hidden: false,
    voteCount,
    createdAt: admin.firestore.Timestamp.fromMillis(now - age * day),
  });
  const stale = Array.from({length: 20}, (_, i) => snapshot(`z${99 - i}`, 5, 31));
  const tied = snapshot("z79", 5, 1);
  const lower = snapshot("a1", MIN_STUDIO_VOTES, 1);
  const queries: QueryProto["structuredQuery"][] = [];
  const tx = {
    get: async (query: admin.firestore.Query) => {
      const proto = (query as unknown as {toProto(): QueryProto}).toProto();
      queries.push(proto.structuredQuery);
      assert.ok(queries.length <= 2, "the second page must satisfy the requested picks");
      return {docs: queries.length === 1 ? stale : [tied, lower]};
    },
  } as unknown as admin.firestore.Transaction;

  const picks = await studioRequestPicks(tx, 2, now);
  assert.deepEqual(picks.map((pick) => pick.requestId), ["z79", "a1"]);
  assert.equal(queries.length, 2);
  assert.deepEqual(queries[0].where, {compositeFilter: {op: "AND", filters: [
    {fieldFilter: {field: {fieldPath: "status"}, op: "EQUAL", value: {stringValue: "open"}}},
    {fieldFilter: {field: {fieldPath: "hidden"}, op: "EQUAL", value: {booleanValue: false}}},
    {fieldFilter: {field: {fieldPath: "voteCount"}, op: "GREATER_THAN_OR_EQUAL", value: {integerValue: MIN_STUDIO_VOTES}}},
  ]}});
  assert.deepEqual(queries[0].orderBy, [{field: {fieldPath: "voteCount"}, direction: "DESCENDING"}]);
  assert.deepEqual(queries[1].where, queries[0].where);
  assert.deepEqual(queries[1].orderBy, [
    {field: {fieldPath: "voteCount"}, direction: "DESCENDING"},
    {field: {fieldPath: "__name__"}, direction: "DESCENDING"},
  ]);
  assert.equal(queries[1].startAt?.before ?? false, false);
  assert.deepEqual(queries[1].startAt?.values, [
    {integerValue: 5},
    {referenceValue: "projects/demo-prism/databases/(default)/documents/wallRequests/z80"},
  ]);
});
