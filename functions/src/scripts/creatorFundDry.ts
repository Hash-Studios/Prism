import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {db} from "../common";
import {CREATOR_FUND_METRICS, type CreatorFundConfig, ECONOMY_CONFIG_DOC, parseEconomy} from "../economy";
import {loadLegacyEvents} from "../creatorFund/legacy";
import {loadFundGates, loadLedgerEvents, loadWallCensus, previousWeek, weekRange} from "../creatorFund/load";
import {computeCreatorFund, type FundEvent} from "../creatorFund/score";

/** Read only: this script never writes. It prints hashed UIDs, never names or emails. */
export type DryArgs = {week: string; source: "auto" | "ledger" | "legacy"; pools: number[] | null; top: number};

export function parseDryArgs(argv: string[], nowMs: number): DryArgs {
  const value = (flag: string): string | undefined => {
    const i = argv.indexOf(flag);
    if (i >= 0) return argv[i + 1];
    return argv.find((arg) => arg.startsWith(`${flag}=`))?.slice(flag.length + 1);
  };
  const week = value("--week") ?? previousWeek(nowMs);
  weekRange(week);
  const source = value("--source") ?? "auto";
  if (source !== "auto" && source !== "ledger" && source !== "legacy") throw new Error("--source must be auto, ledger or legacy.");
  const poolText = value("--pool");
  const pools = poolText === undefined ? null : poolText.split(",").map(Number);
  if (pools?.some((pool) => !Number.isInteger(pool) || pool < 0 || pool > 100_000)) throw new Error("--pool must be 0..100000.");
  const top = Number(value("--top") ?? 20);
  if (!Number.isInteger(top) || top < 0) throw new Error("--top must be a whole number.");
  return {week, source, pools, top};
}

const tag = (uid: string) => createHash("sha256").update(uid).digest("hex").slice(0, 10);
const pct = (bps: number) => `${(bps / 100).toFixed(2)}%`;

async function main() {
  const args = parseDryArgs(process.argv.slice(2), Date.now());
  const range = weekRange(args.week);
  const config = parseEconomy((await db.doc(ECONOMY_CONFIG_DOC).get()).data() ?? null).creatorFund;
  let source: "ledger" | "legacy" = args.source === "legacy" ? "legacy" : "ledger";
  let events: FundEvent[] = source === "ledger" ? await loadLedgerEvents(db, args.week) : [];
  let modes: Record<string, string> = {};
  if (args.source === "legacy" || (args.source === "auto" && events.length === 0)) {
    source = "legacy";
    ({events, modes} = await loadLegacyEvents(db, range));
  }
  const census = await loadWallCensus(db, range);
  const gates = await loadFundGates(db, admin.auth(), events, census, config.excludedUids, range.end);

  const perMetric = Object.fromEntries(CREATOR_FUND_METRICS.map((m) => [m, events.filter((e) => e.metric === m).length]));
  const onEligible = events.filter((e) => census.wallCreators.has(e.wallId));
  const self = onEligible.filter((e) => census.wallCreators.get(e.wallId) === e.actorUid).length;
  const gateCounts: Record<string, number> = {};
  for (const gate of gates.creatorGates.values()) gateCounts[gate] = (gateCounts[gate] ?? 0) + 1;
  console.log(JSON.stringify({week: args.week, source, modes, rules: config, events: events.length, perMetric,
    eventsOnEligibleWalls: onEligible.length, selfActions: self, eligibleWalls: census.wallCreators.size,
    struckCreators: census.struck.size, creatorGates: gateCounts, excludedActors: gates.excludedActors.size,
    actors: new Set(onEligible.map((e) => e.actorUid)).size}, null, 2));

  const pools = args.pools ?? [config.pool];
  for (const pool of pools) {
    const rules: CreatorFundConfig = {...config, pool};
    const result = computeCreatorFund({events, wallCreators: census.wallCreators, ...gates, rules});
    const reasons: Record<string, number> = {};
    for (const row of result.rows) if (row.status === "notQualified") reasons[row.reason] = (reasons[row.reason] ?? 0) + 1;
    const coins = result.rows.flatMap((row) => row.status === "paid" ? [row.coins] : []).sort((a, b) => b - a);
    console.log(`\npool ${pool}: ${JSON.stringify({...result.totals, notQualified: reasons,
      atCap: coins.filter((c) => c === rules.perCreatorCap).length,
      medianPaid: coins.length ? coins[Math.floor(coins.length / 2)] : 0})}`);
    const rows = [...result.rows].sort((a, b) => b.scoreCenti - a.scoreCenti).slice(0, args.top);
    console.table(rows.map((row) => ({creator: tag(row.uid), status: row.status === "paid" ? "paid" : row.reason,
      users: row.distinctUsers, score: row.scoreCenti / 100, share: pct(row.shareBps),
      coins: row.status === "paid" ? row.coins : 0, capped: row.capped})));
  }
  console.log("\nRead only. Nothing was written.");
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
