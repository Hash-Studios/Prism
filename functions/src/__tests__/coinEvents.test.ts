import test from "node:test";
import assert from "node:assert/strict";
import {type CoinEvent, liveCoinEvent, parseCoinEvents, type WeeklyCoinEvent} from "../coinEvents";
import {resetEconomyCache} from "../economy";
import {awardCoins} from "../coinsCallables";
import {beginRewardedSession, settleVerifiedReward} from "../rewardedAds";
import {installFakeDb} from "./fakeDb";

const UNIT = "ca-app-pub-1234567890123456/1234567890";
const NOW = Date.UTC(2026, 9, 30, 12);
const DAY_MS = 86_400_000;
type Store = Map<string, Record<string, any>>;
function harness(t: test.TestContext) {
  const store: Store = installFakeDb(t, {"usersv2/u": {coins: 0}});
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
function callback(reservation: any, extra: Record<string, string> = {}) {
  return new URLSearchParams({ad_network: "123", ad_unit: UNIT.split("/")[1], custom_data: reservation.customData, reward_amount: "1",
    reward_item: "coins", timestamp: String(NOW), transaction_id: "google_001", user_id: "u", ...extra});
}
const launch = (over: Partial<CoinEvent> = {}): CoinEvent => ({id: "launch", startsAtMs: NOW, endsAtMs: NOW + 3_600_000,
  multiplier: 2, actions: ["rewardedAd"], label: "event", ...over});
const LAUNCH_RECEIPT = {id: "launch", multiplier: 2, label: "event"};

test("parseCoinEvents keeps the valid event and drops each bad one", () => {
  const bad = [
    {...launch(), id: "bad_mult_1", multiplier: 1},
    {...launch(), id: "bad_mult_4", multiplier: 4},
    {...launch(), id: "bad_mult_half", multiplier: 2.5},
    {...launch(), id: "bad_actions_empty", actions: []},
    {...launch(), id: "bad_actions_spend", actions: ["spend"]},
    {...launch(), id: "bad_actions_mixed", actions: ["rewardedAd", "quest"]},
    {...launch(), id: "bad_end_equal", endsAtMs: NOW},
    {...launch(), id: "bad_too_long", endsAtMs: NOW + 31 * DAY_MS + 1},
    {...launch(), id: "Bad Id"},
    {...launch(), id: "bad_label", label: "party"},
  ];
  const {label: _unused, ...withoutLabel} = launch({id: "nolabel"});
  const result = parseCoinEvents({events: [launch(), ...bad, withoutLabel]});
  assert.deepEqual(result.events.map((e) => e.id), ["launch", "nolabel"]);
  assert.deepEqual(result.events[0], launch());
  assert.equal(result.events[1].label, "event");
});

test("parseCoinEvents ignores a non-list events and checks weekly bounds", () => {
  assert.deepEqual(parseCoinEvents({events: "launch"}).events, []);
  const weekend = {id: "weekend", startDay: 6, startMinute: 0, durationMinutes: 2880, multiplier: 2,
    actions: ["rewardedAd"], label: "weekend"};
  assert.deepEqual(parseCoinEvents({weeklyEvent: weekend}).weeklyEvent, weekend);
  for (const bounds of [{startDay: 0}, {startDay: 8}, {durationMinutes: 0}, {durationMinutes: 10080}]) {
    assert.equal(parseCoinEvents({weeklyEvent: {...weekend, ...bounds}}).weeklyEvent, null);
  }
});

test("liveCoinEvent is start-inclusive and end-exclusive for one-off events", () => {
  const S = NOW;
  const E = NOW + 3_600_000;
  const events = {events: [launch({startsAtMs: S, endsAtMs: E})], weeklyEvent: null};
  assert.deepEqual(liveCoinEvent(events, "rewardedAd", S), {id: "launch", multiplier: 2, label: "event", startsAtMs: S, endsAtMs: E});
  assert.notEqual(liveCoinEvent(events, "rewardedAd", E - 1), null);
  assert.equal(liveCoinEvent(events, "rewardedAd", S - 1), null);
  assert.equal(liveCoinEvent(events, "rewardedAd", E), null);
});

test("weekly Saturday event is live for its 48 hours in UTC", () => {
  const weekend: WeeklyCoinEvent = {id: "weekend", startDay: 6, startMinute: 0, durationMinutes: 2880, multiplier: 2,
    actions: ["rewardedAd"], label: "weekend"};
  const events = {events: [], weeklyEvent: weekend};
  assert.equal(liveCoinEvent(events, "rewardedAd", Date.UTC(2026, 10, 14, 0, 0))?.id, "weekend-2026-11-14");
  assert.equal(liveCoinEvent(events, "rewardedAd", Date.UTC(2026, 10, 15, 23, 59, 59, 999))?.id, "weekend-2026-11-14");
  assert.equal(liveCoinEvent(events, "rewardedAd", Date.UTC(2026, 10, 16, 0, 0)), null);
  assert.equal(liveCoinEvent(events, "rewardedAd", Date.UTC(2026, 10, 13, 23, 59, 59, 999)), null);
});

test("overlapping events pay the highest multiplier", () => {
  const events = {events: [launch({id: "double"}), launch({id: "triple", multiplier: 3})], weeklyEvent: null};
  assert.equal(liveCoinEvent(events, "rewardedAd", NOW)?.multiplier, 3);
  assert.equal(liveCoinEvent(events, "rewardedAd", NOW)?.id, "triple");
});

test("SSV inside the window quotes 2x, records coinEvent, and pays once", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch()]});
  const first = await begin();
  assert.equal(first.rewardCoins, 40);
  assert.deepEqual(first.coinEvent, LAUNCH_RECEIPT);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 40);
  const tx = h.store.get(`coinTransactions/ssv_${first.sessionId}`)!;
  assert.equal(tx.delta, 40);
  assert.deepEqual(tx.coinEvent, LAUNCH_RECEIPT);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 40);
});

test("SSV with an event ending at now pays base with no coinEvent", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch({endsAtMs: NOW})]});
  const first = await begin();
  assert.equal(first.rewardCoins, 20);
  assert.equal(first.coinEvent, undefined);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
  assert.equal(h.store.get(`coinTransactions/ssv_${first.sessionId}`)!.coinEvent, undefined);
});

test("SSV with an event starting one ms later pays base with no coinEvent", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch({startsAtMs: NOW + 1})]});
  const first = await begin();
  assert.equal(first.rewardCoins, 20);
  assert.equal(first.coinEvent, undefined);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
  assert.equal(h.store.get(`coinTransactions/ssv_${first.sessionId}`)!.coinEvent, undefined);
});

test("SSV with an invalid multiplier pays base with no coinEvent", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch({multiplier: 5 as any})]});
  const first = await begin();
  assert.equal(first.rewardCoins, 20);
  assert.equal(first.coinEvent, undefined);
});

test("the quoted SSV award is kept after the event ends", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch({endsAtMs: NOW + 1})]});
  const first = await begin();
  assert.equal(first.rewardCoins, 40);
  h.advance(1_000);
  await settleVerifiedReward(callback(first));
  assert.equal(h.store.get("usersv2/u")!.coins, 40);
  assert.equal(h.store.get(`coinTransactions/ssv_${first.sessionId}`)!.delta, 40);
});

test("the daily cap is unchanged by the event", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  h.store.set("economyConfig/current", {events: [launch()]});
  h.store.set("coinAdRateDaily/u_2026-10-30", {count: 19});
  const last = await begin();
  assert.equal(last.rewardCoins, 20);
  assert.equal(last.adsRemaining, 0);
  h.advance(600_001);
  assert.equal((await begin("request_002")).reason, "daily_limit");
});

test("legacy awardCoins doubles inside the window and replays the same award", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  const old = process.env.REWARDED_AD_LEGACY_UNTIL;
  delete process.env.REWARDED_AD_LEGACY_UNTIL;
  t.after(() => {
    if (old === undefined) delete process.env.REWARDED_AD_LEGACY_UNTIL; else process.env.REWARDED_AD_LEGACY_UNTIL = old;
  });
  h.store.set("economyConfig/current", {events: [launch()]});
  const request = {auth: {uid: "u"}, data: {action: "rewardedAd", sourceTag: "test", requestId: "legacy_request_1"}} as
    unknown as Parameters<typeof awardCoins.run>[0];
  const first = await awardCoins.run(request);
  const replay = await awardCoins.run(request);
  assert.equal(first.delta, 40);
  assert.deepEqual(first.coinEvent, LAUNCH_RECEIPT);
  assert.equal(replay.delta, 40);
  assert.deepEqual(replay.coinEvent, LAUNCH_RECEIPT);
  assert.equal(h.store.get("usersv2/u")!.coins, 40);
  assert.deepEqual(h.store.get("coinTransactions/award_u_legacy_request_1")!.coinEvent, LAUNCH_RECEIPT);
});

test("legacy awardCoins outside the window pays 20 with no coinEvent", async (t) => {
  resetEconomyCache(); t.after(resetEconomyCache);
  const h = harness(t);
  const old = process.env.REWARDED_AD_LEGACY_UNTIL;
  delete process.env.REWARDED_AD_LEGACY_UNTIL;
  t.after(() => {
    if (old === undefined) delete process.env.REWARDED_AD_LEGACY_UNTIL; else process.env.REWARDED_AD_LEGACY_UNTIL = old;
  });
  h.store.set("economyConfig/current", {events: [launch({endsAtMs: NOW})]});
  const legacy = await awardCoins.run({auth: {uid: "u"}, data: {action: "rewardedAd", sourceTag: "test"}} as
    unknown as Parameters<typeof awardCoins.run>[0]);
  assert.equal(legacy.delta, 20);
  assert.equal(legacy.coinEvent, undefined);
  assert.equal(h.store.get("usersv2/u")!.coins, 20);
});
