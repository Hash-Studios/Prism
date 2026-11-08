import * as admin from "firebase-admin";

export const USAGE = `Usage: node lib/scripts/measureFollowGraph.js

Read-only. Measures the follow graph for issue #541. It writes nothing.
1. Legacy email arrays on usersv2 (followers and following fields).
2. UID edge subcollections profiles/{uid}/followers and profiles/{uid}/following.
It prints counts and 4-character uid prefixes only. It never prints emails, full uids, names or array elements.
Credentials come from Application Default Credentials, as in the other backfills.`;

const USERS_PAGE_SIZE = 500;
const EDGE_PAGE_SIZE = 1000;
const EDGE_CLIENT_CAP = 500;
const TOP_N = 10;

/** Nearest-rank percentile over a sorted ascending list. Empty list gives 0. */
export function percentile(sortedAsc: readonly number[], p: number): number {
  if (sortedAsc.length === 0) {
    return 0;
  }
  const rank = Math.min(sortedAsc.length, Math.max(1, Math.ceil(p * sortedAsc.length)));
  return sortedAsc[rank - 1];
}

export type CountSummary = {
  docs: number;
  nonEmpty: number;
  max: number;
  p50: number;
  p90: number;
  p99: number;
  over500: number;
  over1000: number;
  over5000: number;
};

/** Percentiles and threshold counts over one count per doc. */
export function summarizeCounts(values: readonly number[]): CountSummary {
  const sorted = [...values].sort((a, b) => a - b);
  return {
    docs: values.length,
    nonEmpty: values.filter((v) => v > 0).length,
    max: sorted.length > 0 ? sorted[sorted.length - 1] : 0,
    p50: percentile(sorted, 0.5),
    p90: percentile(sorted, 0.9),
    p99: percentile(sorted, 0.99),
    over500: values.filter((v) => v > 500).length,
    over1000: values.filter((v) => v > 1000).length,
    over5000: values.filter((v) => v > 5000).length,
  };
}

/** Total UTF-8 bytes of the string elements in one array. Other elements count as 0. */
export function utf8Bytes(values: readonly unknown[]): number {
  let total = 0;
  for (const value of values) {
    if (typeof value === "string") {
      total += Buffer.byteLength(value, "utf8");
    }
  }
  return total;
}

const uidPrefix = (uid: string): string => `${uid.slice(0, 4)}…`;

const formatSummary = (s: CountSummary): string =>
  `docs=${s.docs} nonEmpty=${s.nonEmpty} max=${s.max} p50=${s.p50} p90=${s.p90} p99=${s.p99} ` +
  `over500=${s.over500} over1000=${s.over1000} over5000=${s.over5000}`;

type LegacyField = "followers" | "following";
type EdgeCollection = "followers" | "following";

/** Pages usersv2 and measures the two legacy email arrays. */
async function measureLegacy(db: admin.firestore.Firestore, log: (line: string) => void): Promise<void> {
  const fields: LegacyField[] = ["followers", "following"];
  const lengths: Record<LegacyField, number[]> = {followers: [], following: []};
  const maxBytes: Record<LegacyField, number> = {followers: 0, following: 0};
  const topFollowers: {prefix: string; length: number}[] = [];
  let last: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query: admin.firestore.Query = db.collection("usersv2")
      .orderBy(admin.firestore.FieldPath.documentId())
      .select("followers", "following")
      .limit(USERS_PAGE_SIZE);
    if (last) {
      query = query.startAfter(last);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      last = doc;
      for (const field of fields) {
        const raw = doc.get(field);
        const values: unknown[] = Array.isArray(raw) ? raw : [];
        lengths[field].push(values.length);
        maxBytes[field] = Math.max(maxBytes[field], utf8Bytes(values));
      }
      const followerCount = lengths.followers[lengths.followers.length - 1];
      if (followerCount > 0) {
        topFollowers.push({prefix: uidPrefix(doc.id), length: followerCount});
      }
    }
    if (snapshot.size < USERS_PAGE_SIZE) {
      break;
    }
  }

  log(`usersv2 scanned=${lengths.followers.length}`);
  for (const field of fields) {
    log(`usersv2.${field}: ${formatSummary(summarizeCounts(lengths[field]))} maxUtf8Bytes=${maxBytes[field]}`);
  }
  log(`top ${TOP_N} usersv2.followers by length (uid prefix, length):`);
  topFollowers.sort((a, b) => b.length - a.length);
  for (const row of topFollowers.slice(0, TOP_N)) {
    log(`  ${row.prefix} ${row.length}`);
  }
}

/** Pages one collection group and counts edges per parent uid under profiles/{uid}/{collection}/{x}. */
async function measureEdges(
  db: admin.firestore.Firestore,
  collection: EdgeCollection,
  log: (line: string) => void,
): Promise<void> {
  const perParent = new Map<string, number>();
  let total = 0;
  let scanned = 0;
  let pages = 0;
  let last: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query: admin.firestore.Query = db.collectionGroup(collection)
      .orderBy(admin.firestore.FieldPath.documentId())
      .select()
      .limit(EDGE_PAGE_SIZE);
    if (last) {
      query = query.startAfter(last);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }
    pages += 1;

    for (const doc of snapshot.docs) {
      last = doc;
      scanned += 1;
      const parts = doc.ref.path.split("/");
      if (parts.length !== 4 || parts[0] !== "profiles" || parts[2] !== collection) {
        continue;
      }
      total += 1;
      perParent.set(parts[1], (perParent.get(parts[1]) ?? 0) + 1);
    }
    if (pages % 50 === 0) {
      log(`progress edges.${collection} pages=${pages} scanned=${scanned}`);
    }
    if (snapshot.size < EDGE_PAGE_SIZE) {
      break;
    }
  }

  const summary = summarizeCounts([...perParent.values()]);
  log(`edges.${collection}: totalEdges=${total} parents=${summary.docs} max=${summary.max} ` +
    `p50=${summary.p50} p90=${summary.p90} p99=${summary.p99} parentsOver${EDGE_CLIENT_CAP}=${summary.over500} ` +
    `scanned=${scanned}`);
  log(`top ${TOP_N} edges.${collection} by count (uid prefix, count):`);
  const top = [...perParent.entries()].sort((a, b) => b[1] - a[1]).slice(0, TOP_N);
  for (const [uid, count] of top) {
    log(`  ${uidPrefix(uid)} ${count}`);
  }
}

/** Read-only follow graph report. Prints counts and uid prefixes only. */
export async function measureFollowGraph(
  db: admin.firestore.Firestore,
  log: (line: string) => void = console.log,
): Promise<void> {
  await measureLegacy(db, log);
  await measureEdges(db, "followers", log);
  await measureEdges(db, "following", log);
  log("done");
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    measureFollowGraph(admin.firestore()).catch((err: unknown) => {
      const message = err instanceof Error ? err.message : "unknown error";
      const code = (err as {code?: unknown} | null)?.code;
      console.error(`measure failed code=${String(code ?? "none")} message=${message}`);
      process.exitCode = 1;
    });
  }
}
