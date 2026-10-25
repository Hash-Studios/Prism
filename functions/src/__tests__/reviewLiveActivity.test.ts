import assert from "node:assert/strict";
import test from "node:test";
import {
  buildLiveActivityMessage,
  isApnsToken,
  isPendingWall,
  planSend,
  stateKey,
  summarizeQueue,
} from "../reviewLiveActivity";

const TOKEN = "a".repeat(64);
const FCM = "fcm-token";
// 2026-10-20T10:00:00Z in unix seconds.
const OLDEST_SECONDS = 1792490400;

test("isPendingWall counts only unapproved walls outside drops", () => {
  assert.equal(isPendingWall({review: false}), true);
  assert.equal(isPendingWall({review: true}), false);
  assert.equal(isPendingWall({review: false, dropWeek: "2026-W43"}), false);
  assert.equal(isPendingWall(undefined), false);
});

test("summarizeQueue keeps pending walls and reads the newest and oldest", () => {
  const docs = [
    {review: false, by: "  Ana ", createdAt: new Date("2026-10-21T10:00:00Z")},
    {review: true, by: "Bob", createdAt: new Date("2026-10-20T12:00:00Z")},
    {review: false, by: "Cy", createdAt: new Date("2026-10-20T10:00:00Z")},
    {review: false, dropWeek: "2026-W43", by: "Dee", createdAt: new Date("2026-10-19T10:00:00Z")},
  ];
  assert.deepEqual(summarizeQueue(docs), {pending: 2, newestBy: "Ana", oldestAt: OLDEST_SECONDS});
  assert.deepEqual(summarizeQueue([]), {pending: 0, newestBy: null, oldestAt: null});
});

test("isApnsToken accepts 16 to 512 hex characters only", () => {
  assert.equal(isApnsToken(TOKEN), true);
  assert.equal(isApnsToken("abcdef0123456789"), true);
  assert.equal(isApnsToken("abc"), false);
  assert.equal(isApnsToken("g".repeat(64)), false);
  assert.equal(isApnsToken("a".repeat(513)), false);
  assert.equal(isApnsToken(12345), false);
});

test("buildLiveActivityMessage builds a start message with alert and attributes", () => {
  const message = buildLiveActivityMessage({
    fcmToken: FCM,
    liveActivityToken: TOKEN,
    event: "start",
    state: {pending: 3, newestBy: "Ana", oldestAt: OLDEST_SECONDS},
    nowSeconds: 1792490500,
  });
  assert.deepEqual(message, {
    token: FCM,
    apns: {
      liveActivityToken: TOKEN,
      headers: {"apns-priority": "10"},
      payload: {
        aps: {
          "timestamp": 1792490500,
          "event": "start",
          "content-state": {pending: 3, newestBy: "Ana", oldestAt: OLDEST_SECONDS},
          "attributes-type": "PrismReviewAttributes",
          "attributes": {},
          "alert": {title: "Walls to review", body: "3 waiting for review"},
        },
      },
    },
  });
});

test("buildLiveActivityMessage sends a quiet update and omits a null newestBy", () => {
  const message = buildLiveActivityMessage({
    fcmToken: FCM,
    liveActivityToken: TOKEN,
    event: "update",
    state: {pending: 2, newestBy: null, oldestAt: OLDEST_SECONDS},
    nowSeconds: 1792490500,
  });
  assert.deepEqual(message, {
    token: FCM,
    apns: {
      liveActivityToken: TOKEN,
      headers: {"apns-priority": "5"},
      payload: {
        aps: {
          "timestamp": 1792490500,
          "event": "update",
          "content-state": {pending: 2, oldestAt: OLDEST_SECONDS},
        },
      },
    },
  });
});

test("buildLiveActivityMessage sets dismissal-date on end", () => {
  const message = buildLiveActivityMessage({
    fcmToken: FCM,
    liveActivityToken: TOKEN,
    event: "end",
    state: {pending: 0, newestBy: null, oldestAt: null},
    nowSeconds: 1792490500,
  });
  assert.deepEqual(message, {
    token: FCM,
    apns: {
      liveActivityToken: TOKEN,
      headers: {"apns-priority": "10"},
      payload: {
        aps: {
          "timestamp": 1792490500,
          "event": "end",
          "content-state": {pending: 0},
          "dismissal-date": 1792490500,
        },
      },
    },
  });
});

test("planSend ends the activity when the queue is empty", () => {
  const empty = {pending: 0, newestBy: null, oldestAt: null};
  const doc = {pushToStartToken: null, activityToken: TOKEN, startRequestedAtMs: null, lastStateKey: "x"};
  assert.deepEqual(planSend(doc, empty, 1_000_000), {event: "end", token: TOKEN});
  assert.equal(planSend({...doc, activityToken: null}, empty, 1_000_000), null);
});

test("planSend updates a live activity only when the state changed", () => {
  const state = {pending: 2, newestBy: "Ana", oldestAt: OLDEST_SECONDS};
  const doc = {pushToStartToken: null, activityToken: TOKEN, startRequestedAtMs: null, lastStateKey: "1|X|"};
  assert.deepEqual(planSend(doc, state, 1_000_000), {event: "update", token: TOKEN});
  assert.equal(planSend({...doc, lastStateKey: stateKey(state)}, state, 1_000_000), null);
});

test("planSend starts an activity from the push-to-start token, once per 120 seconds", () => {
  const state = {pending: 1, newestBy: null, oldestAt: null};
  const base = {pushToStartToken: TOKEN, activityToken: null, lastStateKey: null};
  assert.deepEqual(planSend({...base, startRequestedAtMs: null}, state, 1_000_000),
    {event: "start", token: TOKEN});
  assert.equal(planSend({...base, startRequestedAtMs: 1_000_000 - 60_000}, state, 1_000_000), null);
  assert.equal(planSend({...base, startRequestedAtMs: 1_000_000 - 120_000}, state, 1_000_000), null);
  assert.deepEqual(planSend({...base, startRequestedAtMs: 1_000_000 - 120_001}, state, 1_000_000),
    {event: "start", token: TOKEN});
});

test("planSend does nothing without any token", () => {
  const state = {pending: 1, newestBy: null, oldestAt: null};
  const doc = {pushToStartToken: null, activityToken: null, startRequestedAtMs: null, lastStateKey: null};
  assert.equal(planSend(doc, state, 1_000_000), null);
});
