import * as admin from "firebase-admin";
import {FieldPath, type Firestore} from "firebase-admin/firestore";
import {str} from "../common";
import {approvedWall} from "../creatorProgress";
import {CREATOR_FUND_METRICS, type CreatorFundMetric, weekBounds, weekKey} from "../economy";
import {normalizeId} from "../viewStats";
import {FUND_EVENTS} from "./events";
import type {CreatorGate, FundEvent} from "./score";

const DAY_MS = 86_400_000;
const PAGE = 1000;
const GET_ALL_CHUNK = 100;
/** Fails the week loudly instead of scoring a partial week. Raise with real volume. */
export const MAX_FUND_EVENTS = 2_000_000;
export const MAX_FUND_WALLS = 100_000;

const WEEK_KEY = /^(\d{4})-W(\d{2})$/;

/** Monday 00:00 UTC of an ISO week key and of the next week. Throws on a key that does not round-trip. */
export function weekRange(week: string): {start: number; end: number} {
  const match = WEEK_KEY.exec(week);
  if (!match) throw new Error(`Bad week key "${week}".`);
  const week1 = weekBounds(Date.UTC(Number(match[1]), 0, 4)).start;
  const start = week1 + (Number(match[2]) - 1) * 7 * DAY_MS;
  if (weekKey(start) !== week) throw new Error(`Bad week key "${week}".`);
  return {start, end: start + 7 * DAY_MS};
}

/** The last complete ISO week before `nowMs`. */
export function previousWeek(nowMs: number): string {
  return weekKey(weekBounds(nowMs).start - 1);
}

const isMetric = (value: unknown): value is CreatorFundMetric =>
  typeof value === "string" && (CREATOR_FUND_METRICS as readonly string[]).includes(value);

export async function loadLedgerEvents(db: Firestore, week: string): Promise<FundEvent[]> {
  const events: FundEvent[] = [];
  let cursor: string | undefined;
  for (;;) {
    let query = db.collection(FUND_EVENTS).where("week", "==", week).orderBy(FieldPath.documentId())
      .select("wallId", "metric", "actorUid").limit(PAGE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const {wallId, metric, actorUid} = doc.data();
      if (typeof wallId === "string" && isMetric(metric) && typeof actorUid === "string" && actorUid) {
        events.push({wallId, metric, actorUid});
      }
    }
    if (events.length > MAX_FUND_EVENTS) throw new Error(`More than ${MAX_FUND_EVENTS} fund events in ${week}.`);
    if (page.size < PAGE) return events;
    cursor = page.docs[page.docs.length - 1].id;
  }
}

export interface WallCensus {
  /** Normalized wall ID to creator UID, for approved non-Studio walls with one owner per ID. */
  wallCreators: Map<string, string>;
  /** Creators with a wall held by reports during the week, or held now. */
  struck: Set<string>;
}

const millis = (value: unknown): number | null =>
  value instanceof admin.firestore.Timestamp ? value.toMillis() : null;

/** One projected scan of every wall. An ID that two walls share belongs to no one. */
export async function loadWallCensus(db: Firestore, range: {start: number; end: number}): Promise<WallCensus> {
  const owners = new Map<string, string | null>();
  const struck = new Set<string>();
  let cursor: string | undefined;
  let seen = 0;
  for (;;) {
    let query = db.collection("walls").orderBy(FieldPath.documentId())
      .select("id", "creatorUid", "review", "origin", "wallpaper_provider", "heldAt", "heldForReview").limit(PAGE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const data = doc.data();
      const creator = str(data.creatorUid);
      const heldAt = millis(data.heldAt);
      if (creator && (data.heldForReview === true || (heldAt !== null && heldAt >= range.start && heldAt < range.end))) {
        struck.add(creator);
      }
      let id: string;
      try {
        id = normalizeId(data.id);
      } catch {
        continue;
      }
      if (owners.has(id)) {
        owners.set(id, null);
        continue;
      }
      owners.set(id, creator && approvedWall(data) ? creator : null);
    }
    seen += page.size;
    if (seen > MAX_FUND_WALLS) throw new Error(`More than ${MAX_FUND_WALLS} walls.`);
    if (page.size < PAGE) break;
    cursor = page.docs[page.docs.length - 1].id;
  }
  const wallCreators = new Map<string, string>();
  for (const [id, creator] of owners) if (creator) wallCreators.set(id, creator);
  return {wallCreators, struck};
}

function chunks<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** An actor must sign in with a real provider and be this old when the week ends, like a tipper. */
export const MIN_ACTOR_AGE_MS = 7 * DAY_MS;

export interface AccountCheck {
  /** Missing, deleted, behind a closed deletion barrier, or disabled in Firebase Auth. */
  closed: Set<string>;
  /** Open, but anonymous only or younger than MIN_ACTOR_AGE_MS at `weekEnd`. */
  untrusted: Set<string>;
}

export async function loadAccounts(db: Firestore, auth: admin.auth.Auth, uids: Iterable<string>, weekEnd: number):
  Promise<AccountCheck> {
  const closed = new Set<string>();
  const untrusted = new Set<string>();
  for (const part of chunks([...new Set(uids)], GET_ALL_CHUNK)) {
    const [users, barriers, accounts] = await Promise.all([
      db.getAll(...part.map((uid) => db.collection("usersv2").doc(uid))),
      db.getAll(...part.map((uid) => db.collection("creatorDeletionState").doc(uid))),
      auth.getUsers(part.map((uid) => ({uid}))),
    ]);
    const records = new Map(accounts.users.map((user) => [user.uid, user]));
    part.forEach((uid, i) => {
      const record = records.get(uid);
      if (!users[i].exists || users[i].data()?.deleted === true || barriers[i].data()?.closed === true ||
        !record || record.disabled) {
        closed.add(uid);
        return;
      }
      const created = Date.parse(record.metadata.creationTime);
      const signedIn = record.providerData.some((provider) => !!provider.providerId && provider.providerId !== "anonymous");
      if (!signedIn || !Number.isFinite(created) || weekEnd - created < MIN_ACTOR_AGE_MS) untrusted.add(uid);
    });
  }
  return {closed, untrusted};
}

export interface FundGates {
  creatorGates: Map<string, CreatorGate>;
  excludedActors: Set<string>;
}

/**
 * Account gates for every creator and actor in the week. Team accounts never count as creators or actors. New and
 * anonymous accounts still earn as creators, but their actions do not count.
 */
export async function loadFundGates(db: Firestore, auth: admin.auth.Auth, events: FundEvent[], census: WallCensus,
  excludedUids: readonly string[], weekEnd: number): Promise<FundGates> {
  const team = new Set(excludedUids);
  const creators = new Set<string>();
  const actors = new Set<string>();
  for (const event of events) {
    const creator = census.wallCreators.get(event.wallId);
    if (creator === undefined) continue;
    creators.add(creator);
    actors.add(event.actorUid);
  }
  const {closed, untrusted} = await loadAccounts(db, auth, [...creators, ...actors], weekEnd);
  const creatorGates = new Map<string, CreatorGate>();
  for (const uid of creators) {
    creatorGates.set(uid, closed.has(uid) ? "closed" : team.has(uid) ? "team" : census.struck.has(uid) ? "moderation" : "ok");
  }
  const excludedActors = new Set<string>();
  for (const uid of actors) if (closed.has(uid) || untrusted.has(uid) || team.has(uid)) excludedActors.add(uid);
  return {creatorGates, excludedActors};
}
