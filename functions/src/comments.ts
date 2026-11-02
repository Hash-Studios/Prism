import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {isValidRequestId} from "./coinsCallables";
import {CALLABLE_REGIONS, db, int, str, utcDateString} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {isLoggedOut, type PersonalPayload, type PushRecipient, sendToUser} from "./notificationHelper";
import {hasBlockedWord, HIDDEN_CHARACTERS, TEXT_SEGMENTER} from "./textSafety";
import {normalizeId, WALLPAPER_STATS} from "./viewStats";

export const COMMENTS = "comments";
export const COMMENT_RATE = "commentRate";
const COMMENT_PUSH = "commentPush";
export const COMMENT_MAX_GRAPHEMES = 500;
export const COMMENT_MIN_GAP_MS = 10_000;
export const COMMENTS_PER_DAY = 50;
export const COMMENT_PUSH_GAP_MS = 60 * 60 * 1000;
const MIN_ACCOUNT_AGE_MS = 24 * 60 * 60 * 1000;
const PREVIEW_GRAPHEMES = 80;
const FLAG_CACHE_MS = 60_000;
const DOC_ID = /^[^/\s]{1,128}$/;

export type CommentState = "visible" | "hidden";
export type CommentRefusal =
  | "comments_disabled"
  | "comment_guest"
  | "comment_too_new"
  | "comment_wall_unavailable"
  | "comment_empty"
  | "comment_too_long"
  | "comment_hidden_characters"
  | "comment_blocked_word"
  | "comment_blocked"
  | "comment_too_fast"
  | "comment_daily_limit";
export type DeleteRole = "author" | "creator" | "admin";

export interface CommentView {
  id: string;
  wallId: string;
  authorUid: string;
  authorName: string;
  authorUsername: string;
  authorPhoto: string;
  text: string;
  createdAtMs: number;
  state: CommentState;
}

export type AddCommentResponse = {ok: true; comment: CommentView} | {ok: false; reason: CommentRefusal};

let flagCache: {at: number; value: Promise<boolean>} | undefined;

/** Overridable in tests. */
export const commentIo = {
  /** Account age, and whether it is a signed-in, verified, non-guest account. */
  async account(uid: string): Promise<{createdMs: number; member: boolean}> {
    const user = await admin.auth().getUser(uid);
    return {
      createdMs: Date.parse(user.metadata.creationTime),
      member: user.emailVerified === true && !user.disabled &&
        user.providerData.some((provider) => !!provider.providerId && provider.providerId !== "anonymous"),
    };
  },
  /** The Remote Config kill switch `comments_enabled`. Missing or unreadable means on. */
  enabled(): Promise<boolean> {
    if (flagCache && Date.now() - flagCache.at <= FLAG_CACHE_MS) return flagCache.value;
    const value = admin.remoteConfig().getTemplate().then((template) => {
      const raw = (template.parameters?.comments_enabled?.defaultValue as {value?: string} | undefined)?.value;
      return !["false", "0"].includes(str(raw).toLowerCase());
    }, (err: unknown) => {
      logger.warn("comments: could not read comments_enabled.", {err});
      return true;
    });
    flagCache = {at: Date.now(), value};
    return value;
  },
  notify: (payload: PersonalPayload, recipient: PushRecipient, pushEnabled: boolean): Promise<boolean> =>
    sendToUser(payload, recipient, pushEnabled),
};

const graphemes = (text: string): string[] => [...TEXT_SEGMENTER.segment(text)].map((s) => s.segment);

/**
 * The text to store, or the refusal. Spaces collapse, at most one blank line stays, and the ends are trimmed.
 * A newline and a joiner between two emoji are the only control or format characters allowed.
 */
export function commentText(raw: unknown): {text: string} | {reason: CommentRefusal} {
  if (typeof raw !== "string") throw new HttpsError("invalid-argument", "text must be a string.");
  if (raw.length > COMMENT_MAX_GRAPHEMES * 16) return {reason: "comment_too_long"};
  const normalized = raw.replace(/\r\n?/g, "\n");
  const bare = normalized.replace(/\n/g, "").replace(
    /(?<=\p{Extended_Pictographic}️?\p{Emoji_Modifier}?)‍(?=\p{Extended_Pictographic})/gu, "");
  if (HIDDEN_CHARACTERS.test(bare) || /\p{Cs}/u.test(bare)) return {reason: "comment_hidden_characters"};
  const text = normalized.replace(/[^\S\n]+/g, " ").replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  if (text === "") return {reason: "comment_empty"};
  if (graphemes(text).length > COMMENT_MAX_GRAPHEMES) return {reason: "comment_too_long"};
  if (hasBlockedWord(text)) return {reason: "comment_blocked_word"};
  return {text};
}

function docIdFrom(raw: unknown, name: string): string {
  if (typeof raw !== "string" || !DOC_ID.test(raw) || raw === "." || raw === ".." || raw.startsWith("__")) {
    throw new HttpsError("invalid-argument", `${name} is invalid.`);
  }
  return raw;
}

function signedIn(request: CallableRequest<unknown>): string {
  const uid = str(request.auth?.uid);
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to comment.");
  return uid;
}

function field(data: unknown, name: string): unknown {
  return typeof data === "object" && data !== null ? (data as Record<string, unknown>)[name] : undefined;
}

export const commentRef = (wallId: string, commentId: string) =>
  db.collection("walls").doc(wallId).collection(COMMENTS).doc(commentId);

/** A comment id is a hash of the author and the request, so a retried request finds the comment it wrote. */
export function commentIdFor(uid: string, requestId: string): string {
  return createHash("sha256").update(`${uid}\n${requestId}`).digest("hex").slice(0, 32);
}

function millis(value: unknown): number {
  return value instanceof admin.firestore.Timestamp ? value.toMillis() : 0;
}

export function commentView(id: string, data: admin.firestore.DocumentData): CommentView {
  return {
    id,
    wallId: str(data.wallId),
    authorUid: str(data.authorUid),
    authorName: str(data.authorName),
    authorUsername: str(data.authorUsername),
    authorPhoto: str(data.authorPhoto),
    text: typeof data.text === "string" ? data.text : "",
    createdAtMs: millis(data.createdAt),
    state: data.state === "visible" ? "visible" : "hidden",
  };
}

/**
 * The count of visible comments lives in the wall's public stats doc, next to its favourites. A write to the wall doc
 * would wake its 12 triggers, one of them a 1 GiB conversion, on every comment.
 */
function statsRef(wall: admin.firestore.DocumentData | undefined, comment?: admin.firestore.DocumentData):
  admin.firestore.DocumentReference | null {
  try {
    const id = comment?.statsId ?? wall?.id;
    return db.collection(WALLPAPER_STATS).doc(normalizeId(id));
  } catch {
    return null;
  }
}

const countBy = (n: number) => ({comments: admin.firestore.FieldValue.increment(n)});

/** Adds a comment and counts it in one transaction. Refusals come back as a reason, not an error. */
export const addComment = onCall({region: CALLABLE_REGIONS, cors: true, maxInstances: 10},
  async (request: CallableRequest<unknown>): Promise<AddCommentResponse> => {
    const uid = signedIn(request);
    const wallId = docIdFrom(field(request.data, "wallId"), "wallId");
    const requestId = field(request.data, "requestId");
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    const parsed = commentText(field(request.data, "text"));
    if (!(await commentIo.enabled())) return {ok: false, reason: "comments_disabled"};

    const ref = commentRef(wallId, commentIdFor(uid, requestId));
    if ("reason" in parsed) return {ok: false, reason: parsed.reason};

    const account = await commentIo.account(uid);
    if (!account.member) return {ok: false, reason: "comment_guest"};
    if (!Number.isFinite(account.createdMs) || Date.now() - account.createdMs < MIN_ACCOUNT_AGE_MS) {
      return {ok: false, reason: "comment_too_new"};
    }

    const wallRef = db.collection("walls").doc(wallId);
    const authorRef = db.collection("usersv2").doc(uid);
    const rateRef = db.collection(COMMENT_RATE).doc(uid);
    const pushRef = db.collection(COMMENT_PUSH).doc(wallId);
    let response: AddCommentResponse | null = null;
    let notice: {payload: PersonalPayload; recipient: PushRecipient; pushEnabled: boolean} | null = null;
    await db.runTransaction(async (tx) => {
      response = null;
      notice = null;
      const [commentSnap, wallSnap, authorSnap, barrierSnap, rateSnap, pushSnap] = await Promise.all([
        tx.get(ref), tx.get(wallRef), tx.get(authorRef), tx.get(db.collection("creatorDeletionState").doc(uid)),
        tx.get(rateRef), tx.get(pushRef),
      ]);
      const author = authorSnap.data();
      if (!author || author.deleted === true || barrierSnap.data()?.closed === true) {
        response = {ok: false, reason: "comment_guest"};
        return;
      }
      const wall = wallSnap.data();
      if (!wall || wall.review !== true) {
        response = {ok: false, reason: "comment_wall_unavailable"};
        return;
      }
      const creatorUid = str(wall.creatorUid);
      const creatorRef = creatorUid && creatorUid !== uid ? db.collection("usersv2").doc(creatorUid) : null;
      const [blockedBy, blocking, creatorSnap, sessionSnap, creatorBarrier] = creatorRef ? await Promise.all([
        tx.get(creatorRef.collection("blockedUsers").doc(uid)),
        tx.get(authorRef.collection("blockedUsers").doc(creatorUid)),
        tx.get(creatorRef),
        tx.get(creatorRef.collection("private").doc("session")),
        tx.get(db.collection("creatorDeletionState").doc(creatorUid)),
      ]) : [null, null, null, null, null];
      if (blockedBy?.exists || blocking?.exists) {
        response = {ok: false, reason: "comment_blocked"};
        return;
      }
      if (commentSnap.exists) {
        const existing = commentSnap.data() ?? {};
        if (existing.authorUid !== uid || existing.wallId !== wallId || existing.requestId !== requestId) {
          throw new HttpsError("already-exists", "Comment request conflicts with an existing comment.");
        }
        response = existing.state === "visible" ?
          {ok: true, comment: commentView(ref.id, existing)} : {ok: false, reason: "comment_wall_unavailable"};
        return;
      }
      const nowMs = Date.now();
      const today = utcDateString(new Date(nowMs));
      const rate = rateSnap.data();
      if (nowMs - int(rate?.lastAtMs, 0) < COMMENT_MIN_GAP_MS) {
        response = {ok: false, reason: "comment_too_fast"};
        return;
      }
      const todayCount = rate?.day === today ? int(rate?.count, 0) : 0;
      if (todayCount >= COMMENTS_PER_DAY) {
        response = {ok: false, reason: "comment_daily_limit"};
        return;
      }

      const stats = statsRef(wall);
      if (!stats) {
        response = {ok: false, reason: "comment_wall_unavailable"};
        return;
      }
      const at = admin.firestore.Timestamp.fromMillis(nowMs);
      const data = {
        wallId,
        statsId: stats.id,
        authorUid: uid,
        authorName: str(author.name) || str(author.username),
        authorUsername: str(author.username),
        authorPhoto: str(author.profilePhoto),
        text: parsed.text,
        createdAt: at,
        state: "visible" satisfies CommentState,
        requestId,
      };
      tx.create(ref, data);
      tx.set(stats, countBy(1), {merge: true});
      tx.set(rateRef, {lastAtMs: nowMs, day: today, count: todayCount + 1});
      response = {ok: true, comment: commentView(ref.id, data)};

      const creator = creatorSnap?.data();
      const creatorEmail = str(creator?.email);
      if (!creatorRef || !creator || creator.deleted === true || creatorBarrier?.data()?.closed === true || !creatorEmail) return;
      if (nowMs - int(pushSnap.data()?.lastAtMs, 0) < COMMENT_PUSH_GAP_MS) return;
      tx.set(pushRef, {lastAtMs: nowMs, creatorUid});
      const preview = graphemes(parsed.text.replace(/\n/g, " "));
      notice = {
        payload: {
          ...notificationCopyPayload({
            kind: "wallCommented",
            commenterName: data.authorName || "A Prism user",
            wallTitle: str(wall.title),
            text: preview.length > PREVIEW_GRAPHEMES ? `${preview.slice(0, PREVIEW_GRAPHEMES).join("")}…` : parsed.text,
          }),
          data: {route: "wall", wall_id: wallId, notification_kind: "wall_comment"},
          modifier: creatorEmail,
          channelId: "followers",
          scoreKind: "follower",
          collapseKey: `comment_${wallId}`,
          docId: `comment_${ref.id}`,
        },
        recipient: {uid: creatorUid, email: creatorEmail, loggedOut: isLoggedOut(creator), legacyToken: creator.fcmToken},
        pushEnabled: sessionSnap?.data()?.followerAlerts !== false,
      };
    });
    if (!response) throw new HttpsError("internal", "Comment did not finish.");

    const result = response as AddCommentResponse;
    if (result.ok) {
      const current = await ref.get();
      if (!current.exists || current.data()?.state !== "visible") return {ok: false, reason: "comment_wall_unavailable"};
    }
    const sent = notice as {payload: PersonalPayload; recipient: PushRecipient; pushEnabled: boolean} | null;
    if (sent && sent.recipient.uid) {
      try {
        const creatorRef = db.collection("usersv2").doc(sent.recipient.uid);
        const [creator, barrier, session] = await Promise.all([
          creatorRef.get(), db.collection("creatorDeletionState").doc(sent.recipient.uid).get(),
          creatorRef.collection("private").doc("session").get(),
        ]);
        if (creator.exists && creator.data()?.deleted !== true && barrier.data()?.closed !== true) {
          await commentIo.notify(sent.payload, sent.recipient, session.data()?.followerAlerts !== false);
        }
      } catch (err) {
        logger.warn("addComment: notification failed.", {err});
      }
    }
    return response;
  });

/**
 * Moves a comment between visible and hidden, and keeps the count equal to the visible comments.
 * Returns false when the comment is gone or already in that state, so a retry changes nothing.
 */
export async function setCommentState(wallId: string, commentId: string, state: CommentState, by: string, reportId?: string):
  Promise<boolean> {
  const ref = commentRef(wallId, commentId);
  const wallRef = db.collection("walls").doc(wallId);
  return db.runTransaction(async (tx) => {
    const reportRef = reportId ? db.collection("contentReports").doc(reportId) : null;
    const [comment, wall, report] = await Promise.all([tx.get(ref), tx.get(wallRef), reportRef ? tx.get(reportRef) : null]);
    if (reportRef) {
      if (!report?.exists || report.data()?.status !== "open" || report.data()?.moderationApplied === true) return false;
      tx.update(reportRef, {moderationApplied: true});
    }
    if (!comment.exists || (comment.data()?.state === "visible") === (state === "visible")) return false;
    tx.update(ref, state === "hidden" ?
      {state, hiddenBy: by, hiddenAt: admin.firestore.FieldValue.serverTimestamp()} :
      {state, hiddenBy: admin.firestore.FieldValue.delete(), hiddenAt: admin.firestore.FieldValue.delete()});
    const stats = statsRef(wall.data(), comment.data());
    if (stats) tx.set(stats, countBy(state === "visible" ? 1 : -1), {merge: true});
    return true;
  });
}

/** Deletes one comment. A visible comment leaves the count. Returns false when it was already gone. */
async function removeComment(wallId: string, commentId: string, expectAuthor?: string): Promise<boolean> {
  const ref = commentRef(wallId, commentId);
  const wallRef = db.collection("walls").doc(wallId);
  return db.runTransaction(async (tx) => {
    const [comment, wall] = await Promise.all([tx.get(ref), tx.get(wallRef)]);
    if (!comment.exists || (expectAuthor !== undefined && comment.data()?.authorUid !== expectAuthor)) return false;
    tx.delete(ref);
    const stats = statsRef(wall.data(), comment.data());
    if (comment.data()?.state === "visible" && stats) tx.set(stats, countBy(-1), {merge: true});
    return true;
  });
}

/** The author, the wall's creator, or an admin deletes a comment. */
export const deleteComment = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>): Promise<{ok: true; deleted: boolean; role: DeleteRole | ""}> => {
    const uid = signedIn(request);
    const wallId = docIdFrom(field(request.data, "wallId"), "wallId");
    const commentId = docIdFrom(field(request.data, "commentId"), "commentId");
    const ref = commentRef(wallId, commentId);
    const adminCaller = await isAdminCaller(request.auth);
    return db.runTransaction(async (tx) => {
      const [comment, wall] = await Promise.all([tx.get(ref), tx.get(db.collection("walls").doc(wallId))]);
      if (!comment.exists) return {ok: true as const, deleted: false, role: "" as const};
      const role: DeleteRole | null = comment.data()?.authorUid === uid ? "author" :
        wall.exists && str(wall.data()?.creatorUid) === uid ? "creator" : adminCaller ? "admin" : null;
      if (!role) throw new HttpsError("permission-denied", "comment_delete_denied");
      tx.delete(ref);
      const stats = statsRef(wall.data(), comment.data());
      if (comment.data()?.state === "visible" && stats) tx.set(stats, countBy(-1), {merge: true});
      return {ok: true as const, deleted: true, role};
    });
  });

/** Admin only: hides a comment, or shows a comment that reports hid. */
export const setCommentHidden = onCall({region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<unknown>): Promise<{ok: true; changed: boolean}> => {
    const uid = signedIn(request);
    if (!(await isAdminCaller(request.auth))) throw new HttpsError("permission-denied", "Only admins can hide comments.");
    const hidden = field(request.data, "hidden");
    if (typeof hidden !== "boolean") throw new HttpsError("invalid-argument", "hidden must be true or false.");
    const wallId = docIdFrom(field(request.data, "wallId"), "wallId");
    const commentId = docIdFrom(field(request.data, "commentId"), "commentId");
    return {ok: true, changed: await setCommentState(wallId, commentId, hidden ? "hidden" : "visible", uid)};
  });

/** A comment report names its target as `<wallId>:<commentId>`. Comment ids never hold a colon. */
export function parseCommentTarget(target: string): {wallId: string; commentId: string} | null {
  const at = target.lastIndexOf(":");
  if (at <= 0 || at === target.length - 1) return null;
  const wallId = target.slice(0, at);
  const commentId = target.slice(at + 1);
  return DOC_ID.test(wallId) && /^[0-9a-f]{32}$/.test(commentId) ? {wallId, commentId} : null;
}

/** Deletes every comment the account wrote and takes the visible ones off their walls' counts. Safe to run again. */
export async function removeCommentsForAccount(uid: string): Promise<void> {
  const mine = await db.collectionGroup(COMMENTS).where("authorUid", "==", uid).get();
  for (const doc of mine.docs) {
    const parts = doc.ref.path.split("/");
    if (parts.length !== 4 || parts[0] !== "walls" || parts[2] !== COMMENTS) continue;
    await removeComment(parts[1], parts[3], uid);
  }
}
