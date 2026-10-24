import * as admin from "firebase-admin";
import {db, str} from "../common";
import {verifiedUidForEmail} from "../authoredContentUid";
import {applyFollowEdge, syncPublicProfile} from "../profiles";
import {parseConcurrency, runChunked, runPool} from "./runChunked";

const PAGE_SIZE = 200;

export type ProfileBackfillCounts = {users: number; profiles: number; edges: number; created: number; unresolved: number; refused: number};

export const USAGE = `Usage: node lib/scripts/backfillPublicProfiles.js [--apply] [--concurrency=N] [--edges-only]

Projects the allowlisted usersv2 fields to profiles/{uid}, then converts the legacy followers/following
email arrays to UID edges with notify=false. Safe to re-run. Dry-run is the default.
Credentials come from Application Default Credentials.`;

export async function backfillPublicProfiles(
  {apply, concurrency = 1, edgesOnly = false}: {apply: boolean; concurrency?: number; edgesOnly?: boolean},
  log: (line: string) => void = console.log,
): Promise<ProfileBackfillCounts> {
  const counts: ProfileBackfillCounts = {users: 0, profiles: 0, edges: 0, created: 0, unresolved: 0, refused: 0};
  const owners = new Map<string, Promise<string | null>>();
  const lookup = (email: string) => {
    const key = email.toLowerCase();
    if (!owners.has(key)) owners.set(key, verifiedUidForEmail(email));
    return owners.get(key) as Promise<string | null>;
  };
  const users: admin.firestore.QueryDocumentSnapshot[] = [];
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = db.collection("usersv2").orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    users.push(...page.docs);
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }

  // Profiles first, so every edge target has one. A re-run after a completed profile pass can skip it.
  await runChunked(users, concurrency, async (user) => {
    counts.users += 1;
    if (apply && !edgesOnly) await syncPublicProfile(user.id);
    counts.profiles += 1;
  });

  const entries: Array<{userId: string; followerUid: string; targetUid: string; email: string}> = [];
  for (const user of users) {
    const data = user.data();
    for (const email of Array.isArray(data.following) ? data.following : []) {
      entries.push({userId: user.id, followerUid: user.id, targetUid: "", email: str(email)});
    }
    for (const email of Array.isArray(data.followers) ? data.followers : []) {
      entries.push({userId: user.id, followerUid: "", targetUid: user.id, email: str(email)});
    }
  }
  const emails = [...new Set(entries.map((entry) => entry.email).filter(Boolean))];
  await runChunked(emails, concurrency, async (email) => void await lookup(email));

  // Each follow usually appears twice (A.following and B.followers), so apply each edge once.
  const edges = new Map<string, {followerUid: string; targetUid: string}>();
  for (const entry of entries) {
    const other = entry.email ? await lookup(entry.email) : null;
    if (!other || other === entry.userId) {
      counts.unresolved += 1;
      continue;
    }
    const edge = {followerUid: entry.followerUid || other, targetUid: entry.targetUid || other};
    counts.edges += 1;
    edges.set(`${edge.followerUid}/${edge.targetUid}`, edge);
  }

  if (apply) {
    // Every edge rewrites its target profile's followerCount, and one document takes about one write a second.
    // So each target gets one lane that applies its edges in turn, the busiest lanes start first, and lanes for
    // different targets run in parallel. A failed edge gets one more try alone below.
    const lanes = new Map<string, Array<{followerUid: string; targetUid: string}>>();
    for (const edge of edges.values()) {
      const lane = lanes.get(edge.targetUid) ?? [];
      lane.push(edge);
      lanes.set(edge.targetUid, lane);
    }
    const ordered = [...lanes.values()].sort((a, b) => b.length - a.length);
    const failed: Array<{followerUid: string; targetUid: string}> = [];
    await runPool(ordered, concurrency, async (lane) => {
      for (const edge of lane) {
        try {
          if (await applyFollowEdge({...edge, follow: true, notify: false}) === "created") counts.created += 1;
        } catch {
          failed.push(edge);
        }
      }
    });
    for (const edge of failed) {
      try {
        if (await applyFollowEdge({...edge, follow: true, notify: false}) === "created") counts.created += 1;
      } catch (err) {
        counts.refused += 1;
        log(`${edge.followerUid}->${edge.targetUid} refused: ${(err as Error).message}`);
      }
    }
  }
  log(`done ${JSON.stringify(counts)} applied=${apply}`);
  return counts;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  const unknown = argv.filter((arg) => arg !== "--apply" && arg !== "--edges-only" && !arg.startsWith("--concurrency"));
  let concurrency = 1;
  try {
    concurrency = parseConcurrency(argv);
  } catch {
    unknown.push("--concurrency");
  }
  if (unknown.length > 0) {
    console.log(USAGE);
    process.exitCode = 2;
  } else {
    if (!admin.apps.length) admin.initializeApp();
    backfillPublicProfiles({apply: argv.includes("--apply"), concurrency, edgesOnly: argv.includes("--edges-only")}).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
