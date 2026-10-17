import type {EconomyConfig} from "./economy";

export type ShopItemKind = "theme" | "appIcon" | "frame" | "nameGlow";
export type CosmeticSlot = "frame" | "nameGlow";

export interface ShopItem {
  id: string;
  kind: ShopItemKind;
  name: string;
  price: number;
  /** Only Pro members may buy it. Ownership survives a lapse; equipping does not. */
  proOnly?: boolean;
  /** Rank id required to buy it. */
  minRank?: string;
  /** Limited drop: sold only until `flags.foundersUntil`. */
  founders?: boolean;
  /** Eligible for the quest chest bonus. */
  common?: boolean;
  /** For themes, the `PrismThemeOption.id` it unlocks. */
  themeId?: string;
}

/** Mirrored by lib/features/shop/domain/shop_catalog.dart. Keep ids stable. */
export const SHOP_CATALOG: readonly ShopItem[] = [
  {id: "theme_rose", kind: "theme", name: "Rose", price: 150, themeId: "kLRose", common: true},
  {id: "theme_cotton_blue", kind: "theme", name: "Cotton Blue", price: 150, themeId: "kLCotton Blue", common: true},
  {id: "theme_olive", kind: "theme", name: "Olive", price: 150, themeId: "kDOlive", common: true},
  {id: "theme_deep_ocean", kind: "theme", name: "Deep Ocean", price: 150, themeId: "kDDeep Ocean", common: true},
  {id: "theme_jungle", kind: "theme", name: "Jungle", price: 150, themeId: "kDJungle", common: true},
  {id: "theme_pepper", kind: "theme", name: "Pepper", price: 150, themeId: "kDPepper", common: true},
  {id: "theme_sky", kind: "theme", name: "Sky", price: 150, themeId: "kDSky", common: true},
  {id: "theme_steel", kind: "theme", name: "Steel", price: 150, themeId: "kDSteel", common: true},
  {id: "icon_noir", kind: "appIcon", name: "Noir", price: 200},
  {id: "icon_glass", kind: "appIcon", name: "Glass", price: 200},
  {id: "icon_sunset", kind: "appIcon", name: "Sunset", price: 200},
  {id: "icon_mono", kind: "appIcon", name: "Mono", price: 200},
  {id: "frame_ring", kind: "frame", name: "Ring", price: 120, common: true},
  {id: "frame_aurora", kind: "frame", name: "Aurora", price: 200},
  {id: "frame_prism", kind: "frame", name: "Prism", price: 300, proOnly: true},
  {id: "frame_gold", kind: "frame", name: "Gold", price: 250, minRank: "gold"},
  {id: "frame_founders", kind: "frame", name: "Founders", price: 1000, founders: true},
  {id: "glow_ember", kind: "nameGlow", name: "Ember", price: 100, common: true},
  {id: "glow_ocean", kind: "nameGlow", name: "Ocean", price: 100, common: true},
  {id: "glow_aurora", kind: "nameGlow", name: "Aurora", price: 200, minRank: "silver"},
  {id: "glow_founders", kind: "nameGlow", name: "Founders", price: 1000, founders: true},
];

export function shopItem(id: string): ShopItem | undefined {
  return SHOP_CATALOG.find((item) => item.id === id);
}

/** Catalog price unless the config overrides it. */
export function shopPrice(item: ShopItem, config: EconomyConfig): number {
  const override = config.shopPrices[item.id];
  return typeof override === "number" ? override : item.price;
}

export function slotFor(kind: ShopItemKind): CosmeticSlot | null {
  return kind === "frame" || kind === "nameGlow" ? kind : null;
}

/** A random common cosmetic the user does not own yet, or null when they own them all. */
export function pickChestCosmetic(owned: readonly string[], random: () => number = Math.random): ShopItem | null {
  const pool = SHOP_CATALOG.filter((item) => item.common && !owned.includes(item.id));
  if (pool.length === 0) return null;
  return pool[Math.min(pool.length - 1, Math.floor(random() * pool.length))];
}
