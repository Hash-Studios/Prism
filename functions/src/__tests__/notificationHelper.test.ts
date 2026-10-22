import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test, {beforeEach} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db, utcDateString} from "../common";
import {installFakeDb} from "./fakeDb";
import {
  nativeNotificationLocalization,
  notificationCopyPayload,
  type NotificationCopy,
} from "../notificationCatalog";

import {
  emailToTopic,
  fcmMessage,
  isLoggedOut,
  pickFcmToken,
  sendNotification,
  sendToUser,
  sendToUserByEmail,
  userIdToTopic,
} from "../notificationHelper";

beforeEach((t) => {
  assert.ok("mock" in t);
  installFakeDb(t);
});

test("notification topics match the names the app subscribes to", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "samone");
  assert.equal(emailToTopic("john+alerts.test@example.com"), "johnalerts.test");
  assert.equal(emailToTopic("Az-_.~%09@example.com"), "Az-_.~%09");
  assert.equal(userIdToTopic("abc/123"), "u_abc123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});

test("fcmMessage puts a condition target on the message and no topic or token", () => {
  const message = fcmMessage({
    title: "t",
    body: "b",
    data: {route: "r"},
    modifier: "m",
    channelId: "c",
    fcmTarget: {condition: "'a' in topics || 'b' in topics"},
  });
  assert.equal(
    "condition" in message && message.condition,
    "'a' in topics || 'b' in topics",
  );
  assert.ok(!("topic" in message));
  assert.ok(!("token" in message));
});

test("typed notifications use native device-locale keys and retain English fallbacks", () => {
  const payload = {
    ...notificationCopyPayload({
      kind: "wallLiveForFollowers",
      artistName: "Asha",
      wallTitle: "Blue hour",
    }),
    data: {route: "wall"},
    modifier: "all",
    channelId: "posts",
    fcmTarget: {topic: "posts"},
  };
  const message = fcmMessage(payload);
  const android = message.android?.notification;
  const apns = message.apns?.payload?.aps.alert;

  assert.deepEqual(message.notification, {
    title: "New wall by Asha",
    body: "\"Blue hour\" is now live on Prism.",
  });
  assert.equal(android?.titleLocKey, undefined, "legacy message uses its English title");
  assert.equal(apns, undefined, "legacy iOS message uses its English fallback");
});

test("localization-capable topic payloads omit common strings so device resources win", () => {
  const payload = {
    ...notificationCopyPayload({
      kind: "wallLiveForFollowers",
      artistName: "Asha",
      wallTitle: "Blue hour",
    }),
    data: {route: "wall"},
    modifier: "all",
    channelId: "posts",
    fcmTarget: {topic: "posts_loc_v1"},
  };
  const message = fcmMessage(payload);
  assert.equal(message.notification, undefined);
  assert.equal(message.android?.notification?.titleLocKey, "notif_push_wall_live_for_followers_title");
  const alert = message.apns?.payload?.aps.alert;
  assert.ok(alert && typeof alert !== "string");
  assert.equal(alert.locKey, "notif_push_wall_live_for_followers_body");
});

test("native localization uses count-neutral resource keys for drop counts", () => {
  const oneWall = notificationCopyPayload({kind: "dropLive", wallCount: 1});
  const manyWalls = notificationCopyPayload({kind: "dropLive", wallCount: 4});
  const oneHour = notificationCopyPayload({
    kind: "dropLastCall",
    dropTitle: "Blue hour",
    hoursLeft: 1,
  });
  const manyHours = notificationCopyPayload({
    kind: "dropLastCall",
    dropTitle: "Blue hour",
    hoursLeft: 3,
  });

  assert.equal(
    nativeNotificationLocalization(oneWall.message)?.bodyKey,
    "notif_push_drop_live_body",
  );
  assert.deepEqual(nativeNotificationLocalization(oneWall.message)?.bodyArgs, ["1"]);
  assert.equal(
    nativeNotificationLocalization(manyWalls.message)?.bodyKey,
    "notif_push_drop_live_body",
  );
  assert.deepEqual(nativeNotificationLocalization(manyWalls.message)?.bodyArgs, ["4"]);
  assert.equal(
    nativeNotificationLocalization(oneHour.message)?.bodyKey,
    "notif_push_drop_last_call_body",
  );
  assert.deepEqual(nativeNotificationLocalization(oneHour.message)?.bodyArgs, ["Blue hour", "1"]);
  assert.equal(
    nativeNotificationLocalization(manyHours.message)?.bodyKey,
    "notif_push_drop_last_call_body",
  );
  assert.deepEqual(nativeNotificationLocalization(manyHours.message)?.bodyArgs, ["Blue hour", "3"]);
});

test("native resources contain every typed notification key on Android and iOS", () => {
  const copies: NotificationCopy[] = [
    {kind: "wallApprovedForArtist", wallTitle: "Blue hour"},
    {kind: "wallApprovedForArtist", wallTitle: ""},
    {
      kind: "wallLiveForFollowers",
      artistName: "Asha",
      wallTitle: "Blue hour",
    },
    {
      kind: "wallApprovedForAdmin",
      wallTitle: "Blue hour",
      artistName: "Asha",
    },
    {kind: "newFollower", followerName: "Asha"},
    {kind: "streakReminder"},
    {kind: "wotdForCreator"},
    {kind: "wotdForAudience", wallTitle: "Blue hour"},
    {kind: "wotdForAudience", wallTitle: ""},
    {kind: "winBack7"},
    {kind: "winBack14"},
    {kind: "winBack30"},
    {kind: "winBack60"},
    {kind: "dropLive", wallCount: 1},
    {kind: "dropLive", wallCount: 3},
    {kind: "dropLastCall", dropTitle: "Blue hour", hoursLeft: 1},
    {kind: "dropLastCall", dropTitle: "Blue hour", hoursLeft: 3},
    {kind: "drawWinner"},
    {kind: "giftReceived", senderName: "Asha"},
    {kind: "reportNeedsReview", contentType: "wall", reason: "spam"},
    {
      kind: "newContentReport",
      contentType: "wall",
      reason: "spam",
      targetId: "w1",
    },
    {
      kind: "wallSubmittedForReview",
      artistName: "Asha",
      artistEmail: "asha@example.com",
    },
  ];
  const argumentsByKey = new Map<string, number>();
  const expectedByKey = new Map<string, { args: string[]; fallback: string; resourceText?: string }>();
  for (const copy of copies) {
    const {message, title, body} = notificationCopyPayload(copy);
    const native = nativeNotificationLocalization(message);
    assert.ok(native, `expected ${copy.kind} to have native localization`);
    argumentsByKey.set(native.titleKey, native.titleArgs.length);
    argumentsByKey.set(native.bodyKey, native.bodyArgs.length);
    expectedByKey.set(native.titleKey, {
      args: native.titleArgs,
      fallback: title,
    });
    expectedByKey.set(native.bodyKey, {
      args: native.bodyArgs,
      fallback: body,
      resourceText:
        native.bodyKey === "notif_push_drop_live_body" ?
          "Wallpapers in this week's Drop: %1$s. Preview the Drop before it closes." :
          native.bodyKey === "notif_push_drop_last_call_body" ?
            "%1$s ends in %2$s h. Wallpapers are unavailable for a month afterward." :
            undefined,
    });
  }

  const android = readFileSync(
    "../android/app/src/main/res/values/strings.xml",
    "utf8",
  );
  const apple = JSON.parse(
    readFileSync("../ios/Runner/Localizable.xcstrings", "utf8"),
  ) as {
    strings: Record<
      string,
      { localizations?: { en?: { stringUnit?: { value?: string } } } }
    >;
  };
  for (const [key, argumentCount] of argumentsByKey) {
    const encodedAndroidValue = new RegExp(
      `<string name="${key}">([^<]+)</string>`,
    ).exec(android)?.[1];
    const androidValue = encodedAndroidValue
      ?.replace(/&amp;/g, "&")
      .replace(/\\'/g, "'")
      .replace(/\\"/g, "\"");
    assert.ok(androidValue, `missing Android resource ${key}`);
    const iosValue = apple.strings[key]?.localizations?.en?.stringUnit?.value;
    assert.ok(iosValue, `missing iOS resource ${key}`);
    assert.equal(
      (androidValue.match(/%\d+\$s/g) ?? []).length,
      argumentCount,
      `Android placeholders do not match args for ${key}`,
    );
    assert.equal(
      (iosValue.match(/%\d+\$@/g) ?? []).length,
      argumentCount,
      `iOS placeholders do not match args for ${key}`,
    );
    const expected = expectedByKey.get(key)!;
    const expectedResource = (expected.resourceText ?? expected.fallback).replace(
      /%(\d+)\$s/g,
      (_match: string, index: string) => expected.args[Number(index) - 1],
    );
    assert.equal(
      androidValue.replace(
        /%(\d+)\$s/g,
        (_match: string, index: string) => expected.args[Number(index) - 1],
      ),
      expectedResource,
      `Android English resource does not match native copy for ${key}`,
    );
    assert.equal(
      iosValue.replace(
        /%(\d+)\$@/g,
        (_match: string, index: string) => expected.args[Number(index) - 1],
      ),
      expectedResource.replace(/%1\$s/g, "%1$@").replace(/%2\$s/g, "%2$@"),
      `iOS English resource does not match native copy for ${key}`,
    );
  }
});

test("custom campaign copy remains literal and is not assigned a native template", () => {
  const payload = {
    ...notificationCopyPayload({
      kind: "custom",
      title: "Community update",
      body: "A custom message from the Prism team.",
    }),
    data: {route: "announcement"},
    modifier: "all",
    channelId: "recommendations",
    fcmTarget: {topic: "recommendations"},
  };
  const message = fcmMessage(payload);
  assert.deepEqual(message.notification, {
    title: "Community update",
    body: "A custom message from the Prism team.",
  });
  assert.equal(message.android?.notification?.titleLocKey, undefined);
  assert.equal(message.android?.notification?.bodyLocKey, undefined);
  assert.equal(message.apns?.payload?.aps.alert, undefined);
});

test("custom topic copy reaches both topic generations with literal text", async (t) => {
  const {sent} = personalSetup(t);
  const payload = {
    ...notificationCopyPayload({
      kind: "custom",
      title: "Community update",
      body: "A custom message from the Prism team.",
    }),
    data: {route: "announcement"},
    modifier: "all",
    channelId: "recommendations",
    fcmTarget: {topic: "announcements"},
    pushOnly: true,
  };

  await sendNotification(payload);

  assert.deepEqual(sent.map((message) => message.topic).sort(), [
    "announcements",
    "announcements_loc_v1",
  ]);
  assert.deepEqual(sent.map((message) => message.notification), [
    {title: "Community update", body: "A custom message from the Prism team."},
    {title: "Community update", body: "A custom message from the Prism team."},
  ]);
  assert.ok(sent.every((message) => message.android?.notification?.titleLocKey === undefined));
});

test("only an explicit loggedIn false counts as signed out", () => {
  assert.equal(isLoggedOut({loggedIn: false}), true);
  assert.equal(isLoggedOut({loggedIn: true}), false);
  assert.equal(isLoggedOut({}), false);
  assert.equal(isLoggedOut(undefined), false);
});

test("signed-out personal pushOnly email fallbacks are skipped", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({
      empty: false,
      docs: [{data: () => ({loggedIn: false})}],
    }),
  };
  t.mock.method(db, "collection", (name: string) =>
    name === "usersv2" ? query : {add: async () => undefined},
  );
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t",
    body: "b",
    data: {route: "r"},
    modifier: "sam@example.com",
    channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
    pushOnly: true,
  });

  assert.equal(send.mock.callCount(), 0);
});

test("a personal payload is never sent to an email-prefix topic, even for a signed-in user", async (t) => {
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({
      empty: false,
      docs: [{data: () => ({loggedIn: true})}],
    }),
  };
  t.mock.method(db, "collection", (name: string) =>
    name === "usersv2" ? query : {add: async () => undefined},
  );
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t",
    body: "b",
    data: {route: "r"},
    modifier: "sam@example.com",
    channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
    pushOnly: true,
  });
  await sendNotification({
    title: "t",
    body: "b",
    data: {route: "r"},
    modifier: "sam@example.com",
    channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
  });

  assert.equal(send.mock.callCount(), 0);
});

test("personal topic lookup failure prevents FCM delivery", async (t) => {
  const inbox: Record<string, unknown>[] = [];
  t.mock.method(db, "collection", (name: string) =>
    name === "usersv2" ?
      {
        where: () => ({
          limit: () => ({
            get: async () => {
              throw new Error("lookup failed");
            },
          }),
        }),
      } :
      {add: async (data: Record<string, unknown>) => inbox.push(data)},
  );
  const send = t.mock.method(admin.messaging(), "send", async () => "id");

  await sendNotification({
    title: "t",
    body: "b",
    data: {route: "r"},
    modifier: "sam@example.com",
    channelId: "c",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
  });

  assert.equal(send.mock.callCount(), 0);
  assert.equal(inbox.length, 1);
  assert.equal(inbox[0].modifier, "sam@example.com");
});

type Sent = {
  topic?: string;
  token?: string;
  notification?: { title?: string; body?: string };
  data?: Record<string, string>;
  android?: {
    notification?: {
      tag?: string;
      titleLocKey?: string;
      bodyLocKey?: string;
    };
  };
};

function personalSetup(
  t: test.TestContext,
  sessionToken?: string,
  nativeLocalization = false,
  localizationToken = sessionToken,
) {
  const inbox: Array<{ id?: string; data: Record<string, unknown> }> = [];
  const document = db.doc.bind(db);
  t.mock.method(db, "collection", () => ({
    add: async (data: Record<string, unknown>) => inbox.push({data}),
    doc: (id: string) => ({
      set: async (data: Record<string, unknown>) => inbox.push({id, data}),
    }),
  }));
  t.mock.method(db, "doc", (path: string) => path.endsWith("/private/session") ? ({
    get: async () => ({
      data: () => (sessionToken ?
        {
          fcmToken: sessionToken,
          ...(nativeLocalization ?
            {
              notificationLocalizationVersion: 1,
              notificationLocalizationToken: localizationToken,
            } :
            {}),
        } :
        {}),
    }),
  }) : document(path));
  const sent: Sent[] = [];
  t.mock.method(admin.messaging(), "send", async (message: Sent) => {
    sent.push(message);
    return "id";
  });
  return {inbox, sent};
}

const personal = {
  title: "t",
  body: "b",
  data: {route: "r"},
  modifier: "sam@example.com",
  channelId: "c",
};

function scoreboardSetup(
  t: test.TestContext,
  options: { failWrites?: boolean } = {},
) {
  const day = `metrics/notificationScoreboard/days/${utcDateString()}`;
  const documents = new Map<string, Record<string, unknown>>();
  const attempts: string[] = [];
  const inboxWrites: string[] = [];
  let transactionQueue = Promise.resolve();
  t.mock.method(db, "doc", (path: string) =>
    path.endsWith("/private/session") ?
      {
        get: async () => ({data: () => ({fcmToken: "session-token"})}),
      } :
      {path, firestore: db},
  );
  t.mock.method(
    db,
    "runTransaction",
    async (
      callback: (tx: {
        get: (ref: { path: string }) => Promise<{
          exists: boolean;
          data: () => Record<string, unknown> | undefined;
        }>;
        set: (
          ref: { path: string },
          data: Record<string, unknown>,
          options?: { merge?: boolean },
        ) => void;
      }) => Promise<unknown>,
    ) => {
      attempts.push("transaction");
      if (options.failWrites) throw new Error("scoreboard unavailable");
      const priorTransaction = transactionQueue;
      let releaseTransaction: () => void = () => undefined;
      transactionQueue = new Promise<void>((resolve) => {
        releaseTransaction = resolve;
      });
      await priorTransaction;
      try {
        const writes: Array<{
          path: string;
          data: Record<string, unknown>;
          merge: boolean;
        }> = [];
        const result = await callback({
          get: async (ref) => {
            const data = documents.get(ref.path);
            return {exists: data !== undefined, data: () => data};
          },
          set: (ref, data, setOptions) =>
            writes.push({
              path: ref.path,
              data,
              merge: setOptions?.merge ?? false,
            }),
        });
        for (const write of writes) {
          const prior = write.merge ? (documents.get(write.path) ?? {}) : {};
          documents.set(write.path, {...prior, ...write.data});
        }
        return result;
      } finally {
        releaseTransaction();
      }
    },
  );
  const sent: Sent[] = [];
  t.mock.method(admin.messaging(), "send", async (message: Sent) => {
    sent.push(message);
    return "id";
  });
  t.mock.method(db, "collection", (name: string) =>
    name === "notifications" ?
      {
        add: async () => inboxWrites.push("add"),
        doc: () => ({set: async () => inboxWrites.push("set")}),
      } :
      {add: async () => undefined},
  );
  return {day, documents, attempts, inboxWrites, sent};
}

test("a personal push goes to the uid topic and the session token under one collapse key", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  const ok = await sendToUser(personal, {
    uid: "u1",
    email: "sam@example.com",
    legacyToken: "legacy-token",
  });
  assert.equal(ok, true);
  assert.equal(inbox.length, 1);
  assert.deepEqual(
    sent.map((m) => m.topic ?? m.token),
    ["u_u1", "u_u1_loc_v1", "session-token"],
  );
  assert.ok(sent[0].android?.notification?.tag?.startsWith("p_"));
  assert.equal(
    sent[0].android?.notification?.tag,
    sent[1].android?.notification?.tag,
  );
});

test("a personal uid-topic and token each count as an FCM attempt", async (t) => {
  const {day, documents, sent} = scoreboardSetup(t);
  await sendToUser(
    {...personal, data: {route: "wall"}, scoreKind: "post"},
    {
      uid: "u1",
      email: "sam@example.com",
      legacyToken: "legacy-token",
    },
  );
  assert.deepEqual(
    sent.map((message) => message.topic ?? message.token),
    ["u_u1", "u_u1_loc_v1", "session-token"],
  );
  const totals = {
    sends: {} as Record<string, number>,
    accepts: {} as Record<string, number>,
  };
  for (const [path, data] of documents) {
    assert.equal(path.startsWith(`${day}_`), true, path);
    for (const outcome of ["sends", "accepts"] as const) {
      const bucket = data[outcome] as Record<string, number> | undefined;
      for (const [kind, count] of Object.entries(bucket ?? {})) {
        totals[outcome][kind] = (totals[outcome][kind] ?? 0) + count;
      }
    }
  }
  assert.equal(documents.has(day), false);
  assert.deepEqual(totals, {sends: {post: 3}, accepts: {post: 3}});
});

test("an inbox-only notification with a known kind does not count as a push", async (t) => {
  const {documents, attempts, inboxWrites} = scoreboardSetup(t);
  await sendNotification({
    ...personal,
    data: {route: "wall"},
    scoreKind: "post",
  });
  assert.deepEqual(inboxWrites, ["add"]);
  assert.equal(attempts.length, 0);
  assert.equal(documents.size, 0);
});

test("an unknown route with an FCM target sends but does not count", async (t) => {
  const {documents, attempts, sent} = scoreboardSetup(t);
  await sendNotification({
    ...personal,
    data: {route: "unrecognized"},
    fcmTarget: {token: "device-token"},
    pushOnly: true,
  });
  assert.equal(sent.length, 1);
  assert.equal(attempts.length, 0);
  assert.equal(documents.size, 0);
});

test("an email-prefix topic with a known kind does not send or count", async (t) => {
  const {documents, attempts, sent} = scoreboardSetup(t);
  await sendNotification({
    ...personal,
    data: {route: "wall"},
    scoreKind: "post",
    fcmTarget: {topic: emailToTopic("sam@example.com")},
    pushOnly: true,
  });
  assert.equal(sent.length, 0);
  assert.equal(attempts.length, 0);
  assert.equal(documents.size, 0);
});

test("a recipient lookup failure does not count as an FCM failure", async (t) => {
  const {documents, attempts, sent} = scoreboardSetup(t);
  const failing = {
    where: () => failing,
    limit: () => failing,
    get: async () => {
      throw new Error("lookup failed");
    },
  };
  t.mock.method(db, "collection", (name: string) =>
    name === "usersv2" ? failing : {add: async () => undefined},
  );
  const error = Object.getOwnPropertyDescriptor(logger, "error");
  Object.defineProperty(logger, "error", {
    configurable: true,
    value: () => undefined,
  });
  try {
    const ok = await sendNotification({
      ...personal,
      data: {route: "wall"},
      scoreKind: "post",
      fcmTarget: {topic: "u_u1"},
    });
    assert.equal(ok, false);
    assert.equal(sent.length, 0);
    assert.equal(attempts.length, 0);
    assert.equal(documents.size, 0);
  } finally {
    if (error) Object.defineProperty(logger, "error", error);
  }
});

test("scoreboard write failures do not fail an accepted push", async (t) => {
  const {attempts, sent} = scoreboardSetup(t, {failWrites: true});
  const warn = Object.getOwnPropertyDescriptor(logger, "warn");
  Object.defineProperty(logger, "warn", {
    configurable: true,
    value: () => undefined,
  });
  try {
    const ok = await sendNotification({
      ...personal,
      data: {route: "wall"},
      scoreKind: "post",
      fcmTarget: {token: "device-token"},
      pushOnly: true,
    });
    assert.equal(ok, true);
    assert.equal(sent.length, 1);
    assert.equal(attempts.length, 2);
  } finally {
    if (warn) Object.defineProperty(logger, "warn", warn);
  }
});

test("a personal push falls back to the legacy token and never uses the email-prefix topic", async (t) => {
  const {sent} = personalSetup(t);
  await sendToUser(personal, {
    uid: "u1",
    email: "sam@example.com",
    legacyToken: "legacy-token",
  });
  assert.deepEqual(
    sent.map((m) => m.topic ?? m.token),
    ["u_u1", "u_u1_loc_v1", "legacy-token"],
  );
});

test("a personal push keeps the caller's collapse key", async (t) => {
  const {sent} = personalSetup(t);
  await sendToUser(
    {...personal, collapseKey: "follow_1"},
    {uid: "u1", email: "sam@example.com"},
  );
  assert.equal(sent[0].android?.notification?.tag, "follow_1");
});

test("a signed-out or muted user keeps the inbox doc and gets no push", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  await sendToUser(personal, {
    uid: "u1",
    email: "sam@example.com",
    loggedOut: true,
  });
  await sendToUser(personal, {uid: "u1", email: "sam@example.com"}, false);
  assert.equal(inbox.length, 2);
  assert.equal(sent.length, 0);
});

test("a recipient with no uid gets the inbox doc and no push", async (t) => {
  const {sent, inbox} = personalSetup(t);
  const ok = await sendToUser(personal, {email: "sam@example.com"});
  assert.equal(ok, true);
  assert.deepEqual(sent, []);
  assert.equal(inbox.length, 1);
});

test("a recipient lookup error gives no push and never falls back to the prefix topic", async (t) => {
  const {sent, inbox} = personalSetup(t);
  const failing = {
    where: () => failing,
    limit: () => failing,
    get: async () => {
      throw new Error("lookup failed");
    },
  };
  t.mock.method(db, "collection", (name: string) =>
    name === "usersv2" ?
      failing :
      {add: async (data: Record<string, unknown>) => inbox.push({data})},
  );
  await sendToUserByEmail(personal, "sam@example.com");
  assert.deepEqual(sent, []);
  assert.equal(inbox.length, 1);
});

test("sendToUser reports a failed delivery", async (t) => {
  personalSetup(t);
  t.mock.method(admin.messaging(), "send", async () => {
    throw new Error("fcm down");
  });
  assert.equal(
    await sendToUser(personal, {
      uid: "u1",
      email: "sam@example.com",
      legacyToken: "x",
    }),
    false,
  );
});

test("a fixed docId writes one inbox doc that a retry rewrites", async (t) => {
  const {inbox} = personalSetup(t);
  await sendToUser(
    {...personal, docId: "streak_u1_2026-01-02"},
    {uid: "u1", email: "sam@example.com"},
    false,
  );
  await sendToUser(
    {...personal, docId: "streak_u1_2026-01-02"},
    {uid: "u1", email: "sam@example.com"},
    false,
  );
  assert.deepEqual(
    inbox.map((d) => d.id),
    ["streak_u1_2026-01-02", "streak_u1_2026-01-02"],
  );
});

test("structured copy stays beside legacy text in the inbox and push payload", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  const payload = {
    ...notificationCopyPayload({kind: "newFollower", followerName: "Asha"}),
    data: {route: "follower"},
    modifier: "sam@example.com",
    channelId: "followers",
  };
  await sendToUser(payload, {uid: "u1", email: "sam@example.com"});

  assert.deepEqual(inbox[0].data.message, {
    kind: "newFollower",
    args: {followerName: "Asha"},
  });
  assert.equal(
    (inbox[0].data.notification as Record<string, unknown>).body,
    "Asha is now following you.",
  );
  assert.equal(sent[0].data?.notification_copy_kind, "newFollower");
  assert.equal(
    sent[0].data?.notification_args,
    JSON.stringify({followerName: "Asha"}),
  );
});

test("structured topic sends preserve English for legacy subscribers and localize capable subscribers", async (t) => {
  const {sent} = personalSetup(t);
  const payload = {
    ...notificationCopyPayload({kind: "newFollower", followerName: "Asha"}),
    data: {route: "follower"},
    modifier: "sam@example.com",
    channelId: "followers",
  };

  await sendNotification({...payload, fcmTarget: {topic: "u_u1"}, pushOnly: true});

  assert.deepEqual(sent.map((message) => message.topic), ["u_u1", "u_u1_loc_v1"]);
  assert.deepEqual(sent[0].notification, {
    title: "You have a new follower! 🎉",
    body: "Asha is now following you.",
  });
  assert.equal(sent[1].notification, undefined);
  assert.equal(sent[0].android?.notification?.tag, sent[1].android?.notification?.tag);
});

test("a capable direct token omits English notification fields", async (t) => {
  const {sent} = personalSetup(t, "session-token", true);
  const payload = {
    ...notificationCopyPayload({kind: "newFollower", followerName: "Asha"}),
    data: {route: "follower"},
    modifier: "sam@example.com",
    channelId: "followers",
  };

  await sendToUser(payload, {uid: "u1", email: "sam@example.com"});

  const direct = sent.find((message) => message.token === "session-token");
  assert.ok(direct);
  assert.equal(direct.notification, undefined);
  assert.equal(direct.android?.notification?.titleLocKey, "notif_push_new_follower_title");
  assert.equal(direct.data?.notification_copy_kind, "newFollower");
});

test("a stale localization marker does not classify a replaced token as capable", async (t) => {
  const {sent} = personalSetup(t, "replaced-token", true, "old-token");
  const payload = {
    ...notificationCopyPayload({kind: "newFollower", followerName: "Asha"}),
    data: {route: "follower"},
    modifier: "sam@example.com",
    channelId: "followers",
  };

  await sendToUser(payload, {uid: "u1", email: "sam@example.com"});

  const direct = sent.find((message) => message.token === "replaced-token");
  assert.ok(direct);
  assert.deepEqual(direct.notification, {
    title: "You have a new follower! 🎉",
    body: "Asha is now following you.",
  });
  assert.equal(direct.android?.notification?.titleLocKey, undefined);
});

test("new content report copy carries localized parameters with the English fallback", async (t) => {
  const {inbox, sent} = personalSetup(t, "session-token");
  const payload = {
    ...notificationCopyPayload({
      kind: "newContentReport",
      contentType: "wall",
      reason: "spam",
      targetId: "wall-123",
    }),
    data: {route: "content_report"},
    modifier: "admin@example.com",
    channelId: "moderation",
  };
  await sendToUser(payload, {uid: "admin-uid", email: "admin@example.com"});

  assert.deepEqual(inbox[0].data.message, {
    kind: "newContentReport",
    args: {contentType: "wall", reason: "spam", targetId: "wall-123"},
  });
  assert.equal(
    (inbox[0].data.notification as Record<string, unknown>).body,
    "A new content report is ready for review.",
  );
  assert.equal(sent[0].data?.notification_copy_kind, "newContentReport");
});

test("sendNotification returns false when the push fails and true when none was asked for", async (t) => {
  t.mock.method(db, "collection", () => ({add: async () => undefined}));
  t.mock.method(admin.messaging(), "send", async () => {
    throw new Error("fcm down");
  });
  assert.equal(
    await sendNotification({...personal, fcmTarget: {topic: "x"}}),
    false,
  );
  assert.equal(await sendNotification(personal), true);
});

test("pushes carry no app icon badge", () => {
  const message = fcmMessage({...personal, fcmTarget: {topic: "x"}});
  assert.equal(message.apns?.payload?.aps.badge, undefined);
  assert.equal(message.apns?.payload?.aps.sound, "default");
});

test("session token wins over the legacy one", () => {
  assert.equal(pickFcmToken(" s ", "l"), "s");
  assert.equal(pickFcmToken("", "l"), "l");
});
