import {seededPick, weekKey, dayKey} from "./economy";
import type {EconomyConfig} from "./economy";

export type QuestEvent =
  | "set_wallpaper"
  | "favourite"
  | "view_wotd"
  | "colour_search"
  | "view_trending"
  | "share"
  | "download"
  | "view_wallpaper"
  | "watch_ad"
  | "pro_spin";

export const QUEST_EVENTS: readonly QuestEvent[] = [
  "set_wallpaper", "favourite", "view_wotd", "colour_search", "view_trending", "share", "download", "view_wallpaper",
  "watch_ad", "pro_spin",
];

/** The only events a client may report. The server counts every other event where it already sees it. */
export const CLIENT_QUEST_EVENTS: readonly QuestEvent[] = ["view_wotd", "colour_search", "view_trending"];

export interface QuestDef { id: string; event: QuestEvent; target: number; title: string }

/** Mirrored by the Rewards page. Keep ids stable. */
export const QUEST_POOL: readonly QuestDef[] = [
  {id: "set_wall", event: "set_wallpaper", target: 1, title: "Set or save a wallpaper"},
  {id: "fav_3", event: "favourite", target: 3, title: "Favourite 3 walls"},
  {id: "wotd_view", event: "view_wotd", target: 1, title: "Open today's Wall of the Day"},
  {id: "colour_search", event: "colour_search", target: 1, title: "Search by colour"},
  {id: "trending_view", event: "view_trending", target: 1, title: "See what's trending"},
  {id: "share_wall", event: "share", target: 1, title: "Share a wallpaper"},
  {id: "download_2", event: "download", target: 2, title: "Download 2 walls"},
  {id: "browse_10", event: "view_wallpaper", target: 10, title: "Look at 10 walls"},
];

export const WATCH_AD_QUEST: QuestDef = {id: "watch_ad", event: "watch_ad", target: 1, title: "Watch a video"};
export const PRO_SPIN_QUEST: QuestDef = {id: "pro_spin", event: "pro_spin", target: 1, title: "Open your Pro spin"};

export const WEEKLY_QUEST = {
  id: "weekly_set_5",
  event: "set_wallpaper" as QuestEvent,
  target: 5,
  title: "Save or set 5 walls",
};

export const DAILY_QUEST_COUNT = 3;

/** The three required items for the day, then the bonus id: `watch_ad` for free users, `pro_spin` for Pro. */
export function dailyQuestIds(day: string, isPro: boolean): {items: string[]; bonus: string} {
  return {
    items: seededPick(day, DAILY_QUEST_COUNT, QUEST_POOL).map((q) => q.id),
    bonus: isPro ? PRO_SPIN_QUEST.id : WATCH_AD_QUEST.id,
  };
}

/** Largest target any quest has for `event`. */
export function maxTargetFor(event: QuestEvent): number {
  const targets = [...QUEST_POOL, WATCH_AD_QUEST, PRO_SPIN_QUEST, WEEKLY_QUEST]
    .filter((q) => q.event === event)
    .map((q) => q.target);
  return Math.max(1, ...targets);
}

export interface QuestItem { id: string; event: QuestEvent; target: number; progress: number; claimed: boolean }

export interface QuestState {
  dayKey: string;
  items: QuestItem[];
  bonus: QuestItem;
  chestOpened: boolean;
  chestDoubled: boolean;
  weekKey: string;
  weekly: QuestItem;
}

const freshItem = (def: {id: string; event: QuestEvent; target: number}): QuestItem =>
  ({id: def.id, event: def.event, target: def.target, progress: 0, claimed: false});

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

function readItem(raw: unknown): QuestItem | null {
  if (!isRecord(raw)) return null;
  const {id, event, target, progress, claimed} = raw;
  if (typeof id !== "string" || !QUEST_EVENTS.includes(event as QuestEvent)) return null;
  if (typeof target !== "number" || !Number.isInteger(target) || target < 1) return null;
  if (typeof progress !== "number" || !Number.isInteger(progress) || progress < 0) return null;
  if (typeof claimed !== "boolean") return null;
  return {id, event: event as QuestEvent, target, progress: Math.min(progress, target), claimed};
}

function questDef(id: string): QuestDef {
  const def = [...QUEST_POOL, WATCH_AD_QUEST, PRO_SPIN_QUEST].find((q) => q.id === id);
  if (!def) throw new Error(`unknown quest ${id}`);
  return def;
}

/**
 * Today's quest state. Daily items reset when `dayKey` changes and the weekly item when `weekKey` changes.
 * A day's assignment is kept as stored, so a Pro flip mid-day never reshuffles the bonus.
 */
export function buildQuestState(existing: unknown, nowMs: number, isPro: boolean): QuestState {
  const raw = isRecord(existing) ? existing : {};
  const day = dayKey(nowMs);
  const week = weekKey(nowMs);

  let daily: Pick<QuestState, "items" | "bonus" | "chestOpened" | "chestDoubled">;
  const storedItems = Array.isArray(raw.items) ? raw.items.map(readItem) : [];
  const storedBonus = readItem(raw.bonus);
  if (raw.dayKey === day && storedItems.length === DAILY_QUEST_COUNT && !storedItems.includes(null) && storedBonus) {
    daily = {
      items: storedItems as QuestItem[],
      bonus: storedBonus,
      chestOpened: raw.chestOpened === true,
      chestDoubled: raw.chestDoubled === true,
    };
  } else {
    const ids = dailyQuestIds(day, isPro);
    daily = {
      items: ids.items.map((id) => freshItem(questDef(id))),
      bonus: freshItem(questDef(ids.bonus)),
      chestOpened: false,
      chestDoubled: false,
    };
  }

  const storedWeekly = readItem(raw.weekly);
  const weekly = raw.weekKey === week && storedWeekly ? storedWeekly : freshItem(WEEKLY_QUEST);
  return {dayKey: day, ...daily, weekKey: week, weekly};
}

export interface CompletedQuest { id: string; scope: "daily" | "weekly"; coins: number; xp: number }

/** Counts one `event` on every matching item. Returns the new state and the paid items that just finished. */
export function applyQuestEvent(
  state: QuestState,
  event: QuestEvent,
  config: EconomyConfig,
): {state: QuestState; completed: CompletedQuest[]} {
  const completed: CompletedQuest[] = [];
  const bump = (item: QuestItem, pay: Omit<CompletedQuest, "id"> | null): QuestItem => {
    if (item.event !== event || item.claimed) return item;
    const progress = Math.min(item.target, item.progress + 1);
    const done = progress >= item.target;
    if (done && pay) completed.push({id: item.id, ...pay});
    return {...item, progress, claimed: done};
  };
  const {questCoins, questXp, weeklyQuestCoins, weeklyQuestXp} = config.award;
  const next: QuestState = {
    ...state,
    items: state.items.map((i) => bump(i, {scope: "daily", coins: questCoins, xp: questXp})),
    bonus: bump(state.bonus, null),
    weekly: bump(state.weekly, {scope: "weekly", coins: weeklyQuestCoins, xp: weeklyQuestXp}),
  };
  return {state: next, completed};
}
