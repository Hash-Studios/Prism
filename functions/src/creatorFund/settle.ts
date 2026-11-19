import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {coinTransactionDoc, db, int, str, US_REGION} from "../common";
import {type CreatorFundConfig, ECONOMY_CONFIG_DOC, parseEconomy} from "../economy";
import {notificationCopyPayload} from "../notificationCatalog";
import {isLoggedOut, notificationDocument, sendToUser} from "../notificationHelper";
import {previousWeek} from "./load";
import {checkLease, computePage} from "./compute";
import {CREATOR_FUND_RULES_VERSION} from "./score";

export const CREATOR_FUND = "creatorFund";
export const FUND_ROWS = "creators";
const PAY_BATCH = 75;
const NOTICE_BATCH = 50;
const LEASE_MS = 600_000;
const SOFT_BUDGET_MS = 240_000;

/** computing → paying → notifying → complete. Each run resumes the state it finds. */
export type WeekState = "computing" | "paying" | "notifying" | "complete";
export type SettleOutcome = "off" | "busy" | "complete" | "partial";

export const creatorFundIo = {
  economy: async (tx?: admin.firestore.Transaction): Promise<CreatorFundConfig> => {
    const ref = db.doc(ECONOMY_CONFIG_DOC);
    return parseEconomy((await (tx ? tx.get(ref) : ref.get())).data()).creatorFund;
  },
  sendToUser,
  now: () => Date.now(),
};

const uidKey = (uid: string) => encodeURIComponent(uid).replace(/_/g, "%5F");
export const fundTxId = (uid: string, week: string) => `ctx_creatorFund_${uidKey(uid)}_${week}`;
const weekRef = (week: string) => db.collection(CREATOR_FUND).doc(week);

/** Takes or renews the week lease. Creates the week only while the pool is above 0. */
async function acquire(week: string, token: string, pool: typeof creatorFundIo.economy):
  Promise<{state: WeekState; rules: CreatorFundConfig} | "off" | "busy"> {
  const ref = weekRef(week);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = creatorFundIo.now();
    const lease = admin.firestore.Timestamp.fromMillis(now + LEASE_MS);
    if (!snap.exists) {
      const config = await pool(tx);
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
    checkLease(data, token, from, creatorFundIo.now());
    tx.update(ref, {state: next, ...fields,
      ...(next === "complete" ? {lease: admin.firestore.FieldValue.delete(),
        completedAt: admin.firestore.FieldValue.serverTimestamp()} : {})});
  });
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
    const data = weekSnap.data() ?? {};
    checkLease(data, token, "paying", creatorFundIo.now());
    const accounts = await admin.auth().getUsers(uids.map((uid) => ({uid})));
    const open = new Set(accounts.users.filter((u) => !u.disabled).map((u) => u.uid));
    const snaps = await Promise.all(reads.map(async (r) => {
      const [row, ledger, user, barrier, strike] = await tx.getAll(r.row, r.ledger, r.user, r.barrier,
        r.barrier.collection("fundStrikes").doc(week),
        {fieldMask: ["payState", "status", "coins", "createdAt", "deleted", "closed", "delta", "noticeState"]});
      const held = await tx.get(db.collection("walls").where("creatorUid", "==", r.uid).where("heldForReview", "==", true).where("review", "==", false).select().limit(1));
      return {...r, struck: strike.exists || !held.empty, rowSnap: row, ledgerSnap: ledger, userSnap: user, barrierSnap: barrier};
    }));
    checkLease(data, token, "paying", creatorFundIo.now());
    const rules = parseEconomy({creatorFund: data.rules}).creatorFund;
    const at = admin.firestore.Timestamp.fromMillis(creatorFundIo.now());
    let coinsPaid = 0;
    let paidCreators = 0;
    for (const s of snaps) {
      const row = s.rowSnap.data();
      if (row?.payState !== "due") continue;
      const txId = fundTxId(s.uid, week);
      if (s.ledgerSnap.exists) {
        tx.update(s.row, {payState: "done", txId, coins: s.ledgerSnap.data()?.delta, paidAt: s.ledgerSnap.data()?.createdAt ?? at,
          noticeState: row.noticeState ?? "due"});
        continue;
      }
      const user = s.userSnap.data();
      const coins = row.coins;
      if (s.struck) {
        tx.update(s.row, {status: "notQualified", reason: "moderation", coins: 0, shareBps: 0, payState: "void"});
        continue;
      }
      if (!open.has(s.uid) || !user || user.deleted === true || s.barrierSnap.data()?.closed === true ||
        row.status !== "paid" || !Number.isSafeInteger(coins) || coins < rules.minPayout || coins > rules.perCreatorCap) {
        tx.update(s.row, {payState: "void"});
        continue;
      }
      const balance = user.coins ?? 0;
      if (!Number.isSafeInteger(balance) || balance < 0 || !Number.isSafeInteger(balance + coins)) {
        throw new Error(`Unsafe balance for Creator fund transaction ${txId}.`);
      }
      tx.update(s.user, {coins: balance + coins});
      tx.set(s.ledger, {...coinTransactionDoc({id: txId, userId: s.uid, at, delta: coins, balanceBefore: balance,
        action: "creatorFund", description: `Creator fund: ${week}`, sourceTag: "creatorFund.weekly",
        reason: `creator_fund_${week}`}), week});
      tx.update(s.row, {payState: "done", txId, paidAt: at, noticeState: "due"});
      coinsPaid += coins;
      paidCreators += 1;
    }
    if ((data.coinsPaid ?? 0) + coinsPaid > rules.pool) throw new Error("Creator fund payments exceed the frozen pool.");
    tx.update(ref, {coinsPaid: admin.firestore.FieldValue.increment(coinsPaid),
      paidCreators: admin.firestore.FieldValue.increment(paidCreators)});
    return paidCreators;
  });
}

/** One inbox item and push per paid creator. A claim before the send means a crash can drop a push, never repeat it. */
async function notify(week: string, token: string, uid: string): Promise<void> {
  const ref = weekRef(week);
  const row = ref.collection(FUND_ROWS).doc(uid);
  const claim = await db.runTransaction(async (tx) => {
    const [parent, snap, user, barrier, session] = await tx.getAll(ref, row, db.doc(`usersv2/${uid}`),
      db.doc(`creatorDeletionState/${uid}`), db.doc(`usersv2/${uid}/private/session`));
    checkLease(parent.data(), token, "notifying", creatorFundIo.now());
    const data = snap.data();
    if (data?.noticeState !== "due") return null;
    if (data.payState !== "done") throw new Error("Creator fund notice without a committed credit.");
    if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) {
      tx.update(row, {noticeState: "skipped"});
      return null;
    }
    const email = str(user.data()?.email);
    const docId = `creator_fund_${uidKey(uid)}_${week}`;
    const inbox = db.collection("notifications").doc(docId);
    if ((await tx.get(inbox)).exists) {
      tx.update(row, {noticeState: "claimed"});
      return null;
    }
    const payload = {
      ...notificationCopyPayload({kind: "creatorFundPaid", coins: int(data.coins), week}),
      data: {route: "creator_stats", url: "prism://creator-stats", notification_kind: "creator_fund"},
      modifier: email, channelId: "posts", scoreKind: "post", collapseKey: `creator_fund_${week}`, docId,
    };
    tx.set(inbox, notificationDocument(payload));
    tx.update(row, {noticeState: "claimed"});
    return {payload, recipient: {uid, email, loggedOut: isLoggedOut(user.data())}, push: session.data()?.postAlerts !== false};
  });
  if (!claim) return;
  let sent = false;
  try {
    sent = await creatorFundIo.sendToUser({...claim.payload, pushOnly: true}, claim.recipient, claim.push);
  } catch (err) {
    logger.warn("creatorFund: notice failed.", {week, err});
  }
  await db.runTransaction(async (tx) => {
    if ((await tx.get(row)).data()?.noticeState === "claimed") tx.update(row, {noticeState: sent ? "sent" : "failed"});
  });
}

/**
 * Settles one week. Safe to run again at any point: a finished week costs one read, a crashed compute resumes its page,
 * and a crashed payout resumes from the rows still due.
 */
export async function settleCreatorFundWeek(week: string): Promise<SettleOutcome> {
  const started = creatorFundIo.now();
  const token = randomUUID();
  const lease = await acquire(week, token, creatorFundIo.economy);
  if (lease === "off" || lease === "busy") return lease;
  let state = lease.state;
  if (state === "complete") return "complete";
  const rows = weekRef(week).collection(FUND_ROWS);
  const inBudget = () => creatorFundIo.now() - started < SOFT_BUDGET_MS;
  while (state === "computing" && inBudget()) {
    if (await computePage(weekRef(week), token, lease.rules, creatorFundIo.now)) state = "paying";
  }
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
    for (const doc of due.docs) {
      if (!inBudget()) break;
      await notify(week, token, doc.id);
    }
  }
  return "partial";
}

export async function scheduledWeek(ms: number): Promise<string | null> {
  const date = new Date(ms);
  if (date.getUTCDay() === 1 && date.getUTCHours() >= 6 && date.getUTCHours() <= 12) return previousWeek(ms);
  const pending = await db.collection(CREATOR_FUND).where("state", "in", ["computing", "paying", "notifying"])
    .orderBy("lease.until").limit(1).get();
  return pending.docs[0]?.id ?? null;
}

export const settleCreatorFund = onSchedule(
  {schedule: "0 * * * *", timeZone: "UTC", region: US_REGION, retryCount: 1, timeoutSeconds: 540, memory: "1GiB", cpu: "gcf_gen1"},
  async (event) => {
    const week = await scheduledWeek(Date.parse(event.scheduleTime));
    if (!week) return;
    const outcome = await settleCreatorFundWeek(week);
    logger.info("creatorFund: run finished.", {week, outcome});
  },
);
