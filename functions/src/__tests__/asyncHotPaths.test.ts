import assert from "node:assert/strict";
import test from "node:test";
import {awardCoins, buyStreakFreeze, claimProSpin, restoreStreak, spendCoins, spinWheel, unlockPremiumPreview} from "../coinsCallables";
import {buyDrawTicket} from "../draw";
import {loadEconomy, resetEconomyCache} from "../economy";
import {equipCosmetic, purchaseShopItem} from "../shop";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 14, 12);
const cases: Array<{name: string; run: () => Promise<unknown>; user?: Doc}> = [
  {name: "coin spend", run: () => spendCoins.run({auth: {uid: "u1"},
    data: {action: "premiumFilter", sourceTag: "test", requestId: "request_0001"}} as unknown as Parameters<typeof spendCoins.run>[0])},
  {name: "wheel spin", run: () => spinWheel.run({auth: {uid: "u1"},
    data: {requestId: "request_0001", maxCost: 100}} as Parameters<typeof spinWheel.run>[0])},
  {name: "coin award", run: () => awardCoins.run({auth: {uid: "u1"},
    data: {action: "proDailyBonus", sourceTag: "test"}} as unknown as Parameters<typeof awardCoins.run>[0])},
  {name: "Pro spin", run: () => claimProSpin.run({auth: {uid: "u1"},
    data: {requestId: "request_0001"}} as Parameters<typeof claimProSpin.run>[0])},
  {name: "preview unlock", run: () => unlockPremiumPreview.run({auth: {uid: "u1"},
    data: {collectionKey: "space", pricingVersion: 2}} as Parameters<typeof unlockPremiumPreview.run>[0])},
  {name: "freeze purchase", run: () => buyStreakFreeze.run({auth: {uid: "u1"},
    data: {requestId: "request_0001"}} as Parameters<typeof buyStreakFreeze.run>[0])},
  {name: "streak restore", user: {coinState: {streakCount: 0, rescue: {count: 20, expiresAtMs: NOW + 3600000}}},
    run: () => restoreStreak.run({auth: {uid: "u1"},
      data: {requestId: "request_0001"}} as Parameters<typeof restoreStreak.run>[0])},
  {name: "shop purchase", run: () => purchaseShopItem.run({auth: {uid: "u1"},
    data: {itemId: "frame_ring", requestId: "request_0001"}} as Parameters<typeof purchaseShopItem.run>[0])},
  {name: "cosmetic equip", run: () => equipCosmetic.run({auth: {uid: "u1"},
    data: {slot: "frame", itemId: "frame_ring"}} as Parameters<typeof equipCosmetic.run>[0])},
  {name: "draw ticket", user: {premium: false}, run: () => buyDrawTicket.run({auth: {uid: "u1"},
    data: {requestId: "request_0001"}} as Parameters<typeof buyDrawTicket.run>[0])},
];

for (const scenario of cases) {
  test(`${scenario.name} batches independent transaction reads into one round`, async (t) => {
    t.mock.method(Date, "now", () => NOW);
    resetEconomyCache();
    const observed = {reads: 0, writes: 0, readRounds: 0};
    installFakeDb(t, {
      "economyConfig/current": {flags: {drawEnabled: true}},
      "usersv2/u1": {coins: 500, premium: true, ...scenario.user},
      "usersv2/u1/private/economy": {inventory: {owned: scenario.name === "cosmetic equip" ? {frame_ring: 1} : {}}},
    }, observed);
    await loadEconomy();
    observed.readRounds = 0;
    const result = await scenario.run();
    assert.ok(result && typeof result === "object" && "success" in result);
    assert.equal(result.success, true, JSON.stringify(result));
    assert.equal(observed.readRounds, 1);
  });
}
