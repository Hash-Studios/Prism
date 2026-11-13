import * as admin from "firebase-admin";
import {createHash, timingSafeEqual} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "../common";
import {R2Storage, r2Secrets} from "../r2Storage";
import {postDay} from "../studio/telegram";
import {
  assertFits, gridContent, panoramaContent, type Pipeline, setContent, type SocialContent, stillContent, themedStillContent,
} from "./content";
import {
  type ApprovalPress, parsePress, socialBotToken, socialOwnerChatId, socialTelegramSecrets, type Telegram, telegramClient,
  webhookSecret,
} from "./telegram";
import {type XClient, xClient, XError, xSecrets, xAccessSecret, xAccessToken, xApiKey, xApiSecret} from "./x";

// The X posting queue: prepare (build and preview), webhook (approve), publish (post, reply, reconcile), measure.
// Every post is one doc, socialPosts/{day}_{slot}. A run never sends a post twice: anything that may have reached X
// is reconciled against the account's own posts, and the owner decides when that check finds nothing.

export const SOCIAL_POSTS = "socialPosts";
const SEEN = "socialSeen";
const STATE = "socialState";

export type Slot = "am" | "noon" | "set" | "eve" | "night";
/** `weekday` (0 is Sunday, in IST) limits a slot to one day of the week. */
export const SLOTS: Record<Slot, {time: string; pipeline: Pipeline; weekday?: number}> = {
  am: {time: "09:30", pipeline: "grid"},
  noon: {time: "13:00", pipeline: "panorama"},
  set: {time: "15:00", pipeline: "set", weekday: 6},
  eve: {time: "17:00", pipeline: "still"},
  night: {time: "20:00", pipeline: "still"},
};
/** Each post is scheduled up to this far before or after its slot time, uniformly. */
export const JITTER_MS = 15 * 60_000;
export const EXPIRE_AFTER_MS = 2 * 3_600_000;
export const STALE_POSTING_MS = 10 * 60_000;
export const UNCERTAIN_AFTER_MS = 30 * 60_000;
/** A link reply later than this is not worth sending. */
export const REPLY_WINDOW_MS = 3 * 86_400_000;
const COOLDOWN_MS = {prism: 60 * 86_400_000, wallhaven: 180 * 86_400_000};

export interface SocialConfig {
  enabled: boolean;
  dryRun: boolean;
  slots: Record<Slot, boolean>;
  sketchyPerPost: number;
  autoApprove: {panorama: boolean; still: boolean};
  blockedTags: string[];
  blockedIds: string[];
}

/** socialConfig/current with safe defaults: off, dry run, approval for panoramas. A grid always needs approval. */
export async function loadSocialConfig(): Promise<SocialConfig> {
  const data = (await db.collection("socialConfig").doc("current").get()).data() ?? {};
  const strings = (value: unknown) => Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
  const sketchy = data.sketchyPerPost;
  return {
    enabled: data.enabled === true,
    dryRun: data.dryRun !== false,
    slots: Object.fromEntries((Object.keys(SLOTS) as Slot[]).map((slot) => [slot, data.slots?.[slot] !== false])) as
      Record<Slot, boolean>,
    sketchyPerPost: typeof sketchy === "number" && Number.isInteger(sketchy) && sketchy >= 0 && sketchy <= 3 ? sketchy : 2,
    autoApprove: {panorama: data.autoApprove?.panorama === true, still: data.autoApprove?.still === undefined || data.autoApprove?.still === true},
    blockedTags: strings(data.blockedTags),
    blockedIds: strings(data.blockedIds),
  };
}

/** The slot time in IST plus or minus up to 15 minutes, uniformly at random. */
export function scheduledAt(day: string, slot: Slot, random = Math.random): Date {
  return new Date(Date.parse(`${day}T${SLOTS[slot].time}:00+05:30`) + Math.round((random() * 2 - 1) * JITTER_MS));
}

export const contentHash = (mediaShas: string[], text: string, replyText: string,
  metadata: Array<{alt: string; sensitive: boolean}> = []) =>
  createHash("sha256").update(JSON.stringify([mediaShas, text, replyText, metadata])).digest("hex");
export const uncertaintyHash = (hash: string, attemptId: string, reply = false) =>
  createHash("sha256").update(JSON.stringify([hash, attemptId, reply])).digest("hex");
const storedContentHash = (post: admin.firestore.DocumentData) => contentHash(
  (post.media ?? []).map((m: admin.firestore.DocumentData) => m.sha256), str(post.text), str(post.replyText),
  (post.media ?? []).map((m: admin.firestore.DocumentData) => ({alt: str(m.alt), sensitive: m.sensitive})));
const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

export interface SocialDeps {
  now: Date;
  config: SocialConfig;
  telegram: Telegram | null;
  x: XClient | null;
  storage: Pick<R2Storage, "get" | "put">;
}

// ---------- prepare ----------

async function recentlyPosted(now: Date, blockedIds: string[]): Promise<Set<string>> {
  const since = admin.firestore.Timestamp.fromMillis(now.getTime() - COOLDOWN_MS.wallhaven);
  // Reservations first: a post that turns posted between the reads is then still seen in its cooldown.
  const queued = await db.collection(SOCIAL_POSTS).where("status", "in", ["pending_approval", "approved", "posting", "uncertain"]).get();
  const seen = await db.collection(SEEN).where("lastPostedAt", ">=", since).get();
  const out = new Set(blockedIds);
  for (const doc of seen.docs) {
    const kind = str(doc.data().kind) === "wallhaven" ? "wallhaven" : "prism";
    const at = doc.data().lastPostedAt?.toMillis?.() ?? 0;
    if (now.getTime() - at < COOLDOWN_MS[kind]) out.add(str(doc.data().id));
  }
  // Prepared walls are reserved before posting records their cooldown, including across IST days.
  for (const doc of queued.docs) {
    for (const id of doc.data().source?.ids ?? []) out.add(String(id));
  }
  return out;
}

export type Builders = Record<Pipeline, (day: string, exclude: Set<string>, slot: Slot, config: SocialConfig) =>
  Promise<SocialContent | null>>;

const weekday = (day: string) => new Date(`${day}T12:00:00+05:30`).getUTCDay();
const isSunday = (day: string) => weekday(day) === 0;
const istHour = (now: Date) => new Intl.DateTimeFormat("en-GB", {timeZone: "Asia/Kolkata", hour: "2-digit", hourCycle: "h23"})
  .format(now);

/** From 21:00 IST a run prepares tomorrow, so the owner reviews the next day's posts the night before. */
export const prepareFor = (now: Date) =>
  postDay(Number(istHour(now)) >= 21 ? new Date(now.getTime() + 24 * 3_600_000) : now);

export const defaultBuilders: Builders = {
  grid: (day, exclude, _slot, config) => gridContent(day, exclude, config),
  panorama: (day, exclude) => panoramaContent(day, exclude),
  still: async (day, exclude, slot, config) => {
    const wotd = slot === "night" && isSunday(day);
    const salt = slot === "eve" ? 0 : 1;
    // Wallhaven's most favourited walls of a theme first. Studio walls fill in when Wallhaven fails or runs dry.
    const themed = wotd ? null : await themedStillContent(day, exclude, config, salt).catch(() => {
      logger.warn("social: themed still failed.", {day, slot});
      return null;
    });
    return themed ?? stillContent(day, exclude, {wotd, salt});
  },
  set: (day, exclude, _slot, config) => setContent(day, exclude, config),
};

/** States a dry-run trigger may replace. Never anything that reached, or may have reached, X. */
const DRY_RUN_REBUILDS = new Set(["pending_approval", "approved", "dry_run", "skipped", "failed"]);

/** Builds missing posts, or rebuilds never-attempted posts in dry run. */
export async function prepareDay(deps: SocialDeps, builders: Builders = defaultBuilders): Promise<string[]> {
  const {config, now} = deps;
  if (!config.enabled) return [];
  const day = prepareFor(now);
  const exclude = await recentlyPosted(now, config.blockedIds);
  const existing = await db.collection(SOCIAL_POSTS).where("day", "==", day).get();
  // Every wall previewed in the prepared day's earlier dry runs, so a rebuild never shows an older set again.
  const drySeenRef = db.collection(STATE).doc("dryRunSeen");
  const drySeen = config.dryRun ? (await drySeenRef.get()).data() : undefined;
  const previewed = new Set<string>(drySeen?.day === day && Array.isArray(drySeen.ids) ? drySeen.ids.map(String) : []);
  for (const id of previewed) exclude.add(id);
  for (const doc of existing.docs) {
    for (const id of doc.data().source?.ids ?? []) {
      exclude.add(String(id));
      if (config.dryRun) previewed.add(String(id));
    }
  }
  // Save before deleting previews: a failed history write must leave their ids available for a retry.
  if (config.dryRun && previewed.size > 0) await drySeenRef.set({day, ids: [...previewed]});
  const kept = new Set<string>();
  for (const doc of existing.docs) {
    // In a dry run, every trigger rebuilds the prepared day's unposted posts with new walls, so the owner can try many sets.
    const removed = await db.runTransaction(async (tx) => {
      const post = (await tx.get(doc.ref)).data();
      // Empty/failed builds may recover by morning. Never retry owner skips or X refusals.
      const retryBuild = (post?.status === "failed" && post.error === "build_failed") ||
        (post?.status === "skipped" && post.error === "no_content");
      // Recheck under the publisher's claim lock. Owner drop/retry changes the status but retains attemptAt.
      if (!post || !(config.dryRun ? DRY_RUN_REBUILDS.has(str(post.status)) : retryBuild) ||
          post.attemptAt || post.attemptId || post.dispatchedAt || post.tweetId || post.postedAt) return false;
      tx.delete(doc.ref);
      return true;
    });
    if (!removed) kept.add(doc.id);
  }
  const made: string[] = [];
  for (const slot of Object.keys(SLOTS) as Slot[]) {
    const postId = `${day}_${slot}`;
    if (!config.slots[slot] || kept.has(postId)) continue;
    if (SLOTS[slot].weekday !== undefined && SLOTS[slot].weekday !== weekday(day)) continue;
    // Wall of the Day is picked at 09:00 IST, so the Sunday night post waits for Sunday's 10:00 run.
    if (slot === "night" && isSunday(day) && (postDay(now) !== day || Number(istHour(now)) < 10)) continue;
    const pipeline = SLOTS[slot].pipeline;
    const ref = db.collection(SOCIAL_POSTS).doc(postId);
    const base = {day, slot, pipeline, scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt(day, slot)),
      createdAt: admin.firestore.FieldValue.serverTimestamp()};
    let content: SocialContent | null;
    try {
      content = await builders[pipeline](day, exclude, slot, config);
      if (content) assertFits(content);
    } catch {
      logger.error("social: build failed.", {postId});
      await ref.create({...base, status: "failed", error: "build_failed"}).catch(() => null);
      continue;
    }
    if (!content) {
      await ref.create({...base, status: "skipped", error: "no_content"}).catch(() => null);
      continue;
    }
    const media = [];
    for (const item of content.media) {
      const digest = sha256(item.jpeg);
      const r2Key = `social/${postId}/${digest}.jpg`;
      await deps.storage.put("private", r2Key, item.jpeg, {sha256: digest}, "image/jpeg");
      media.push({r2Key, sha256: digest, bytes: item.jpeg.length, alt: item.alt, sensitive: item.sensitive,
        suggestFlag: item.suggestFlag === true});
    }
    const hash = contentHash(media.map((m) => m.sha256), content.text, content.replyText,
      media.map((m) => ({alt: m.alt, sensitive: m.sensitive})));
    // Every Wallhaven post (grid, set, themed still) needs the owner: tags and Vision cannot prove what is in a picture.
    const needsApproval = content.source.kind === "wallhaven" ||
      !(config.autoApprove as Record<string, boolean | undefined>)[pipeline];
    const queued = {...base, status: needsApproval ? "pending_approval" : "approved", source: content.source, media,
      text: content.text, replyText: content.replyText, contentHash: hash, approval: {required: needsApproval}};
    try {
      await ref.create(queued);
    } catch (err) {
      if ((err as {code?: number}).code === 6) continue;
      throw err;
    }
    for (const id of content.source.ids) exclude.add(id);
    made.push(postId);
    if (deps.telegram && (needsApproval || config.dryRun)) {
      await preview(deps, ref, queued, content.media.map((m) => m.jpeg));
    }
  }
  return made;
}

async function preview(deps: SocialDeps, ref: admin.firestore.DocumentReference,
  post: admin.firestore.DocumentData, bytes?: Buffer[]): Promise<void> {
  if (!deps.telegram) return;
  try {
    const media = post.media ?? [];
    const images = bytes ?? await Promise.all(media.map((m: admin.firestore.DocumentData) =>
      deps.storage.get("private", str(m.r2Key))));
    for (let i = 0; i < images.length; i++) {
      if (sha256(images[i]) !== media[i].sha256) throw new Error("Stored media changed.");
    }
    await deps.telegram.sendPhotos([
      `${deps.config.dryRun ? "[DRY RUN] " : ""}${ref.id} · ${post.pipeline} · ${SLOTS[post.slot as Slot].time} IST`,
      post.text, ...(str(post.replyText) ? [`Reply: ${post.replyText}`] : []),
      `Sensitive flags: ${media.filter((m: admin.firestore.DocumentData) => m.sensitive === true).length}`,
      ...(post.pipeline === "grid" ?
        [`Vision suggests a flag on: ${media.filter((m: admin.firestore.DocumentData) => m.suggestFlag).length} of ${media.length}`] : []),
      `Source: ${post.source.kind} ${post.source.ids.join(", ")}`,
    ].join("\n\n"), images);
    if (post.pipeline === "grid" || post.approval?.required) {
      await deps.telegram.sendButtons(`${ref.id}: post this?`, [
        {label: "Approve", action: "approve", postId: ref.id, hash: str(post.contentHash)},
        ...(post.pipeline === "grid" ? [{label: "Approve + flag", action: "flag" as const, postId: ref.id,
          hash: str(post.contentHash)}] : []),
        {label: "Skip", action: "skip", postId: ref.id, hash: str(post.contentHash)},
      ]);
    }
    await ref.update({previewSentAt: admin.firestore.FieldValue.serverTimestamp()});
  } catch {
    logger.error("social: preview failed.", {postId: ref.id});
  }
}

// ---------- approvals ----------

/** Applies one owner press. The hash ties the press to the exact content that was previewed. */
export async function applyPress(press: ApprovalPress): Promise<string> {
  const ref = db.collection(SOCIAL_POSTS).doc(press.postId);
  return db.runTransaction(async (tx) => {
    const post = (await tx.get(ref)).data();
    if (!post || !/^[a-f0-9]{12}$/.test(press.hash)) return "This post changed or is gone.";
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (press.action === "approve" || press.action === "flag" || press.action === "skip") {
      if (!str(post.contentHash).startsWith(press.hash)) return "This post changed or is gone.";
      if (press.action === "flag" && post.status === "pending_approval" && post.pipeline === "grid") {
        // Only the flags may change from what the owner previewed.
        if (storedContentHash(post) !== post.contentHash) return "This post changed or is gone.";
        // Flags the images Vision suggested, or all of them when it suggested none. The hash then covers the flags.
        const media = (post.media ?? []) as admin.firestore.DocumentData[];
        const pick = media.some((m) => m.suggestFlag === true);
        const flagged = {...post, media: media.map((m) => ({...m, sensitive: !pick || m.suggestFlag === true}))};
        const hash = storedContentHash(flagged);
        tx.update(ref, {status: "approved", media: flagged.media, contentHash: hash, approval: {...post.approval,
          decision: "approve", flagged: true, approvedHash: hash, decidedAt: now}});
        return "Approved with flag.";
      }
      if (press.action === "approve" && post.status === "pending_approval") {
        tx.update(ref, {status: "approved", approval: {...post.approval, decision: "approve",
          approvedHash: post.contentHash, decidedAt: now}});
        return "Approved.";
      }
      if (press.action === "skip" && ["pending_approval", "approved"].includes(post.status)) {
        tx.update(ref, {status: "skipped", approval: {...post.approval, decision: "skip", decidedAt: now}});
        return "Skipped.";
      }
    } else if (post.status === "uncertain" &&
        uncertaintyHash(str(post.contentHash), str(post.attemptId)).startsWith(press.hash)) {
      tx.update(ref, press.action === "retry" ?
        // The owner asked for it, so it gets a fresh posting window instead of the slot's old expiry.
        {status: "approved", attemptId: admin.firestore.FieldValue.delete(), dispatchedAt: admin.firestore.FieldValue.delete(),
          scheduledAt: admin.firestore.Timestamp.now()} :
        {status: "skipped", error: "owner_dropped_uncertain"});
      return press.action === "retry" ? "Will post again." : "Dropped.";
    } else if (post.replyStatus === "uncertain" &&
        uncertaintyHash(str(post.contentHash), str(post.replyAttemptId), true).startsWith(press.hash)) {
      tx.update(ref, press.action === "retry" ? {replyStatus: admin.firestore.FieldValue.delete(),
        replyDispatchedAt: admin.firestore.FieldValue.delete(), replyAttemptId: admin.firestore.FieldValue.delete()} :
        {replyStatus: "dropped"});
      return press.action === "retry" ? "Will reply again." : "Reply dropped.";
    }
    return `Nothing to do: the post is ${post.status}.`;
  });
}

const DECIDED = new Set(["Approved.", "Approved with flag.", "Skipped.", "Will post again.", "Dropped.", "Will reply again.", "Reply dropped."]);

/**
 * One Telegram webhook update. Applies an owner press at once, shows the result as a toast, and replaces the buttons
 * with the outcome. Anything that is not an owner press is ignored.
 */
export async function handleTelegramUpdate(update: unknown, telegram: Telegram, ownerChatId: string): Promise<void> {
  const press = parsePress(update, ownerChatId);
  if (!press) return;
  const reply = await applyPress(press);
  await telegram.answer(press.callbackId, reply).catch(() => null);
  if (DECIDED.has(reply) && press.messageId > 0) {
    await telegram.markDone(press.messageId, `${press.postId}: ${reply.replace(/\.$/, "")} ✅`).catch(() => null);
  }
}

// ---------- publish ----------

const decode = (text: string) => text.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
/** X adds a t.co media link to the end of a post's text. */
export const normalizePostText = (text: string) => decode(text).replace(/(\s*https:\/\/t\.co\/\w+)+$/, "").trim();

async function myUserId(x: XClient): Promise<string> {
  const ref = db.collection(STATE).doc("x");
  const cached = str((await ref.get()).data()?.userId);
  if (cached) return cached;
  const id = await x.me();
  await ref.set({userId: id}, {merge: true});
  return id;
}

async function alert(deps: SocialDeps, postId: string, hash: string, text: string): Promise<boolean> {
  if (!deps.telegram) return false;
  try {
    await deps.telegram.sendButtons(text, [
      {label: "Post again", action: "retry", postId, hash},
      {label: "Leave it", action: "drop", postId, hash},
    ]);
    return true;
  } catch {
    logger.error("social: alert failed.", {postId});
    return false;
  }
}

async function notifyUncertain(deps: SocialDeps, ref: admin.firestore.DocumentReference,
  post: admin.firestore.DocumentData, reply = false): Promise<void> {
  const hash = uncertaintyHash(str(post.contentHash), str(reply ? post.replyAttemptId : post.attemptId), reply);
  const field = reply ? "replyAlertHash" : "alertHash";
  if (post[field] === hash) return;
  if (await alert(deps, ref.id, hash,
    `${ref.id}: ${reply ? "the link reply" : "the post"} may or may not be on X. Check @PrismWallpapers, then choose.`)) {
    await ref.update({[field]: hash});
  }
}

/** Moves the doc from one state to the next only when it is still in the expected state. */
async function transition(ref: admin.firestore.DocumentReference, expect: (post: admin.firestore.DocumentData) => boolean,
  update: Record<string, unknown>): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const post = (await tx.get(ref)).data();
    if (!post || !expect(post)) return false;
    tx.update(ref, update);
    return true;
  });
}

async function postMain(deps: SocialDeps, x: XClient, ref: admin.firestore.DocumentReference, post: admin.firestore.DocumentData) {
  const attemptId = `${deps.now.getTime()}-${Math.random().toString(36).slice(2, 8)}`;
  if (!await transition(ref, (p) => p.status === "approved" && p.contentHash === post.contentHash,
    {status: "posting", attemptId, attemptAt: admin.firestore.Timestamp.fromDate(deps.now)})) return;
  const back = (error: string) => transition(ref, (p) => p.attemptId === attemptId && p.status === "posting",
    {status: "approved", error, attemptId: admin.firestore.FieldValue.delete(),
      dispatchedAt: admin.firestore.FieldValue.delete(), mediaIds: admin.firestore.FieldValue.delete()});
  let mediaIds: string[];
  try {
    mediaIds = [];
    for (const item of post.media ?? []) {
      const jpeg = await deps.storage.get("private", str(item.r2Key));
      if (sha256(jpeg) !== item.sha256) throw new XError("Stored media changed.", 400);
      const id = await x.uploadImage(jpeg);
      try {
        await x.setMediaMetadata(id, str(item.alt), item.sensitive === true);
      } catch (err) {
        // Alt text is worth having but not worth a lost post. A sensitive image never posts without its flag.
        if (item.sensitive === true) throw err;
        logger.warn("social: alt text not set.", {postId: ref.id});
      }
      mediaIds.push(id);
    }
  } catch (err) {
    // Nothing is posted before the create call, so any failure here is safe to try again, except a refusal.
    const refused = err instanceof XError && err.status >= 400 && err.status < 500 && !err.retryable;
    if (refused) {
      await transition(ref, (p) => p.attemptId === attemptId, {status: "failed", error: "media_refused"});
    } else {
      await back("media_failed");
    }
    return;
  }
  if (!await transition(ref, (p) => p.status === "posting" && p.attemptId === attemptId && !p.dispatchedAt,
    {dispatchedAt: admin.firestore.Timestamp.fromDate(deps.now), mediaIds})) return;
  try {
    const tweetId = await x.createPost(str(post.text), {mediaIds});
    await markPosted(ref, attemptId, tweetId, post);
  } catch (err) {
    if (err instanceof XError && err.retryable) {
      await back("create_rate_limited");
    } else if (err instanceof XError && !err.uncertain) {
      await transition(ref, (p) => p.attemptId === attemptId, {status: "failed", error: "create_refused"});
    } else {
      // The post may exist. Leave it "posting"; reconcile checks the account after STALE_POSTING_MS.
      logger.warn("social: create result unknown.", {postId: ref.id});
    }
  }
}

async function markPosted(ref: admin.firestore.DocumentReference, attemptId: string, tweetId: string,
  post: admin.firestore.DocumentData): Promise<void> {
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data();
    if (current?.attemptId !== attemptId || current.status !== "posting") return;
    tx.update(ref, {status: "posted", tweetId, postedAt: admin.firestore.FieldValue.serverTimestamp(),
      error: admin.firestore.FieldValue.delete()});
    for (const id of post.source?.ids ?? []) {
      tx.set(db.collection(SEEN).doc(`${post.source.kind}_${id}`),
        {kind: post.source.kind, id, lastPostedAt: admin.firestore.FieldValue.serverTimestamp(), postId: ref.id});
    }
  });
}

/** A "posting" doc whose run died or whose create result was unknown. Never resends on its own. */
async function reconcileMain(deps: SocialDeps, x: XClient, ref: admin.firestore.DocumentReference, post: admin.firestore.DocumentData) {
  const dispatched = post.dispatchedAt?.toDate?.() as Date | undefined;
  const attemptId = str(post.attemptId);
  if (!dispatched) {
    // The run died before the create call: nothing reached X.
    await transition(ref, (p) => p.attemptId === attemptId && p.status === "posting",
      {status: "approved", attemptId: admin.firestore.FieldValue.delete()});
    return;
  }
  const own = await x.ownPostsSince(await myUserId(x), new Date(dispatched.getTime() - 120_000));
  const match = own.find((p) => p.replyTo === null && normalizePostText(p.text) === normalizePostText(str(post.text)) &&
    p.mediaCount === (post.media?.length ?? 0) &&
    Date.parse(p.createdAt) >= dispatched.getTime() - 1000 &&
    Date.parse(p.createdAt) <= dispatched.getTime() + STALE_POSTING_MS &&
    Array.isArray(post.mediaIds) && JSON.stringify(p.mediaIds) === JSON.stringify(post.mediaIds));
  if (match) {
    await markPosted(ref, attemptId, match.id, post);
    return;
  }
  if (deps.now.getTime() - dispatched.getTime() < UNCERTAIN_AFTER_MS) return;
  if (await transition(ref, (p) => p.attemptId === attemptId && p.status === "posting",
    {status: "uncertain", error: "create result unknown and no matching post found"})) {
    await notifyUncertain(deps, ref, post);
  }
}

async function postReply(deps: SocialDeps, x: XClient, ref: admin.firestore.DocumentReference, post: admin.firestore.DocumentData) {
  const replyAttemptId = `${deps.now.getTime()}-${Math.random().toString(36).slice(2)}`;
  if (!await transition(ref, (p) => p.status === "posted" && p.replyStatus === undefined,
    {replyStatus: "posting", replyAttemptId, replyDispatchedAt: admin.firestore.Timestamp.fromDate(deps.now)})) return;
  const update = (data: Record<string, unknown>) => transition(ref,
    (p) => p.replyStatus === "posting" && p.replyAttemptId === replyAttemptId, data);
  try {
    const replyId = await x.createPost(str(post.replyText), {replyTo: str(post.tweetId)});
    await update({replyStatus: "posted", replyId});
  } catch (err) {
    if (err instanceof XError && err.retryable) {
      await update({replyStatus: admin.firestore.FieldValue.delete(), replyDispatchedAt: admin.firestore.FieldValue.delete()});
    } else if (err instanceof XError && !err.uncertain) {
      await update({replyStatus: "failed", error: "reply_refused"});
    }
  }
}

async function reconcileReply(deps: SocialDeps, x: XClient, ref: admin.firestore.DocumentReference, post: admin.firestore.DocumentData) {
  const dispatched = post.replyDispatchedAt?.toDate?.() as Date;
  const own = await x.ownPostsSince(await myUserId(x), new Date(dispatched.getTime() - 120_000));
  const match = own.find((p) => p.replyTo === str(post.tweetId) && decode(p.text).trim() === decode(str(post.replyText)).trim() &&
    Date.parse(p.createdAt) >= dispatched.getTime() - 1000 &&
    Date.parse(p.createdAt) <= dispatched.getTime() + STALE_POSTING_MS);
  if (match) {
    await transition(ref, (p) => p.replyStatus === "posting" && p.replyAttemptId === post.replyAttemptId,
      {replyStatus: "posted", replyId: match.id});
    return;
  }
  if (deps.now.getTime() - dispatched.getTime() < UNCERTAIN_AFTER_MS) return;
  if (await transition(ref, (p) => p.replyStatus === "posting", {replyStatus: "uncertain"})) {
    await notifyUncertain(deps, ref, post, true);
  }
}

const ms = (value: unknown) => (value as admin.firestore.Timestamp | undefined)?.toMillis?.() ?? 0;

/** One publish pass, including unfinished work from earlier days. */
export async function publishDue(deps: SocialDeps): Promise<void> {
  if (!deps.config.enabled) return;
  const now = deps.now.getTime();
  // Open work in any state, plus recent posts that may still need their reply. Old posted docs are never read again.
  const [open, recent] = await Promise.all([
    db.collection(SOCIAL_POSTS).where("status", "in", ["pending_approval", "approved", "posting", "uncertain"]).get(),
    db.collection(SOCIAL_POSTS).where("postedAt", ">=", admin.firestore.Timestamp.fromMillis(now - REPLY_WINDOW_MS)).get(),
  ]);
  const posts = {docs: [...open.docs, ...recent.docs.filter((doc) => doc.data().status === "posted")]};
  let sentMain = false;
  for (const doc of posts.docs.sort((a, b) => ms(a.data().scheduledAt) - ms(b.data().scheduledAt))) {
    const post = doc.data();
    const due = ms(post.scheduledAt);
    try {
      if (!post.previewSentAt && deps.telegram && now <= due + EXPIRE_AFTER_MS &&
          (post.status === "pending_approval" || (deps.config.dryRun && post.status === "approved"))) {
        await preview(deps, doc.ref, post);
      }
      if (["pending_approval", "approved"].includes(post.status) && now > due + EXPIRE_AFTER_MS) {
        await transition(doc.ref, (p) => p.status === post.status, {status: "skipped", error: "expired"});
      } else if (post.status === "approved" && now >= due && !sentMain && deps.config.slots[post.slot as Slot]) {
        const blockedTags = new Set(deps.config.blockedTags.map((tag) => tag.toLowerCase()));
        if ((post.source?.ids ?? []).some((id: string) => deps.config.blockedIds.includes(id)) ||
            (post.source?.tags ?? []).some((tag: string) => blockedTags.has(tag.toLowerCase())) ||
            (post.pipeline === "grid" && blockedTags.size > 0 && !Array.isArray(post.source?.tags))) {
          await transition(doc.ref, (p) => p.status === "approved", {status: "skipped", error: "blocked_content"});
          continue;
        }
        if (storedContentHash(post) !== post.contentHash || (post.media ?? []).some(
          (m: admin.firestore.DocumentData) => typeof m.sensitive !== "boolean")) {
          await transition(doc.ref, (p) => p.status === "approved", {status: "failed", error: "content_changed"});
          continue;
        }
        if ((post.pipeline === "grid" || post.approval?.required) &&
            (post.approval?.decision !== "approve" || post.approval?.approvedHash !== post.contentHash)) {
          await transition(doc.ref, (p) => p.status === "approved", {status: "pending_approval",
            approval: {...post.approval, required: true}, previewSentAt: admin.firestore.FieldValue.delete()});
          continue;
        }
        if (deps.config.dryRun || !deps.x) {
          await transition(doc.ref, (p) => p.status === "approved", {status: "dry_run"});
        } else {
          await postMain(deps, deps.x, doc.ref, post);
          sentMain = true;
        }
      } else if (post.status === "uncertain") {
        await notifyUncertain(deps, doc.ref, post);
      } else if (post.status === "posted" && post.replyStatus === "uncertain") {
        await notifyUncertain(deps, doc.ref, post, true);
      } else if (post.status === "posting" && deps.x && now - ms(post.attemptAt) > STALE_POSTING_MS) {
        await reconcileMain(deps, deps.x, doc.ref, post);
      } else if (post.status === "posted" && !deps.config.dryRun && deps.x && post.replyStatus === undefined && str(post.replyText)) {
        await postReply(deps, deps.x, doc.ref, post);
      } else if (post.status === "posted" && !deps.config.dryRun && deps.x && post.replyStatus === "posting" &&
          now - ms(post.replyDispatchedAt) > STALE_POSTING_MS) {
        await reconcileReply(deps, deps.x, doc.ref, post);
      }
    } catch {
      logger.error("social: publish step failed.", {postId: doc.id});
    }
  }
}

// ---------- measure ----------

/** Reads metrics for posts and replies at 24 hours and 7 days. */
export async function measurePosts(deps: SocialDeps): Promise<number> {
  if (!deps.config.enabled || !deps.x) return 0;
  const since = admin.firestore.Timestamp.fromMillis(deps.now.getTime() - 9 * 86_400_000);
  const posts = (await db.collection(SOCIAL_POSTS).where("postedAt", ">=", since).get()).docs
    .filter((doc) => doc.data().status === "posted" && str(doc.data().tweetId));
  const due: Array<{doc: admin.firestore.QueryDocumentSnapshot; key: "h24" | "d7"}> = [];
  for (const doc of posts) {
    const age = deps.now.getTime() - ms(doc.data().postedAt);
    for (const key of ["h24", "d7"] as const) {
      const threshold = (key === "h24" ? 1 : 7) * 86_400_000;
      if (age >= threshold && (!doc.data().metrics?.post?.[key] ||
          (str(doc.data().replyId) && !doc.data().metrics?.reply?.[key]))) due.push({doc, key});
    }
  }
  if (due.length === 0) return 0;
  const ids = [...new Set(due.flatMap(({doc}) => [str(doc.data().tweetId), str(doc.data().replyId)]).filter(Boolean))];
  const metrics = await deps.x.metrics(ids);
  for (const {doc, key} of due) {
    const post = metrics[str(doc.data().tweetId)];
    const reply = metrics[str(doc.data().replyId)];
    const update: Record<string, unknown> = {};
    if (post && !doc.data().metrics?.post?.[key]) {
      update[`metrics.post.${key}`] = post;
      update[`metrics.postSampledAt.${key}`] = admin.firestore.FieldValue.serverTimestamp();
    }
    if (reply && !doc.data().metrics?.reply?.[key]) {
      update[`metrics.reply.${key}`] = reply;
      update[`metrics.replySampledAt.${key}`] = admin.firestore.FieldValue.serverTimestamp();
    }
    if (Object.keys(update).length) await doc.ref.update(update);
  }
  return due.length;
}

// ---------- schedules ----------

async function liveDeps(withX: boolean, withTelegram: boolean): Promise<SocialDeps> {
  const config = await loadSocialConfig();
  return {
    now: new Date(),
    config,
    telegram: withTelegram ? telegramClient(socialBotToken.value(), socialOwnerChatId.value()) : null,
    x: withX && !config.dryRun ? xClient({apiKey: xApiKey.value(), apiSecret: xApiSecret.value(),
      token: xAccessToken.value(), tokenSecret: xAccessSecret.value()}) : null,
    storage: new R2Storage(),
  };
}

/** A lease so two publish runs never post at the same time. */
async function withLease(name: string, ttlMs: number, run: () => Promise<void>): Promise<void> {
  const ref = db.collection(STATE).doc(`lease_${name}`);
  const owner = Math.random().toString(36).slice(2);
  const got = await db.runTransaction(async (tx) => {
    const until = ms((await tx.get(ref)).data()?.until);
    if (until > Date.now()) return false;
    tx.set(ref, {owner, until: admin.firestore.Timestamp.fromMillis(Date.now() + ttlMs)});
    return true;
  });
  if (!got) return;
  try {
    await run();
  } finally {
    await db.runTransaction(async (tx) => {
      if ((await tx.get(ref)).data()?.owner === owner) tx.delete(ref);
    });
  }
}

const WEBHOOK_FUNCTION = "socialTelegramWebhook";
const projectId = () => process.env.GCLOUD_PROJECT || JSON.parse(process.env.FIREBASE_CONFIG ?? "{}").projectId;

export const socialPrepare = onSchedule({schedule: "0 7,10,22 * * *", timeZone: "Asia/Kolkata", region: REGION,
  memory: "1GiB", timeoutSeconds: 540, retryCount: 1, secrets: [...socialTelegramSecrets, ...r2Secrets]}, async () => {
  const deps = await liveDeps(false, true);
  // Points the approval bot at the webhook. Idempotent, so every run repairs a lost or changed registration.
  await deps.telegram?.setWebhook(`https://${REGION}-${projectId()}.cloudfunctions.net/${WEBHOOK_FUNCTION}`,
    webhookSecret(socialBotToken.value())).catch(() => logger.error("social: setWebhook failed."));
  const made = await prepareDay(deps);
  logger.info("social: prepared.", {made});
});

/** Telegram calls this on every approval button press. Only requests with the bot's secret header count. */
export const socialTelegramWebhook = onRequest({region: REGION, invoker: "public", maxInstances: 1, cpu: "gcf_gen1", timeoutSeconds: 30,
  memory: "256MiB", secrets: socialTelegramSecrets}, async (req, res) => {
  const token = socialBotToken.value();
  const supplied = Buffer.from(req.get("X-Telegram-Bot-Api-Secret-Token") ?? "");
  const expected = Buffer.from(webhookSecret(token));
  if (req.method !== "POST" || !token || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    res.sendStatus(403);
    return;
  }
  try {
    await handleTelegramUpdate(req.body, telegramClient(token, socialOwnerChatId.value()), socialOwnerChatId.value());
  } catch {
    logger.error("social: approval press failed.");
  }
  // Always 200 for a real Telegram call, so Telegram does not resend the same press.
  res.sendStatus(200);
});

export const socialPublish = onSchedule({schedule: "every 5 minutes", region: REGION, memory: "512MiB",
  timeoutSeconds: 300, secrets: [...xSecrets, ...socialTelegramSecrets, ...r2Secrets]}, async () => {
  await withLease("publish", 6 * 60_000, async () => publishDue(await liveDeps(true, true)));
});

export const socialMeasure = onSchedule({schedule: "30 6 * * *", timeZone: "Asia/Kolkata", region: REGION,
  timeoutSeconds: 120, secrets: [...xSecrets], cpu: "gcf_gen1"}, async () => {
  const measured = await measurePosts(await liveDeps(true, false));
  logger.info("social: measured.", {measured});
});
