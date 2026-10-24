import * as admin from "firebase-admin";
import {db} from "../common";
import {syncAuthoredContentUid, verifiedUidForEmail} from "../authoredContentUid";

const PAGE_SIZE = 200;
const COLLECTIONS = ["walls", "setups"] as const;

export type CreatorUidBackfillOptions = {apply: boolean};
export type CreatorUidBackfillCounts = {scanned: number; assigned: number; cleared: number; skipped: number};

export const USAGE = `Usage: node lib/scripts/backfillCreatorUids.js [--apply]

Resolves wall and setup email ownership through Firebase Auth verified identities and writes creatorUid.
Dry-run is the default. Missing, unverified, deleted, or deletion-barrier identities are not assigned.
Credentials come from Application Default Credentials.`;

/** Pages through both authored collections and reconciles UID ownership from verified Auth identities. */
export async function backfillCreatorUids(
  options: CreatorUidBackfillOptions,
  log: (line: string) => void = console.log,
): Promise<CreatorUidBackfillCounts> {
  const counts: CreatorUidBackfillCounts = {scanned: 0, assigned: 0, cleared: 0, skipped: 0};
  const owners = new Map<string, Promise<string | null>>();
  const lookup = (email: string) => {
    if (!owners.has(email)) owners.set(email, verifiedUidForEmail(email));
    return owners.get(email) as Promise<string | null>;
  };
  for (const collection of COLLECTIONS) {
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let query = db.collection(collection).select("email", "creatorUid")
        .orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        counts.scanned += 1;
        const outcome = await syncAuthoredContentUid(collection, doc.id, doc.data().email, {apply: options.apply, lookup});
        counts[outcome] += 1;
        if (outcome !== "skipped") log(`${doc.ref.path} ${outcome}`);
      }
      if (page.size < PAGE_SIZE) break;
      cursor = page.docs[page.docs.length - 1];
    }
  }
  log(`done ${JSON.stringify(counts)} applied=${options.apply}`);
  return counts;
}

export function parseArgs(argv: string[]): {help: boolean; apply: boolean} {
  if (argv.some((arg) => arg !== "--help" && arg !== "--apply") ||
    (argv.includes("--help") && argv.length !== 1) || argv.filter((arg) => arg === "--apply").length > 1) {
    throw new Error("Invalid arguments.");
  }
  return {help: argv.includes("--help"), apply: argv.includes("--apply")};
}

if (require.main === module) {
  let args: {help: boolean; apply: boolean} | undefined;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch {
    console.error("Invalid arguments. Use --help for usage.");
    process.exitCode = 2;
  }
  if (args) {
    if (args.help) console.log(USAGE);
    else {
      if (!admin.apps.length) admin.initializeApp();
      backfillCreatorUids({apply: args.apply}).catch(() => {
        console.error("Creator UID backfill failed.");
        process.exitCode = 1;
      });
    }
  }
}
