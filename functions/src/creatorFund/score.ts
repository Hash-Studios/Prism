import type {CreatorFundConfig, CreatorFundMetric} from "../economy";

/** Bump when the scoring or payout rules change, so each week records the rules that paid it. */
export const CREATOR_FUND_RULES_VERSION = 1;

/** One server-recorded action by one user on one wall. `wallId` is the normalized wall ID. */
export interface FundEvent {
  wallId: string;
  metric: CreatorFundMetric;
  actorUid: string;
}

/**
 * Why a creator with engagement gets no row (`closed`) or an unpaid row. `closed` is a deleted, deletion-barred,
 * missing, or disabled account.
 */
export type CreatorGate = "ok" | "team" | "moderation" | "closed";

export type NotQualifiedReason = "fewUsers" | "smallShare" | "moderation" | "team";

interface RowBase {
  uid: string;
  /** Capped score in hundredths of a point, so the per-user cap stays an exact integer. */
  scoreCenti: number;
  distinctUsers: number;
  capped: boolean;
}

export type CreatorRow =
  | RowBase & {status: "paid"; coins: number; shareBps: number}
  | RowBase & {status: "notQualified"; reason: NotQualifiedReason; shareBps: number};

export interface FundTotals {
  creators: number;
  qualified: number;
  paid: number;
  coins: number;
  unpaid: number;
  scoreCenti: number;
}

export interface FundInput {
  events: Iterable<FundEvent>;
  /** Eligible walls only: approved, one owner per normalized ID, not Studio. Keyed by normalized wall ID. */
  wallCreators: ReadonlyMap<string, string>;
  /** A gate for every creator in `wallCreators`. A missing gate counts as closed. */
  creatorGates: ReadonlyMap<string, CreatorGate>;
  /** Actors whose actions never count: closed accounts and Prism team accounts. */
  excludedActors: ReadonlySet<string>;
  rules: CreatorFundConfig;
}

export interface FundResult {
  rows: CreatorRow[];
  totals: FundTotals;
}

/** Contribution of each actor per creator, after exclusions and dedupe. */
function contributions(input: FundInput): Map<string, Map<string, number>> {
  const seen = new Set<string>();
  const byCreator = new Map<string, Map<string, number>>();
  for (const event of input.events) {
    const creator = input.wallCreators.get(event.wallId);
    if (creator === undefined || event.actorUid === creator || input.excludedActors.has(event.actorUid)) continue;
    if ((input.creatorGates.get(creator) ?? "closed") === "closed") continue;
    const key = JSON.stringify([event.wallId, event.metric, event.actorUid]);
    if (seen.has(key)) continue;
    seen.add(key);
    const weight = input.rules.weights[event.metric];
    const actors = byCreator.get(creator) ?? new Map<string, number>();
    actors.set(event.actorUid, (actors.get(event.actorUid) ?? 0) + weight * 100);
    byCreator.set(creator, actors);
  }
  return byCreator;
}

/** Raw score, then each actor capped at `maxUserSharePercent` of that raw score. */
function cappedScore(actors: Map<string, number>, maxUserSharePercent: number): {scoreCenti: number; capped: boolean} {
  let raw = 0;
  for (const value of actors.values()) raw += value;
  const cap = raw * maxUserSharePercent / 100;
  let scoreCenti = 0;
  let capped = false;
  for (const value of actors.values()) {
    if (value > cap) capped = true;
    scoreCenti += Math.min(value, cap);
  }
  return {scoreCenti: Math.floor(scoreCenti), capped};
}

const bps = (part: number, total: number): number => total > 0 ? Number(BigInt(part) * BigInt(10_000) / BigInt(total)) : 0;

/**
 * Splits the pool by score share. Coins are floored, capped per creator, and dropped below the minimum payout.
 * Coins that are not paid stay unpaid. Pure: the same input always gives the same rows in uid order.
 */
export function computeCreatorFund(input: FundInput): FundResult {
  const {rules} = input;
  const scored = [...contributions(input)].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([uid, actors]) => {
    const distinctUsers = [...actors.values()].filter((value) => value > 0).length;
    return {uid, distinctUsers, gate: input.creatorGates.get(uid) ?? "closed", ...cappedScore(actors, rules.maxUserSharePercent)};
  });
  const qualifies = (row: typeof scored[number]) =>
    row.gate === "ok" && row.distinctUsers >= rules.minDistinctUsers && row.scoreCenti > 0;
  const totalCenti = scored.filter(qualifies).reduce((sum, row) => sum + row.scoreCenti, 0);

  const rows: CreatorRow[] = scored.map((row) => {
    const base = {uid: row.uid, scoreCenti: row.scoreCenti, distinctUsers: row.distinctUsers, capped: row.capped};
    if (row.gate === "team" || row.gate === "moderation") return {...base, status: "notQualified", reason: row.gate, shareBps: 0};
    if (!qualifies(row)) return {...base, status: "notQualified", reason: "fewUsers", shareBps: 0};
    const shareBps = bps(row.scoreCenti, totalCenti);
    const coins = Math.min(Number(BigInt(rules.pool) * BigInt(row.scoreCenti) / BigInt(totalCenti)), rules.perCreatorCap);
    if (coins < rules.minPayout) return {...base, status: "notQualified", reason: "smallShare", shareBps};
    return {...base, status: "paid", coins, shareBps};
  });

  const paidRows = rows.filter((row) => row.status === "paid");
  const coins = paidRows.reduce((sum, row) => sum + (row.status === "paid" ? row.coins : 0), 0);
  return {
    rows,
    totals: {
      creators: rows.length,
      qualified: scored.filter(qualifies).length,
      paid: paidRows.length,
      coins,
      unpaid: rules.pool - coins,
      scoreCenti: totalCenti,
    },
  };
}
