import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {db, CALLABLE_REGIONS, findUserByEmail, readDailyCount, str, utcDateString} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {sendToUser} from "./notificationHelper";
import {isPreviewUrl, similarWallIds} from "./pushGallery";
import {premiumCollections, protectedWalls, SIMILAR_FIELDS} from "./wallOfTheDay";

export const WALL_REQUESTS = "wallRequests";
export const VOTES = "votes";
export const REQUEST_RATE_DAILY = "wallRequestRateDaily";
export const VOTE_RATE_DAILY = "wallRequestVoteRateDaily";
export const MIN_TEXT_LENGTH = 3;
export const MAX_TEXT_LENGTH = 80;
export const MAX_TAGS = 3;
export const MAX_REQUESTS_PER_DAY = 3;
export const MAX_VOTE_CHANGES_PER_DAY = 200;
export const MIN_STUDIO_VOTES = 3;
export const MAX_STUDIO_REQUESTS = 3;
const SIMILAR_SCORE = 0.6;
const DAY_MS = 24 * 60 * 60 * 1000;
const TOP_WINDOW_MS = 30 * DAY_MS;
const STUDIO_RETRY_MS = 7 * DAY_MS;
const LIST_LIMIT = 50;
const TOP_SCAN = 200;
const PUSH_CHUNK = 25;
const DOC_ID = /^[A-Za-z0-9_-]{1,128}$/;

/** The browse categories (lib/data/categories/categories.dart) and the mood ids a request may carry as tags. */
export const REQUEST_CATEGORIES = [
  "AI Art", "Aesthetic", "Cyberpunk", "3D Render", "Gradient", "Minimal", "Dark", "Nature", "Landscape", "Space",
  "Anime", "Neon", "Abstract", "Architecture", "Ocean", "Forest", "Galaxy", "Vintage", "Flowers", "Cars", "AMOLED",
];
export const REQUEST_MOODS = ["dreamy", "dark_quiet", "bright_bold"];
const REQUEST_TAGS = new Set([...REQUEST_CATEGORIES, ...REQUEST_MOODS]);

export type RequestStatus = "open" | "filled";
export type FilledBy = "creator" | "studio";

/** What a client sees of one request. The requester is only a display name and an avatar. */
export interface WallRequestView {
  id: string;
  text: string;
  tags: string[];
  voteCount: number;
  status: RequestStatus;
  createdAtMs: number;
  requesterName: string;
  requesterPhoto: string;
  mine: boolean;
  voted: boolean;
  hidden: boolean;
  filledWallId: string;
  filledWallThumb: string;
  filledBy: FilledBy | "";
  filledAtMs: number;
}

const HIDDEN_CHARACTERS = /[\p{Cc}\p{Cf}\p{Co}\p{Cn}]/u;
const STOP_WORDS = new Set([
  "a", "an", "the", "of", "and", "or", "with", "in", "on", "for", "to", "some", "any", "me", "my", "i", "pls", "please",
  "want", "need", "like", "wall", "walls", "wallpaper", "wallpapers", "background", "backgrounds", "hd", "4k", "phone",
]);
// ponytail: a short list of slurs and sexual words. Reports and admin hiding catch the rest; grow it from reports.
const BLOCKED_WORDS = new Set([
  "nigger", "nigga", "faggot", "fag", "retard", "kike", "chink", "spic", "tranny", "porn", "porno", "nude", "nudes",
  "naked", "nsfw", "hentai", "sex", "sexy", "xxx", "boobs", "tits", "dick", "cock", "pussy", "cum", "rape", "milf",
]);
const BLOCKED_WORD_PATTERNS = [...BLOCKED_WORDS].map((word) =>
  new RegExp(`^${[...word].map((character) => `${character}+`).join("")}$`));
const LEET: Record<string, string> = {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"};

function words(text: string): string[] {
  return text.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}

function hasBlockedWord(text: string): boolean {
  const plain = words(text);
  const unleet = words(text.toLowerCase().replace(/[013457@$]/g, (c) => LEET[c]));
  return [...plain, ...unleet].some((w) => BLOCKED_WORDS.has(w) || BLOCKED_WORD_PATTERNS.some((pattern) => pattern.test(w)));
}

/** Sorted unique words that carry meaning. Two requests with the same tokens ask for the same wall. */
export function requestTokens(text: string): string[] {
  return [...new Set(words(text).filter((w) => !STOP_WORDS.has(w)))].sort();
}

/**
 * The text others see, or null when it may not be public: 3 to 80 characters after trimming and collapsing spaces,
 * no control, format or bidi characters, no blocked word, and at least one word that is not a filler word.
 */
export function publicRequestText(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  if (HIDDEN_CHARACTERS.test(raw)) return null;
  const text = raw.replace(/\s+/g, " ").trim();
  if (text.length < MIN_TEXT_LENGTH || text.length > MAX_TEXT_LENGTH) return null;
  if (hasBlockedWord(text) || requestTokens(text).length === 0) return null;
  return text;
}

/** Jaccard overlap of two token lists, 0 to 1. */
export function similarity(a: string[], b: string[]): number {
  if (a.length === 0 || b.length === 0) return 0;
  const right = new Set(b);
  const shared = a.filter((t) => right.has(t)).length;
  return shared / (new Set([...a, ...b]).size);
}

export function parseCreateInput(data: unknown): {text: string; tags: string[]; force: boolean} {
  const input = typeof data === "object" && data !== null ? data as Record<string, unknown> : {};
  const text = publicRequestText(input.text);
  if (text === null) throw new HttpsError("invalid-argument", "text-rejected");
  const rawTags = input.tags ?? [];
  if (!Array.isArray(rawTags) || rawTags.length > MAX_TAGS ||
    rawTags.some((t) => typeof t !== "string" || !REQUEST_TAGS.has(t))) {
    throw new HttpsError("invalid-argument", "tags-invalid");
  }
  return {text, tags: [...new Set(rawTags as string[])], force: input.force === true};
}

export function requestIdFrom(raw: unknown): string {
  if (typeof raw !== "string" || !DOC_ID.test(raw)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  return raw;
}

const requestRef = (id: string) => db.collection(WALL_REQUESTS).doc(id);
const millis = (value: unknown): number => value instanceof admin.firestore.Timestamp ? value.toMillis() : 0;
const blockRef = (owner: string, other: string) => db.doc(`usersv2/${owner}/blockedUsers/${other}`);

export async function blockedEitherWay(a: string, b: string): Promise<boolean> {
  if (!a || !b || a === b) return false;
  const [mine, theirs] = await Promise.all([blockRef(a, b).get(), blockRef(b, a).get()]);
  return mine.exists || theirs.exists;
}

function toView(doc: admin.firestore.DocumentSnapshot, viewer: string, voted: boolean): WallRequestView {
  const d = doc.data() ?? {};
  return {
    id: doc.id,
    text: str(d.text),
    tags: Array.isArray(d.tags) ? d.tags.filter((t): t is string => typeof t === "string") : [],
    voteCount: typeof d.voteCount === "number" ? d.voteCount : 0,
    status: d.status === "filled" ? "filled" : "open",
    createdAtMs: millis(d.createdAt),
    requesterName: str(d.requesterName),
    requesterPhoto: str(d.requesterPhoto),
    mine: viewer !== "" && d.requesterUid === viewer,
    voted,
    hidden: d.hidden === true,
    // The app opens the wall by its logical id. An upload's doc id is its file name.
    filledWallId: str(d.filledWallLogicalId) || str(d.filledWallId),
    filledWallThumb: str(d.filledWallThumb),
    filledBy: d.filledBy === "creator" || d.filledBy === "studio" ? d.filledBy : "",
    filledAtMs: millis(d.filledAt),
  };
}

/** The caller may write: signed in, account not deleted and not in account deletion. */
async function openAccount(tx: admin.firestore.Transaction, uid: string): Promise<admin.firestore.DocumentData> {
  const [user, barrier] = await Promise.all([
    tx.get(db.collection("usersv2").doc(uid)),
    tx.get(db.collection("creatorDeletionState").doc(uid)),
  ]);
  const data = user.data();
  if (!data || data.deleted === true || barrier.data()?.closed === true) {
    throw new HttpsError("failed-precondition", "account-closed");
  }
  return data;
}

async function accountIsOpen(tx: admin.firestore.Transaction, uid: string): Promise<boolean> {
  const [user, barrier] = await Promise.all([
    tx.get(db.collection("usersv2").doc(uid)),
    tx.get(db.collection("creatorDeletionState").doc(uid)),
  ]);
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true;
}

/** Open, visible requests whose words overlap `tokens`, best match first. Requests of blocked users are left out. */
async function closestOpenRequest(tx: admin.firestore.Transaction, uid: string, tokens: string[]):
  Promise<{doc: admin.firestore.QueryDocumentSnapshot; exact: boolean} | null> {
  const queries = [db.collection(WALL_REQUESTS).where("key", "==", tokens.join(" "))];
  for (let i = 0; i < tokens.length; i += 10) {
    queries.push(db.collection(WALL_REQUESTS)
      .where("status", "==", "open")
      .where("hidden", "==", false)
      .where("tokens", "array-contains-any", tokens.slice(i, i + 10))
      .limit(30));
  }
  const snapshots = await Promise.all(queries.map((query) => tx.get(query)));
  const docs = new Map<string, admin.firestore.QueryDocumentSnapshot>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) docs.set(doc.id, doc);
  }
  const key = tokens.join(" ");
  const scored = [...docs.values()]
    .filter((doc) => doc.data()?.status === "open" && doc.data()?.hidden !== true)
    .map((doc) => ({doc, score: similarity(tokens, Array.isArray(doc.data().tokens) ? doc.data().tokens : [])}))
    .filter(({score}) => score >= SIMILAR_SCORE)
    .sort((a, b) => b.score - a.score || (b.doc.data().voteCount ?? 0) - (a.doc.data().voteCount ?? 0));
  for (const {doc} of scored) {
    const requesterUid = str(doc.data().requesterUid);
    if (requesterUid && requesterUid !== uid) {
      const [mine, theirs] = await Promise.all([
        tx.get(blockRef(uid, requesterUid)),
        tx.get(blockRef(requesterUid, uid)),
      ]);
      if (mine.exists || theirs.exists) continue;
    }
    return {doc, exact: str(doc.data().key) === key};
  }
  return null;
}

export type CreateResult =
  | {status: "created"; request: WallRequestView}
  | {status: "duplicate"; exact: boolean; request: WallRequestView};

/**
 * Creates a request, at most MAX_REQUESTS_PER_DAY per UTC day. A close open request comes back as a duplicate instead,
 * so the app can offer an upvote. `force` creates anyway, except for the same words or the caller's own request.
 */
export async function createWallRequest(uid: string, data: unknown, nowMs = Date.now()): Promise<CreateResult> {
  const {text, tags, force} = parseCreateInput(data);
  const tokens = requestTokens(text);
  const profile = (await db.collection("profiles").doc(uid).get()).data();
  const day = utcDateString(new Date(nowMs));
  const rateRef = db.collection(REQUEST_RATE_DAILY).doc(`${uid}_${day}`);
  const key = tokens.join(" ");
  const lockRef = db.collection("wallRequestKeyLocks").doc(createHash("sha256").update(key).digest("hex"));
  const ref = db.collection(WALL_REQUESTS).doc();
  const now = admin.firestore.Timestamp.fromMillis(nowMs);
  const result = await db.runTransaction(async (tx) => {
    const [user, rate] = await Promise.all([openAccount(tx, uid), tx.get(rateRef)]);
    await tx.get(lockRef);
    const match = await closestOpenRequest(tx, uid, tokens);
    if (match && (!force || match.exact || match.doc.data()?.requesterUid === uid)) {
      const voted = (await tx.get(match.doc.ref.collection(VOTES).doc(uid))).exists;
      return {status: "duplicate" as const, exact: match.exact, request: toView(match.doc, uid, voted)};
    }
    const used = readDailyCount(rate, day);
    if (used >= MAX_REQUESTS_PER_DAY) throw new HttpsError("resource-exhausted", "daily-limit");
    tx.create(ref, {
      text,
      key,
      tokens,
      tags,
      requesterUid: uid,
      requesterName: str(profile?.name) || str(user.name),
      requesterPhoto: str(profile?.profilePhoto) || str(user.profilePhoto),
      status: "open",
      hidden: false,
      voteCount: 0,
      createdAt: now,
    });
    tx.set(rateRef, {day, count: used + 1, uid, updatedAt: now});
    tx.set(lockRef, {updatedAt: now});
    return {status: "created" as const, ref};
  });
  if (result.status === "duplicate") return result;
  return {status: "created", request: toView(await result.ref.get(), uid, false)};
}

/** Sets the caller's vote to `vote`. A repeat is a no-op, so a retried call never counts twice. */
export async function setWallRequestVote(uid: string, requestId: string, vote: boolean, nowMs = Date.now()):
  Promise<{voted: boolean; voteCount: number}> {
  const ref = requestRef(requestId);
  const voteRef = ref.collection(VOTES).doc(uid);
  const day = utcDateString(new Date(nowMs));
  const rateRef = db.collection(VOTE_RATE_DAILY).doc(`${uid}_${day}`);
  return db.runTransaction(async (tx) => {
    const [request, existing, rate, user, barrier] = await Promise.all([
      tx.get(ref), tx.get(voteRef), tx.get(rateRef), tx.get(db.collection("usersv2").doc(uid)),
      tx.get(db.collection("creatorDeletionState").doc(uid)),
    ]);
    if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) {
      throw new HttpsError("failed-precondition", "account-closed");
    }
    const data = request.data();
    if (!data || data.hidden === true) throw new HttpsError("not-found", "request-missing");
    const requester = str(data.requesterUid);
    if (requester && !(await accountIsOpen(tx, requester))) {
      throw new HttpsError("not-found", "request-missing");
    }
    if (requester === uid) throw new HttpsError("failed-precondition", "own-request");
    const [mine, theirs] = await Promise.all([tx.get(blockRef(uid, requester)), tx.get(blockRef(requester, uid))]);
    if (mine.exists || theirs.exists) throw new HttpsError("not-found", "request-missing");
    const count = typeof data.voteCount === "number" ? data.voteCount : 0;
    if (existing.exists === vote) return {voted: vote, voteCount: count};
    if (data.status !== "open") throw new HttpsError("failed-precondition", "request-closed");
    const used = readDailyCount(rate, day);
    if (used >= MAX_VOTE_CHANGES_PER_DAY) throw new HttpsError("resource-exhausted", "daily-limit");
    const next = Math.max(0, count + (vote ? 1 : -1));
    const now = admin.firestore.Timestamp.fromMillis(nowMs);
    if (vote) tx.create(voteRef, {uid, createdAt: now});
    else tx.delete(voteRef);
    tx.update(ref, {voteCount: next});
    tx.set(rateRef, {day, count: used + 1, uid, updatedAt: now});
    return {voted: vote, voteCount: next};
  });
}

export type RequestTab = "top" | "new" | "filled";

function tabFrom(raw: unknown): RequestTab {
  if (raw !== "top" && raw !== "new" && raw !== "filled") throw new HttpsError("invalid-argument", "tab is invalid.");
  return raw;
}

/**
 * One tab of requests for `viewer` (empty for a guest). Top is open requests of the last 30 days by votes, New is open
 * requests newest first, Filled is filled requests newest fill first. Hidden requests show only to admins, and
 * requests of users the viewer blocked, or who blocked the viewer, never show.
 */
export async function listWallRequests(viewer: string, tab: RequestTab, isAdmin: boolean, nowMs = Date.now()):
  Promise<WallRequestView[]> {
  let query: admin.firestore.Query = db.collection(WALL_REQUESTS).where("status", "==", tab === "filled" ? "filled" : "open");
  if (!isAdmin) query = query.where("hidden", "==", false);
  query = tab === "top" ? query.orderBy("voteCount", "desc").limit(TOP_SCAN) :
    query.orderBy(tab === "new" ? "createdAt" : "filledAt", "desc").limit(LIST_LIMIT);
  let docs = (await query.get()).docs;
  // ponytail: Top scans the 200 most voted open requests and keeps the last 30 days; add a window field if it grows.
  if (tab === "top") docs = docs.filter((d) => millis(d.data().createdAt) >= nowMs - TOP_WINDOW_MS).slice(0, LIST_LIMIT);
  if (viewer) {
    const mine = new Set((await db.collection(`usersv2/${viewer}/blockedUsers`).get()).docs.map((d) => d.id));
    const requesters = [...new Set(docs.map((d) => str(d.data().requesterUid)))].filter((u) => u && u !== viewer);
    const blockedMe = new Set((await Promise.all(requesters.map(async (u) =>
      (await blockRef(u, viewer).get()).exists ? u : null))).filter((u): u is string => u !== null));
    docs = docs.filter((d) => !mine.has(str(d.data().requesterUid)) && !blockedMe.has(str(d.data().requesterUid)));
  }
  const voted = viewer ? await Promise.all(docs.map(async (d) => (await d.ref.collection(VOTES).doc(viewer).get()).exists)) :
    docs.map(() => false);
  return docs.map((d, i) => toView(d, viewer, voted[i]));
}

/** Admin only: hides or shows a request. A hidden request leaves every list, Studio and the filled push. */
export async function setWallRequestHidden(requestId: string, hidden: boolean, by: string): Promise<void> {
  const ref = requestRef(requestId);
  if (!(await ref.get()).exists) throw new HttpsError("not-found", "request-missing");
  await ref.update({hidden, hiddenBy: hidden ? by : admin.firestore.FieldValue.delete(),
    hiddenAt: hidden ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.delete()});
}

/**
 * Marks the request of an approved wall as filled by it. Runs on every approval event: a request filled by this wall
 * gets the current thumbnail, a request filled by another wall stays as it is. Returns the request id when this wall
 * filled it. A creator wall never fills a request of a user who blocked the creator or whom the creator blocked.
 */
export async function fillRequestFromWall(wallId: string, wall: admin.firestore.DocumentData, studio: boolean):
  Promise<string | null> {
  const requestId = str(wall.requestId);
  if (!DOC_ID.test(requestId)) return null;
  const ref = requestRef(requestId);
  let fillerUid = "";
  if (!studio) {
    fillerUid = str(wall.creatorUid) || (str(wall.email) ? (await findUserByEmail(str(wall.email)))?.id ?? "" : "");
  }
  const thumb = str(wall.wallpaper_thumb);
  const logicalId = str(wall.id) || wallId;
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (!data || data.hidden === true) return null;
    const requesterUid = str(data.requesterUid);
    const [barrier, user, mine, theirs] = await Promise.all([
      requesterUid ? tx.get(db.collection("creatorDeletionState").doc(requesterUid)) : Promise.resolve({data: () => undefined}),
      requesterUid ? tx.get(db.collection("usersv2").doc(requesterUid)) : Promise.resolve({data: () => undefined}),
      !studio && fillerUid && requesterUid ? tx.get(blockRef(fillerUid, requesterUid)) : Promise.resolve({exists: false}),
      !studio && fillerUid && requesterUid ? tx.get(blockRef(requesterUid, fillerUid)) : Promise.resolve({exists: false}),
    ]);
    if (barrier.data()?.closed === true || user.data()?.deleted === true || mine.exists || theirs.exists) {
      return null;
    }
    if (data.status === "filled") {
      if (data.filledWallId !== wallId) return null;
      if (data.filledWallThumb !== thumb || data.filledWallLogicalId !== logicalId) {
        tx.update(ref, {filledWallThumb: thumb, filledWallLogicalId: logicalId});
      }
      return requestId;
    }
    tx.update(ref, {
      status: "filled",
      filledWallId: wallId,
      filledWallLogicalId: logicalId,
      filledWallThumb: thumb,
      filledBy: studio ? "studio" : "creator",
      fillerUid,
      fillerName: studio ? "Prism Studio" : str(wall.by),
      filledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return requestId;
  });
}

/**
 * The logical ids of the filled wall and up to 3 walls like it, for the gallery page the push opens. The gallery loads
 * walls by their `id` field, which differs from the doc id for uploads.
 */
async function galleryIds(wallId: string): Promise<string[]> {
  const logical = (doc: {id: string; data: admin.firestore.DocumentData}) => str(doc.data.id) || doc.id;
  try {
    const wall = await db.collection("walls").doc(wallId).get();
    if (!wall.exists) return [];
    const lead = {id: wallId, data: wall.data() ?? {}};
    // ponytail: one scan of the protected walls per fill, as the Wall of the Day pick does; fills are a few a day.
    const snap = await protectedWalls().select(...SIMILAR_FIELDS).get();
    const candidates = snap.docs.map((d) => ({id: d.id, data: d.data()}));
    const byDocId = new Map(candidates.map((c) => [c.id, c]));
    const others = similarWallIds(lead, candidates, await premiumCollections())
      .map((id) => byDocId.get(id)).filter((c): c is typeof lead => c !== undefined).map(logical);
    return [logical(lead), ...others];
  } catch (err) {
    logger.warn("wallRequests: no similar walls for the filled push.", {wallId, err});
    return [];
  }
}

/** Claims the user's request push for the UTC day when the account and delivery conditions still allow it. */
async function claimPushDay(uid: string, day: string, requestId: string, requesterUid: string, fillerUid: string):
  Promise<"claimed" | "unavailable" | "closed" | "blocked"> {
  const ref = db.doc(`usersv2/${uid}/private/wallRequestPush`);
  const request = requestRef(requestId);
  return db.runTransaction(async (tx) => {
    const [claim, user, barrier, session, current, requesterBlocksUser, userBlocksRequester,
      fillerBlocksUser, userBlocksFiller] = await Promise.all([
      tx.get(ref), tx.get(db.collection("usersv2").doc(uid)),
      tx.get(db.collection("creatorDeletionState").doc(uid)),
      tx.get(db.doc(`usersv2/${uid}/private/session`)),
      tx.get(request),
      requesterUid ? tx.get(blockRef(requesterUid, uid)) : Promise.resolve({exists: false}),
      requesterUid ? tx.get(blockRef(uid, requesterUid)) : Promise.resolve({exists: false}),
      fillerUid ? tx.get(blockRef(fillerUid, uid)) : Promise.resolve({exists: false}),
      fillerUid ? tx.get(blockRef(uid, fillerUid)) : Promise.resolve({exists: false}),
    ]);
    if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) return "closed";
    if (!current.exists || current.data()?.status !== "filled" || current.data()?.hidden === true ||
      publicRequestText(current.data()?.text) === null || requesterBlocksUser.exists || userBlocksRequester.exists ||
      fillerBlocksUser.exists || userBlocksFiller.exists) return "blocked";
    const claimedDay = claim.data()?.day;
    const alreadyClaimedToday = typeof claimedDay === "string" && /^\d{4}-\d{2}-\d{2}$/.test(claimedDay) &&
      claimedDay >= day;
    if (session.data()?.postAlerts === false || user.data()?.loggedIn === false || alreadyClaimedToday) {
      return "unavailable";
    }
    tx.set(ref, {day, requestId, at: admin.firestore.FieldValue.serverTimestamp()});
    return "claimed";
  });
}

type Recipient = "sent" | "inbox" | "skipped";

async function notifyOne(uid: string, request: admin.firestore.DocumentData, payload: ReturnType<typeof filledPayload>,
  requestId: string, day: string): Promise<Recipient> {
  const user = (await db.doc(`usersv2/${uid}`).get()).data();
  const email = str(user?.email);
  if (!user || !email || user.deleted === true) return "skipped";
  const claim = await claimPushDay(uid, day, requestId, str(request.requesterUid), str(request.fillerUid));
  if (claim === "closed") return "skipped";
  if (claim === "blocked") return "skipped";
  const session = (await db.doc(`usersv2/${uid}/private/session`).get()).data();
  const push = claim === "claimed" && session?.postAlerts !== false;
  await sendToUser({...payload, modifier: email, docId: `wall_request_${requestId}_${uid}`},
    {
      uid,
      email,
      loggedOut: user.loggedIn === false,
      legacyToken: user.fcmToken,
      ...(typeof session?.postAlertsToken === "string" ? {postAlertsToken: session.postAlertsToken} : {}),
    }, push);
  return push ? "sent" : "inbox";
}

function filledPayload(requestId: string, text: string, wallId: string, galleryIds: string[], thumb: string) {
  return {
    ...notificationCopyPayload({kind: "wallRequestFilled", requestText: text}),
    // Route `wall` opens the filled wall on a build without the gallery page; `wall_ids` opens the gallery.
    data: {
      route: "wall",
      wall_id: wallId,
      ...(galleryIds.length > 1 ? {wall_ids: galleryIds.join(",")} : {}),
      request_id: requestId,
      notification_kind: "wall_request_filled",
    },
    // A single image: the Wall of the Day push is the day's one gallery image.
    imageUrl: isPreviewUrl(thumb) ? thumb : undefined,
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `wall_request_${requestId}`,
  };
}

/**
 * Tells the requester and every voter once that the request is filled. The claim on the request makes a retried
 * event send nothing. Each user gets at most one request push a UTC day and none with Posts off; both still get the
 * inbox entry. Users who block, or are blocked by, the requester or the filler get nothing.
 */
export async function notifyRequestFilled(requestId: string, nowMs = Date.now()):
  Promise<Record<Recipient, number>> {
  const ref = requestRef(requestId);
  const request: admin.firestore.DocumentData | null = await db.runTransaction(async (tx):
    Promise<admin.firestore.DocumentData | null> => {
    const data = (await tx.get(ref)).data();
    const text = publicRequestText(data?.text);
    if (!data || data.status !== "filled" || data.hidden === true || data.notifiedAt != null || text === null) return null;
    const requesterUid = str(data.requesterUid);
    if (requesterUid) {
      const [user, barrier] = await Promise.all([
        tx.get(db.collection("usersv2").doc(requesterUid)),
        tx.get(db.collection("creatorDeletionState").doc(requesterUid)),
      ]);
      if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true) return null;
    }
    tx.update(ref, {notifiedAt: admin.firestore.FieldValue.serverTimestamp()});
    return {...data, text};
  });
  const counts: Record<Recipient, number> = {sent: 0, inbox: 0, skipped: 0};
  if (!request) return counts;
  const voters = (await ref.collection(VOTES).get()).docs.map((d) => d.id);
  const recipients = [...new Set([str(request.requesterUid), ...voters])].filter(Boolean);
  const payload = filledPayload(requestId, str(request.text), str(request.filledWallId),
    await galleryIds(str(request.filledWallId)), str(request.filledWallThumb));
  const day = utcDateString(new Date(nowMs));
  for (let i = 0; i < recipients.length; i += PUSH_CHUNK) {
    const results = await Promise.allSettled(recipients.slice(i, i + PUSH_CHUNK)
      .map((uid) => notifyOne(uid, request, payload, requestId, day)));
    for (const r of results) {
      if (r.status === "fulfilled") counts[r.value]++;
      else logger.warn("wallRequests: one filled push failed.", {requestId, err: String(r.reason)});
    }
  }
  logger.info("wallRequests: filled push done.", {requestId, ...counts});
  return counts;
}

/** A Studio candidate made from a request. */
export interface StudioRequestPick {
  requestId: string;
  text: string;
  tags: string[];
}

/**
 * Up to `max` open requests for the daily Studio run, most votes first: visible, at least MIN_STUDIO_VOTES votes, made
 * in the last 30 days, the text still passes the checks, and not given to Studio in the last 7 days. Reads only, so
 * the run's transaction can mark them.
 */
export async function studioRequestPicks(tx: admin.firestore.Transaction, max: number, nowMs: number):
  Promise<StudioRequestPick[]> {
  if (max <= 0) return [];
  const base = db.collection(WALL_REQUESTS)
    .where("status", "==", "open")
    .where("hidden", "==", false)
    .orderBy("voteCount", "desc");
  const pageSize = 20;
  let query = base.limit(pageSize);
  const picks: StudioRequestPick[] = [];
  while (picks.length < max) {
    const snap = await tx.get(query);
    for (const doc of snap.docs) {
      const d = doc.data();
      const text = publicRequestText(d.text);
      const fresh = millis(d.createdAt) >= nowMs - TOP_WINDOW_MS;
      const queuedRecently = millis(d.studioQueuedAt) > nowMs - STUDIO_RETRY_MS;
      if (text === null || !fresh || queuedRecently || (d.voteCount ?? 0) < MIN_STUDIO_VOTES) continue;
      const tags = Array.isArray(d.tags) ? d.tags.filter((t): t is string => REQUEST_TAGS.has(t)) : [];
      picks.push({requestId: doc.id, text, tags});
      if (picks.length >= max) break;
    }
    if (picks.length >= max || snap.docs.length < pageSize) break;
    query = base.startAfter(snap.docs[snap.docs.length - 1]).limit(pageSize);
  }
  return picks;
}

/** Deletes the user's requests with their votes, and takes the user's votes off other requests. */
export async function removeWallRequestsForAccount(uid: string): Promise<void> {
  const own = await db.collection(WALL_REQUESTS).where("requesterUid", "==", uid).get();
  for (const doc of own.docs) await db.recursiveDelete(doc.ref);
  const votes = await db.collectionGroup(VOTES).where("uid", "==", uid).get();
  for (const vote of votes.docs) {
    // Other collections may have a "votes" subcollection too.
    const parts = vote.ref.path.split("/");
    if (parts.length !== 4 || parts[0] !== WALL_REQUESTS || parts[2] !== VOTES) continue;
    const parent = requestRef(parts[1]);
    await db.runTransaction(async (tx) => {
      const [current, request] = await Promise.all([tx.get(vote.ref), tx.get(parent)]);
      if (!current.exists) return;
      tx.delete(vote.ref);
      if (request.exists) {
        tx.update(parent, {voteCount: Math.max(0, (Number(request.data()?.voteCount) || 0) - 1)});
      }
    });
  }
}

function signedIn(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to request walls.");
  return uid;
}

const field = (data: unknown, key: string): unknown =>
  typeof data === "object" && data !== null ? (data as Record<string, unknown>)[key] : undefined;

export const createWallRequestCallable = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>) => createWallRequest(signedIn(request), request.data));

export const setWallRequestVoteCallable = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>) => {
    const uid = signedIn(request);
    const vote = field(request.data, "vote");
    if (typeof vote !== "boolean") throw new HttpsError("invalid-argument", "vote must be true or false.");
    return setWallRequestVote(uid, requestIdFrom(field(request.data, "requestId")), vote);
  });

export const listWallRequestsCallable = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>) => {
    const tab = tabFrom(field(request.data, "tab"));
    const isAdmin = Boolean(request.auth) && await isAdminCaller(request.auth);
    return {requests: await listWallRequests(request.auth?.uid ?? "", tab, isAdmin)};
  });

export const setWallRequestHiddenCallable = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>) => {
    const uid = signedIn(request);
    if (!(await isAdminCaller(request.auth))) throw new HttpsError("permission-denied", "Only admins can hide requests.");
    const hidden = field(request.data, "hidden");
    if (typeof hidden !== "boolean") throw new HttpsError("invalid-argument", "hidden must be true or false.");
    await setWallRequestHidden(requestIdFrom(field(request.data, "requestId")), hidden, uid);
    return {ok: true};
  });
