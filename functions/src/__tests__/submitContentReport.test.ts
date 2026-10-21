import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {submitContentReport} from "../submitContentReport";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const DAY = 86_400_000;
const data = {contentType: "wall", targetFirestoreDocId: "wall", reason: "spam"};
const request = (changes: Doc = {}) => ({auth: {uid: "reporter", token: {email: " person@example.com "}},
  data: {...data, ...changes},
} as Parameters<typeof submitContentReport.run>[0]);

function setup(t: TestContext, extra: Record<string, Doc> = {}) {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  return installFakeDb(t, {"walls/wall": {review: true}, ...extra});
}

test("a report stores normalized content and atomically advances both rate limits", async (t) => {
  const store = setup(t);
  const result = await submitContentReport.run(request({targetFirestoreDocId: " wall ", details: " evidence ",
    appVersion: " 3.0 "}));
  assert.equal(typeof result.reportId, "string");
  assert.deepEqual(store.get(`contentReports/${result.reportId}`), {
    contentType: "wall", targetFirestoreDocId: "wall", reason: "spam", details: "evidence",
    reporterUid: "reporter", reporterEmail: "person@example.com", appVersion: "3.0", status: "open",
    createdAt: admin.firestore.Timestamp.fromDate(NOW), targetCollection: "walls",
  });
  assert.deepEqual(store.get("contentReportRateByTarget/reporter_wall_wall"), {
    lastAt: admin.firestore.Timestamp.fromDate(NOW), contentType: "wall", targetFirestoreDocId: "wall", reporterUid: "reporter",
  });
  assert.equal(store.get("contentReportRateDaily/reporter_2026-01-10")?.count, 1);
});

test("unauthenticated and malformed reports cannot write", async (t) => {
  const store = setup(t);
  const before = [...store.entries()];
  await assert.rejects(() => submitContentReport.run({...request(), auth: undefined}), {code: "unauthenticated"});
  for (const change of [{contentType: "unknown"}, {targetFirestoreDocId: 2}, {targetFirestoreDocId: ""},
    {targetFirestoreDocId: "a".repeat(257)}, {targetFirestoreDocId: "../wall"}, {targetFirestoreDocId: "a/b"},
    {reason: "unknown"}, {details: 1}, {details: "a".repeat(2001)}]) {
    await assert.rejects(() => submitContentReport.run(request(change)), {code: "invalid-argument"});
  }
  assert.deepEqual([...store.entries()], before);
});

test("missing content and exhausted rate limits reject without partial writes", async (t) => {
  const store = setup(t);
  await assert.rejects(() => submitContentReport.run(request({targetFirestoreDocId: "missing"})), {code: "not-found"});
  await submitContentReport.run(request());
  const afterFirst = [...store.entries()];
  await assert.rejects(() => submitContentReport.run(request()), {code: "resource-exhausted"});
  assert.deepEqual([...store.entries()], afterFirst);
  store.delete("contentReportRateByTarget/reporter_wall_wall");
  store.set("contentReportRateDaily/reporter_2026-01-10", {day: "2026-01-10", count: 20});
  const atCap = [...store.entries()];
  await assert.rejects(() => submitContentReport.run(request()), {code: "resource-exhausted"});
  assert.deepEqual([...store.entries()], atCap);
});

test("the twentieth daily report succeeds once the target cooldown reaches a day", async (t) => {
  const store = setup(t, {
    "contentReportRateByTarget/reporter_wall_wall": {lastAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() - DAY)},
    "contentReportRateDaily/reporter_2026-01-10": {day: "2026-01-10", count: 19},
  });
  const result = await submitContentReport.run(request());
  assert.equal(store.get(`contentReports/${result.reportId}`)?.details, "");
  assert.equal(store.get(`contentReports/${result.reportId}`)?.appVersion, null);
  assert.equal(store.get("contentReportRateDaily/reporter_2026-01-10")?.count, 20);
});

for (const [contentType, collection] of [["user", "usersv2"], ["setup", "setups"]]) {
  test(`reports resolve ${contentType} content in its collection and reset stale daily counters`, async (t) => {
    const store = setup(t, {[`${collection}/wall`]: {},
      "contentReportRateDaily/reporter_2026-01-10": {day: "2026-01-09", count: 20}});
    const result = await submitContentReport.run(request({contentType, appVersion: "x".repeat(70)}));
    assert.equal(store.get(`contentReports/${result.reportId}`)?.targetCollection, collection);
    assert.equal(store.get(`contentReports/${result.reportId}`)?.appVersion, "x".repeat(64));
    assert.equal(store.get("contentReportRateDaily/reporter_2026-01-10")?.count, 1);
  });
}
