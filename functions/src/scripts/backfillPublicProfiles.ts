import * as admin from "firebase-admin";
import {db, str} from "../common";
import {verifiedUidForEmail} from "../authoredContentUid";
import {applyFollowEdge, syncPublicProfile} from "../profiles";

const PAGE_SIZE = 200;

export type ProfileBackfillCounts = {users: number; profiles: number; edges: number; created: number; unresolved: number; refused: number};

export const USAGE = `Usage: node lib/scripts/backfillPublicProfiles.js [--apply]

Projects the allowlisted usersv2 fields to profiles/{uid}, then converts the legacy followers/following
email arrays to UID edges with notify=false. Safe to re-run. Dry-run is the default.
Credentials come from Application Default Credentials.`;

export async function backfillPublicProfiles(
  {apply}: {apply: boolean},
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

  // Profiles first, so every edge target has one.
  for (const user of users) {
    counts.users += 1;
    if (apply) await syncPublicProfile(user.id);
    counts.profiles += 1;
  }

  for (const user of users) {
    const data = user.data();
    const pairs: Array<[string, string, string]> = [];
    for (const email of Array.isArray(data.following) ? data.following : []) pairs.push([user.id, "", str(email)]);
    for (const email of Array.isArray(data.followers) ? data.followers : []) pairs.push(["", user.id, str(email)]);
    for (const [followerUid, targetUid, email] of pairs) {
      const other = email ? await lookup(email) : null;
      if (!other || other === user.id) {
        counts.unresolved += 1;
        continue;
      }
      const edge = {followerUid: followerUid || other, targetUid: targetUid || other};
      counts.edges += 1;
      if (!apply) continue;
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
  const unknown = argv.filter((arg) => arg !== "--apply");
  if (unknown.length > 0) {
    console.log(USAGE);
    process.exitCode = 2;
  } else {
    if (!admin.apps.length) admin.initializeApp();
    backfillPublicProfiles({apply: argv.includes("--apply")}).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
