import test from "node:test";
import assert from "node:assert/strict";
import {generateKeyPairSync, sign} from "node:crypto";
import {db} from "../common";
import {admobRewardedSsv, beginRewardedSession, getRewardedSession, settleVerifiedReward, rewardedConfig} from "../rewardedAds";
import {GoogleSsvVerifier, SsvInvalid, SsvUnavailable} from "../admobSsv";
import {awardCoins, legacyRewardedAdsAllowed} from "../coinsCallables";
import {installFakeDb} from "./fakeDb";

const UNIT = "ca-app-pub-1234567890123456/1234567890";
const NOW = Date.UTC(2026, 9, 30, 12);
type Store = Map<string, Record<string, any>>;
function harness(t: test.TestContext, observed?: {reads: number; writes: number; outsideReads: number; outsideWrites: number}) {
  const store: Store = installFakeDb(t, {"usersv2/u": {coins: 0}}, observed);
  let now = NOW;
  t.mock.method(Date, "now", () => now);
  for (const [key, value] of Object.entries({REWARDED_AD_ENABLED: "true", REWARDED_AD_ANDROID_UNIT_ID: UNIT,
    REWARDED_AD_IOS_UNIT_ID: UNIT, REWARDED_AD_GOOGLE_REWARD_TYPE: "coins", REWARDED_AD_GOOGLE_REWARD_AMOUNT: "1"})) {
    const old = process.env[key]; process.env[key] = value;
    t.after(() => {
      if (old === undefined) delete process.env[key]; else process.env[key] = old;
    });
  }
  return {store, advance: (ms: number) => {
    now += ms;
  }};
}
const begin = (requestId = "request_001", extra = {}) => beginRewardedSession.run({auth: {uid: "u"},
  data: {requestId, placement: "coins.watch_ad", platform: "android", ...extra}} as any) as Promise<any>;
const get = (data: object, uid = "u") => getRewardedSession.run({auth: {uid}, data} as any) as Promise<any>;
function callback(reservation: any, extra: Record<string, string> = {}) {
  return new URLSearchParams({ad_network: "123", ad_unit: UNIT.split("/")[1], custom_data: reservation.customData, reward_amount: "1",
    reward_item: "coins", timestamp: String(NOW), transaction_id: "google_001", user_id: "u", ...extra});
}

test("reservations serialize concurrent calls, persist replay, reserve first bonus and release only show lock", async (t) => {
  const h = harness(t);
  const [first, blocked] = await Promise.all([begin(), begin("request_002")]);
  assert.equal(first.rewardCoins, 20);
  assert.equal(first.adsRemaining, 19);
  assert.equal(blocked.reason, "active_session");
  assert.deepEqual(await begin(), first);
  assert.equal(h.store.get("usersv2/u")!.coins, 0);
  h.advance(600_001);
  const second = await begin("request_002");
  assert.equal(second.rewardCoins, 10);
  assert.equal(second.adsRemaining, 18);
  assert.equal((await get({requestId: "request_001"})).status, "reserved");
  h.advance(86_400_000);
  assert.equal((await get({sessionId: first.sessionId})).status, "expired");
  assert.deepEqual(await begin(), first);
});

test("cap includes pending sessions; midnight uses separate capacity and bonus", async (t) => {
  const h = harness(t);
  h.store.set("coinAdRateDaily/u_2026-10-30", {count: 19});
  const last = await begin();
  assert.equal(last.rewardCoins, 10);
  h.advance(600_001);
  assert.equal((await begin("request_002")).reason, "daily_limit");
  h.advance(12 * 3_600_000);
  const next = await begin("request_003");
  assert.equal(next.rewardCoins, 20);
  assert.equal(next.adsRemaining, 19);
});

test("verified settlement atomically credits ledger, ad count, quest, and deduplicates session and Google ID", async (t) => {
  const h = harness(t);
  const first = await begin();
  await settleVerifiedReward(callback(first));
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
  assert.equal(h.store.get("coinAdRateDaily/u_2026-10-30")!.count, 1);
  assert.deepEqual(h.store.get("coinAdRateDaily/u_2026-10-30")!.reservations, {});
  assert.equal(h.store.get("usersv2/u/private/economy")!.rev, 1);
  assert.ok(h.store.get("usersv2/u/private/economy")!.quests);
  assert.equal(h.store.get("usersv2/u/private/economy")!.quests.bonus.progress, 1);
  assert.equal(h.store.get("usersv2/u/private/economy")!.quests.bonus.claimed, true);
  assert.equal([...h.store.keys()].filter((key) => key.startsWith("coinTransactions/")).length, 1);
  const result = await get({sessionId: first.sessionId});
  assert.equal(result.status, "settled"); assert.equal(result.currentBalance, 20);
  await assert.rejects(settleVerifiedReward(callback(first, {transaction_id: "other"})), SsvInvalid);
  h.advance(600_001);
  const second = await begin("request_002");
  await assert.rejects(settleVerifiedReward(callback(second, {timestamp: String(NOW + 600_001)})), SsvInvalid);
});

test("HTTP verifies probes before acknowledging them without writes or consuming a transaction ID", async (t) => {
  const observed = {reads: 0, writes: 0, outsideReads: 0, outsideWrites: 0};
  const h = harness(t, observed);
  const first = await begin();
  const before = structuredClone(h.store);
  const ioBefore = {...observed};
  const pair = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  const verifier = new GoogleSsvVerifier((async () => new Response(JSON.stringify({keys: [
    {keyId: 1, pem: pair.publicKey.export({type: "spki", format: "pem"})},
  ]}))) as typeof fetch);
  // Keep real signature verification; replace only its Google key source with a local test key.
  t.mock.method(GoogleSsvVerifier.prototype, "verify", verifier.verify.bind(verifier));
  const signed = (raw: string) =>
    `${raw}&signature=${sign("sha256", Buffer.from(raw), pair.privateKey).toString("base64url")}&key_id=1`;
  const request = async (raw: string, method = "GET") => {
    const result = {status: 0, body: ""};
    const response = {
      status(code: number) {
        result.status = code; return this;
      },
      send(body: string) {
        result.body = body; return this;
      },
    };
    await admobRewardedSsv({method, originalUrl: `/admobRewardedSsv?${raw}`, headers: {}} as
      Parameters<typeof admobRewardedSsv>[0], response as unknown as Parameters<typeof admobRewardedSsv>[1]);
    return result;
  };
  // The exact fields of the console probe seen in production on 2026-10-31.
  const probe = {ad_network: "5450213213286189855", ad_unit: "1234567890", reward_amount: "10",
    reward_item: "download_coins", timestamp: String(NOW), transaction_id: "123456789"};
  const raw = new URLSearchParams(probe).toString();
  for (const invalid of [raw, signed(raw).replace("reward_amount=10", "reward_amount=20"),
    signed(`${raw}&user_id=u`).replace("&user_id=u", ""), signed(`${raw}&ad_unit=other`),
    signed(`${raw}&%75ser_id=&%63ustom_data=`)]) {
    assert.deepEqual(await request(invalid), {status: 400, body: "Invalid callback"});
    assert.deepEqual(h.store, before);
  }
  assert.deepEqual(await request(signed(raw), "POST"), {status: 405, body: "GET required"});
  // Replaying even an old signed probe remains a no-op and reveals no session state.
  for (const timestamp of [String(NOW), String(NOW), "1"]) {
    assert.deepEqual(await request(signed(new URLSearchParams({...probe, timestamp}).toString())), {status: 200, body: "OK"});
    assert.deepEqual(h.store, before);
  }
  const invalidFields: Record<string, string>[] = [{user_id: "u"}, {custom_data: first.customData},
    {user_id: ""}, {custom_data: ""}, {user_id: "", custom_data: ""}, {user_id: "u", custom_data: ""},
    {user_id: "", custom_data: first.customData}];
  for (const fields of invalidFields) {
    assert.deepEqual(await request(signed(new URLSearchParams({...probe, ...fields}).toString())),
      {status: 400, body: "Invalid callback"});
    assert.deepEqual(h.store, before);
  }
  assert.deepEqual(observed, ioBefore);
  const earned = signed(callback(first, {transaction_id: probe.transaction_id}).toString());
  assert.deepEqual(await request(earned), {status: 200, body: "OK"});
  assert.equal(h.store.get("usersv2/u")?.coins, 20);
  assert.equal(h.store.get(`rewardedAdSessions/${first.sessionId}`)?.status, "settled");
  assert.equal([...h.store.keys()].filter((key) => key.startsWith("rewardedAdGoogleTransactions/")).length, 1);
  const settled = new Map(h.store);
  assert.deepEqual(await request(signed(raw)), {status: 200, body: "OK"});
  assert.deepEqual(await request(earned), {status: 200, body: "OK"});
  assert.deepEqual(h.store, settled);
});

test("legacy awards respect pending capacity and first bonus, and the cutoff rejects the actual callable", async (t) => {
  const h = harness(t);
  await begin();
  h.advance(21_000);
  const old = process.env.REWARDED_AD_LEGACY_UNTIL;
  delete process.env.REWARDED_AD_LEGACY_UNTIL;
  t.after(() => {
    if (old === undefined) delete process.env.REWARDED_AD_LEGACY_UNTIL; else process.env.REWARDED_AD_LEGACY_UNTIL = old;
  });
  const request = {auth: {uid: "u"}, data: {action: "rewardedAd", sourceTag: "test"}} as unknown as Parameters<typeof awardCoins.run>[0];
  const legacy = await awardCoins.run(request);
  assert.equal(legacy.delta, 10);
  assert.equal(legacy.adsRemaining, 18);
  assert.equal(Object.keys(h.store.get("coinAdRateDaily/u_2026-10-30")!.reservations).length, 1);
  process.env.REWARDED_AD_LEGACY_UNTIL = new Date(NOW).toISOString();
  await assert.rejects(awardCoins.run(request), {code: "failed-precondition"});
});

test("settlement releases its display lock and preserves the short cooldown", async (t) => {
  const h = harness(t);
  const first = await begin();
  h.advance(30_000);
  await settleVerifiedReward(callback(first));
  assert.equal((await begin("request_002")).reason, "cooldown");
  h.advance(20_001);
  assert.equal((await begin("request_002")).status, "reserved");
});

test("accepted rewards survive disabled or rotated configuration", async (t) => {
  const h = harness(t);
  const first = await begin();
  process.env.REWARDED_AD_ENABLED = "false";
  process.env.REWARDED_AD_ANDROID_UNIT_ID = "ca-app-pub-1234567890123456/9999999999";
  process.env.REWARDED_AD_GOOGLE_REWARD_AMOUNT = "2";
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
});

test("late prior-day settlement preserves today's count and a newer session lock", async (t) => {
  const h = harness(t);
  const first = await begin();
  h.advance(12 * 3_600_000);
  h.store.set("usersv2/u", {coins: 10, coinState: {adsToday: {day: "2026-10-31", count: 1}}});
  const second = await begin("request_002");
  await settleVerifiedReward(callback(first));
  assert.deepEqual(h.store.get("usersv2/u")!.coinState.adsToday, {day: "2026-10-31", count: 1});
  assert.equal((await begin("request_003")).reason, "active_session");
  assert.equal(h.store.get("rewardedAdUsers/u")!.sessionId, second.sessionId);
});

test("a transaction failure cannot partially settle; retry credits once", async (t) => {
  const h = harness(t);
  const first = await begin();
  const original = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (body: (tx: any) => Promise<unknown>) => original(async (tx) => {
    const result = await body(tx);
    if (fail) throw new Error("commit aborted");
    return result;
  }));
  await assert.rejects(settleVerifiedReward(callback(first)), /commit aborted/);
  assert.equal(h.store.get("usersv2/u")!.coins, 0);
  assert.equal(h.store.get(`rewardedAdSessions/${first.sessionId}`)!.status, "reserved");
  assert.equal([...h.store.keys()].filter((key) => key.startsWith("coinTransactions/")).length, 0);
  fail = false;
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
});

test("ownership, deleted profile, and deletion barrier never resurrect balances", async (t) => {
  const h = harness(t);
  const first = await begin();
  h.store.set("usersv2/other", {coins: 0});
  await assert.rejects(get({sessionId: first.sessionId}, "other"), {code: "not-found"});
  h.store.set("creatorDeletionState/u", {closed: true});
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 0);
  await assert.rejects(begin("request_002"), {code: "not-found"});
  h.store.delete("creatorDeletionState/u"); h.store.set("usersv2/u", {deleted: true, coins: 0});
  await settleVerifiedReward(callback(first));
  h.store.delete("usersv2/u");
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.has("usersv2/u"), false);
});

test("callback validates metadata, earning window and grace; delayed valid delivery settles", async (t) => {
  const h = harness(t);
  const first = await begin();
  const invalid: Record<string, string>[] = [{reward_amount: "20"}, {reward_item: "other"}, {ad_unit: "test"}, {user_id: "other"},
    {timestamp: String(NOW - 1)}, {timestamp: String(NOW + 600_001)}, {custom_data: first.customData + "x"}];
  for (const extra of invalid) {
    await assert.rejects(settleVerifiedReward(callback(first, extra)), SsvInvalid);
  }
  h.advance(86_400_000);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
  const second = await begin("request_002");
  h.advance(87_000_001);
  await assert.rejects(settleVerifiedReward(callback(second, {timestamp: String(NOW + 86_400_000), transaction_id: "google_002"})), SsvInvalid);
});

test("configuration fails closed and explicit legacy cutoff preserves default compatibility", async (t) => {
  harness(t);
  for (const extra of [{placement: "bad space"}, {placement: "a".repeat(121)}, {platform: "web"}, {amount: 100}]) {
    await assert.rejects(begin("request_001", extra), {code: "invalid-argument"});
  }
  process.env.REWARDED_AD_ANDROID_UNIT_ID = "ca-app-pub-3940256099942544/5224354917";
  assert.equal(rewardedConfig().enabled, false);
  assert.equal((await begin()).reason, "disabled");
  const old = process.env.REWARDED_AD_LEGACY_UNTIL;
  t.after(() => {
    if (old === undefined) delete process.env.REWARDED_AD_LEGACY_UNTIL; else process.env.REWARDED_AD_LEGACY_UNTIL = old;
  });
  delete process.env.REWARDED_AD_LEGACY_UNTIL;
  assert.equal(legacyRewardedAdsAllowed(NOW), true);
  process.env.REWARDED_AD_LEGACY_UNTIL = new Date(NOW).toISOString();
  assert.equal(legacyRewardedAdsAllowed(NOW), false);
  process.env.REWARDED_AD_LEGACY_UNTIL = "invalid";
  assert.equal(legacyRewardedAdsAllowed(NOW), false);
});

test("Google ECDSA verifies exact raw bytes, rejects suffix/duplicate/tampering, caches and rotates keys", async (t) => {
  let now = NOW; t.mock.method(Date, "now", () => now);
  const one = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  const two = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  let calls = 0; let outage = false;
  const verifier = new GoogleSsvVerifier((async (url: string) => {
    assert.equal(url, "https://www.gstatic.com/admob/reward/verifier-keys.json"); calls++;
    if (outage) throw new Error("offline");
    const pair = calls === 1 ? one : two;
    return new Response(JSON.stringify({keys: [{keyId: calls === 1 ? 1 : 2, pem: pair.publicKey.export({type: "spki", format: "pem"})}]}));
  }) as typeof fetch);
  const signed = (raw: string, key = one.privateKey, id = 1) => `${raw}&signature=${sign("sha256", Buffer.from(raw), key).toString("base64url")}&key_id=${id}`;
  const fixture = signed("ad_unit=unit&custom_data=a%20b");
  assert.equal((await verifier.verify(fixture)).get("custom_data"), "a b");
  await verifier.verify(fixture); assert.equal(calls, 1);
  await assert.rejects(verifier.verify(fixture.replace("%20", "+")), SsvInvalid);
  await assert.rejects(verifier.verify(fixture + "&extra=1"), SsvInvalid);
  await assert.rejects(verifier.verify(signed("ad_unit=x&ad_unit=y")), SsvInvalid);
  await assert.rejects(verifier.verify(signed("ad_unit=x&custom_data=%GG")), SsvInvalid);
  await assert.rejects(verifier.verify(signed("ad_unit=x", two.privateKey)), SsvInvalid);
  await verifier.verify(signed("ad_unit=x", two.privateKey, 2)); assert.equal(calls, 2);
  now += 3_600_001; outage = true;
  await assert.rejects(verifier.verify(signed("ad_unit=x", two.privateKey, 2)), SsvUnavailable);
});

test("unknown-key outages remain retryable and concurrent refreshes share one fetch", async (t) => {
  let now = NOW;
  t.mock.method(Date, "now", () => now);
  const one = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  const two = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  let calls = 0;
  let outage = false;
  const verifier = new GoogleSsvVerifier((async () => {
    calls++;
    await Promise.resolve();
    if (outage) throw new Error("offline");
    const keyId = calls === 1 ? 1 : 2;
    const pair = keyId === 1 ? one : two;
    return new Response(JSON.stringify({keys: [{keyId, pem: pair.publicKey.export({type: "spki", format: "pem"})}]}));
  }) as typeof fetch);
  const query = (pair: typeof one, id: number) =>
    `ad_unit=x&signature=${sign("sha256", Buffer.from("ad_unit=x"), pair.privateKey).toString("base64url")}&key_id=${id}`;
  await Promise.all([verifier.verify(query(one, 1)), verifier.verify(query(one, 1))]);
  assert.equal(calls, 1);
  outage = true;
  await assert.rejects(verifier.verify(query(two, 2)), SsvUnavailable);
  outage = false;
  await assert.rejects(verifier.verify(query(two, 2)), SsvUnavailable);
  assert.equal(calls, 2);
  now += 30_001;
  assert.equal((await verifier.verify(query(two, 2))).get("ad_unit"), "x");
  assert.equal(calls, 3);
});
