import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {coinTransactionDoc, db, int, REGION, str} from "../common";
import {type CreatorFundConfig, ECONOMY_CONFIG_DOC, parseEconomy} from "../economy";
import {notificationCopyPayload} from "../notificationCatalog";
import {isLoggedOut, sendToUser} from "../notificationHelper";
import {loadFundGates, loadLedgerEvents, loadWallCensus, previousWeek, weekRange} from "./load";
import {computeCreatorFund, CREATOR_FUND_RULES_VERSION, type CreatorRow, type FundEvent} from "./score";

export const CREATOR_FUND = "creatorFund";
export const FUND_ROWS = "creators";
const PAY_BATCH = 100;
const ROW_BATCH = 400;
const NOTICE_BATCH = 50;
const LEASE_MS = 600_000;
const SOFT_BUDGET_MS = 240_000;

/** computing → paying → notifying → complete. Each run resumes the state it finds. */
export type WeekState = "computing" | "paying" | "notifying" | "complete";
export type SettleOutcome = "off" | "busy" | "complete" | "partial";

export const creatorFundIo = {
  economy: async (): Promise<CreatorFundConfig> =>
    parseEconomy((await db.doc(ECONOMY_CONFIG_DOC).get()).data() ?? null).creatorFund,
  events: (week: string): Promise<FundEvent[]> => loadLedgerEvents(db, week),
  census: (week: string) => loadWallCensus(db, weekRange(week)),
  gates: (events: FundEvent[], census: Awaited<ReturnType<typeof loadWallCensus>>, team: readonly string[], week: string) =>
    loadFundGates(db, admin.auth(), events, census, team, weekRange(week).end),
  sendToUser,
  now: () => Date.now(),
};

const uidKey = (uid: string) => encodeURIComponent(uid).replace(/_/g, "%5F");
export const fundTxId = (uid: string, week: string) => `ctx_creatorFund_${uidKey(uid)}_${week}`;
const weekRef = (week: string) => db.collection(CREATOR_FUND).doc(week);

function rowDoc(row: CreatorRow): Record<string, unknown> {
  const base = {scoreCenti: row.scoreCenti, distinctUsers: row.distinctUsers, capped: row.capped, shareBps: row.shareBps};
  return row.status === "paid" ?
    {...base, status: "paid", coins: row.coins, payState: "due"} :
    {...base, status: "notQualified", reason: row.reason, coins: 0, payState: "none"};
}

/** Takes or renews the week lease. Creates the week only while the pool is above 0. */
async function acquire(week: string, token: string, pool: () => Promise<CreatorFundConfig>):
  Promise<{state: WeekState; rules: CreatorFundConfig} | "off" | "busy"> {
  const config = await pool();
  const ref = weekRef(week);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = creatorFundIo.now();
    const lease = admin.firestore.Timestamp.fromMillis(now + LEASE_MS);
    if (!snap.exists) {
      if (config.pool === 0) return "off";
      tx.create(ref, {week, state: "computing", rulesVersion: CREATOR_FUND_RULES_VERSION, rules: config,
        pool: config.pool, coinsPaid: 0, paidCreators: 0, startedAt: admin.firestore.FieldValue.serverTimestamp(),
        lease: {token, until: lease}});
      return {state: "computing", rules: config};
    }
    const data = snap.data() ?? {};
    if (data.state === "complete") return {state: "complete", rules: data.rules};
    const until = data.lease?.until;
    if (until instanceof admin.firestore.Timestamp && until.toMillis() > now && data.lease?.token !== token) return "busy";
    tx.update(ref, {lease: {token, until: lease}});
    return {state: data.state as WeekState, rules: parseEconomy({creatorFund: data.rules}).creatorFund};
  });
}

/** Moves the week to `next` only while this run still holds the lease. */
async function advance(week: string, token: string, from: WeekState, next: WeekState, fields: Record<string, unknown> = {}) {
  const ref = weekRef(week);
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (data?.lease?.token !== token || data.state !== from) throw new Error(`Creator fund ${week} lease lost.`);
    tx.update(ref, {state: next, ...fields,
      ...(next === "complete" ? {lease: admin.firestore.FieldValue.delete(),
        completedAt: admin.firestore.FieldValue.serverTimestamp()} : {})});
  });
}

/** Scores the week and writes every row. Rows from a crashed earlier attempt are deleted first. */
async function compute(week: string, token: string, rules: CreatorFundConfig): Promise<void> {
  const rows = weekRef(week).collection(FUND_ROWS);
  await db.recursiveDelete(rows);
  const [events, census] = await Promise.all([creatorFundIo.events(week), creatorFundIo.census(week)]);
  const gates = await creatorFundIo.gates(events, census, rules.excludedUids, week);
  const result = computeCreatorFund({events, wallCreators: census.wallCreators, ...gates, rules});
  for (let i = 0; i < result.rows.length; i += ROW_BATCH) {
    const batch = db.batch();
    for (const row of result.rows.slice(i, i + ROW_BATCH)) batch.set(rows.doc(row.uid), rowDoc(row));
    await batch.commit();
  }
  await advance(week, token, "computing", "paying", {totals: result.totals, events: events.length,
    computedAt: admin.firestore.FieldValue.serverTimestamp()});
  logger.info("creatorFund: computed.", {week, ...result.totals, events: events.length});
}

/**
 * Pays up to PAY_BATCH due rows in one transaction. The ledger document ID is fixed per creator and week, so a row
 * whose ledger already exists is marked done without paying again.
 */
async function payBatch(week: string, token: string, uids: string[]): Promise<number> {
  const ref = weekRef(week);
  return db.runTransaction(async (tx) => {
    const reads = uids.map((uid) => ({
      uid,
      row: ref.collection(FUND_ROWS).doc(uid),
      ledger: db.collection("coinTransactions").doc(fundTxId(uid, week)),
      user: db.collection("usersv2").doc(uid),
      barrier: db.collection("creatorDeletionState").doc(uid),
    }));
    const weekSnap = await tx.get(ref);
    const snaps = await Promise.all(reads.map(async (r) => {
      const [row, ledger, user, barrier] = await tx.getAll(r.row, r.ledger, r.user, r.barrier);
      return {...r, rowSnap: row, ledgerSnap: ledger, userSnap: user, barrierSnap: barrier};
    }));
    const data = weekSnap.data();
    if (data?.lease?.token !== token || data.state !== "paying") throw new Error(`Creator fund ${week} lease lost.`);
    const cap = parseEconomy({creatorFund: data.rules}).creatorFund.perCreatorCap;
    const at = admin.firestore.Timestamp.fromMillis(creatorFundIo.now());
    let coinsPaid = 0;
    let paidCreators = 0;
    for (const s of snaps) {
      const row = s.rowSnap.data();
      if (row?.payState !== "due") continue;
      const txId = fundTxId(s.uid, week);
      if (s.ledgerSnap.exists) {
        tx.update(s.row, {payState: "done", txId, paidAt: s.ledgerSnap.data()?.createdAt ?? at});
        continue;
      }
      const user = s.userSnap.data();
      const coins = row.coins;
      if (!user || user.deleted === true || s.barrierSnap.data()?.closed === true ||
        !Number.isSafeInteger(coins) || coins < 1 || coins > cap) {
        tx.update(s.row, {payState: "void"});
        continue;
      }
      const balance = int(user.coins, 0);
      tx.update(s.user, {coins: balance + coins});
      tx.set(s.ledger, {...coinTransactionDoc({id: txId, userId: s.uid, at, delta: coins, balanceBefore: balance,
        action: "creatorFund", description: `Creator fund: ${week}`, sourceTag: "creatorFund.weekly",
        reason: `creator_fund_${week}`}), week});
      tx.update(s.row, {payState: "done", txId, paidAt: at, noticeState: "due"});
      coinsPaid += coins;
      paidCreators += 1;
    }
    tx.update(ref, {coinsPaid: admin.firestore.FieldValue.increment(coinsPaid),
      paidCreators: admin.firestore.FieldValue.increment(paidCreators)});
    return paidCreators;
  });
}

/** One inbox item and push per paid creator. A claim before the send means a crash can drop a push, never repeat it. */
async function notify(week: string, uid: string): Promise<void> {
  const row = weekRef(week).collection(FUND_ROWS).doc(uid);
  const claimed = await db.runTransaction(async (tx) => {
    const data = (await tx.get(row)).data();
    if (data?.noticeState !== "due") return null;
    tx.update(row, {noticeState: "sending"});
    return int(data.coins, 0);
  });
  if (claimed === null) return;
  let sent = false;
  try {
    const [user, session] = await Promise.all([db.doc(`usersv2/${uid}`).get(), db.doc(`usersv2/${uid}/private/session`).get()]);
    const email = str(user.data()?.email);
    sent = await creatorFundIo.sendToUser(
      {
        ...notificationCopyPayload({kind: "creatorFundPaid", coins: claimed, week}),
        data: {route: "creator_stats", url: "prism://creator-stats", notification_kind: "creator_fund"},
        modifier: email,
        channelId: "posts",
        scoreKind: "post",
        collapseKey: `creator_fund_${week}`,
        docId: `creator_fund_${uidKey(uid)}_${week}`,
      },
      {uid, email, loggedOut: isLoggedOut(user.data())},
      session.data()?.postAlerts !== false,
    );
  } catch (err) {
    logger.warn("creatorFund: notice failed.", {week, err});
  }
  await row.update({noticeState: sent ? "sent" : "failed"});
}

/**
 * Settles one week. Safe to run again at any point: a finished week costs one read, a crashed compute starts over
 * before any coin moves, and a crashed payout resumes from the rows still due.
 */
export async function settleCreatorFundWeek(week: string): Promise<SettleOutcome> {
  const started = creatorFundIo.now();
  const token = randomUUID();
  const lease = await acquire(week, token, creatorFundIo.economy);
  if (lease === "off" || lease === "busy") return lease;
  let state = lease.state;
  if (state === "complete") return "complete";
  if (state === "computing") {
    await compute(week, token, lease.rules);
    state = "paying";
  }
  const rows = weekRef(week).collection(FUND_ROWS);
  const inBudget = () => creatorFundIo.now() - started < SOFT_BUDGET_MS;
  while (state === "paying" && inBudget()) {
    const due = await rows.where("payState", "==", "due").limit(PAY_BATCH).get();
    if (due.empty) {
      await advance(week, token, "paying", "notifying");
      state = "notifying";
      break;
    }
    await payBatch(week, token, due.docs.map((doc) => doc.id));
  }
  while (state === "notifying" && inBudget()) {
    const due = await rows.where("noticeState", "==", "due").limit(NOTICE_BATCH).get();
    if (due.empty) {
      await advance(week, token, "notifying", "complete");
      return "complete";
    }
    for (const doc of due.docs) await notify(week, doc.id);
  }
  return "partial";
}

/** Hourly on Monday morning, after the week closes at 00:00 UTC. Later runs resume or do nothing. */
export const settleCreatorFund = onSchedule(
  {schedule: "0 6-12 * * 1", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540, memory: "1GiB"},
  async (event) => {
    const week = previousWeek(Date.parse(event.scheduleTime));
    const outcome = await settleCreatorFundWeek(week);
    logger.info("creatorFund: run finished.", {week, outcome});
  },
);
