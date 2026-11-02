import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";

test("fake reads without readRounds retain their immediate snapshots", async (t) => {
  const observed = {reads: 0, writes: 0, outsideReads: 0};
  const store = installFakeDb(t, {"rows/one": {value: "before"}}, observed);
  const doc = db.collection("rows").doc("one").get();
  const query = db.collection("rows").get();
  store.set("rows/one", {value: "after"});
  assert.deepEqual((await doc).data(), {value: "before"});
  assert.deepEqual((await query).docs.map((row) => row.data()), [{value: "before"}]);
  assert.deepEqual(observed, {reads: 0, writes: 0, outsideReads: 2});
});

test("fake read rounds group parallel document and query reads but separate awaited reads", async (t) => {
  const observed = {reads: 0, writes: 0, readRounds: 0, outsideReads: 0};
  installFakeDb(t, {"rows/one": {value: 1}, "rows/two": {value: 2}}, observed);
  const [doc, query] = await Promise.all([db.collection("rows").doc("one").get(), db.collection("rows").get()]);
  assert.deepEqual(doc.data(), {value: 1});
  assert.deepEqual(query.docs.map((row) => row.data()), [{value: 1}, {value: 2}]);
  assert.equal(observed.readRounds, 1);
  assert.equal(observed.outsideReads, 3);
  assert.deepEqual((await db.collection("rows").doc("two").get()).data(), {value: 2});
  assert.equal((await db.collection("rows").get()).size, 2);
  assert.equal(observed.readRounds, 3);
  assert.equal(observed.outsideReads, 6);
});

test("delayed fake queries classify transaction and outside reads at their start", async (t) => {
  const observed = {reads: 0, writes: 0, readRounds: 0, outsideReads: 0};
  installFakeDb(t, {"rows/one": {value: 1}, "rows/two": {value: 2}}, observed);
  const values = await db.runTransaction(async (tx) => {
    const [doc, query, outsideDoc, outsideQuery] = await Promise.all([
      tx.get(db.collection("rows").doc("one")), tx.get(db.collection("rows")),
      db.collection("rows").doc("two").get(), db.collection("rows").get(),
    ]);
    return [doc.data(), query.size, outsideDoc.data(), outsideQuery.size];
  });
  assert.deepEqual(values, [{value: 1}, 2, {value: 2}, 2]);
  assert.deepEqual(observed, {reads: 3, writes: 0, readRounds: 1, outsideReads: 3});
});
