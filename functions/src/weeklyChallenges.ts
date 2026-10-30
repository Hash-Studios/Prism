import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {onDocumentCreatedWithAuthContext, onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {CALLABLE_REGIONS, db, int, REGION, str} from "./common";
import {publicRequestText} from "./wallRequests";
import {isWotdEligible, pickWallOfTheDay, premiumCollections, readyWall} from "./wallOfTheDay";
import {r2Secrets} from "./r2Storage";
import {sendToUser} from "./notificationHelper";
import {notificationCopyPayload} from "./notificationCatalog";

const DAY = 86_400_000;
const WEEK = 7 * DAY;
const PAGE = 200;
const stamp = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const challenges = () => db.collection("weeklyChallenges");
const entryRef = (id: string, entry: string) => challenges().doc(id).collection("entries").doc(entry);
const admissions = (id: string) => challenges().doc(id).collection("admissions");
const reservationRef = (day: string) => db.doc(`challengeWotdReservations/${day}`);
type Data = admin.firestore.DocumentData;
type Snap = admin.firestore.DocumentSnapshot;
type Tx = admin.firestore.Transaction;
export type ChallengeState = "scheduled" | "open" | "voting_closed" | "winner_picked" | "archived";
export type EntryView = {id: string; wallId: string; wallLogicalId: string; creatorUid: string; creatorName: string;
  thumbUrl: string; title: string; voteCount: number; approvedAtMs: number; voted: boolean; mine: boolean};
export type ChallengeView = {id: string; theme: string; state: ChallengeState; opensAtMs: number; closesAtMs: number;
  winner: EntryView | null; reservedDate: string | null; noWinner: boolean};

export const challengeIo = {
  owner: async (uid: string) => admin.auth().getUser(uid),
  ready: readyWall,
  premium: premiumCollections,
  send: sendToUser,
};

function id(raw: unknown): string {
  if (typeof raw !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(raw)) {
    throw new HttpsError("invalid-argument", "Invalid challenge or entry ID.");
  }
  return raw;
}
function millis(value: unknown): number {
  return value instanceof admin.firestore.Timestamp ? value.toMillis() : 0;
}
export function compareTimestamp(a: admin.firestore.Timestamp, b: admin.firestore.Timestamp): number {
  return a.seconds - b.seconds || a.nanoseconds - b.nanoseconds;
}
export function mondayAt(ms: number): number {
  const date = new Date(ms);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) - ((date.getUTCDay() + 6) % 7) * DAY;
}
export const dateKey = (ms: number) => new Date(ms).toISOString().slice(0, 10);
export function admissionIdentity(challenge: string, wall: string, created: admin.firestore.Timestamp): string {
  return createHash("sha256").update(`${challenge}:${wall}:${created.seconds}:${created.nanoseconds}`).digest("hex");
}
function ownerEmailHash(email: unknown): string {
  return createHash("sha256").update(str(email).toLowerCase()).digest("hex");
}
function sameIncarnation(wall: Snap, entry: Data): boolean {
  return wall.exists && entry.createTime instanceof admin.firestore.Timestamp &&
    !!wall.createTime?.isEqual(entry.createTime) && wall.data()?.challengeId === entry.challengeId &&
    (!entry.wallLogicalId || wall.data()?.id === entry.wallLogicalId) &&
    (!entry.ownerEmailHash || ownerEmailHash(wall.data()?.email) === entry.ownerEmailHash) &&
    (!wall.data()?.creatorUid || wall.data()?.creatorUid === entry.creatorUid);
}
async function account(tx: Tx, uid: string): Promise<Data | null> {
  if (!uid || uid.includes("/")) return null;
  const [user, barrier] = await Promise.all([tx.get(db.doc(`usersv2/${uid}`)), tx.get(db.doc(`creatorDeletionState/${uid}`))]);
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true ? user.data() ?? null : null;
}
async function all(query: admin.firestore.Query, tx?: Tx): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const rows: admin.firestore.QueryDocumentSnapshot[] = [];
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    const page = cursor ? query.startAfter(cursor).limit(PAGE) : query.limit(PAGE);
    const result = tx ? await tx.get(page) : await page.get();
    rows.push(...result.docs);
    if (result.size < PAGE) return rows;
    cursor = result.docs[result.size - 1];
  }
}
function gateKey(wall: Snap): string {
  const w = wall.data();
  return createHash("sha256").update(JSON.stringify(w ? [w.review, w.rejected, w.moderation, w.challengeId, w.email, w.creatorUid, w.originalProtected,
    w.collections, w.is_streak_exclusive, w.dropReserved, w.dropWeek, w.id, w.originalObjectId,
    w.wallpaper_url, w.wallpaper_path, w.wallpaper_sha, w.thumb_path, w.thumb_sha] : null)).digest("hex");
}
function moderation(wall: Snap): string {
  if (!wall.exists) return "withdrawn";
  const data = wall.data() ?? {};
  if (data.review === true) return "approved";
  if (data.rejected === true || data.moderation?.status === "rejected") return "rejected";
  return "pending";
}
export function rankEntries(a: {id: string; data: Data}, b: {id: string; data: Data}): number {
  return int(b.data.voteCount) - int(a.data.voteCount) ||
    compareTimestamp(a.data.approvedAt, b.data.approvedAt) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}
function entryView(entryId: string, entry: Data, wall: Data, viewer: string, voted: boolean): EntryView {
  return {id: entryId, wallId: entry.wallId, wallLogicalId: str(wall.id), creatorUid: entry.creatorUid,
    creatorName: str(wall.by), thumbUrl: str(wall.wallpaper_thumb), title: str(wall.title),
    voteCount: int(entry.voteCount), approvedAtMs: millis(entry.approvedAt), voted, mine: entry.creatorUid === viewer};
}

export async function admitChallengeWall(snapshot: Snap, authId?: string, authType?: string): Promise<boolean> {
  const submitted = snapshot.data();
  const created = snapshot.createTime;
  if (!submitted || submitted.challengeId === undefined || !created) return false;
  const challengeId = typeof submitted.challengeId === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(submitted.challengeId) ?
    submitted.challengeId : "";
  const principal = authId && authId.length <= 128 && !authId.includes("/") && ["unknown", "api_key"].includes(authType ?? "") ? authId : "";
  // Only the authenticated event can prove ownership. Mutable profile email is not proof.
  const owner = principal ? await challengeIo.owner(principal).catch((error: {code?: string}) => {
    if (["auth/user-not-found", "auth/invalid-uid"].includes(error.code ?? "")) return null;
    throw error;
  }) : null;
  return db.runTransaction(async (tx) => {
    const current = await tx.get(snapshot.ref);
    if (!current.createTime?.isEqual(created) || current.data()?.challengeId !== submitted.challengeId) return false;
    const challenge = challengeId ? await tx.get(challenges().doc(challengeId)) : null;
    const c = challenge?.data();
    const key = admissionIdentity(challengeId, snapshot.id, created);
    const decisionRef = challengeId ? admissions(challengeId).doc(key) : null;
    const decision = decisionRef ? await tx.get(decisionRef) : null;
    if (decision?.exists) return decision.data()?.admitted === true;
    const user = principal ? await account(tx, principal) : null;
    const quotaRef = challengeId && principal ? challenges().doc(challengeId).collection("members").doc(principal) : null;
    const quota = quotaRef ? await tx.get(quotaRef) : null;
    const approval = challengeId ? await tx.get(challenges().doc(challengeId).collection("approvalEvents").doc(key)) : null;
    const valid = !!c && !c.sealed && ["scheduled", "open", "voting_closed"].includes(c.state) &&
      compareTimestamp(created, c.opensAt) >= 0 &&
      compareTimestamp(created, c.closesAt) < 0 && owner?.uid === principal && !owner.disabled && !!owner.email &&
      owner.email.toLowerCase() === str(submitted.email).toLowerCase() && !!user &&
      submitted.review !== true && submitted.origin !== "studio" &&
      (!submitted.creatorUid || submitted.creatorUid === principal) && int(quota?.data()?.count) < 3;
    const status = moderation(current);
    if (decisionRef && c) {
      tx.create(decisionRef, {challengeId, wallId: snapshot.id, createTime: snapshot.createTime,
        admitted: valid, ...(valid ? {creatorUid: principal} : {})});
      tx.update(challenges().doc(challengeId), {revision: int(c.revision) + 1});
    }
    if (!valid || !quotaRef) {
      tx.update(snapshot.ref, {challengeId: admin.firestore.FieldValue.delete()});
      return false;
    }
    const entry = {challengeId, wallId: snapshot.id, createTime: snapshot.createTime, creatorUid: principal,
      wallLogicalId: str(submitted.id), ownerEmailHash: ownerEmailHash(owner?.email), state: status, gateKey: gateKey(current), voteCount: 0, approvedAt: approval?.data()?.firstApprovedAt ?? null};
    tx.create(entryRef(challengeId, key), entry);
    tx.set(quotaRef, {count: int(quota?.data()?.count) + 1});
    return true;
  });
}

export const onChallengeWallSubmitted = onDocumentCreatedWithAuthContext(
  {document: "walls/{wallId}", region: REGION, retry: true},
  async (event) => {
    if (event.data) await admitChallengeWall(event.data, event.authId, event.authType);
  },
);

export async function reconcileChallengeWall(wallId: string, challengeId: string,
  approvedAt?: admin.firestore.Timestamp, expectedCreateTime?: admin.firestore.Timestamp): Promise<void> {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(challengeId)) return;
  await db.runTransaction(async (tx) => {
    const challenge = await tx.get(challenges().doc(challengeId));
    if (!challenge.exists) return;
    const wall = await tx.get(db.doc(`walls/${wallId}`));
    const entries = await tx.get(challenge.ref.collection("entries").where("wallId", "==", wallId));
    const key = expectedCreateTime ? admissionIdentity(challengeId, wallId, expectedCreateTime) : null;
    const approvalRef = key ? challenge.ref.collection("approvalEvents").doc(key) : null;
    const approval = approvalRef ? await tx.get(approvalRef) : null;
    const previous = approval?.data()?.firstApprovedAt;
    const first = approvedAt && (!previous || compareTimestamp(approvedAt, previous) < 0) ? approvedAt : previous;
    let changed = !!approvedAt && first !== previous;
    if (changed && approvalRef) tx.set(approvalRef, {firstApprovedAt: first});
    for (const row of entries.docs) {
      const e = row.data();
      const state = sameIncarnation(wall, e) ? moderation(wall) : "withdrawn";
      const entryFirst = key === row.id && first && (!e.approvedAt || compareTimestamp(first, e.approvedAt) < 0) ?
        first : e.approvedAt;
      if (e.state === state && entryFirst === e.approvedAt && e.gateKey === gateKey(wall)) continue;
      tx.update(row.ref, {state, approvedAt: entryFirst ?? null, gateKey: gateKey(wall)});
      changed = true;
    }
    if (changed) tx.update(challenge.ref, {revision: int(challenge.data()?.revision) + 1});
  });
}
export const onChallengeWallWritten = onDocumentWritten({document: "walls/{wallId}", region: REGION, retry: true},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const ids = new Set([before?.challengeId, after?.challengeId].filter((v): v is string => typeof v === "string"));
    for (const challengeId of ids) {
      await reconcileChallengeWall(event.params.wallId, challengeId,
        after?.review === true && before?.review !== true ? event.data?.after.updateTime : undefined,
        event.data?.after.createTime ?? event.data?.before.createTime);
    }
  });

async function visible(tx: Tx, entry: Data, viewer = ""): Promise<Snap | null> {
  const wall = await tx.get(db.doc(`walls/${entry.wallId}`));
  if (entry.state !== "approved" || !entry.approvedAt || !sameIncarnation(wall, entry) || wall.data()?.review !== true ||
    !await account(tx, entry.creatorUid)) return null;
  if (viewer && viewer !== entry.creatorUid) {
    const [a, b] = await Promise.all([tx.get(db.doc(`usersv2/${viewer}/blockedUsers/${entry.creatorUid}`)),
      tx.get(db.doc(`usersv2/${entry.creatorUid}/blockedUsers/${viewer}`))]);
    if (a.exists || b.exists) return null;
  }
  return wall;
}
export async function voteChallenge(uid: string, challengeId: string, entryId: string, vote: boolean, clock: () => number = Date.now) {
  id(challengeId); id(entryId);
  if (typeof vote !== "boolean") throw new HttpsError("invalid-argument", "vote must be true or false.");
  const ref = entryRef(challengeId, entryId);
  const voteRef = ref.collection("challengeVotes").doc(uid);
  return db.runTransaction(async (tx) => {
    const now = clock();
    const rateRef = db.doc(`challengeVoteRateDaily/${uid}_${dateKey(now)}`);
    const challenge = await tx.get(challenges().doc(challengeId));
    const entry = await tx.get(ref);
    const existing = await tx.get(voteRef);
    const rate = await tx.get(rateRef);
    if (!await account(tx, uid)) throw new HttpsError("failed-precondition", "account-closed");
    const c = challenge.data();
    if (!c) throw new HttpsError("not-found", "challenge-missing");
    if (c.state !== "open" || now < millis(c.opensAt) || now >= millis(c.closesAt)) {
      throw new HttpsError("failed-precondition", "challenge-closed");
    }
    const e = entry.data();
    if (!e || !await visible(tx, e, uid)) throw new HttpsError("not-found", "entry-missing");
    if (e.creatorUid === uid) throw new HttpsError("failed-precondition", "own-entry");
    const count = int(e.voteCount);
    if (existing.exists === vote) return {voted: vote, voteCount: count};
    if (int(rate.data()?.count) >= 200) throw new HttpsError("resource-exhausted", "daily-limit");
    const next = Math.max(0, count + (vote ? 1 : -1));
    if (vote) tx.create(voteRef, {uid}); else tx.delete(voteRef);
    tx.update(ref, {voteCount: next});
    tx.set(rateRef, {uid, count: int(rate.data()?.count) + 1});
    tx.update(challenge.ref, {revision: int(c.revision) + 1});
    return {voted: vote, voteCount: next};
  });
}

async function viewChallenge(snap: Snap, viewer: string): Promise<ChallengeView> {
  const c = snap.data();
  if (!c) throw new HttpsError("not-found", "challenge-missing");
  let winner: EntryView | null = null;
  if (c.winnerEntryId) {
    winner = await db.runTransaction(async (tx) => {
      const entry = await tx.get(entryRef(snap.id, c.winnerEntryId));
      const e = entry.data();
      const wall = e ? await visible(tx, e, viewer) : null;
      return wall && e ? entryView(entry.id, e, wall.data() ?? {}, viewer, false) : null;
    }, {readOnly: true});
  }
  return {id: snap.id, theme: str(c.theme), state: c.state, opensAtMs: millis(c.opensAt), closesAtMs: millis(c.closesAt),
    winner, reservedDate: c.reservedDate ?? null, noWinner: c.noWinner === true};
}
export async function getChallenge(challengeId: string, viewer: string, sort: "top" | "new", cursor?: string) {
  const snap = await challenges().doc(id(challengeId)).get();
  if (!snap.exists) throw new HttpsError("not-found", "challenge-missing");
  let query = snap.ref.collection("entries").where("state", "==", "approved");
  query = sort === "top" ? query.orderBy("voteCount", "desc").orderBy("approvedAt") : query.orderBy("approvedAt", "desc");
  query = query.orderBy(admin.firestore.FieldPath.documentId());
  if (cursor) {
    const after = await entryRef(challengeId, id(cursor)).get();
    if (!after.exists) throw new HttpsError("invalid-argument", "Invalid cursor.");
    query = query.startAfter(after);
  }
  const rows = (await query.limit(PAGE).get()).docs;
  const entries: EntryView[] = [];
  for (const row of rows) {
    const result = await db.runTransaction(async (tx) => {
      const entry = await tx.get(row.ref);
      const e = entry.data();
      const wall = e ? await visible(tx, e, viewer) : null;
      const vote = viewer ? await tx.get(row.ref.collection("challengeVotes").doc(viewer)) : null;
      return wall && e ? entryView(row.id, e, wall.data() ?? {}, viewer, vote?.exists ?? false) : null;
    }, {readOnly: true});
    if (result) entries.push(result);
  }
  const member = viewer ? await snap.ref.collection("members").doc(viewer).get() : null;
  const mine = viewer ? await snap.ref.collection("entries").where("creatorUid", "==", viewer).limit(3).get() : null;
  return {challenge: await viewChallenge(snap, viewer), entries,
    nextCursor: rows.length === PAGE ? rows[rows.length - 1].id : null,
    myEntryCount: int(member?.data()?.count),
    myAdmittedWallIds: mine?.docs.map((r) => str(r.data().wallId)) ?? []};
}

export async function fallbackTheme(opens: number): Promise<{theme: string; sourceId: string} | null> {
  const rows = await all(db.collection("wallRequests").where("createdAt", ">=", stamp(opens - WEEK))
    .where("createdAt", "<", stamp(opens)).orderBy("createdAt").orderBy(admin.firestore.FieldPath.documentId()));
  const eligible = [];
  for (const row of rows) {
    const r = row.data();
    if (r.status !== "open" || r.hidden === true || !publicRequestText(r.text)) continue;
    if (!await db.runTransaction((tx) => account(tx, str(r.requesterUid)), {readOnly: true})) continue;
    eligible.push(row);
  }
  eligible.sort((a, b) => int(b.data().voteCount) - int(a.data().voteCount) ||
    compareTimestamp(a.data().createdAt, b.data().createdAt) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return eligible.length ? {theme: eligible[0].data().text, sourceId: eligible[0].id} : null;
}

export async function openChallengeSlot(opens: number): Promise<void> {
  const challengeId = dateKey(opens);
  const ref = challenges().doc(challengeId);
  const slotRef = db.doc(`weeklyChallengeSlots/${challengeId}`);
  if ((await ref.get()).exists || (await slotRef.get()).exists) return;
  const queue = await all(db.collection("challengeThemes").orderBy("order").orderBy(admin.firestore.FieldPath.documentId()));
  const theme = queue.find((d) => !d.data().usedBy && typeof d.data().theme === "string" && d.data().theme.trim());
  const fallback = theme ? null : await fallbackTheme(opens);
  const selection = theme ? {theme: theme.data().theme, sourceId: theme.id, source: "queue"} :
    fallback ? {...fallback, source: "request"} : null;
  if (!selection) {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      const slot = await tx.get(slotRef);
      if (!current.exists && !slot.exists) tx.create(slotRef, {state: "skipped"});
    });
    return;
  }
  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    const slot = await tx.get(slotRef);
    const source = theme ? await tx.get(theme.ref) : null;
    if (current.exists || slot.exists) return;
    if (source?.data()?.usedBy) throw new Error("Challenge queue changed; retry the scheduled slot.");
    tx.create(ref, {...selection, opensAt: stamp(opens), closesAt: stamp(opens + WEEK),
      state: "scheduled", revision: 0, sealed: false, noWinner: false});
    tx.create(slotRef, {state: "opened"});
    if (theme) tx.update(theme.ref, {usedBy: challengeId});
  });
}

type SettlementGuard = {wallId: string; fingerprint: string; creatorUid: string; accountOpen: boolean};
type Settled = {revision: number; candidates: {id: string; data: Data}[]; guards: SettlementGuard[]};
const wallFingerprint = (wall: Snap) => JSON.stringify([wall.createTime ?? null, gateKey(wall)]);
export async function scanClosedChallenge(challengeId: string): Promise<Settled | null> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(challenges().doc(challengeId));
    const c = snap.data();
    if (!c || c.state !== "voting_closed" || c.sealed) return null;
    const walls = await all(db.collection("walls").where("challengeId", "==", challengeId)
      .orderBy(admin.firestore.FieldPath.documentId()), tx);
    const ledger = await all(admissions(challengeId).orderBy(admin.firestore.FieldPath.documentId()), tx);
    const decisions = new Set(ledger.map((d) => d.id));
    for (const wall of walls) {
      if (wall.createTime && compareTimestamp(wall.createTime, c.opensAt) >= 0 &&
        compareTimestamp(wall.createTime, c.closesAt) < 0 &&
        !decisions.has(admissionIdentity(challengeId, wall.id, wall.createTime))) return null;
    }
    const entries = await all(snap.ref.collection("entries").orderBy(admin.firestore.FieldPath.documentId()), tx);
    const candidates = [];
    const guards: SettlementGuard[] = [];
    for (const row of entries) {
      const e = row.data();
      const wall = await tx.get(db.doc(`walls/${e.wallId}`));
      const accountOpen = !!await account(tx, e.creatorUid);
      guards.push({wallId: e.wallId, fingerprint: wallFingerprint(wall), creatorUid: e.creatorUid, accountOpen});
      const live = sameIncarnation(wall, e) && accountOpen;
      if (live && moderation(wall) === "pending") return null;
      // Reconciliation owns approval provenance. A delayed approval trigger also blocks settlement.
      if (live && wall.data()?.review === true && (e.state !== "approved" || !e.approvedAt)) return null;
      if (live && e.state === "approved" && wall.data()?.review === true) candidates.push({id: row.id, data: e});
    }
    return {revision: int(c.revision), candidates: candidates.sort(rankEntries), guards};
  }, {readOnly: true});
}

function winnerBadges(user: Data, now: number): unknown[] | null {
  const badges = Array.isArray(user.badges) ? [...user.badges] : [];
  if (badges.some((b: {id?: string}) => b.id === "challenge_winner")) return null;
  return [...badges, {id: "challenge_winner", name: "Challenge Winner", description: "Win a weekly challenge",
    awardedAt: new Date(now).toISOString(), imageUrl: "", color: "", url: ""}];
}

export async function finalizeChallenge(challengeId: string, finalizationTime?: number): Promise<boolean> {
  const settled = await scanClosedChallenge(challengeId);
  if (!settled) return false;
  const premium = await challengeIo.premium();
  let winner: {id: string; data: Data} | undefined;
  for (const candidate of settled.candidates) {
    if (await challengeIo.ready(candidate.data.wallId, premium)) {
      winner = candidate; break;
    }
  }
  const rankingId = createHash("sha256").update(JSON.stringify(settled)).digest("hex");
  const ranking = challenges().doc(challengeId).collection("settlements").doc(rankingId);
  for (let offset = 0; offset < settled.candidates.length; offset += PAGE) {
    await ranking.collection("pages").doc(String(offset / PAGE).padStart(8, "0"))
      .set({entries: settled.candidates.slice(offset, offset + PAGE).map((e) => e.id)});
  }
  return db.runTransaction(async (tx) => {
    const now = finalizationTime ?? Date.now();
    const ref = challenges().doc(challengeId);
    const challenge = await tx.get(ref);
    const c = challenge.data();
    if (!c || c.state !== "voting_closed" || c.sealed || int(c.revision) !== settled.revision) return false;
    for (const guard of settled.guards) {
      const current = await tx.get(db.doc(`walls/${guard.wallId}`));
      if (wallFingerprint(current) !== guard.fingerprint ||
        !!await account(tx, guard.creatorUid) !== guard.accountOpen) return false;
    }
    const wall = winner ? await visible(tx, winner.data) : null;
    if (winner && (!wall || !isWotdEligible((wall.data() ?? {}), premium))) return false;
    const winnerUser = winner ? await tx.get(db.doc(`usersv2/${winner.data.creatorUid}`)) : null;
    let day = Date.UTC(new Date(now).getUTCFullYear(), new Date(now).getUTCMonth(), new Date(now).getUTCDate()) + DAY;
    let reservation: admin.firestore.DocumentReference | undefined;
    if (winner) {
      for (;;) {
        const ref = reservationRef(dateKey(day));
        const existing = await tx.get(ref);
        if (!existing.exists) {
          reservation = ref; break;
        }
        day += DAY;
      }
    }
    tx.update(ref, {sealed: true, state: winner ? "winner_picked" : "archived", noWinner: !winner,
      rankingId, finalizedAt: stamp(now), selectedWinnerEntryId: winner?.id ?? null, winnerEntryId: winner?.id ?? null, reservedDate: winner ? dateKey(day) : null,
      revision: settled.revision + 1});
    if (reservation && winner) tx.create(reservation, {challengeId, entryId: winner.id, state: "reserved"});
    if (winnerUser?.exists) {
      const badges = winnerBadges((winnerUser.data() ?? {}), now);
      if (badges) tx.update(winnerUser.ref, {badges});
    }
    return true;
  });
}

export async function reservedChallengePick(day: string, premium: string[]): Promise<{wallId: string; reservation: string} | null> {
  const reservation = await reservationRef(day).get();
  const r = reservation.data();
  if (!r || !["reserved", "consumed"].includes(r.state)) return null;
  const c = (await challenges().doc(r.challengeId).get()).data();
  if (!c?.rankingId) return null;
  const pages = await all(challenges().doc(r.challengeId).collection("settlements").doc(c.rankingId)
    .collection("pages").orderBy(admin.firestore.FieldPath.documentId()));
  const candidates = [];
  for (const page of pages) {
    for (const entryId of page.data().entries) {
      const entry = await entryRef(r.challengeId, entryId).get();
      const data = entry.data();
      if (data) candidates.push({id: entry.id, data});
    }
  }
  for (const entry of candidates) {
    const wall = await db.runTransaction((tx) => visible(tx, entry.data), {readOnly: true});
    if (wall && await challengeIo.ready(wall.id, premium, wall.data())) {
      return {wallId: wall.id, reservation: reservation.id};
    }
  }
  await db.runTransaction(async (tx) => {
    const current = await tx.get(reservation.ref);
    const challenge = await tx.get(challenges().doc(r.challengeId));
    if (!["reserved", "consumed"].includes(current.data()?.state)) return;
    if (int(challenge.data()?.revision) !== int(c.revision)) throw new Error("Challenge reservation changed; retry.");
    tx.update(reservation.ref, {state: "exhausted"});
    tx.update(challenge.ref, {state: "archived", awardEntryId: null, winnerEntryId: null, noWinner: true,
      revision: int(challenge.data()?.revision) + 1});
  });
  return null;
}

export async function commitChallengeReservation(tx: Tx, day: string, wallId: string | null, premium: string[]): Promise<boolean> {
  const reservation = await tx.get(reservationRef(day));
  const r = reservation.data();
  if (!r || !["reserved", "consumed"].includes(r.state)) return true;
  const challenge = await tx.get(challenges().doc(r.challengeId));
  if (wallId === null) return false;
  const rows = await tx.get(challenge.ref.collection("entries").where("wallId", "==", wallId));
  if (rows.size !== 1) return false;
  const entry = rows.docs[0];
  const c = challenge.data();
  if (!c?.rankingId) return false;
  const pages = await tx.get(challenge.ref.collection("settlements").doc(c.rankingId).collection("pages"));
  if (!pages.docs.some((p) => p.data().entries.includes(entry.id))) return false;
  const wall = await visible(tx, entry.data());
  if (!wall || !isWotdEligible((wall.data() ?? {}), premium)) return false;
  const winnerUser = await tx.get(db.doc(`usersv2/${entry.data().creatorUid}`));
  const badges = winnerUser.exists ? winnerBadges((winnerUser.data() ?? {}), Date.now()) : null;
  tx.update(reservation.ref, {state: "consumed", entryId: entry.id, wallId});
  if (badges) tx.update(winnerUser.ref, {badges});
  tx.update(challenge.ref, {state: "archived", awardEntryId: entry.id, winnerEntryId: entry.id, revision: int(challenge.data()?.revision) + 1});
  return true;
}

export async function challengeAwardAvailable(tx: Tx, day: string, wallId: string): Promise<boolean> {
  const reservation = (await tx.get(reservationRef(day))).data();
  if (!reservation || reservation.wallId !== wallId) return true;
  const entry = (await tx.get(entryRef(reservation.challengeId, reservation.entryId))).data();
  return !!entry && !!await visible(tx, entry);
}

export async function refreshPublishedChallengeAward(now: number): Promise<void> {
  const reservation = (await reservationRef(dateKey(now)).get()).data();
  if (reservation?.state !== "consumed") return;
  const current = (await db.doc("wall_of_the_day/current").get()).data();
  if (!current || current.wallId !== reservation.wallId || dateKey(millis(current.date)) !== dateKey(now)) return;
  const entry = (await entryRef(reservation.challengeId, reservation.entryId).get()).data();
  const wall = entry ? await db.runTransaction((tx) => visible(tx, entry), {readOnly: true}) : null;
  if (wall && await challengeIo.ready(wall.id, await challengeIo.premium(), wall.data())) return;
  await pickWallOfTheDay(now);
}

export async function runChallengeSchedule(slot: number, now?: number): Promise<void> {
  if (!Number.isFinite(slot)) throw new Error("Invalid challenge scheduler slot");
  const errors: unknown[] = [];
  const attempt = async (operation: string, work: () => Promise<void>): Promise<void> => {
    try {
      await work();
    } catch (error) {
      logger.error("Weekly challenge scheduling failed", {operation, error: error instanceof Error ? error.stack : error});
      errors.push(error);
    }
  };
  await attempt("past reservations", async () => {
    const pastReservations = await all(db.collection("challengeWotdReservations")
      .where(admin.firestore.FieldPath.documentId(), "<", dateKey(now ?? Date.now())));
    for (const row of pastReservations) {
      await attempt(row.ref.path, () => db.runTransaction(async (tx) => {
        const current = await tx.get(row.ref);
        const r = current.data();
        if (r?.state !== "reserved") return;
        const challenge = await tx.get(challenges().doc(r.challengeId));
        tx.update(row.ref, {state: "missed"});
        if (challenge.exists) tx.update(challenge.ref, {state: "archived", awardOutcome: "missed", revision: int(challenge.data()?.revision) + 1});
      }));
    }
  });
  const week = mondayAt(slot);
  if (slot === week && (now ?? Date.now()) < week + WEEK) await attempt("open slot", () => openChallengeSlot(week));
  await attempt("challenge scan", async () => {
    const rows = await all(challenges());
    for (const row of rows) {
      await attempt(row.ref.path, async () => {
        const c = row.data();
        await db.runTransaction(async (tx) => {
          const current = await tx.get(row.ref);
          const d = current.data();
          if (!d) return;
          const state = millis(d.closesAt) <= slot && ["scheduled", "open"].includes(d.state) ? "voting_closed" :
            d.state === "scheduled" && millis(d.opensAt) <= slot ? "open" : d.state;
          if (state !== d.state) tx.update(row.ref, {state, revision: int(d.revision) + 1});
        });
        if (millis(c.closesAt) <= slot) await finalizeChallenge(row.id, now);
        await notifyChallengeWinner(row.id);
      });
    }
  });
  await attempt("published award recovery", () => refreshPublishedChallengeAward(now ?? Date.now()));
  if (errors.length) throw Object.assign(new Error("Weekly challenge scheduling failed"), {errors});
}
export const scheduleWeeklyChallenges = onSchedule({schedule: "*/15 * * * *", timeZone: "UTC", region: REGION,
  retryCount: 3, secrets: r2Secrets}, async (event) => runChallengeSchedule(Date.parse(event.scheduleTime)));

export async function notifyChallengeWinner(challengeId: string): Promise<void> {
  const c = (await challenges().doc(challengeId).get()).data();
  if (!c?.winnerEntryId) return;
  const entry = (await entryRef(challengeId, c.winnerEntryId).get()).data();
  if (!entry) return;
  const uid = entry.creatorUid;
  const marker = db.doc(`challengeNotices/winner_${challengeId}_${uid}`);
  const recipient = await db.runTransaction(async (tx) => {
    const existing = await tx.get(marker);
    const user = await account(tx, uid);
    const session = await tx.get(db.doc(`usersv2/${uid}/private/session`));
    const wall = await visible(tx, entry);
    if (existing.data()?.sent || !user || !wall) return null;
    if (existing.data()?.leaseUntil && millis(existing.data()?.leaseUntil) > Date.now()) return null;
    tx.set(marker, {uid, leaseUntil: stamp(Date.now() + 5 * 60_000), sent: false,
      inboxWritten: existing.data()?.inboxWritten === true, pushState: "sending"});
    return {user, session: session.data()};
  });
  if (!recipient) return;
  const email = str(recipient.user.email);
  const key = `challenge_winner_${challengeId}_${uid}`;
  const sent = await challengeIo.send({...notificationCopyPayload({kind: "challengeWinner", theme: c.theme}),
    modifier: email, docId: key, collapseKey: key, channelId: "posts", scoreKind: "post",
    data: {route: "challenge", challenge_id: challengeId, url: `https://prismwalls.com/challenges/${challengeId}`,
      notification_kind: "challenge_winner"}},
  {uid, email, loggedOut: recipient.user.loggedIn === false, legacyToken: recipient.user.fcmToken,
    ...(typeof recipient.session?.postAlertsToken === "string" ? {postAlertsToken: recipient.session.postAlertsToken} : {})},
  recipient.session?.postAlerts !== false);
  if (!sent) {
    await marker.set({sent: false, uid, inboxWritten: true, pushState: "retry", leaseUntil: stamp(0)});
    throw new Error("Challenge winner notice failed");
  }
  await marker.set({sent: true, uid, inboxWritten: true,
    pushState: recipient.session?.postAlerts === false ? "disabled" : "sent"});
}

export async function removeChallengeVotesForAccount(uid: string): Promise<void> {
  const votes = await db.collectionGroup("challengeVotes").where("uid", "==", uid).get();
  for (const vote of votes.docs) {
    const parts = vote.ref.path.split("/");
    if (parts.length !== 6 || parts[0] !== "weeklyChallenges" || parts[2] !== "entries") continue;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(vote.ref);
      const entry = await tx.get(entryRef(parts[1], parts[3]));
      const challenge = await tx.get(challenges().doc(parts[1]));
      if (!current.exists) return;
      tx.delete(vote.ref);
      if (entry.exists) {
        tx.update(entry.ref, {voteCount: Math.max(0, int(entry.data()?.voteCount) - 1)});
        tx.update(challenge.ref, {revision: int(challenge.data()?.revision) + 1});
      }
    });
  }
  const rates = await db.collection("challengeVoteRateDaily").where("uid", "==", uid).get();
  for (const rate of rates.docs) await rate.ref.delete();
}

export const listWeeklyChallenges = onCall({region: CALLABLE_REGIONS, cors: true}, async (request) => {
  const kind = request.data?.kind;
  if (kind !== "open" && kind !== "past") throw new HttpsError("invalid-argument", "Invalid challenge kind.");
  let query = challenges().where("state", "in", kind === "open" ? ["scheduled", "open"] :
    ["voting_closed", "winner_picked", "archived"]).orderBy("opensAt", "desc");
  if (request.data?.cursor != null) {
    const cursor = await challenges().doc(id(request.data.cursor)).get();
    if (!cursor.exists) throw new HttpsError("invalid-argument", "Invalid cursor.");
    query = query.startAfter(cursor);
  }
  const rows = (await query.limit(20).get()).docs;
  return {challenges: await Promise.all(rows.map((d) => viewChallenge(d, request.auth?.uid ?? ""))),
    nextCursor: rows.length === 20 ? rows[rows.length - 1].id : null};
});
export const getWeeklyChallenge = onCall({region: CALLABLE_REGIONS, cors: true}, async (request) => {
  if (request.data?.sort !== "top" && request.data?.sort !== "new") throw new HttpsError("invalid-argument", "Invalid sort.");
  return getChallenge(id(request.data?.challengeId), request.auth?.uid ?? "", request.data.sort,
    request.data?.cursor == null ? undefined : id(request.data.cursor));
});
export const setChallengeVote = onCall({region: CALLABLE_REGIONS, cors: true}, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to vote.");
  return voteChallenge(request.auth.uid, id(request.data?.challengeId), id(request.data?.entryId), request.data?.vote);
});
