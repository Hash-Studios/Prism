import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";

import {db} from "../common";
import {claimSyncSlot, releaseSyncSlot, subscriptionFromRevenueCat, syncSubscription} from "../syncSubscription";

const NOW = Date.parse("2026-01-01T00:00:00.000Z");
type Doc = Record<string, unknown>;

function subscriberJson(entitlements: Record<string, {expires_date: string | null}>): unknown {
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
