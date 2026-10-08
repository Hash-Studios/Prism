import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";

import {db} from "../common";
import {logger} from "firebase-functions/v2";
import type {ScheduledEvent} from "firebase-functions/v2/scheduler";
import {
  claimSyncSlot,
  reconcileSubscriptions,
  releaseSyncSlot,
  subscriptionFromRevenueCat,
  syncSubscription,
} from "../syncSubscription";

const NOW = Date.parse("2026-01-01T00:00:00.000Z");
type Doc = Record<string, unknown>;

function subscriberJson(
  entitlements: Record<string, {expires_date: string | null; grace_period_expires_date?: string | null}>,
): unknown {
  return {subscriber: {entitlements}};
}

test("subscriptionFromRevenueCat: a lifetime entitlement (null expiry) grants the lifetime tier", () => {
  const json = subscriberJson({prism_premium: {expires_date: null}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: true, subscriptionTier: "lifetime"});
});

test("subscriptionFromRevenueCat: an entitlement expiring in the future grants the pro tier", () => {
  const json = subscriberJson({prism_ultra: {expires_date: "2026-02-01T00:00:00.000Z"}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: true, subscriptionTier: "pro"});
});

test("subscriptionFromRevenueCat: an expired entitlement grants no premium", () => {
  const json = subscriberJson({prism_ultra: {expires_date: "2025-01-01T00:00:00.000Z"}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: false, subscriptionTier: "free"});
});

test("subscriptionFromRevenueCat: an unknown entitlement key is ignored", () => {
  const json = subscriberJson({some_other_entitlement: {expires_date: null}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: false, subscriptionTier: "free"});
});

test("subscriptionFromRevenueCat: no entitlements at all grants no premium", () => {
  assert.deepEqual(subscriptionFromRevenueCat({subscriber: {entitlements: {}}}, NOW), {premium: false, subscriptionTier: "free"});
});

test("syncSubscription: RevenueCat and Firestore failures do not consume the cooldown", async (t: TestContext) => {
  const store = new Map<string, Doc>([["usersv2/u", {premium: false, subscriptionTier: "free"}]]);
  const path = (collection: string, id: string) => `${collection}/${id}`;
  const time = {value: NOW};
  let failUserWrite = false;
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({
      path: path(name, id),
      get: async () => ({data: () => store.get(path(name, id))}),
      update: async (data: Doc) => store.set(path(name, id), {...store.get(path(name, id)), ...data}),
    }),
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    update: (ref: {path: string}, data: Doc) => {
      if (ref.path === "usersv2/u" && failUserWrite) {
        failUserWrite = false;
        throw new Error("user write failed");
      }
      store.set(ref.path, {...store.get(ref.path), ...data});
    },
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));
  t.mock.method(Date, "now", () => time.value);
  const originalKey = process.env.REVENUECAT_SECRET_KEY;
  process.env.REVENUECAT_SECRET_KEY = "test-token";
  t.after(() => {
    if (originalKey === undefined) delete process.env.REVENUECAT_SECRET_KEY;
    else process.env.REVENUECAT_SECRET_KEY = originalKey;
  });
  let fetches = 0;
  t.mock.method(globalThis, "fetch", async () => {
    fetches++;
    if (fetches === 1) return {ok: false, status: 503} as Response;
    return {
      ok: true,
      json: async () => ({subscriber: {entitlements: {prism_ultra: {expires_date: "2026-02-01T00:00:00.000Z"}}}}),
    } as Response;
  });
  const request = {auth: {uid: "u"}, data: {}} as never;

  await assert.rejects(() => syncSubscription.run(request), {code: "unavailable"});
  const result = await syncSubscription.run(request);

  assert.equal(fetches, 2);
  assert.deepEqual(result, {premium: true, subscriptionTier: "pro"});
  assert.deepEqual(store.get("usersv2/u"), {premium: true, subscriptionTier: "pro"});

  time.value = NOW + 30_000;
  failUserWrite = true;
  await assert.rejects(() => syncSubscription.run(request), /user write failed/);
  const retry = await syncSubscription.run(request);

  assert.equal(fetches, 4);
  assert.deepEqual(retry, {premium: true, subscriptionTier: "pro"});
});

test("releaseSyncSlot: a failed older request cannot release a newer slot", async (t: TestContext) => {
  const store = new Map<string, Doc>();
  const path = (collection: string, id: string) => `${collection}/${id}`;
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({path: path(name, id)}),
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));

  assert.equal(await claimSyncSlot("u", NOW), true);
  assert.equal(await claimSyncSlot("u", NOW + 30_000), true);
  await releaseSyncSlot("u", NOW);

  assert.equal(await claimSyncSlot("u", NOW + 59_999), false);
  assert.deepEqual(store.get("subscriptionSync/u"), {lastAt: NOW + 30_000});
});

test("syncSubscription: an older response cannot overwrite a newer subscription result", async (t: TestContext) => {
  const store = new Map<string, Doc>([["usersv2/u", {premium: false, subscriptionTier: "free"}]]);
  const path = (collection: string, id: string) => `${collection}/${id}`;
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({
      path: path(name, id),
      get: async () => ({data: () => store.get(path(name, id))}),
      update: async (data: Doc) => store.set(path(name, id), {...store.get(path(name, id)), ...data}),
    }),
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    update: (ref: {path: string}, data: Doc) => store.set(ref.path, {...store.get(ref.path), ...data}),
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));
  const time = {value: NOW};
  t.mock.method(Date, "now", () => time.value);
  const originalKey = process.env.REVENUECAT_SECRET_KEY;
  process.env.REVENUECAT_SECRET_KEY = "test-token";
  t.after(() => {
    if (originalKey === undefined) delete process.env.REVENUECAT_SECRET_KEY;
    else process.env.REVENUECAT_SECRET_KEY = originalKey;
  });
  let releaseFirstFetch: (response: Response) => void = () => undefined;
  let firstFetchStarted: () => void = () => undefined;
  const firstStarted = new Promise<void>((resolve) => {
    firstFetchStarted = resolve;
  });
  const firstFetch = new Promise<Response>((resolve) => {
    releaseFirstFetch = resolve;
  });
  let fetches = 0;
  t.mock.method(globalThis, "fetch", async () => {
    fetches++;
    if (fetches === 1) {
      firstFetchStarted();
      return firstFetch;
    }
    return {
      ok: true,
      json: async () => ({subscriber: {entitlements: {prism_ultra: {expires_date: "2026-02-01T00:00:00.000Z"}}}}),
    } as Response;
  });
  const request = {auth: {uid: "u"}, data: {}} as never;

  const olderRequest = syncSubscription.run(request);
  await firstStarted;
  time.value = NOW + 30_000;
  const newerResult = await syncSubscription.run(request);
  releaseFirstFetch({ok: true, json: async () => ({subscriber: {entitlements: {}}})} as Response);
  const olderResult = await olderRequest;

  assert.deepEqual(newerResult, {premium: true, subscriptionTier: "pro"});
  assert.deepEqual(olderResult, newerResult);
  assert.deepEqual(store.get("usersv2/u"), newerResult);
});

function syncHarness(t: TestContext, user: Doc) {
  const store = new Map<string, Doc>([["usersv2/u", user], ["subscriptionSync/u", {lastAt: NOW}]]);
  const path = (collection: string, id: string) => `${collection}/${id}`;
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({path: path(name, id), get: async () => ({data: () => store.get(path(name, id))})}),
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    update: (ref: {path: string}, data: Doc) => store.set(ref.path, {...store.get(ref.path), ...data}),
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));
  t.mock.method(Date, "now", () => NOW + 5_000);
  const originalKey = process.env.REVENUECAT_SECRET_KEY;
  process.env.REVENUECAT_SECRET_KEY = "test-token";
  t.after(() => {
    if (originalKey === undefined) delete process.env.REVENUECAT_SECRET_KEY;
    else process.env.REVENUECAT_SECRET_KEY = originalKey;
  });
  const fetchMock = t.mock.method(globalThis, "fetch", async () => ({
    ok: true,
    json: async () => ({subscriber: {entitlements: {prism_ultra: {expires_date: "2026-02-01T00:00:00.000Z"}}}}),
  }) as Response);
  return {store, fetchMock};
}

test("syncSubscription: a stored-Free user inside the cooldown still gets a fresh RevenueCat result", async (t: TestContext) => {
  const {store, fetchMock} = syncHarness(t, {premium: false, subscriptionTier: "free"});

  const result = await syncSubscription.run({auth: {uid: "u"}, data: {}} as never);

  assert.equal(fetchMock.mock.callCount(), 1);
  assert.deepEqual(result, {premium: true, subscriptionTier: "pro"});
  assert.deepEqual(store.get("usersv2/u"), {premium: true, subscriptionTier: "pro"});
});

test("syncSubscription: a stored-premium user inside the cooldown gets the cached result without RevenueCat", async (t: TestContext) => {
  const {fetchMock} = syncHarness(t, {premium: true, subscriptionTier: "lifetime"});

  const result = await syncSubscription.run({auth: {uid: "u"}, data: {}} as never);

  assert.equal(fetchMock.mock.callCount(), 0);
  assert.deepEqual(result, {premium: true, subscriptionTier: "lifetime"});
});

test("subscriptionFromRevenueCat: a billing grace period that has not ended keeps premium", () => {
  const json = subscriberJson({prism_ultra: {
    expires_date: "2025-12-30T00:00:00.000Z", grace_period_expires_date: "2026-01-03T00:00:00.000Z",
  }});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: true, subscriptionTier: "pro"});
});

test("subscriptionFromRevenueCat: a grace period that has ended, or none, grants no premium", () => {
  const ended = subscriberJson({prism_ultra: {
    expires_date: "2025-12-20T00:00:00.000Z", grace_period_expires_date: "2025-12-25T00:00:00.000Z",
  }});
  assert.deepEqual(subscriptionFromRevenueCat(ended, NOW), {premium: false, subscriptionTier: "free"});
  const none = subscriberJson({prism_ultra: {expires_date: "2025-12-20T00:00:00.000Z", grace_period_expires_date: null}});
  assert.deepEqual(subscriptionFromRevenueCat(none, NOW), {premium: false, subscriptionTier: "free"});
});

test("claimSyncSlot: a stored-Free bypass still waits 5 seconds, and exactly 5 seconds passes", async (t: TestContext) => {
  const store = new Map<string, Doc>([["subscriptionSync/u", {lastAt: NOW}]]);
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({path: `${name}/${id}`}),
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
  }));
  assert.equal(await claimSyncSlot("u", NOW + 1_000, true), false);
  assert.equal(await claimSyncSlot("u", NOW + 4_999, true), false);
  assert.equal(await claimSyncSlot("u", NOW + 5_000, true), true);
  assert.equal(await claimSyncSlot("u", NOW + 5_000 + 29_999, false), false);
});

test("syncSubscription: a stored-Free user 1 second after the last sync gets the stored result without RevenueCat", async (t: TestContext) => {
  const {fetchMock} = syncHarness(t, {premium: false, subscriptionTier: "free"});
  t.mock.method(Date, "now", () => NOW + 1_000);

  const result = await syncSubscription.run({auth: {uid: "u"}, data: {}} as never);

  assert.equal(fetchMock.mock.callCount(), 0);
  assert.deepEqual(result, {premium: false, subscriptionTier: "free"});
});

test("syncSubscription: a RevenueCat 404 is unavailable and leaves the stored state alone", async (t: TestContext) => {
  const {store, fetchMock} = syncHarness(t, {premium: false, subscriptionTier: "free"});
  fetchMock.mock.mockImplementation(async () => ({ok: false, status: 404}) as Response);

  await assert.rejects(() => syncSubscription.run({auth: {uid: "u"}, data: {}} as never), {code: "unavailable"});

  assert.deepEqual(store.get("usersv2/u"), {premium: false, subscriptionTier: "free"});
  assert.equal(store.has("subscriptionSync/u"), false);
});

test("syncSubscription: a missing user doc fails and releases the slot", async (t: TestContext) => {
  const {store} = syncHarness(t, {premium: false, subscriptionTier: "free"});
  store.delete("usersv2/u");
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    update: (ref: {path: string}) => {
      if (!store.has(ref.path)) throw new Error("NOT_FOUND");
    },
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));

  await assert.rejects(() => syncSubscription.run({auth: {uid: "u"}, data: {}} as never), /NOT_FOUND/);

  assert.equal(store.has("subscriptionSync/u"), false);
});

type EntitlementJson = Record<string, {expires_date: string | null}>;

/** In-memory usersv2 and subscriptionSync with a paged `where("premium", "==", true)` query. */
function reconcileHarness(t: TestContext, users: Record<string, Doc>, entitlements: Record<string, EntitlementJson | number>) {
  const store = new Map<string, Doc>(Object.entries(users).map(([id, doc]) => [`usersv2/${id}`, doc]));
  const path = (collection: string, id: string) => `${collection}/${id}`;
  const pageSizes: number[] = [];
  const premiumDocs = () => [...store].filter(([p, d]) => p.startsWith("usersv2/") && d.premium === true)
    .map(([p]) => ({id: p.slice("usersv2/".length)})).sort((a, b) => a.id.localeCompare(b.id));
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({path: path(name, id), get: async () => ({data: () => store.get(path(name, id))})}),
    where: () => {
      let after: string | undefined;
      let size = Number.POSITIVE_INFINITY;
      const query = {
        limit: (n: number) => {
          size = n;
          return query;
        },
        startAfter: (cursor: {id: string}) => {
          after = cursor.id;
          return query;
        },
        get: async () => {
          const docs = premiumDocs().filter((d) => after === undefined || d.id > after).slice(0, size);
          pageSizes.push(docs.length);
          return {docs, size: docs.length};
        },
      };
      return query;
    },
  }) as unknown as ReturnType<typeof db.collection>);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => callback({
    get: async (ref: {path: string}) => ({data: () => store.get(ref.path)}),
    set: (ref: {path: string}, data: Doc) => store.set(ref.path, data),
    update: (ref: {path: string}, data: Doc) => store.set(ref.path, {...store.get(ref.path), ...data}),
    delete: (ref: {path: string}) => store.delete(ref.path),
  }));
  const originalKey = process.env.REVENUECAT_SECRET_KEY;
  process.env.REVENUECAT_SECRET_KEY = "test-token";
  t.after(() => {
    if (originalKey === undefined) delete process.env.REVENUECAT_SECRET_KEY;
    else process.env.REVENUECAT_SECRET_KEY = originalKey;
  });
  const asked: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string) => {
    const id = decodeURIComponent(url.split("/").pop() ?? "");
    asked.push(id);
    const answer = entitlements[id];
    if (typeof answer === "number") return {ok: false, status: answer} as Response;
    return {ok: true, json: async () => ({subscriber: {entitlements: answer ?? {}}})} as Response;
  });
  return {store, asked, pageSizes};
}

const runReconcile = () => reconcileSubscriptions.run({
  jobName: "reconcile-test", scheduleTime: new Date(NOW).toISOString(),
} satisfies ScheduledEvent);

test("reconcileSubscriptions: an expired entitlement flips premium off and a lifetime one stays", async (t: TestContext) => {
  const {store, asked} = reconcileHarness(t, {
    expired: {premium: true, subscriptionTier: "pro"},
    lifetime: {premium: true, subscriptionTier: "lifetime"},
    renewed: {premium: true, subscriptionTier: "lifetime"},
    free: {premium: false, subscriptionTier: "free"},
  }, {
    expired: {prism_ultra: {expires_date: "2025-01-01T00:00:00.000Z"}},
    lifetime: {prism_premium: {expires_date: null}},
    renewed: {prism_ultra: {expires_date: "2099-01-01T00:00:00.000Z"}},
    free: {prism_ultra: {expires_date: null}},
  });
  t.mock.method(Date, "now", () => NOW);

  await runReconcile();

  assert.deepEqual(store.get("usersv2/expired"), {premium: false, subscriptionTier: "free"});
  assert.deepEqual(store.get("usersv2/lifetime"), {premium: true, subscriptionTier: "lifetime"});
  assert.deepEqual(store.get("usersv2/renewed"), {premium: true, subscriptionTier: "pro"});
  assert.deepEqual(store.get("usersv2/free"), {premium: false, subscriptionTier: "free"});
  assert.ok(!asked.includes("free"));
});

test("reconcileSubscriptions: a user turned Free during the run is never granted premium", async (t: TestContext) => {
  const {store} = reconcileHarness(t, {
    racer: {premium: true, subscriptionTier: "pro"},
  }, {racer: {prism_ultra: {expires_date: null}}});
  t.mock.method(Date, "now", () => NOW);
  const innerFetch = globalThis.fetch;
  t.mock.method(globalThis, "fetch", async (url: string) => {
    store.set("usersv2/racer", {premium: false, subscriptionTier: "free"});
    return innerFetch(url);
  });

  await runReconcile();

  assert.deepEqual(store.get("usersv2/racer"), {premium: false, subscriptionTier: "free"});
});

test("reconcileSubscriptions: a RevenueCat error leaves the user premium and the run continues", async (t: TestContext) => {
  const {store} = reconcileHarness(t, {
    a: {premium: true, subscriptionTier: "pro"},
    b: {premium: true, subscriptionTier: "pro"},
  }, {a: 503, b: {prism_ultra: {expires_date: "2025-01-01T00:00:00.000Z"}}});
  t.mock.method(Date, "now", () => NOW);
  t.mock.method(logger, "error", () => undefined);

  await runReconcile();

  assert.deepEqual(store.get("usersv2/a"), {premium: true, subscriptionTier: "pro"});
  assert.deepEqual(store.get("usersv2/b"), {premium: false, subscriptionTier: "free"});
});

test("reconcileSubscriptions: pages by 200 and checks every premium user once", async (t: TestContext) => {
  const users: Record<string, Doc> = {};
  const entitlements: Record<string, EntitlementJson> = {};
  for (let i = 0; i < 205; i++) {
    const id = `u${String(i).padStart(3, "0")}`;
    users[id] = {premium: true, subscriptionTier: "pro"};
    entitlements[id] = {prism_ultra: {expires_date: "2099-01-01T00:00:00.000Z"}};
  }
  const {asked, pageSizes} = reconcileHarness(t, users, entitlements);
  t.mock.method(Date, "now", () => NOW);

  await runReconcile();

  assert.deepEqual(pageSizes, [200, 5]);
  assert.equal(asked.length, 205);
  assert.equal(new Set(asked).size, 205);
});
