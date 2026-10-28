import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {notificationCopyPayload} from "./notificationCatalog";
import {sendToUser} from "./notificationHelper";
import {galleryTags, galleryWall, tagsLine, type GalleryWall} from "./pushGallery";
import {premiumCollections} from "./wallOfTheDay";

const DIGEST_MINUTE = 19 * 60;
const OFFSET_STEP = 15;
const WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_GALLERY_WALLS = 12;
const CHUNK_SIZE = 25;

function isLocalDay(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/** A gated wall approved in the window, with its creator. */
export interface RecentWall {
  docId: string;
  creatorUid: string;
  creatorName: string;
  approvedMs: number;
  wall: GalleryWall;
}

/** One follower's digest. Creators with the most walls come first; walls alternate between creators. */
export interface Digest {
  uid: string;
  creators: Array<{uid: string; name: string}>;
  walls: RecentWall[];
  wallCount: number;
}

/** UTC offsets (minutes, 15 minute steps, -12:00 to +14:00) where it is `localMinute` (19:00 by default) at `nowMs`. */
export function offsetsAtDigestTime(nowMs: number, localMinute = DIGEST_MINUTE): number[] {
  const utcMinutes = Math.round(((nowMs / 60_000) % 1440) / OFFSET_STEP) * OFFSET_STEP;
  const base = (((localMinute - utcMinutes) % 1440) + 1440) % 1440;
  return [base, base - 1440].filter((offset) => offset >= -720 && offset <= 840);
}

/** The follower's local calendar day, the unit of the once-a-day marker. */
export function localDay(nowMs: number, offsetMinutes: number): string {
  return new Date(nowMs + offsetMinutes * 60_000).toISOString().slice(0, 10);
}

/** Groups the recent walls into one digest per follower. A creator never appears in their own digest. */
export function planDigests(walls: RecentWall[], followersByCreator: Map<string, string[]>): Digest[] {
  const byCreator = new Map<string, RecentWall[]>();
  for (const wall of [...walls].sort((a, b) => b.approvedMs - a.approvedMs)) {
    byCreator.set(wall.creatorUid, [...(byCreator.get(wall.creatorUid) ?? []), wall]);
  }
  const creatorsOf = new Map<string, string[]>();
  for (const [creator, followers] of followersByCreator) {
    if (!byCreator.has(creator)) continue;
    for (const uid of new Set(followers)) {
      if (uid !== creator) creatorsOf.set(uid, [...(creatorsOf.get(uid) ?? []), creator]);
    }
  }
  return [...creatorsOf].map(([uid, creatorUids]) => {
    const groups = creatorUids.map((c) => byCreator.get(c) as RecentWall[])
      .sort((a, b) => b.length - a.length || b[0].approvedMs - a[0].approvedMs);
    const interleaved: RecentWall[] = [];
    for (let i = 0; interleaved.length < groups.reduce((n, g) => n + g.length, 0); i++) {
      for (const group of groups) if (group[i]) interleaved.push(group[i]);
    }
    return {
      uid,
      creators: groups.map((g) => ({uid: g[0].creatorUid, name: g[0].creatorName})),
      walls: interleaved,
      wallCount: interleaved.length,
    };
  });
}

/** The push for one digest. It keeps a single image, because the Wall of the Day push is the day's gallery. */
export function digestPayload(digest: Digest, day: string) {
  const lead = digest.walls[0];
  const ids = digest.walls.slice(0, MAX_GALLERY_WALLS).map((w) => w.wall.id);
  return {
    ...notificationCopyPayload({
      kind: "followDigest",
      artistName: digest.creators[0].name,
      secondArtistName: digest.creators[1]?.name ?? "",
      creatorCount: digest.creators.length,
      wallCount: digest.wallCount,
      tags: tagsLine(galleryTags(digest.walls.map((w) => w.wall))),
    }),
    // Route `wall` opens the lead wall on a build without the gallery page; `wall_ids` opens the gallery.
    data: {
      route: "wall",
      wall_id: lead.docId,
      ...(ids.length > 1 ? {wall_ids: ids.join(",")} : {}),
      notification_kind: "follow_digest",
      push_kind: "post",
    },
    imageUrl: lead.wall.thumb,
    channelId: "posts",
    scoreKind: "post",
    collapseKey: `follow_digest_${day}`,
    docId: `follow_digest_${digest.uid}_${day}`,
  };
}

async function recentWalls(nowMs: number): Promise<RecentWall[]> {
  const premium = await premiumCollections();
  const snap = await db.collection("walls")
    .where("approvedNotifiedAt", ">=", admin.firestore.Timestamp.fromMillis(nowMs - WINDOW_MS))
    .where("approvedNotifiedAt", "<=", admin.firestore.Timestamp.fromMillis(nowMs))
    .get();
  return snap.docs.flatMap((doc) => {
    const data = doc.data();
    const creatorUid = str(data.creatorUid);
    const wall = data.origin === "studio" || !creatorUid ? null : galleryWall({id: doc.id, data}, premium);
    const approvedMs = (data.approvedNotifiedAt as admin.firestore.Timestamp).toMillis();
    return wall ? [{docId: doc.id, creatorUid, creatorName: str(data.by) || "A creator", approvedMs, wall}] : [];
  });
}

/**
 * Drops creators that the follower blocked or that blocked the follower. Returns null when the follower must get no
 * digest: signed out, deleted, not at 19:00 local, or without a Posts opt-in from a build that has the digest.
 */
async function deliverable(digest: Digest, offsets: number[]):
  Promise<{digest: Digest; offset: number; email: string; token: string} | null> {
  const user = (await db.doc(`usersv2/${digest.uid}`).get()).data();
  const offset = user?.appOpenTimezoneOffsetMinutes;
  const email = str(user?.email);
  if (!user || !email || user.deleted === true || user.loggedIn === false || !offsets.includes(offset)) return null;
  const session = (await db.doc(`usersv2/${digest.uid}/private/session`).get()).data();
  // Only a digest-capable build writes these token-bound markers. An older build keeps its per-upload topic pushes.
  if (session?.postAlerts !== true || typeof session.fcmToken !== "string" || !session.fcmToken.trim() ||
    session.postAlertsToken !== session.fcmToken || session.notificationLocalizationVersion !== 2 ||
    session.notificationLocalizationToken !== session.fcmToken) return null;
  const blocked = await Promise.all(digest.creators.map(async (c) => {
    const [mine, theirs] = await Promise.all([
      db.doc(`usersv2/${digest.uid}/blockedUsers/${c.uid}`).get(),
      db.doc(`usersv2/${c.uid}/blockedUsers/${digest.uid}`).get(),
    ]);
    return mine.exists || theirs.exists;
  }));
  const keep = new Set(digest.creators.filter((_, i) => !blocked[i]).map((c) => c.uid));
  const walls = digest.walls.filter((w) => keep.has(w.creatorUid));
  if (walls.length === 0) return null;
  return {
    digest: {...digest, creators: digest.creators.filter((c) => keep.has(c.uid)), walls, wallCount: walls.length},
    offset,
    email,
    token: session.fcmToken,
  };
}

/** Claims the follower's local day. A second run that day, or a retry after a send, finds the claim and stops. */
export async function claimDay(uid: string, day: string, marker = "followDigest"): Promise<{previous: unknown} | null> {
  const ref = db.doc(`usersv2/${uid}/private/${marker}`);
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (isLocalDay(data?.day) && data.day >= day) return null;
    tx.set(ref, {day, at: admin.firestore.FieldValue.serverTimestamp()});
    return {previous: data?.day ?? null};
  });
}

export async function releaseDay(uid: string, day: string, previous: unknown, marker = "followDigest"): Promise<void> {
  const ref = db.doc(`usersv2/${uid}/private/${marker}`);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).data()?.day !== day) return;
    tx.set(ref, {day: previous ?? admin.firestore.FieldValue.delete()}, {merge: true});
  });
}

/** Sends the digests due at `nowMs`. Returns the number sent. */
export async function sendDueDigests(nowMs: number): Promise<number> {
  const offsets = offsetsAtDigestTime(nowMs);
  const walls = await recentWalls(nowMs);
  if (walls.length === 0) return 0;
  const followersByCreator = new Map<string, string[]>();
  for (const creator of new Set(walls.map((w) => w.creatorUid))) {
    const snap = await db.collection("profiles").doc(creator).collection("followers").get();
    followersByCreator.set(creator, snap.docs.map((d) => d.id));
  }
  // ponytail: every 15 minute run reads each follower's user doc; precompute per-offset lists if followers grow large.
  const digests = planDigests(walls, followersByCreator);
  let sent = 0;
  const failures: unknown[] = [];
  for (let i = 0; i < digests.length; i += CHUNK_SIZE) {
    const results = await Promise.allSettled(digests.slice(i, i + CHUNK_SIZE).map(async (planned) => {
      const ready = await deliverable(planned, offsets);
      if (!ready) return false;
      const day = localDay(nowMs, ready.offset);
      const claim = await claimDay(planned.uid, day);
      if (!claim) return false;
      let delivered = false;
      try {
        const payload = digestPayload(ready.digest, day);
        delivered = await sendToUser({...payload, modifier: ready.email}, {
          uid: planned.uid,
          email: ready.email,
          postAlertsToken: ready.token,
        });
        if (!delivered) throw new Error("followDigest: push delivery failed.");
      } finally {
        if (!delivered) await releaseDay(planned.uid, day, claim.previous);
      }
      return true;
    }));
    sent += results.filter((r) => r.status === "fulfilled" && r.value).length;
    results.filter((r): r is PromiseRejectedResult => r.status === "rejected")
      .forEach((r) => {
        failures.push(r.reason);
        logger.warn("followDigest: one digest failed.", {err: String(r.reason)});
      });
  }
  logger.info("followDigest: run done.", {offsets, walls: walls.length, digests: digests.length, sent});
  if (failures.length > 0) throw new Error(`followDigest: ${failures.length} digest delivery failure(s).`);
  return sent;
}

export const sendFollowDigests = onSchedule(
  {schedule: "*/15 * * * *", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540},
  async (event) => {
    const ms = Date.parse(event.scheduleTime);
    await sendDueDigests(Number.isFinite(ms) ? ms : Date.now());
  },
);
