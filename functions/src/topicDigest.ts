import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {localDay, offsetsAtDigestTime} from "./followDigest";
import {notificationCopyPayload} from "./notificationCatalog";
import {FCM_TOKEN_BINDING_VERSION, sendToUser} from "./notificationHelper";
import {buildPushGallery, galleryTags, galleryWall, tagsLine, type GalleryWall, type PushGallery} from "./pushGallery";
import {CATEGORY_NAMES} from "./wallCategory";
import {premiumCollections} from "./wallEligibility";
import {matchesMood, MOODS} from "./wallMoods";

/** 16:00 local: after the 13:00 folder digest and before the 18:00 win-back and the 19:00 follow digest. */
const TOPIC_DIGEST_MINUTE = 16 * 60;
const WINDOW_MS = 24 * 60 * 60 * 1000;
const INACTIVE_MS = 30 * 24 * 60 * 60 * 1000;
const CHUNK_SIZE = 25;
const MARKER = "topicDigest";
export const MAX_FOLLOWED_TOPICS = 20;
/** The session field the job queries. The app writes it only while the user follows at least one topic. */
export const TOPIC_OFFSET_FIELD = "followedTopicsOffset";
export const TOPIC_NEWS_DOC = "topicNews/current";

export type TopicKind = "category" | "mood";

/** A topic a user can follow. `key` is `<kind>:<id>`, the value stored in `followedTopics`. */
export interface Topic {
  key: string;
  kind: TopicKind;
  id: string;
  /** English name for the push. The app shows its own localized name. */
  name: string;
  matches: (wall: admin.firestore.DocumentData) => boolean;
}

const MOOD_NAMES: Record<string, string> = {
  duo_reveal: "Duo reveal",
  dreamy: "Dreamy",
  dark_quiet: "Dark and quiet",
  bright_bold: "Bright and bold",
  minimal: "Minimal",
  spatial_ready: "Spatial ready",
  depth_ready: "Depth ready",
};

/** The only topics the server accepts. A key that is not here is ignored, whatever the client wrote. */
export const TOPICS: ReadonlyMap<string, Topic> = new Map([
  ...CATEGORY_NAMES.map((name): Topic => ({
    key: `category:${name}`, kind: "category", id: name, name, matches: (wall) => wall.category === name,
  })),
  ...MOODS.map((rule): Topic => ({
    key: `mood:${rule.id}`, kind: "mood", id: rule.id, name: MOOD_NAMES[rule.id] ?? rule.id,
    matches: (wall) => matchesMood(rule, wall),
  })),
].map((topic) => [topic.key, topic]));

/** Known topics from a stored `followedTopics` value, in follow order, without repeats, at most 20. */
export function parseFollowedTopics(value: unknown): Topic[] {
  if (!Array.isArray(value)) return [];
  const topics = new Set<Topic>();
  for (const key of value) {
    const topic = typeof key === "string" ? TOPICS.get(key) : undefined;
    if (topic) topics.add(topic);
  }
  return [...topics].slice(0, MAX_FOLLOWED_TOPICS);
}

/** An approved wall in the window and the keys of every topic it belongs to. */
export interface TopicWall {
  creatorUid: string;
  approvedMs: number;
  wall: GalleryWall;
  topicKeys: string[];
}

/** One user's digest: topics with the most new walls first, walls alternating between them, no wall twice. */
export interface TopicDigest {
  topics: Array<{topic: Topic; count: number}>;
  walls: GalleryWall[];
}

/** The digest of the walls approved after `sinceMs` in `followed`, without blocked creators. Null when none. */
export function planTopicDigest(
  followed: Topic[], walls: TopicWall[], sinceMs: number, blocked: ReadonlySet<string> = new Set(),
): TopicDigest | null {
  const fresh = walls.filter((w) => w.approvedMs > sinceMs && !blocked.has(w.creatorUid))
    .sort((a, b) => b.approvedMs - a.approvedMs);
  const groups = followed
    .map((topic, order) => ({topic, order, walls: fresh.filter((w) => w.topicKeys.includes(topic.key))}))
    .filter((g) => g.walls.length > 0)
    .sort((a, b) => b.walls.length - a.walls.length || a.order - b.order);
  if (groups.length === 0) return null;
  const seen = new Set<string>();
  const ordered: GalleryWall[] = [];
  const longest = Math.max(...groups.map((g) => g.walls.length));
  for (let i = 0; i < longest; i++) {
    for (const group of groups) {
      const wall = group.walls[i]?.wall;
      if (wall && !seen.has(wall.id)) {
        seen.add(wall.id);
        ordered.push(wall);
      }
    }
  }
  return {topics: groups.map((g) => ({topic: g.topic, count: g.walls.length})), walls: ordered};
}

/** The app link of a topic page. */
export function topicUrl(topic: Topic): string {
  return topic.kind === "mood" ?
    `https://prismwalls.com/mood/${topic.id}?source=push` :
    `https://prismwalls.com/category/${encodeURIComponent(topic.id)}`;
}

/** The push for one digest. A tap opens the page of the topic with the most new walls. */
export function topicDigestPayload(digest: TopicDigest, uid: string, day: string, gallery: PushGallery | null) {
  const [lead, second] = digest.topics;
  return {
    ...notificationCopyPayload({
      kind: "topicDigest",
      topicKey: lead.topic.key,
      topicName: lead.topic.name,
      secondTopicKey: second?.topic.key ?? "",
      secondTopicName: second?.topic.name ?? "",
      topicCount: digest.topics.length,
      wallCount: digest.walls.length,
      tags: tagsLine(galleryTags(digest.walls)),
    }),
    // No `wall_ids`: they would open the gallery page instead of the topic page.
    data: {
      route: "topic",
      topic_kind: lead.topic.kind,
      topic_id: lead.topic.id,
      topic_count: String(digest.topics.length),
      url: topicUrl(lead.topic),
      notification_kind: "topic_digest",
      push_kind: "post",
    },
    imageUrl: digest.walls[0].thumb,
    ...(gallery ? {gallery} : {}),
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `topic_digest_${day}`,
    docId: `topic_digest_${uid}_${day}`,
  };
}

/** Approved walls in the 24 hours before `nowMs` that belong to at least one topic and pass the gallery gate. */
async function recentTopicWalls(nowMs: number, premium: string[]): Promise<TopicWall[]> {
  const snap = await db.collection("walls")
    .where("approvedNotifiedAt", ">=", admin.firestore.Timestamp.fromMillis(nowMs - WINDOW_MS))
    .where("approvedNotifiedAt", "<=", admin.firestore.Timestamp.fromMillis(nowMs))
    .get();
  return snap.docs.flatMap((doc) => {
    const data = doc.data();
    const wall = galleryWall({id: doc.id, data}, premium);
    const topicKeys = [...TOPICS.values()].filter((topic) => topic.matches(data)).map((topic) => topic.key);
    if (!wall || topicKeys.length === 0) return [];
    const approvedMs = (data.approvedNotifiedAt as admin.firestore.Timestamp).toMillis();
    return [{creatorUid: str(data.creatorUid), approvedMs, wall, topicKeys}];
  });
}

/** Keeps the newest approval time of every topic in one public doc, for the new-wall dots on Home. */
async function recordTopicNews(walls: TopicWall[]): Promise<void> {
  const latest = new Map<string, number>();
  for (const wall of walls) {
    for (const key of wall.topicKeys) latest.set(key, Math.max(latest.get(key) ?? 0, wall.approvedMs));
  }
  if (latest.size === 0) return;
  const ref = db.doc(TOPIC_NEWS_DOC);
  const stored = ((await ref.get()).data()?.latest ?? {}) as Record<string, unknown>;
  const changed = [...latest].filter(([key, ms]) => typeof stored[key] !== "number" || (stored[key] as number) < ms);
  if (changed.length === 0) return;
  await ref.set({latest: Object.fromEntries(changed), updatedAt: admin.firestore.FieldValue.serverTimestamp()},
    {merge: true});
}

interface Candidate {
  uid: string;
  offset: number;
  token: string;
  topics: Topic[];
}

/** A session that follows topics with the switch on, bound to this device's token. Null otherwise. */
function candidateFrom(doc: admin.firestore.QueryDocumentSnapshot): Candidate | null {
  const user = doc.ref.parent.parent;
  if (doc.id !== "session" || !user || user.parent.id !== "usersv2") return null;
  const session = doc.data();
  const token = typeof session.fcmToken === "string" ? session.fcmToken.trim() : "";
  if (session.topicAlerts !== true || !token || session.topicAlertsToken !== token ||
    session.fcmTokenBindingVersion !== FCM_TOKEN_BINDING_VERSION || session.fcmTokenBindingToken !== token) return null;
  const topics = parseFollowedTopics(session.followedTopics);
  return topics.length > 0 ? {uid: user.id, offset: session[TOPIC_OFFSET_FIELD], token, topics} : null;
}

/** Signed in, not deleted, and opened the app in the last 30 days. Returns the email the inbox needs. */
async function activeEmail(uid: string, nowMs: number): Promise<string | null> {
  const user = (await db.doc(`usersv2/${uid}`).get()).data();
  const email = str(user?.email);
  const lastOpen = user?.lastAppOpenAt;
  if (!user || !email || user.deleted === true || user.loggedIn === false ||
    !(lastOpen instanceof admin.firestore.Timestamp) || lastOpen.toMillis() < nowMs - INACTIVE_MS) return null;
  return email;
}

interface Claim {
  digest: TopicDigest;
  previous: {day?: unknown; atMs?: unknown} | undefined;
}

/**
 * Claims the local day and plans the digest in one transaction, so two runs never both send. Walls already counted
 * in the last push are left out. Returns null when the day is taken or nothing is new.
 */
async function claimDigest(
  candidate: Candidate, day: string, nowMs: number, walls: TopicWall[], blocked: ReadonlySet<string>,
): Promise<Claim | null> {
  const ref = db.doc(`usersv2/${candidate.uid}/private/${MARKER}`);
  return db.runTransaction(async (tx) => {
    const previous = (await tx.get(ref)).data();
    if (typeof previous?.day === "string" && previous.day >= day) return null;
    const lastMs = typeof previous?.atMs === "number" ? previous.atMs : 0;
    const digest = planTopicDigest(candidate.topics, walls, Math.max(nowMs - WINDOW_MS, lastMs), blocked);
    if (!digest) return null;
    tx.set(ref, {day, atMs: nowMs, at: admin.firestore.FieldValue.serverTimestamp()});
    return {digest, previous};
  });
}

async function releaseDigest(uid: string, day: string, previous: Claim["previous"]): Promise<void> {
  const ref = db.doc(`usersv2/${uid}/private/${MARKER}`);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).data()?.day !== day) return;
    if (previous) tx.set(ref, previous);
    else tx.delete(ref);
  });
}

/** Sends the topic digests due at `nowMs`: one push per user and local day at 16:00. Returns the number sent. */
export async function sendDueTopicDigests(nowMs: number): Promise<number> {
  const premium = await premiumCollections();
  const walls = await recentTopicWalls(nowMs, premium);
  await recordTopicNews(walls);
  if (walls.length === 0) return 0;
  const offsets = offsetsAtDigestTime(nowMs, TOPIC_DIGEST_MINUTE);
  const sessions = await db.collectionGroup("private").where(TOPIC_OFFSET_FIELD, "in", offsets).get();
  const candidates = sessions.docs.map(candidateFrom).filter((c): c is Candidate =>
    c !== null && planTopicDigest(c.topics, walls, nowMs - WINDOW_MS) !== null);
  const galleries = new Map<string, Promise<PushGallery | null>>();
  const galleryFor = (digest: TopicDigest) => {
    const key = digest.walls.slice(0, 4).map((w) => w.id).join(",");
    if (!galleries.has(key)) galleries.set(key, buildPushGallery(digest.walls));
    return galleries.get(key) as Promise<PushGallery | null>;
  };
  let sent = 0;
  const failures: unknown[] = [];
  for (let i = 0; i < candidates.length; i += CHUNK_SIZE) {
    const results = await Promise.allSettled(candidates.slice(i, i + CHUNK_SIZE).map(async (candidate) => {
      const email = await activeEmail(candidate.uid, nowMs);
      if (!email) return false;
      const blockedSnap = await db.collection(`usersv2/${candidate.uid}/blockedUsers`).get();
      const blocked = new Set(blockedSnap.docs.map((d) => d.id));
      const day = localDay(nowMs, candidate.offset);
      const claim = await claimDigest(candidate, day, nowMs, walls, blocked);
      if (!claim) return false;
      let delivered = false;
      try {
        const payload = topicDigestPayload(claim.digest, candidate.uid, day, await galleryFor(claim.digest));
        delivered = await sendToUser({...payload, modifier: email},
          {uid: candidate.uid, email, topicAlertsToken: candidate.token});
        if (!delivered) throw new Error("topicDigest: push delivery failed.");
      } finally {
        if (!delivered) await releaseDigest(candidate.uid, day, claim.previous);
      }
      return true;
    }));
    sent += results.filter((r) => r.status === "fulfilled" && r.value).length;
    results.filter((r): r is PromiseRejectedResult => r.status === "rejected").forEach((r) => {
      failures.push(r.reason);
      logger.warn("topicDigest: one digest failed.", {err: String(r.reason)});
    });
  }
  logger.info("topicDigest: run done.", {offsets, walls: walls.length, sessions: sessions.size,
    candidates: candidates.length, sent});
  if (failures.length > 0) throw new Error(`topicDigest: ${failures.length} digest delivery failure(s).`);
  return sent;
}

export const sendTopicDigests = onSchedule(
  {schedule: "*/15 * * * *", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540},
  async (event) => {
    const ms = Date.parse(event.scheduleTime);
    await sendDueTopicDigests(Number.isFinite(ms) ? ms : Date.now());
  },
);
