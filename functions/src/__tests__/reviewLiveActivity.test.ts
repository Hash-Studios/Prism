import assert from "node:assert/strict";
import * as admin from "firebase-admin";
import test from "node:test";
import * as adminConfig from "../adminConfig";
import {db} from "../common";
import * as notificationHelper from "../notificationHelper";
import {
  buildLiveActivityMessage,
  isApnsToken,
  isPendingWall,
  planSend,
  registerReviewLiveActivity,
  stateKey,
  syncReviewLiveActivities,
  summarizeQueue,
} from "../reviewLiveActivity";
import {installFakeDb} from "./fakeDb";

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

test("concurrent syncs send one start for the same admin", async (t) => {
  installFakeDb(t, {
    "adminLiveActivities/admin": {pushToStartToken: TOKEN},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);

  let finishSend: (() => void) | undefined;
  let signalStarted: () => void;
  const sendStarted = new Promise<void>((resolve) => signalStarted = resolve);
  const sendGate = new Promise<void>((resolve) => finishSend = resolve);
  let sends = 0;
  t.mock.method(admin.messaging(), "send", async () => {
    sends += 1;
    signalStarted();
    await sendGate;
    return "message-id";
  });

  const first = syncReviewLiveActivities();
  await sendStarted;
  const second = syncReviewLiveActivities();
  await assert.rejects(second, {code: "unavailable"});
  await new Promise<void>((resolve) => setImmediate(resolve));
  assert.ok(finishSend);
  finishSend();
  await first;

  assert.equal(sends, 1);
});

test("a busy unexpired lease is marked dirty and returns unavailable for retry", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {
      pushToStartToken: TOKEN,
      syncLeaseOwner: "expired-invocation",
      syncLeaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + 60_000),
      syncRequested: false,
    },
  });

  await assert.rejects(syncReviewLiveActivities("admin"), {code: "unavailable"});

  assert.equal(store.get("adminLiveActivities/admin")?.syncRequested, true);
});

test("a sync queued during a send drains the newest queue state", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: TOKEN, lastStateKey: "old"},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);

  let finishSend: (() => void) | undefined;
  let signalStarted: () => void;
  const sendStarted = new Promise<void>((resolve) => signalStarted = resolve);
  const sendGate = new Promise<void>((resolve) => finishSend = resolve);
  const states: Array<Record<string, unknown>> = [];
  t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    states.push(message.apns?.payload?.aps?.["content-state"] as Record<string, unknown>);
    if (states.length === 1) {
      signalStarted();
      await sendGate;
    }
    return "message-id";
  });

  const first = syncReviewLiveActivities();
  await sendStarted;
  store.set("walls/wall", {
    review: false,
    by: "Cy",
    createdAt: new Date("2026-10-20T10:00:00Z"),
  });
  const second = syncReviewLiveActivities();
  await assert.rejects(second, {code: "unavailable"});
  await new Promise<void>((resolve) => setImmediate(resolve));
  assert.ok(finishSend);
  finishSend();
  await first;

  assert.deepEqual(states, [
    {pending: 1, newestBy: "Ana", oldestAt: OLDEST_SECONDS},
    {pending: 1, newestBy: "Cy", oldestAt: OLDEST_SECONDS},
  ]);
  assert.equal(store.get("adminLiveActivities/admin")?.lastStateKey, "1|Cy|1792490400");
});

test("an activity token rotated during an end send is not cleared by the old send", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: TOKEN, lastStateKey: "pending"},
    "usersv2/admin": {loggedIn: true},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);

  const rotatedToken = "b".repeat(64);
  let finishSend: (() => void) | undefined;
  let signalStarted: () => void;
  const sendStarted = new Promise<void>((resolve) => signalStarted = resolve);
  const sendGate = new Promise<void>((resolve) => finishSend = resolve);
  const tokens: string[] = [];
  const events: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    tokens.push(message.apns?.liveActivityToken ?? "");
    events.push(message.apns?.payload?.aps?.event as string);
    if (tokens.length === 1) {
      signalStarted();
      await sendGate;
    }
    return "message-id";
  });

  const sync = syncReviewLiveActivities();
  await sendStarted;
  store.set("walls/wall", {
    review: false,
    by: "Ana",
    createdAt: new Date("2026-10-20T10:00:00Z"),
  });
  await assert.rejects(registerReviewLiveActivity.run({
    auth: {uid: "admin", token: {admin: true}},
    data: {activityToken: rotatedToken},
  } as never), {code: "unavailable"});
  assert.ok(finishSend);
  finishSend();
  await sync;

  assert.deepEqual(tokens, [TOKEN, rotatedToken]);
  assert.deepEqual(events, ["end", "update"]);
  assert.equal(store.get("adminLiveActivities/admin")?.activityToken, rotatedToken);
});

test("sync skips revoked admins but retains tokens if admin lookup cannot confirm rights", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {pushToStartToken: TOKEN},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {}}) as never);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(adminConfig, "isAdminCaller", async () => false);
  const send = t.mock.method(admin.messaging(), "send", async () => "message-id");

  await syncReviewLiveActivities();

  assert.equal(send.mock.callCount(), 0);
  assert.equal(store.get("adminLiveActivities/admin")?.pushToStartToken, TOKEN);
});

test("transient auth lookup failure propagates without clearing tokens", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {pushToStartToken: TOKEN},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => {
    throw Object.assign(new Error("Auth service unavailable"), {code: "auth/internal-error"});
  });
  const send = t.mock.method(admin.messaging(), "send", async () => "message-id");

  await assert.rejects(syncReviewLiveActivities(), {code: "auth/internal-error"});

  assert.equal(send.mock.callCount(), 0);
  assert.equal(store.get("adminLiveActivities/admin")?.pushToStartToken, TOKEN);
});

test("signed-out admins have their saved activity tokens cleared", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {pushToStartToken: TOKEN},
    "usersv2/admin": {loggedIn: false},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  const send = t.mock.method(admin.messaging(), "send", async () => "message-id");

  await syncReviewLiveActivities();

  assert.equal(send.mock.callCount(), 0);
  assert.equal(store.get("adminLiveActivities/admin")?.pushToStartToken, null);
});

test("missing FCM tokens fail callable sync but retain APNs activity tokens", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {pushToStartToken: TOKEN},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(notificationHelper, "userPushTokens", async () => []);
  const send = t.mock.method(admin.messaging(), "send", async () => "message-id");

  await assert.rejects(syncReviewLiveActivities("admin"), {code: "unavailable"});

  assert.equal(send.mock.callCount(), 0);
  assert.equal(store.get("adminLiveActivities/admin")?.pushToStartToken, TOKEN);
});

test("registerReviewLiveActivity rejects a caller without current admin rights", async (t) => {
  installFakeDb(t);
  t.mock.method(adminConfig, "isAdminCaller", async () => false);

  await assert.rejects(
    registerReviewLiveActivity.run({
      auth: {uid: "user", token: {}},
      data: {activityToken: TOKEN},
    } as never),
    {code: "permission-denied"},
  );
});

test("registerReviewLiveActivity validates auth and token boundary inputs", async (t) => {
  const validToken = "c".repeat(64);
  const cases = [
    {name: "unauthenticated", data: {activityToken: TOKEN}, auth: undefined, code: "unauthenticated"},
    {name: "missing token fields", data: {}, auth: {uid: "admin", token: {admin: true}}, code: "invalid-argument"},
    {name: "malformed token", data: {activityToken: "not-an-apns-token"}, auth: {uid: "admin", token: {admin: true}}, code: "invalid-argument"},
  ] as const;
  for (const item of cases) {
    await t.test(item.name, async (subtest) => {
      installFakeDb(subtest, {"usersv2/admin": {loggedIn: true}});
      subtest.mock.method(adminConfig, "isAdminCaller", async () => true);
      await assert.rejects(
        registerReviewLiveActivity.run({auth: item.auth, data: item.data} as never),
        {code: item.code},
      );
    });
  }

  await t.test("null clears a token and an omitted peer field stays absent", async (subtest) => {
    const store = installFakeDb(subtest, {
      "adminLiveActivities/admin": {activityToken: TOKEN, pushToStartToken: TOKEN},
      "usersv2/admin": {loggedIn: true},
    });
    t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
    t.mock.method(adminConfig, "isAdminCaller", async () => true);
    await registerReviewLiveActivity.run({
      auth: {uid: "admin", token: {admin: true}},
      data: {activityToken: null},
    } as never);
    const doc = store.get("adminLiveActivities/admin");
    assert.equal(doc?.activityToken, null);
    assert.equal(doc?.pushToStartToken, TOKEN);
  });

  await t.test("a valid token can be registered without the other token field", async (subtest) => {
    const store = installFakeDb(subtest, {"usersv2/admin": {loggedIn: true}});
    t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
    t.mock.method(adminConfig, "isAdminCaller", async () => true);
    await registerReviewLiveActivity.run({
      auth: {uid: "admin", token: {admin: true}},
      data: {pushToStartToken: validToken},
    } as never);
    const doc = store.get("adminLiveActivities/admin");
    assert.equal(doc?.pushToStartToken, validToken);
    assert.equal(doc?.activityToken, undefined);
  });
});

test("token registration clears lastStateKey when another registration wins the stale-read race", async (t) => {
  const oldToken = "d".repeat(64);
  const interveningToken = "e".repeat(64);
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: oldToken, lastStateKey: "concurrent-state"},
    "usersv2/admin": {loggedIn: true},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(notificationHelper, "userPushTokens", async () => []);

  const originalCollection = db.collection.bind(db);
  let directGets = 0;
  let injectedCompetingWrite = false;
  t.mock.method(db, "collection", (name: string) => {
    const collection = originalCollection(name);
    if (name !== "adminLiveActivities") return collection;
    return {
      ...collection,
      doc: (uid: string) => {
        const ref = collection.doc(uid);
        return {
          ...ref,
          get: async () => {
            directGets += 1;
            if (directGets === 1) {
              return {
                id: "admin",
                exists: true,
                data: () => ({activityToken: oldToken, lastStateKey: "old-state"}),
              };
            }
            return ref.get();
          },
          set: async (data: Record<string, unknown>, options?: {merge?: boolean}) => {
            if (!injectedCompetingWrite) {
              injectedCompetingWrite = true;
              store.set("adminLiveActivities/admin", {
                activityToken: interveningToken,
                lastStateKey: "concurrent-state",
              });
            }
            if (options === undefined) await ref.set(data);
            else await ref.set(data, options);
          },
        };
      },
    };
  });

  const runTransaction = db.runTransaction.bind(db);
  let registrationTransaction = true;
  t.mock.method(db, "runTransaction", async (callback: (transaction: unknown) => Promise<unknown>) => {
    if (!registrationTransaction) return runTransaction(callback as never);
    registrationTransaction = false;
    return callback({
      get: async () => ({data: () => ({activityToken: interveningToken})}),
      set: async (
        ref: {set: (data: Record<string, unknown>, options?: {merge?: boolean}) => Promise<void>},
        data: Record<string, unknown>,
        options?: {merge?: boolean},
      ) => ref.set(data, options),
    });
  });

  await assert.rejects(registerReviewLiveActivity.run({
    auth: {uid: "admin", token: {admin: true}},
    data: {activityToken: oldToken},
  } as never), {code: "unavailable"});

  assert.equal(store.get("adminLiveActivities/admin")?.activityToken, oldToken);
  assert.equal(store.get("adminLiveActivities/admin")?.lastStateKey, null);
});

test("invalid-argument does not erase the registered ActivityKit token", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: TOKEN, lastStateKey: "old"},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(admin.messaging(), "send", async () => {
    throw Object.assign(new Error("Invalid message payload"), {code: "messaging/invalid-argument"});
  });

  await syncReviewLiveActivities();

  assert.equal(store.get("adminLiveActivities/admin")?.activityToken, TOKEN);
});

test("an unregistered FCM token leaves the shared session binding alone", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: TOKEN, lastStateKey: "old"},
    "usersv2/admin": {loggedIn: true},
    "usersv2/admin/private/session": {
      fcmToken: FCM,
      fcmTokenBindingVersion: 1,
      fcmTokenBindingToken: FCM,
    },
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  t.mock.method(admin.messaging(), "send", async () => {
    throw Object.assign(new Error("Token is not registered"), {code: "messaging/registration-token-not-registered"});
  });

  await syncReviewLiveActivities();

  assert.equal(store.get("usersv2/admin/private/session")?.fcmToken, FCM);
  assert.equal(store.get("adminLiveActivities/admin")?.activityToken, TOKEN);
});

test("a transient FCM outage retries once and records the delivered state", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/admin": {activityToken: TOKEN, lastStateKey: "old"},
    "usersv2/admin": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  let sends = 0;
  t.mock.method(admin.messaging(), "send", async () => {
    sends += 1;
    if (sends === 1) {
      throw Object.assign(new Error("FCM is temporarily unavailable"), {code: "messaging/server-unavailable"});
    }
    return "message-id";
  });

  await syncReviewLiveActivities();

  assert.equal(sends, 2);
  assert.equal(store.get("adminLiveActivities/admin")?.lastStateKey, "1|Ana|1792490400");
});

test("one admin's persistent FCM error does not block other admins", async (t) => {
  const store = installFakeDb(t, {
    "adminLiveActivities/a": {activityToken: "a".repeat(64), lastStateKey: "old"},
    "adminLiveActivities/b": {activityToken: "b".repeat(64), lastStateKey: "old"},
    "usersv2/a": {loggedIn: true},
    "usersv2/b": {loggedIn: true},
    "walls/wall": {review: false, by: "Ana", createdAt: new Date("2026-10-20T10:00:00Z")},
  });
  t.mock.method(admin.auth(), "getUser", async () => ({customClaims: {admin: true}}) as never);
  t.mock.method(adminConfig, "isAdminCaller", async () => true);
  t.mock.method(notificationHelper, "userPushTokens", async () => [{token: FCM, nativeLocalization: false}]);
  const tokens: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    const token = message.apns?.liveActivityToken ?? "";
    tokens.push(token);
    if (token === "a".repeat(64)) {
      throw Object.assign(new Error("FCM is unavailable"), {code: "messaging/server-unavailable"});
    }
    return "message-id";
  });

  await assert.rejects(syncReviewLiveActivities(), {code: "messaging/server-unavailable"});

  assert.deepEqual(tokens, ["a".repeat(64), "a".repeat(64), "b".repeat(64)]);
  assert.equal(store.get("adminLiveActivities/b")?.lastStateKey, "1|Ana|1792490400");
});
