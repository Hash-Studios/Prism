import assert from "node:assert/strict";
import test from "node:test";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {equipCosmetic, purchaseShopItem, shopRefusal} from "../shop";
import {shopItem, type ShopItem} from "../shopCatalog";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.parse("2026-10-17T00:00:00Z");
const buyer = {premium: false, xp: 0, owned: [] as string[]};
const item = (id: string): ShopItem => shopItem(id) as ShopItem;

function seed(user: Doc, owned: Record<string, number> = {}, extra: Record<string, Doc> = {}): Record<string, Doc> {
  return {
    "usersv2/u1": {coins: 500, ...user},
    "usersv2/u1/private/economy": {rev: 3, inventory: {owned}},
    ...extra,
  };
}

const buy = (itemId: unknown, requestId: unknown = "request_0001") =>
  purchaseShopItem.run({auth: {uid: "u1"}, data: {itemId, requestId}} as unknown as Parameters<typeof purchaseShopItem.run>[0]);
const equip = (slot: unknown, itemId: unknown) =>
  equipCosmetic.run({auth: {uid: "u1"}, data: {slot, itemId}} as unknown as Parameters<typeof equipCosmetic.run>[0]);

test("shopRefusal covers owned, pro only, rank and founders window", () => {
  assert.equal(shopRefusal(item("frame_ring"), {...buyer, owned: ["frame_ring"]}, DEFAULT_ECONOMY, NOW), "shop_item_owned");
  assert.equal(shopRefusal(item("frame_prism"), buyer, DEFAULT_ECONOMY, NOW), "shop_item_pro_only");
  assert.equal(shopRefusal(item("frame_prism"), {...buyer, premium: true}, DEFAULT_ECONOMY, NOW), null);
  assert.equal(shopRefusal(item("frame_gold"), {...buyer, xp: 1999}, DEFAULT_ECONOMY, NOW), "shop_item_rank_locked");
  assert.equal(shopRefusal(item("frame_gold"), {...buyer, xp: 2000}, DEFAULT_ECONOMY, NOW), null);
  assert.equal(shopRefusal(item("frame_gold"), {...buyer, xp: 9000}, DEFAULT_ECONOMY, NOW), null);
  assert.equal(shopRefusal(item("frame_founders"), buyer, DEFAULT_ECONOMY, NOW), null);
  assert.equal(shopRefusal(item("frame_founders"), buyer, DEFAULT_ECONOMY, Date.parse("2026-11-30T00:00:00Z")), "shop_item_expired");
  assert.equal(shopRefusal(item("theme_rose"), buyer, DEFAULT_ECONOMY, NOW), null);
});

test("shopRefusal refuses a rank the config does not define", () => {
  const config = {...DEFAULT_ECONOMY, xp: {...DEFAULT_ECONOMY.xp, ranks: [{id: "bronze", min: 0}]}};
  assert.equal(shopRefusal(item("frame_gold"), {...buyer, xp: 99999}, config, NOW), "shop_item_rank_locked");
});

test("purchaseShopItem writes balance, ownership, rev and the ledger together", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t, seed({}, {theme_rose: 5}));
  const result = await buy("frame_ring");
  assert.equal(result.success, true);
  assert.equal(result.changed, true);
  assert.equal(result.previousBalance, 500);
  assert.equal(result.currentBalance, 380);
  assert.equal(result.delta, -120);
  assert.equal(result.itemId, "frame_ring");
  assert.deepEqual(result.owned.sort(), ["frame_ring", "theme_rose"]);
  assert.equal(store.get("usersv2/u1")?.coins, 380);
  const priv = store.get("usersv2/u1/private/economy") as {rev: number; inventory: {owned: Record<string, number>}};
  assert.equal(priv.rev, 4);
  assert.equal(priv.inventory.owned.theme_rose, 5);
  assert.equal(typeof priv.inventory.owned.frame_ring, "number");
  const ledger = store.get("coinTransactions/ctx_shop_u1_request_0001");
  assert.equal(ledger?.action, "shopItem");
  assert.equal(ledger?.reason, "shop_frame_ring");
  assert.equal(ledger?.description, "Ring");
  assert.equal(ledger?.sourceTag, "shop.purchase.callable");
  assert.equal(ledger?.delta, -120);
  assert.equal(ledger?.balanceBefore, 500);
});

test("purchaseShopItem creates the private doc when it is missing", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t, {"usersv2/u1": {coins: 500}});
  const result = await buy("glow_ember");
  assert.equal(result.changed, true);
  const priv = store.get("usersv2/u1/private/economy") as {rev: number; inventory: {owned: Record<string, number>}};
  assert.equal(priv.rev, 1);
  assert.deepEqual(Object.keys(priv.inventory.owned), ["glow_ember"]);
});

test("purchaseShopItem replay returns the original result and charges once", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t, seed({}));
  await buy("frame_ring");
  const replay = await buy("frame_ring");
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.previousBalance, 500);
  assert.equal(replay.currentBalance, 380);
  assert.equal(replay.delta, -120);
  assert.deepEqual(replay.owned, ["frame_ring"]);
  assert.equal(store.get("usersv2/u1")?.coins, 380);
  assert.equal((store.get("usersv2/u1/private/economy") as {rev: number}).rev, 4);
});

test("purchaseShopItem charges the full catalog price to Pro and honours config overrides", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t, seed({premium: true}, {}, {"economyConfig/current": {shopPrices: {glow_ocean: 40}}}));
  assert.equal((await buy("frame_aurora")).currentBalance, 300);
  assert.equal((await buy("glow_ocean", "request_0002")).currentBalance, 260);
  assert.equal(store.get("usersv2/u1")?.coins, 260);
});

test("purchaseShopItem refuses without writing", async (t) => {
  const cases: Array<[string, Doc, Record<string, number>, Record<string, Doc>, string]> = [
    ["frame_ring", {}, {frame_ring: 1}, {}, "shop_item_owned"],
    ["frame_prism", {}, {}, {}, "shop_item_pro_only"],
    ["frame_gold", {xp: 100}, {}, {}, "shop_item_rank_locked"],
    ["frame_founders", {}, {}, {"economyConfig/current": {flags: {foundersUntil: "2020-01-01T00:00:00Z"}}}, "shop_item_expired"],
    ["frame_aurora", {coins: 199}, {}, {}, "shopItem_insufficient_balance"],
  ];
  for (const [itemId, user, owned, extra, reason] of cases) {
    resetEconomyCache();
    const store = installFakeDb(t, seed(user, owned, extra));
    const before = JSON.stringify([...store.entries()]);
    const result = await buy(itemId);
    assert.equal(result.success, false, reason);
    assert.equal(result.changed, false, reason);
    assert.equal(result.reason, reason);
    assert.equal(result.insufficientBalance, reason === "shopItem_insufficient_balance");
    assert.equal(JSON.stringify([...store.entries()]), before, reason);
  }
});

test("purchaseShopItem rejects bad input and anonymous callers", async (t) => {
  resetEconomyCache();
  installFakeDb(t, seed({}));
  await assert.rejects(() => buy("nope"), {code: "invalid-argument"});
  await assert.rejects(() => buy(42), {code: "invalid-argument"});
  await assert.rejects(() => buy("frame_ring", "short"), {code: "invalid-argument"});
  await assert.rejects(() => purchaseShopItem.run(
    {data: {itemId: "frame_ring", requestId: "request_0001"}} as unknown as Parameters<typeof purchaseShopItem.run>[0],
  ), {code: "unauthenticated"});
});

test("equipCosmetic equips an owned item and clears a slot", async (t) => {
  const store = installFakeDb(t, seed({cosmetics: {nameGlow: "glow_ember"}}, {frame_ring: 1, frame_aurora: 2}));
  const first = await equip("frame", "frame_ring");
  assert.equal(first.success, true);
  assert.deepEqual(first.cosmetics, {nameGlow: "glow_ember", frame: "frame_ring"});
  assert.deepEqual((await equip("frame", "frame_aurora")).cosmetics, {nameGlow: "glow_ember", frame: "frame_aurora"});
  assert.deepEqual(store.get("usersv2/u1")?.cosmetics, {nameGlow: "glow_ember", frame: "frame_aurora"});
  const cleared = await equip("frame", null);
  assert.equal(cleared.success, true);
  assert.deepEqual(cleared.cosmetics, {nameGlow: "glow_ember"});
  assert.deepEqual(store.get("usersv2/u1")?.cosmetics, {nameGlow: "glow_ember"});
});

test("equipCosmetic refuses an unowned item", async (t) => {
  const store = installFakeDb(t, seed({}, {frame_ring: 1}));
  const result = await equip("frame", "frame_aurora");
  assert.equal(result.success, false);
  assert.equal(result.reason, "equip_not_owned");
  assert.equal(store.get("usersv2/u1")?.cosmetics, undefined);
});

test("equipCosmetic rejects a wrong slot, a theme and a bad slot", async (t) => {
  installFakeDb(t, seed({}, {frame_ring: 1, theme_rose: 1, glow_ember: 1}));
  await assert.rejects(() => equip("nameGlow", "frame_ring"), {code: "invalid-argument"});
  await assert.rejects(() => equip("frame", "theme_rose"), {code: "invalid-argument"});
  await assert.rejects(() => equip("frame", "missing"), {code: "invalid-argument"});
  await assert.rejects(() => equip("hat", "frame_ring"), {code: "invalid-argument"});
  await assert.rejects(() => equip("frame", 7), {code: "invalid-argument"});
});

test("equipCosmetic keeps a Pro item owned but not equippable after a lapse", async (t) => {
  const store = installFakeDb(t, seed({premium: false, cosmetics: {frame: "frame_prism"}}, {frame_prism: 1}));
  const refused = await equip("frame", "frame_prism");
  assert.equal(refused.success, false);
  assert.equal(refused.reason, "equip_pro_required");
  assert.deepEqual(store.get("usersv2/u1")?.cosmetics, {frame: "frame_prism"});
  store.set("usersv2/u1", {...store.get("usersv2/u1"), premium: true});
  assert.equal((await equip("frame", "frame_prism")).success, true);
});
