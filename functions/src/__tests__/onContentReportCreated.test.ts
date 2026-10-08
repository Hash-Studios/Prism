import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {onContentReportCreated} from "../onContentReportCreated";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const DAY = 86_400_000;

const report = (reporterUid: string, extra: Doc = {}): Doc => ({
  contentType: "wall", targetFirestoreDocId: "w1", reason: "spam", reporterUid, status: "open", ...extra,
});

function setup(t: TestContext, reports: Record<string, Doc>, accountAgesDays: Record<string, number>, wall: Doc = {review: true}) {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "walls/w1": wall,
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
    ...Object.fromEntries(Object.entries(reports).map(([id, data]) => [`contentReports/${id}`, data])),
  });
  t.mock.method(admin.auth(), "getUser", async (uid: string) => {
    if (!(uid in accountAgesDays)) throw new Error("auth/user-not-found");
    return {metadata: {creationTime: new Date(NOW.getTime() - accountAgesDays[uid] * DAY).toUTCString()}} as never;
  });
  const pushes: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    pushes.push(message.topic ?? "");
    return "id";
  });
  return {store, pushes};
}

const fire = (reportId: string, data: Doc) => onContentReportCreated.run({
  params: {reportId}, data: {data: () => data},
} as unknown as Parameters<typeof onContentReportCreated.run>[0]);

test("3 different trusted reporters take an approved wall back to review", async (t) => {
  const reports = {r1: report("a"), r2: report("b"), r3: report("c")};
  const {store, pushes} = setup(t, reports, {a: 30, b: 30, c: 30});
  await fire("r3", reports.r3);
  const wall = store.get("walls/w1");
  assert.equal(wall?.review, false);
  assert.equal(wall?.heldForReview, true);
  assert.ok(wall?.heldAt instanceof admin.firestore.Timestamp);
  assert.deepEqual(pushes, ["u_adm1"]);
});

test("2 reporters do not hold the wall", async (t) => {
  const reports = {r1: report("a"), r2: report("b")};
  const {store} = setup(t, reports, {a: 30, b: 30});
  await fire("r2", reports.r2);
  assert.equal(store.get("walls/w1")?.review, true);
  assert.equal(store.get("walls/w1")?.heldForReview, undefined);
});

test("one reporter with 3 reports counts once", async (t) => {
  const reports = {r1: report("a"), r2: report("a"), r3: report("a")};
  const {store} = setup(t, reports, {a: 30});
  await fire("r3", reports.r3);
  assert.equal(store.get("walls/w1")?.review, true);
});

test("accounts younger than 7 days, or that cannot be read, do not count", async (t) => {
  const reports = {r1: report("a"), r2: report("b"), r3: report("young"), r4: report("ghost")};
  const {store} = setup(t, reports, {a: 30, b: 30, young: 2});
  await fire("r4", reports.r4);
  assert.equal(store.get("walls/w1")?.review, true);
});

test("reports of another wall do not count", async (t) => {
  const reports = {r1: report("a"), r2: report("b"), r3: report("c", {targetFirestoreDocId: "w2"})};
  const {store} = setup(t, reports, {a: 30, b: 30, c: 30});
  await fire("r3", reports.r3);
  assert.equal(store.get("walls/w1")?.review, true);
});

test("a wall that is already in review stays untouched and a later report does not hold it again", async (t) => {
  const reports = {r1: report("a"), r2: report("b"), r3: report("c"), r4: report("d")};
  const {store} = setup(t, reports, {a: 30, b: 30, c: 30, d: 30}, {review: false});
  await fire("r4", reports.r4);
  assert.deepEqual(store.get("walls/w1"), {review: false});
});

test("a blocked report sends no admin push", async (t) => {
  const blocked = {contentType: "user", targetFirestoreDocId: "u9", reason: "blocked", reporterUid: "a", status: "open"};
  const {pushes, store} = setup(t, {r1: blocked}, {a: 30});
  await fire("r1", blocked);
  assert.deepEqual(pushes, []);
  assert.equal(store.get("walls/w1")?.review, true);
});

test("a user report is pushed to the admins and holds nothing", async (t) => {
  const userReport = {contentType: "user", targetFirestoreDocId: "u9", reason: "harassment", reporterUid: "a"};
  const {pushes} = setup(t, {r1: userReport}, {a: 30});
  await fire("r1", userReport);
  assert.deepEqual(pushes, ["u_adm1"]);
});
