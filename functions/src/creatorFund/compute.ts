import * as admin from "firebase-admin";
import {FieldPath, type Transaction} from "firebase-admin/firestore";
import {db, str} from "../common";
import {hash} from "../creatorStatsHistory";
import {approvedWall} from "../creatorProgress";
import {type CreatorFundConfig} from "../economy";
import {normalizeId} from "../viewStats";
import {FUND_EVENTS, FUND_RETENTION_MS, fundWallStamp, ledgerEvent} from "./events";
import {heldInWeek, loadAccounts, MAX_FUND_EVENTS, MAX_FUND_WALLS, weekRange} from "./load";
import {allocateRow, actorScoreCenti, qualifies, type CreatorGate, type FundTotals} from "./score";

const EMPTY: FundTotals = {creators: 0, qualified: 0, paid: 0, coins: 0, unpaid: 0, scoreCenti: 0};
const idField = FieldPath.documentId();
type Ref = admin.firestore.DocumentReference;
type Data = admin.firestore.DocumentData;

async function documents(tx: Transaction, refs: Ref[], fields?: string[]) {
  const docs = refs.length ? await tx.getAll(...refs, ...(fields ? [{fieldMask: fields}] : [])) : [];
  return new Map(docs.map((doc) => [doc.ref.path, doc]));
}

function page(query: admin.firestore.Query, size: number, cursor?: string) {
  const ordered = query.orderBy(idField).limit(size);
  return cursor ? ordered.startAfter(cursor) : ordered;
}

export function checkLease(data: Data | undefined, token: string, phase: string, now: number) {
  if (data?.lease?.token !== token || data?.state !== phase ||
      !(data.lease.until instanceof admin.firestore.Timestamp) || data.lease.until.toMillis() <= now) {
    throw new Error("Creator fund lease lost.");
  }
}

/** The cursor and every effect of its page commit together. No replay can add a contribution twice. */
export async function computePage(ref: Ref, token: string, rules: CreatorFundConfig, now: () => number): Promise<boolean> {
  const index = ref.collection("fundIndex");
  const pairs = ref.collection("fundPairs");
  const rows = ref.collection("creators");
  const range = weekRange(ref.id);
  return db.runTransaction(async (tx) => {
    const state = (await tx.get(ref)).data() ?? {};
    checkLease(state, token, "computing", now());
    const phase = state.phase ?? "clear";
    const cursor = state.cursor;
    function next(field: string, docs: admin.firestore.QuerySnapshot, size: number, more: string, extra: Data = {}) {
      tx.update(ref, {phase: docs.size === size ? field : more, cursor: docs.size === size ? docs.docs.at(-1)?.id : null, ...extra});
    }

    if (phase === "clear" || phase === "prune") {
      const docs = await tx.get((phase === "clear" ? rows : index).limit(400));
      docs.docs.forEach((doc) => tx.delete(doc.ref));
      if (docs.size < 400) {
        if (phase === "clear") tx.update(ref, {phase: "walls", cursor: null});
        else {
          tx.update(ref, {phase: admin.firestore.FieldValue.delete(), cursor: admin.firestore.FieldValue.delete(),
            state: "paying", computedAt: admin.firestore.FieldValue.serverTimestamp()});
        }
        return phase === "prune";
      }
      return false;
    }
    if (phase === "walls") {
      const size = 100;
      const docs = await tx.get(page(db.collection("walls").select("id", "creatorUid", "review", "origin",
        "wallpaper_provider", "heldAt", "heldForReview"), size, cursor));
      const walls = new Map<string, Data>();
      const struck = new Set<string>();
      for (const doc of docs.docs) {
        const wall = doc.data();
        if (wall.creatorUid && heldInWeek(wall, range)) struck.add(hash(wall.creatorUid));
        let key: string;
        try {
          key = hash(normalizeId(wall.id));
        } catch {
          continue;
        }
        walls.set(key, walls.has(key) || !approvedWall(wall) ? {} : {wall: doc.id, stamp: fundWallStamp(doc)});
      }
      const existing = await documents(tx, [...walls.keys()].map((key) => index.doc(key)));
      for (const [key, data] of walls) {
        const target = index.doc(key);
        tx.set(target, existing.get(target.path)?.exists ? {} : data);
      }
      for (const key of struck) tx.set(index.doc(`strike_${key}`), {held: true});
      const count = (state.walls ?? 0) + docs.size;
      if (count > MAX_FUND_WALLS) throw new Error("Creator fund wall capacity exceeded.");
      next(phase, docs, size, "events", {walls: count});
    } else if (phase === "events") {
      if (now() >= range.start + FUND_RETENTION_MS) throw new Error("Creator fund source events may have expired.");
      const size = 40;
      const docs = await tx.get(page(db.collection(FUND_EVENTS).where("week", "==", ref.id)
        .select("wallId", "actorUid", "metric", "wallStamp", "resolveAt"), size, cursor));
      const ledger = docs.docs.map((doc) => ledgerEvent(doc, ref.id)).filter((e) => e !== null);
      const ids = new Set(ledger.map((event) => event.wallId));
      const identities = await documents(tx, [...ids].map((id) => index.doc(hash(id))));
      const wallIds = new Set([...identities.values()].map((doc) => doc.data()?.wall).filter(Boolean));
      const walls = await documents(tx, [...wallIds].map((id) => db.collection("walls").doc(id)),
        ["id", "creatorUid", "origin", "wallpaper_provider", "review"]);
      const events = ledger.flatMap(({wallId, actorUid, metric, wallStamp, resolveAt}) => {
        const identity = identities.get(index.doc(hash(wallId)).path)?.data();
        const wall = identity?.wall ? walls.get(`walls/${identity.wall}`) : undefined;
        const data = wall?.data();
        if (!wall || !data || !approvedWall(data) || identity?.stamp !== fundWallStamp(wall) ||
          (resolveAt !== undefined && !(resolveAt >= (wall.updateTime?.toMillis() ?? Infinity))) ||
          (wallStamp && wallStamp !== identity.stamp)) return [];
        const uid = str(data.creatorUid);
        return uid && !uid.includes("/") && uid.length <= 128 && uid !== actorUid && !rules.excludedUids.includes(actorUid) ? [{uid, actorUid, metric}] : [];
      });
      const accounts = await loadAccounts(db, admin.auth(), events.flatMap((e) => [e.uid, e.actorUid]), range.end, tx);
      const changes = new Map<string, {uid: string; weight: number}>();
      for (const {uid, actorUid, metric} of events) {
        if (accounts.closed.has(uid) || accounts.closed.has(actorUid) || accounts.untrusted.has(actorUid)) continue;
        const key = hash(JSON.stringify([uid, actorUid]));
        changes.set(key, {uid, weight: (changes.get(key)?.weight ?? 0) + rules.weights[metric]});
      }
      const creators = new Set([...changes.values()].map((c) => c.uid));
      const existing = await documents(tx, [...changes.keys()].map((key) => pairs.doc(key)));
      const strikes = await documents(tx, [...creators].flatMap((uid) => [index.doc(`strike_${hash(uid)}`),
        db.doc(`creatorDeletionState/${uid}/fundStrikes/${ref.id}`)]));
      const sums = new Map<string, {raw: number; users: number}>();
      for (const [key, {uid, weight}] of changes) {
        const target = pairs.doc(key);
        const previous = existing.get(target.path)?.data()?.weight ?? 0;
        tx.set(target, {uid, weight: previous + weight});
        const sum = sums.get(uid) ?? {raw: 0, users: 0};
        sum.raw += weight;
        if (!previous && weight) sum.users++;
        sums.set(uid, sum);
      }
      for (const [uid, {raw, users}] of sums) {
        const struck = strikes.get(index.doc(`strike_${hash(uid)}`).path)?.exists ||
          strikes.get(`creatorDeletionState/${uid}/fundStrikes/${ref.id}`)?.exists;
        tx.set(rows.doc(uid), {uid, raw: admin.firestore.FieldValue.increment(raw),
          distinctUsers: admin.firestore.FieldValue.increment(users), gate: rules.excludedUids.includes(uid) ? "team" :
            struck ? "moderation" : "ok"}, {merge: true});
      }
      const count = (state.events ?? 0) + docs.size;
      if (count > MAX_FUND_EVENTS) throw new Error("Creator fund event capacity exceeded.");
      next(phase, docs, size, "caps", {events: count});
    } else if (phase === "caps") {
      const docs = await tx.get(pairs.limit(180));
      const uids = new Set(docs.docs.map((doc) => doc.data().uid as string));
      const creators = await documents(tx, [...uids].map((uid) => rows.doc(uid)));
      const sums = new Map<string, {score: number; capped: boolean}>();
      for (const doc of docs.docs) {
        const {uid, weight} = doc.data();
        tx.delete(doc.ref);
        const row = creators.get(rows.doc(uid).path)?.data();
        if (!row) continue;
        const score = actorScoreCenti(weight, row.raw, rules.maxUserSharePercent);
        const sum = sums.get(uid) ?? {score: 0, capped: false};
        sum.score += score;
        sum.capped ||= weight * 100 > score;
        sums.set(uid, sum);
      }
      for (const [uid, {score, capped}] of sums) {
        tx.update(rows.doc(uid),
          {scoreCenti: admin.firestore.FieldValue.increment(score), ...(capped ? {capped} : {})});
      }
      if (docs.size < 180) tx.update(ref, {phase: "sum", cursor: null, totals: {...EMPTY, unpaid: rules.pool}});
    } else if (phase === "sum" || phase === "allocate") {
      const size = 400;
      const docs = await tx.get(page(rows, size, cursor));
      const totals: FundTotals = {...state.totals};
      for (const doc of docs.docs) {
        const data = doc.data();
        if (phase === "sum") {
          totals.creators++;
          if (qualifies(data.gate, data.distinctUsers, data.scoreCenti, rules)) {
            totals.qualified++;
            totals.scoreCenti += data.scoreCenti;
          }
        } else {
          const row = allocateRow({uid: doc.id, gate: data.gate as CreatorGate, scoreCenti: data.scoreCenti,
            distinctUsers: data.distinctUsers, capped: !!data.capped}, totals.scoreCenti, rules);
          if (row.status === "paid") {
            totals.paid++; totals.coins += row.coins; totals.unpaid -= row.coins;
          }
          tx.set(doc.ref, row.status === "paid" ? {...row, payState: "due"} : {...row, payState: "none", coins: 0});
        }
      }
      next(phase, docs, size, phase === "sum" ? "allocate" : "prune", {totals});
    } else {
      throw new Error(`Unknown creator fund compute phase: ${phase}`);
    }
    return false;
  });
}
