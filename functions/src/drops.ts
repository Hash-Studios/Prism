import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {coinTransactionDoc, db, int, REGION, str} from "./common";
import {isValidRequestId} from "./coinsCallables";
import {loadEconomy, proPrice, weekBounds, weekKey} from "./economy";
import {sendNotification} from "./notificationHelper";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const MIN_DROP_WALLS = 4;
const MAX_DROP_WALLS = 10;
const WEEK_KEY = /^\d{4}-W\d{2}$/;
const RELEASE_AFTER_MS = 30 * 86_400_000;
const WALL_ID = /^[A-Za-z0-9_-]{1,128}$/;
const HOUR_MS = 3_600_000;

export interface DropWall {
  id: string;
  title: string;
  thumb: string;
  resolution: string;
  by: string;
  seriesId: string;
}

export interface DropDoc {
  weekKey: string;
  title: string;
  startsAt: number;
  endsAt: number;
  priceWall: number;
  pricePack: number;
  count: number;
  walls: DropWall[];
  pushes?: Partial<Record<DropPushKind, number>>;
  pushClaims?: Partial<Record<DropPushKind, number>>;
}

export interface UnlockedWall {
  id: string;
  url: string;
}

/** The drop fields a client may see: no full image url. */
export function snapshotWall(doc: {id: string; data: () => admin.firestore.DocumentData | undefined}): DropWall {
  const data = doc.data() ?? {};
  return {
    id: doc.id,
    title: str(data.title),
    thumb: str(data.wallpaper_thumb),
    resolution: str(data.resolution),
    by: str(data.by),
    seriesId: str(data.seriesId),
  };
}

export function isDropLive(drop: {startsAt?: unknown; endsAt?: unknown}, nowMs: number): boolean {
  return typeof drop.startsAt === "number" && typeof drop.endsAt === "number" &&
    drop.startsAt <= nowMs && nowMs < drop.endsAt;
}

/** Pack price before the Pro discount. A pack never costs more than buying the rest one by one. */
export function packPrice(priceWall: number, pricePack: number, remaining: number): number {
  return Math.min(pricePack, remaining * priceWall);
}

/** Puts the walls of drops that ended over 30 days ago in the public feed. Returns the drops released. */
export async function releaseOldDrops(nowMs: number): Promise<number> {
  const old = await db.collection("drops").where("endsAt", "<", nowMs - RELEASE_AFTER_MS).get();
  let released = 0;
  for (const doc of old.docs.filter((d) => d.data().released !== true)) {
    const walls = Array.isArray(doc.data().walls) ? (doc.data().walls as Array<{id?: unknown}>) : [];
    const refs = walls.map((w) => str(w.id)).filter((id) => WALL_ID.test(id))
      .map((id) => db.collection("walls").doc(id));
    await db.runTransaction(async (tx) => {
      const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
      for (const snap of snaps) if (snap.exists) tx.update(snap.ref, {review: true});
      tx.update(doc.ref, {released: true});
    });
    released += 1;
  }
  if (released > 0) logger.info("drops: released", {count: released});
  return released;
}

export const planWeeklyDrop = onSchedule(
  {schedule: "30 0 * * 1", region: REGION, timeZone: "UTC", retryCount: 1},
  async () => {
    const nowMs = Date.now();
    await releaseOldDrops(nowMs);
    const key = weekKey(nowMs);
    const dropRef = db.collection("drops").doc(key);
    if ((await dropRef.get()).exists) return;

    const reserved = await db.collection("walls")
      .where("dropReserved", "==", true)
      .where("review", "==", false)
      .orderBy("createdAt", "asc")
      .limit(MAX_DROP_WALLS)
      .get();
    const docs = reserved.docs.filter((doc) => doc.data().origin === "studio");
    if (docs.length < MIN_DROP_WALLS) {
      logger.info("drops: not enough reserved walls", {weekKey: key, count: docs.length});
      return;
    }

    const config = await loadEconomy(nowMs);
    const titleSnap = await db.doc("studioConfig/current").get();
    const titles = titleSnap.data()?.dropTitles;
    const custom = titles && typeof titles === "object" ? str((titles as Record<string, unknown>)[key]) : "";
    const {start, end} = weekBounds(nowMs);
    const drop: DropDoc & {createdAt: admin.firestore.FieldValue} = {
      weekKey: key,
      title: custom || `Drop ${key}`,
      startsAt: start,
      endsAt: end,
      priceWall: config.spend.dropWall,
      pricePack: config.spend.dropPack,
      count: docs.length,
      walls: docs.map(snapshotWall),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const planned = await db.runTransaction(async (tx) => {
      if ((await tx.get(dropRef)).exists) return false;
      tx.set(dropRef, drop);
      for (const doc of docs) tx.update(doc.ref, {dropReserved: false, dropWeek: key});
      return true;
    });
    if (planned) logger.info("drops: planned", {weekKey: key, count: docs.length});
  },
);

const priceOr = (value: unknown, fallback: number): number => {
  const n = int(value, fallback);
  return n >= 0 ? n : fallback;
};

export const unlockDrop = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<{weekKey?: unknown; wallId?: unknown; requestId?: unknown}>) => {
    const uid = request.auth?.uid?.trim() ?? "";
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");
    const {requestId} = request.data ?? {};
    const dropKey = request.data?.weekKey;
    const wallId = request.data?.wallId ?? null;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    if (typeof dropKey !== "string" || !WEEK_KEY.test(dropKey)) {
      throw new HttpsError("invalid-argument", "weekKey is invalid.");
    }
    if (wallId !== null && (typeof wallId !== "string" || !WALL_ID.test(wallId))) {
      throw new HttpsError("invalid-argument", "wallId is invalid.");
    }

    const config = await loadEconomy();
    const userRef = db.collection(USERS).doc(uid);
    const privateRef = userRef.collection("private").doc("economy");
    const dropRef = db.collection("drops").doc(dropKey);
    const txId = `ctx_drop_${uid}_${requestId}`;
    const txRef = db.collection(TRANSACTIONS).doc(txId);
    const skipped = (reason: string, extra: Record<string, unknown> = {}) => ({
      success: false,
      changed: false,
      previousBalance: 0,
      currentBalance: 0,
      delta: 0,
      reason,
      transactionId: "",
      unlocked: [] as UnlockedWall[],
      weekKey: dropKey,
      ...extra,
    });
    let response: Record<string, unknown> = skipped("drop_unlock");

    await db.runTransaction(async (tx) => {
      const [txSnap, userSnap, privateSnap, dropSnap] = await Promise.all([
        tx.get(txRef), tx.get(userRef), tx.get(privateRef), tx.get(dropRef),
      ]);
      if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const user = userSnap.data() ?? {};
      const balance = int(user.coins, 0);
      const current = {previousBalance: balance, currentBalance: balance};

      if (txSnap.exists) {
        const stored = txSnap.data() ?? {};
        response = {
          ...skipped("duplicate", current),
          success: true,
          previousBalance: int(stored.balanceBefore, balance),
          currentBalance: int(stored.balanceAfter, balance),
          delta: int(stored.delta, 0),
          transactionId: txId,
          unlocked: Array.isArray(stored.unlocked) ? stored.unlocked : [],
          weekKey: str(stored.weekKey) || dropKey,
        };
        return;
      }
      if (!config.flags.dropsEnabled) {
        response = skipped("drops_disabled", current);
        return;
      }
      const nowMs = Date.now();
      const drop = dropSnap.data() as Partial<DropDoc> | undefined;
      if (!drop || !isDropLive(drop, nowMs)) {
        response = skipped("drop_not_live", current);
        return;
      }
      const dropWalls = Array.isArray(drop.walls) ? drop.walls : [];
      if (wallId !== null && !dropWalls.some((w) => w.id === wallId)) {
        response = skipped("drop_wall_unknown", current);
        return;
      }

      const privateData = privateSnap.data() ?? {};
      const owned = (privateData.drops?.unlocked ?? {}) as Record<string, {url?: unknown}>;
      const remaining = dropWalls.filter((w) => !owned[w.id]).map((w) => w.id);
      if (wallId !== null && owned[wallId]) {
        response = {
          ...skipped("drop_wall_already_unlocked", current),
          success: true,
          unlocked: [{id: wallId, url: str(owned[wallId].url)}],
        };
        return;
      }
      const targets = wallId !== null ? [wallId] : remaining;
      if (targets.length === 0) {
        response = {...skipped("drop_pack_nothing_left", current), success: true};
        return;
      }

      const wallSnaps = await Promise.all(targets.map((id) => tx.get(db.collection("walls").doc(id))));
      const unlocked: UnlockedWall[] = targets.map((id, i) => ({id, url: str(wallSnaps[i].data()?.wallpaper_url)}));
      if (unlocked.some((w) => w.url === "")) {
        response = skipped("drop_wall_unavailable", current);
        return;
      }

      const priceWall = priceOr(drop.priceWall, config.spend.dropWall);
      const pricePack = priceOr(drop.pricePack, config.spend.dropPack);
      const action = wallId !== null ? "dropWall" : "dropPack";
      const base = wallId !== null ? priceWall : packPrice(priceWall, pricePack, targets.length);
      const price = proPrice(base, user.premium === true);
      if (balance < price) {
        response = {...skipped(`${action}_insufficient_balance`, current), insufficientBalance: true};
        return;
      }

      const firstOfDrop = !Object.values(owned).some((entry) => (entry as {weekKey?: unknown}).weekKey === dropKey);
      const after = balance - price;
      const rev = int(privateData.rev, 0) + 1;
      tx.update(userRef, {coins: after});
      if (firstOfDrop) tx.update(dropRef, {collectors: admin.firestore.FieldValue.increment(1)});
      if (privateSnap.exists) {
        const fields: Record<string, unknown> = {rev};
        for (const w of unlocked) fields[`drops.unlocked.${w.id}`] = {weekKey: dropKey, url: w.url};
        tx.update(privateRef, fields);
      } else {
        const entries = Object.fromEntries(unlocked.map((w) => [w.id, {weekKey: dropKey, url: w.url}]));
        tx.set(privateRef, {rev, drops: {unlocked: entries}}, {merge: true});
      }
      tx.set(txRef, {
        ...coinTransactionDoc({
          id: txId,
          userId: uid,
          at: admin.firestore.Timestamp.now(),
          delta: -price,
          balanceBefore: balance,
          action,
          description: wallId !== null ? "Weekly Drop wallpaper" : "Weekly Drop pack",
          sourceTag: "drops.unlock.callable",
          reason: `drop_${dropKey}`,
        }),
        unlocked,
        weekKey: dropKey,
      });
      response = {
        ...skipped("drop_unlock"),
        success: true,
        changed: true,
        previousBalance: balance,
        currentBalance: after,
        delta: -price,
        transactionId: txId,
        unlocked,
      };
    });
    return response;
  },
);

export type DropPushKind = "live" | "lastCall";

interface DropPushSpec {
  kind: DropPushKind;
  isDue: (drop: DropDoc, nowMs: number) => boolean;
  supersededBy?: DropPushKind;
  title: string;
  body: (drop: DropDoc, nowMs: number) => string;
}

export const DROP_PUSHES: readonly DropPushSpec[] = [
  {
    kind: "live",
    isDue: (drop, nowMs) => nowMs >= drop.startsAt + 4 * HOUR_MS,
    supersededBy: "lastCall",
    title: "A new Drop is live",
    body: (drop) => `${drop.count} walls, this week only. Preview them before they are gone.`,
  },
  {
    kind: "lastCall",
    isDue: (drop, nowMs) => drop.endsAt - nowMs <= 12 * HOUR_MS,
    title: "Last call on this week's Drop",
    body: (drop, nowMs) => {
      const hours = Math.max(1, Math.floor((drop.endsAt - nowMs) / HOUR_MS));
      return `${drop.title} ends in ${hours} ${hours === 1 ? "hour" : "hours"}. Then these walls are gone for a month.`;
    },
  },
];

/** Push kinds due now and not yet sent. A due kind hides the kind it supersedes, so a late run sends only the last call. */
export function duePushKinds(drop: DropDoc, nowMs: number): DropPushKind[] {
  const due = DROP_PUSHES.filter((spec) => spec.isDue(drop, nowMs));
  return due
    .filter((spec) => !due.some((other) => other.kind === spec.supersededBy))
    .map((spec) => spec.kind)
    .filter((kind) => drop.pushes?.[kind] === undefined);
}

const CLAIM_TTL_MS = 15 * 60 * 1000;

async function claimPush(dropRef: admin.firestore.DocumentReference, kind: DropPushKind, nowMs: number) {
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(dropRef)).data();
    if (data?.pushes?.[kind] !== undefined) return false;
    const claimedAt = data?.pushClaims?.[kind];
    if (typeof claimedAt === "number" && nowMs - claimedAt < CLAIM_TTL_MS) return false;
    tx.update(dropRef, {[`pushClaims.${kind}`]: nowMs});
    return true;
  });
}

async function markPushSent(dropRef: admin.firestore.DocumentReference, kind: DropPushKind, nowMs: number) {
  await dropRef.update({
    [`pushes.${kind}`]: nowMs,
    [`pushClaims.${kind}`]: admin.firestore.FieldValue.delete(),
  });
}

async function releasePush(dropRef: admin.firestore.DocumentReference, kind: DropPushKind, claimedAt: number) {
  await db.runTransaction(async (tx) => {
    const claims = (await tx.get(dropRef)).data()?.pushClaims as Record<string, unknown> | undefined;
    if (claims?.[kind] !== claimedAt) return;
    tx.update(dropRef, {[`pushClaims.${kind}`]: admin.firestore.FieldValue.delete()});
  });
}

/**
 * Sends each due push of the live drop. A failed send frees its claim and throws, so the scheduler retries.
 * A run that dies mid-send leaves a stale claim that expires, so a later run resends. The fixed docId and
 * collapseKey make that resend collapse on the device and overwrite one inbox doc.
 */
export async function sendDuePushes(nowMs: number): Promise<DropPushKind[]> {
  const config = await loadEconomy(nowMs);
  if (!config.flags.dropsEnabled) return [];
  const found = await db.collection("drops").where("endsAt", ">", nowMs).orderBy("endsAt", "asc").limit(1).get();
  const dropSnap = found.docs[0];
  const drop = dropSnap?.data() as DropDoc | undefined;
  if (!dropSnap || !drop || !isDropLive(drop, nowMs)) return [];

  const weekKeyOfDrop = str(drop.weekKey) || dropSnap.id;
  const sent: DropPushKind[] = [];
  for (const kind of duePushKinds(drop, nowMs)) {
    if (!await claimPush(dropSnap.ref, kind, nowMs)) continue;
    const spec = DROP_PUSHES.find((s) => s.kind === kind) as DropPushSpec;
    let delivered = false;
    try {
      delivered = await sendNotification({
        title: spec.title,
        body: spec.body(drop, nowMs),
        data: {route: "drops", week_key: weekKeyOfDrop},
        imageUrl: drop.walls?.[0]?.thumb || undefined,
        modifier: "all",
        channelId: "drops",
        fcmTarget: {topic: "drops"},
        collapseKey: `drop_${kind}_${weekKeyOfDrop}`,
        docId: `drop_${kind}_${weekKeyOfDrop}`,
        scoreKind: "drop",
      });
    } finally {
      if (!delivered) await releasePush(dropSnap.ref, kind, nowMs);
    }
    if (!delivered) throw new Error(`Drop ${kind} push failed for ${weekKeyOfDrop}.`);
    await markPushSent(dropSnap.ref, kind, nowMs);
    sent.push(kind);
    logger.info("drops: push sent", {weekKey: weekKeyOfDrop, kind});
  }
  return sent;
}

export const sendDropPushes = onSchedule(
  {schedule: "30 * * * *", region: REGION, timeZone: "UTC", retryCount: 1},
  async () => {
    await sendDuePushes(Date.now());
  },
);
