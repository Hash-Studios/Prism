import {logger} from "firebase-functions/v2";

/** Coin doubler events. Mirrored by lib/core/coins/coin_events.dart. */
export type CoinEventAction = "rewardedAd";
export type CoinEventMultiplier = 2 | 3;
/** Picks the client copy: "Weekend 2x" or "2x coins". */
export type CoinEventLabel = "weekend" | "event";

export interface CoinEvent {
  id: string;
  startsAtMs: number;
  /** Exclusive. */
  endsAtMs: number;
  multiplier: CoinEventMultiplier;
  actions: CoinEventAction[];
  label: CoinEventLabel;
}

/** Repeats every week. `startDay` is ISO (1 Monday .. 7 Sunday), times are UTC. */
export interface WeeklyCoinEvent {
  id: string;
  startDay: number;
  startMinute: number;
  durationMinutes: number;
  multiplier: CoinEventMultiplier;
  actions: CoinEventAction[];
  label: CoinEventLabel;
}

/** The `events` and `weeklyEvent` keys of `economyConfig/current`, by the same names. */
export interface CoinEvents {
  events: CoinEvent[];
  weeklyEvent: WeeklyCoinEvent | null;
}

/** One occurrence that pays. Written to the ledger as `coinEvent`. */
export interface LiveCoinEvent {
  id: string;
  multiplier: CoinEventMultiplier;
  label: CoinEventLabel;
  startsAtMs: number;
  endsAtMs: number;
}

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;
const WEEK_MS = 7 * DAY_MS;
const MAX_EVENTS = 50;
const MAX_EVENT_MS = 31 * DAY_MS;
const ID = /^[a-z0-9_-]{1,40}$/;
const ACTIONS: ReadonlySet<string> = new Set<CoinEventAction>(["rewardedAd"]);

export const NO_COIN_EVENTS: CoinEvents = {events: [], weeklyEvent: null};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const isIntIn = (value: unknown, min: number, max: number): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= min && value <= max;

type Common = Pick<CoinEvent, "id" | "multiplier" | "actions" | "label">;

function parseCommon(raw: Record<string, unknown>): Common | null {
  const {id, multiplier, actions, label = "event"} = raw;
  if (typeof id !== "string" || !ID.test(id)) return null;
  if (multiplier !== 2 && multiplier !== 3) return null;
  if (!Array.isArray(actions) || actions.length === 0 || actions.some((a) => typeof a !== "string" || !ACTIONS.has(a))) {
    return null;
  }
  if (label !== "weekend" && label !== "event") return null;
  return {id, multiplier, actions: [...new Set(actions as CoinEventAction[])], label};
}

function parseEvent(raw: unknown): CoinEvent | null {
  if (!isRecord(raw)) return null;
  const common = parseCommon(raw);
  const {startsAtMs, endsAtMs} = raw;
  if (!common || !isIntIn(startsAtMs, 0, Number.MAX_SAFE_INTEGER) || !isIntIn(endsAtMs, 0, Number.MAX_SAFE_INTEGER) ||
      endsAtMs <= startsAtMs || endsAtMs - startsAtMs > MAX_EVENT_MS) return null;
  return {...common, startsAtMs, endsAtMs};
}

function parseWeekly(raw: unknown): WeeklyCoinEvent | null {
  if (!isRecord(raw)) return null;
  const common = parseCommon(raw);
  const {startDay, startMinute, durationMinutes} = raw;
  if (!common || !isIntIn(startDay, 1, 7) || !isIntIn(startMinute, 0, 1439) ||
      !isIntIn(durationMinutes, 1, WEEK_MS / MINUTE_MS - 1)) return null;
  return {...common, startDay, startMinute, durationMinutes};
}

/** Valid events from a raw config doc. Each bad entry is dropped and logged; the rest still apply. */
export function parseCoinEvents(raw: unknown): CoinEvents {
  if (!isRecord(raw)) return NO_COIN_EVENTS;
  const events: CoinEvent[] = [];
  const rawEvents = raw.events;
  if (rawEvents !== undefined && !Array.isArray(rawEvents)) logger.warn("economy: events is not a list, ignored");
  if (Array.isArray(rawEvents)) {
    rawEvents.slice(0, MAX_EVENTS).forEach((entry, index) => {
      const event = parseEvent(entry);
      if (event) events.push(event);
      else logger.warn("economy: invalid coin event ignored", {index, entry});
    });
    if (rawEvents.length > MAX_EVENTS) logger.warn("economy: coin events over the limit ignored", {count: rawEvents.length});
  }
  const rawWeekly = raw.weeklyEvent;
  const weeklyEvent = rawWeekly === undefined || rawWeekly === null ? null : parseWeekly(rawWeekly);
  if (rawWeekly !== undefined && rawWeekly !== null && weeklyEvent === null) {
    logger.warn("economy: invalid weekly coin event ignored", {entry: rawWeekly});
  }
  return {events, weeklyEvent};
}

/** The weekly rule's occurrence that started last at or before `nowMs`. */
export function weeklyOccurrence(rule: WeeklyCoinEvent, nowMs: number): LiveCoinEvent {
  const now = new Date(nowMs);
  const mondayMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) - ((now.getUTCDay() + 6) % 7) * DAY_MS;
  let startsAtMs = mondayMs + (rule.startDay - 1) * DAY_MS + rule.startMinute * MINUTE_MS;
  if (startsAtMs > nowMs) startsAtMs -= WEEK_MS;
  return {
    id: `${rule.id}-${new Date(startsAtMs).toISOString().slice(0, 10)}`,
    multiplier: rule.multiplier,
    label: rule.label,
    startsAtMs,
    endsAtMs: startsAtMs + rule.durationMinutes * MINUTE_MS,
  };
}

/** The event that pays `action` at `nowMs`: start inclusive, end exclusive. The highest multiplier wins, then the lower id. */
export function liveCoinEvent(events: CoinEvents, action: CoinEventAction, nowMs: number): LiveCoinEvent | null {
  const live: LiveCoinEvent[] = events.events
    .filter((e) => e.actions.includes(action) && e.startsAtMs <= nowMs && nowMs < e.endsAtMs)
    .map(({id, multiplier, label, startsAtMs, endsAtMs}) => ({id, multiplier, label, startsAtMs, endsAtMs}));
  if (events.weeklyEvent?.actions.includes(action)) {
    const occurrence = weeklyOccurrence(events.weeklyEvent, nowMs);
    if (nowMs < occurrence.endsAtMs) live.push(occurrence);
  }
  live.sort((a, b) => b.multiplier - a.multiplier || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return live[0] ?? null;
}

/** What the ledger stores for an award paid under `event`. */
export const coinEventReceipt = (event: LiveCoinEvent) =>
  ({id: event.id, multiplier: event.multiplier, label: event.label});
