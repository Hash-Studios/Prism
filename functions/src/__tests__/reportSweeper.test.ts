import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {isDueForEscalation, sweepOpenReports} from "../reportSweeper";
import {installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const HOUR = 3_600_000;
const ts = (hoursAgo: number) => admin.firestore.Timestamp.fromMillis(NOW.getTime() - hoursAgo * HOUR);

test("only an open, unescalated report older than 12 hours is due", () => {
  assert.equal(isDueForEscalation({status: "open", createdAt: ts(13)}, NOW.getTime()), true);
  assert.equal(isDueForEscalation({status: "open", createdAt: ts(11)}, NOW.getTime()), false);
  assert.equal(isDueForEscalation({status: "reviewed", createdAt: ts(30)}, NOW.getTime()), false);
  assert.equal(isDueForEscalation({status: "open", createdAt: ts(30), escalatedAt: ts(1)}, NOW.getTime()), false);
  assert.equal(isDueForEscalation({status: "open"}, NOW.getTime()), false);
});

test("the sweeper pings the admins once for an old open report and stamps escalatedAt", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
    "contentReports/old": {status: "open", contentType: "wall", targetFirestoreDocId: "w1", reason: "spam", createdAt: ts(14)},
    "contentReports/new": {status: "open", contentType: "wall", targetFirestoreDocId: "w2", reason: "spam", createdAt: ts(2)},
    "contentReports/done": {status: "reviewed", contentType: "wall", targetFirestoreDocId: "w3", createdAt: ts(40)},
  });
  const sent: Array<{topic?: string; data?: Record<string, string>}> = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string; data?: Record<string, string>}) => {
    sent.push(message);
    return "id";
  });
  const run = () => sweepOpenReports.run({jobName: "t", scheduleTime: NOW.toISOString()});
  await run();
  assert.ok(store.get("contentReports/old")?.escalatedAt);
  assert.equal(store.get("contentReports/new")?.escalatedAt, undefined);
  assert.equal(store.get("contentReports/done")?.escalatedAt, undefined);
  const pings = sent.filter((m) => m.data?.report_id === "old");
  assert.ok(pings.length >= 1);
  assert.ok(sent.every((m) => m.data?.report_id === "old"));

  const before = sent.length;
  await run();
  assert.equal(sent.length, before);
});

test("with no admin emails the report stays unescalated so a later run can ping", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "contentReports/old": {status: "open", contentType: "user", targetFirestoreDocId: "u9", createdAt: ts(14)},
  });
  await sweepOpenReports.run({jobName: "t", scheduleTime: NOW.toISOString()});
  assert.equal(store.get("contentReports/old")?.escalatedAt, undefined);
});

test("pages past escalated and recent reports, caps escalations, and does not ping twice", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const seed: Record<string, Record<string, unknown>> = {
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
  };
  for (let i = 0; i < 601; i++) {
    seed[`contentReports/${String(i).padStart(3, "0")}`] = {
      status: "open", contentType: "user", createdAt: ts(i < 400 && i >= 200 ? 2 : 14),
      ...(i < 200 ? {escalatedAt: ts(1)} : {}),
    };
  }
  const store = installFakeDb(t, seed);
  const sent: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: {data?: Record<string, string>}) => {
    sent.push(message.data?.report_id ?? "");
    return "id";
  });
  const run = () => sweepOpenReports.run({jobName: "t", scheduleTime: NOW.toISOString()});
  await run();
  assert.equal(new Set(sent).size, 200);
  assert.ok(store.get("contentReports/599")?.escalatedAt);
  assert.equal(store.get("contentReports/600")?.escalatedAt, undefined);
  assert.equal(store.get("contentReports/200")?.escalatedAt, undefined);
  await run();
  assert.ok(store.get("contentReports/600")?.escalatedAt);
  assert.equal(new Set(sent).size, 201);
  assert.equal(sent.length, 201);
  const count = sent.length;
  await run();
  assert.equal(sent.length, count);
});
