import * as admin from "firebase-admin";
import {db} from "./common";

/** Where admins tune the economy. Clients read the same doc. */
export const ECONOMY_CONFIG_DOC = "economyConfig/current";
const CACHE_MS = 60_000;
const DAY_MS = 86_400_000;

export interface SpinSegment { coins: number; weight: number }
/** One slice of the spin wheel. Mirrored by `WheelSegment` in lib/core/coins/spin_wheel.dart. */
export type WheelSegment =
  ({kind: "coins"; coins: number} | {kind: "cosmetic"; fallbackCoins: number}) &
  {weight: number};
export interface RankDef { id: string; min: number }

export interface EconomyConfig {
  version: number;
  spend: {
    wallpaperDownload: number;
    premiumWallpaperDownload: number;
    liveWallpaperStyle: number;
    premiumFilter: number;
    premiumPreview24h: number;
    autoRotatePass7d: number;
    streakFreeze: number;
    streakRescue: number;
    aiFast: number;
    aiBalanced: number;
    aiQuality: number;
    dropWall: number;
    dropPack: number;
    boostWall: number;
    giftPremiumPass: number;
    drawTicket: number;
    spinWheel: number;
    dailyChest: number;
  };
  proDiscountActions: string[];
  proBypassActions: string[];
  award: {
    rewardedAd: number;
    rewardedAdFirstOfDay: number;
    rewardedAdMaxPerDay: number;
    firstWallpaperUpload: number;
    profileCompletion: number;
    referral: number;
    referralMaxPerDay: number;
    referralMaxLifetime: number;
    streakDaily: number[];
    streakChestMin: number;
    streakChestMax: number;
    proStreakMultiplier: number;
    proSpin: SpinSegment[];
    spinWheelMaxPerDay: number;
    /** Wheel order, clockwise. Index 0 sits under the pointer at rest. */
    spinWheel: WheelSegment[];
    /** The daily chest prize table, same shape as `spinWheel`. Slot order is the odds sheet order. */
    dailyChest: WheelSegment[];
    questCoins: number;
    questXp: number;
    questChestMin: number;
    questChestMax: number;
    questChestCosmeticChance: number;
    weeklyQuestCoins: number;
    weeklyQuestXp: number;
    graceDownloads: number;
  };
  xp: {
    perCoinEarned: number;
    activities: {
      dailyStreak: number;
      streakWeek: number;
      questChest: number;
      firstWallpaperUpload: number;
      profileCompletion: number;
    };
    ranks: RankDef[];
  };
  flags: {
    drawEnabled: boolean;
    dropsEnabled: boolean;
    foundersUntil: string;
    /** Until then a client without `pricingVersion: 2` pays the legacy prices. */
    legacyPricingUntil: string;
  };
  /** Per shop item price overrides, keyed by item id. */
  shopPrices: Record<string, number>;
}

export const DEFAULT_ECONOMY: EconomyConfig = {
  version: 2,
  spend: {
    wallpaperDownload: 10,
    premiumWallpaperDownload: 25,
    liveWallpaperStyle: 20,
    premiumFilter: 5,
    premiumPreview24h: 10,
    autoRotatePass7d: 50,
    streakFreeze: 50,
    streakRescue: 100,
    aiFast: 10,
    aiBalanced: 75,
    aiQuality: 100,
    dropWall: 30,
    dropPack: 150,
    boostWall: 100,
    giftPremiumPass: 50,
    drawTicket: 20,
    spinWheel: 10,
    dailyChest: 8,
  },
  proDiscountActions: ["aiGeneration", "dropWall", "dropPack"],
  proBypassActions: [
    "wallpaperDownload", "premiumWallpaperDownload", "liveWallpaperStyle", "premiumFilter", "premiumPreview24h",
    "autoRotatePass7d",
  ],
  award: {
    rewardedAd: 10,
    rewardedAdFirstOfDay: 20,
    rewardedAdMaxPerDay: 20,
    firstWallpaperUpload: 50,
    profileCompletion: 25,
    referral: 100,
    referralMaxPerDay: 3,
    referralMaxLifetime: 20,
    streakDaily: [3, 3, 5, 5, 8, 8, 10],
    streakChestMin: 15,
    streakChestMax: 40,
    proStreakMultiplier: 1.5,
    proSpin: [
      {coins: 20, weight: 40},
      {coins: 30, weight: 25},
      {coins: 50, weight: 20},
      {coins: 75, weight: 10},
      {coins: 100, weight: 5},
    ],
    spinWheelMaxPerDay: 5,
    spinWheel: [
      {kind: "coins", coins: 10, weight: 18},
      {kind: "coins", coins: 1, weight: 22},
      {kind: "coins", coins: 5, weight: 30},
      {kind: "coins", coins: 100, weight: 1},
      {kind: "coins", coins: 20, weight: 8},
      {kind: "coins", coins: 2, weight: 12},
      {kind: "coins", coins: 50, weight: 3},
      {kind: "cosmetic", fallbackCoins: 50, weight: 6},
    ],
    dailyChest: [
      {kind: "coins", coins: 5, weight: 34},
      {kind: "coins", coins: 8, weight: 28},
      {kind: "coins", coins: 12, weight: 15},
      {kind: "coins", coins: 20, weight: 11},
      {kind: "cosmetic", fallbackCoins: 25, weight: 8},
      {kind: "coins", coins: 40, weight: 3},
      {kind: "coins", coins: 100, weight: 1},
    ],
    questCoins: 2,
    questXp: 25,
    questChestMin: 5,
    questChestMax: 15,
    questChestCosmeticChance: 0.1,
    weeklyQuestCoins: 30,
    weeklyQuestXp: 150,
    graceDownloads: 3,
  },
  xp: {
    perCoinEarned: 1,
    activities: {
      dailyStreak: 5,
      streakWeek: 25,
      questChest: 10,
      firstWallpaperUpload: 50,
      profileCompletion: 25,
    },
    ranks: [
      {id: "bronze", min: 0},
      {id: "silver", min: 500},
      {id: "gold", min: 2000},
      {id: "prism", min: 6000},
    ],
  },
  flags: {
    drawEnabled: false,
    dropsEnabled: true,
    foundersUntil: "2026-11-30T00:00:00Z",
    legacyPricingUntil: "2027-01-31T00:00:00Z",
  },
  shopPrices: {},
};

const MAX_PRICE = 10_000;
const MAX_AWARD = 1_000;
// Pro always pays for these, at most half.
const NEVER_BYPASSED = new Set(["aiGeneration", "dropWall", "dropPack"]);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isIntIn = (value: unknown, max: number): value is number =>
  typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= max;
export const isPrice = (value: unknown): value is number => isIntIn(value, MAX_PRICE);
const isAward = (value: unknown): value is number => isIntIn(value, MAX_AWARD);
const isNumberIn = (value: unknown, min: number, max: number): value is number =>
  typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;

const MIN_WHEEL_SEGMENTS = 2;
const MAX_WHEEL_SEGMENTS = 12;

function parseWheelSegment(raw: unknown): WheelSegment | null {
  if (!isRecord(raw) || !isNumberIn(raw.weight, 0, MAX_AWARD)) return null;
  const weight = raw.weight;
  switch (raw.kind) {
  case "coins": return isIntIn(raw.coins, MAX_AWARD) && raw.coins >= 1 ? {kind: "coins", coins: raw.coins, weight} : null;
  case "cosmetic":
    return isIntIn(raw.fallbackCoins, MAX_AWARD) && raw.fallbackCoins >= 1 ?
      {kind: "cosmetic", fallbackCoins: raw.fallbackCoins, weight} : null;
  default: return null;
  }
}

/** A clean wheel table, or null when it is not an array of 2..12 valid segments with a positive weight sum. */
function parseWheel(raw: unknown): WheelSegment[] | null {
  if (!Array.isArray(raw) || raw.length < MIN_WHEEL_SEGMENTS || raw.length > MAX_WHEEL_SEGMENTS) return null;
  const segments: WheelSegment[] = [];
  for (const entry of raw) {
    const segment = parseWheelSegment(entry);
    if (segment === null) return null;
    segments.push(segment);
  }
  return segments.reduce((sum, s) => sum + s.weight, 0) > 0 ? segments : null;
}

/** Deep merge of `raw` onto `base`. Only keys that exist in `base` with the same shape are taken. */
function mergeOnto<T>(base: T, raw: unknown): T {
  if (Array.isArray(base)) {
    return (Array.isArray(raw) ? raw : base) as T;
  }
  if (isRecord(base)) {
    if (!isRecord(raw)) return base;
    const out: Record<string, unknown> = {...base};
    for (const key of Object.keys(base)) {
      if (key in raw) out[key] = mergeOnto((base as Record<string, unknown>)[key], raw[key]);
    }
    // shopPrices is an open map: take every valid price.
    if ("shopPrices" in base && isRecord(raw.shopPrices)) {
      const prices: Record<string, number> = {};
      for (const [id, price] of Object.entries(raw.shopPrices)) {
        if (isPrice(price)) prices[id] = price;
      }
      out.shopPrices = prices;
    }
    return out as T;
  }
  if (typeof base === "number") {
    return (typeof raw === "number" && Number.isFinite(raw) ? raw : base) as T;
  }
  if (typeof base === "boolean") {
    return (typeof raw === "boolean" ? raw : base) as T;
  }
  if (typeof base === "string") {
    return (typeof raw === "string" ? raw : base) as T;
  }
  return base;
}

/** Config from a raw Firestore doc, with defaults for anything missing or malformed. */
export function parseEconomy(raw: unknown): EconomyConfig {
  const merged = {...mergeOnto(DEFAULT_ECONOMY, raw)};
  const defaults = DEFAULT_ECONOMY;
  merged.spend = {...merged.spend};
  for (const key of Object.keys(defaults.spend) as (keyof EconomyConfig["spend"])[]) {
    if (!isPrice(merged.spend[key])) merged.spend[key] = defaults.spend[key];
  }
  const award = {...merged.award};
  for (const key of Object.keys(defaults.award) as (keyof EconomyConfig["award"])[]) {
    if (key === "proStreakMultiplier" || key === "questChestCosmeticChance") continue;
    if (typeof defaults.award[key] === "number" && !isAward(award[key])) {
      (award as Record<string, unknown>)[key] = defaults.award[key];
    }
  }
  if (!isNumberIn(award.proStreakMultiplier, 1, 10)) award.proStreakMultiplier = defaults.award.proStreakMultiplier;
  if (!isNumberIn(award.questChestCosmeticChance, 0, 1)) {
    award.questChestCosmeticChance = defaults.award.questChestCosmeticChance;
  }
  if (award.streakChestMin > award.streakChestMax) {
    award.streakChestMin = defaults.award.streakChestMin;
    award.streakChestMax = defaults.award.streakChestMax;
  }
  if (award.questChestMin > award.questChestMax) {
    award.questChestMin = defaults.award.questChestMin;
    award.questChestMax = defaults.award.questChestMax;
  }
  if (award.streakDaily.length !== 7 || award.streakDaily.some((n) => !isAward(n))) {
    award.streakDaily = defaults.award.streakDaily;
  }
  if (award.proSpin.length === 0 ||
      award.proSpin.some((s) => !isRecord(s) || !isAward(s.coins) || !isNumberIn(s.weight, 0, MAX_AWARD)) ||
      award.proSpin.reduce((sum, s) => sum + s.weight, 0) <= 0) {
    award.proSpin = defaults.award.proSpin;
  }
  award.spinWheel = parseWheel(award.spinWheel) ?? defaults.award.spinWheel;
  award.dailyChest = parseWheel(award.dailyChest) ?? defaults.award.dailyChest;
  merged.award = award;
  merged.proDiscountActions = merged.proDiscountActions.filter((a) => typeof a === "string");
  merged.proBypassActions = merged.proBypassActions.filter((a) => typeof a === "string" && !NEVER_BYPASSED.has(a));
  const ranks = merged.xp.ranks;
  const ranksOk = ranks.length > 0 &&
    ranks.every((r) => isRecord(r) && typeof r.id === "string" && r.id !== "" && isIntIn(r.min, Number.MAX_SAFE_INTEGER)) &&
    new Set(ranks.map((r) => r.id)).size === ranks.length &&
    Math.min(...ranks.map((r) => r.min)) === 0;
  const activities = {...merged.xp.activities};
  for (const key of Object.keys(defaults.xp.activities) as (keyof EconomyConfig["xp"]["activities"])[]) {
    if (!isAward(activities[key])) activities[key] = defaults.xp.activities[key];
  }
  merged.xp = {
    perCoinEarned: isNumberIn(merged.xp.perCoinEarned, 0, 10) ? merged.xp.perCoinEarned : defaults.xp.perCoinEarned,
    activities,
    ranks: ranksOk ? [...ranks].sort((a, b) => a.min - b.min) : defaults.xp.ranks,
  };
  return merged;
}

let cached: {at: number; config: EconomyConfig} | null = null;

export function resetEconomyCache(): void {
  cached = null;
}

/** The live config, cached for a minute per instance. Falls back to defaults when the doc is missing. */
export async function loadEconomy(nowMs = Date.now()): Promise<EconomyConfig> {
  if (cached && nowMs - cached.at < CACHE_MS) return cached.config;
  let config = DEFAULT_ECONOMY;
  try {
    const snap = await db.doc(ECONOMY_CONFIG_DOC).get();
    config = parseEconomy(snap.exists ? snap.data() : null);
  } catch {
    config = cached?.config ?? DEFAULT_ECONOMY;
  }
  cached = {at: nowMs, config};
  return config;
}

/** UTC calendar day, `YYYY-MM-DD`. */
export function dayKey(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10);
}

/** Start of the ISO week (Monday 00:00 UTC) and the start of the next one. */
export function weekBounds(nowMs: number): {start: number; end: number} {
  const d = new Date(nowMs);
  const day = (d.getUTCDay() + 6) % 7;
  const start = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) - day * DAY_MS;
  return {start, end: start + 7 * DAY_MS};
}

/** ISO week key, `YYYY-Www`, computed in UTC. */
export function weekKey(nowMs: number): string {
  const {start} = weekBounds(nowMs);
  const thursday = new Date(start + 3 * DAY_MS);
  const year = thursday.getUTCFullYear();
  const jan4 = Date.UTC(year, 0, 4);
  const week1Start = weekBounds(jan4).start;
  const week = Math.floor((thursday.getTime() - week1Start) / (7 * DAY_MS)) + 1;
  return `${year}-W${String(week).padStart(2, "0")}`;
}

/** Pro pays half, rounded up, never zero for a positive price. */
export function proPrice(price: number, isPro: boolean): number {
  if (!isPro || price <= 0) return price;
  return Math.max(1, Math.ceil(price / 2));
}

export interface Rank { id: string; min: number; next: RankDef | null }

export function rankFor(xp: number, config: EconomyConfig): Rank {
  const ranks = config.xp.ranks;
  let current = ranks[0];
  let next: RankDef | null = null;
  for (let i = 0; i < ranks.length; i += 1) {
    if (xp >= ranks[i].min) {
      current = ranks[i];
      next = ranks[i + 1] ?? null;
    }
  }
  return {id: current.id, min: current.min, next};
}

export interface XpFields {
  xp: number;
  xpWeek: {weekKey: string; xp: number};
}

/**
 * Fields to merge into the user update that also writes the coins, so one transaction moves both.
 * `userData` is the snapshot read inside the same transaction.
 */
export function grantXp(userData: admin.firestore.DocumentData, xp: number, nowMs: number): XpFields {
  const gained = safeXp(xp);
  const key = weekKey(nowMs);
  const rawWeek = isRecord(userData.xpWeek) ? userData.xpWeek : {};
  const weekXp = rawWeek.weekKey === key ? safeXp(rawWeek.xp) : 0;
  return {xp: safeXp(safeXp(userData.xp) + gained), xpWeek: {weekKey: key, xp: safeXp(weekXp + gained)}};
}

/** A non-negative safe integer; anything else counts as 0. */
function safeXp(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 0;
  return Math.min(Number.MAX_SAFE_INTEGER, Math.max(0, Math.trunc(value)));
}

export interface XpReceipt extends XpFields {
  xpPolicyVersion: 1;
  xpAwarded: number;
}

/**
 * Absolute transaction snapshot. Inactive weeks reply as the current week with zero XP without rewriting history.
 * Awarding callers pass their post-grant fields; no-op/replay callers pass the current user snapshot and award zero.
 */
export function xpReceipt(userData: admin.firestore.DocumentData, nowMs: number, xpAwarded = 0): XpReceipt {
  return {xpPolicyVersion: 1, ...grantXp(userData, 0, nowMs), xpAwarded: safeXp(xpAwarded)};
}

/** Deterministic pick of `count` distinct items from `pool`, stable for the same seed. */
export function seededPick<T>(seed: string, count: number, pool: readonly T[]): T[] {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i += 1) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  const items = [...pool];
  const picked: T[] = [];
  while (picked.length < count && items.length > 0) {
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    picked.push(items.splice(h % items.length, 1)[0]);
  }
  return picked;
}

/** Index of the segment hit by `random` in [0, 1). */
export function weightedPick(table: readonly {weight: number}[], random: () => number = Math.random): number {
  const total = table.reduce((sum, s) => sum + Math.max(0, s.weight), 0);
  if (total <= 0) return 0;
  let roll = random() * total;
  for (let i = 0; i < table.length; i += 1) {
    roll -= Math.max(0, table[i].weight);
    if (roll < 0) return i;
  }
  return table.length - 1;
}

/** Integer in [min, max]. */
export function randomInt(min: number, max: number, random: () => number = Math.random): number {
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  return lo + Math.floor(random() * (hi - lo + 1));
}
