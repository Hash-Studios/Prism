import * as admin from "firebase-admin";
import {db} from "../common";
import {publicFolderDeps} from "../publicFolders";
import {SMART_WALL_KEYS, wallSmartKeys} from "../smartFolders";
import {parseConcurrency, runChunked} from "./runChunked";

const PAGE_SIZE = 300;
const WALL_ID = /^[A-Za-z0-9_-]{1,200}$/;

type Doc = admin.firestore.DocumentData;
type Outcome = "write" | "unchanged" | "delete" | "skipped";

export type SmartWallKeysBackfillOptions = {apply: boolean; concurrency?: number};
export type SmartWallKeysBackfillCounts = {scanned: number; write: number; unchanged: number; delete: number; skipped: number};

export const USAGE = `Usage: node lib/scripts/backfillSmartWallKeys.js [--apply] [--concurrency=N]

Writes the smartWallKeys doc for each wall that passes the free gallery gate, and deletes the doc of each wall that no
longer passes. Folders and items are not touched. Dry-run is the default and writes nothing.
Credentials come from Application Default Credentials.`;

function smartWallDoc(data: Doc, docId: string, keys: string[]): Doc {
  return {
    keys,
    wallId: typeof data.id === "string" && WALL_ID.test(data.id) ? data.id : docId,
    thumb: String(data.wallpaper_thumb),
    createdAt: data.createdAt instanceof admin.firestore.Timestamp ? data.createdAt : admin.firestore.Timestamp.now(),
  };
}

/** Compares one wall with its smartWallKeys doc and writes or deletes it only when [apply] is set. */
async function syncWall(wall: admin.firestore.QueryDocumentSnapshot, premium: string[], apply: boolean): Promise<Outcome> {
  const data = wall.data();
  const keys = wallSmartKeys(data, premium);
  const ref = db.collection(SMART_WALL_KEYS).doc(wall.id);
  const existing = await ref.get();
  if (keys.length === 0) {
    if (!existing.exists) return "skipped";
    if (apply) await ref.delete();
    return "delete";
  }
  if (existing.exists && JSON.stringify(existing.data()?.keys) === JSON.stringify(keys)) return "unchanged";
  if (apply) await ref.set(smartWallDoc(data, wall.id, keys));
  return "write";
}

/** Pages through walls by document id and reconciles each smartWallKeys doc. Dry run unless [apply] is set. */
export async function backfillSmartWallKeys(
  options: SmartWallKeysBackfillOptions,
  log: (line: string) => void = console.log,
): Promise<SmartWallKeysBackfillCounts> {
  // Without the preview base, no thumb passes the gate and an apply run would delete every keys doc.
  if (!process.env.R2_PREVIEW_BASE_URL) throw new Error("Set R2_PREVIEW_BASE_URL (functions/.env) before this backfill.");
  const counts: SmartWallKeysBackfillCounts = {scanned: 0, write: 0, unchanged: 0, delete: 0, skipped: 0};
  const premium = await publicFolderDeps.premium();
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = db.collection("walls").orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    await runChunked(page.docs, options.concurrency ?? 1, async (wall) => {
      counts.scanned += 1;
      const outcome = await syncWall(wall, premium, options.apply);
      counts[outcome] += 1;
      if (outcome === "write" || outcome === "delete") log(`${SMART_WALL_KEYS}/${wall.id} ${outcome}`);
    });
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
  log(JSON.stringify(counts));
  return counts;
}

export function parseArgs(argv: string[]): {help: boolean; apply: boolean; concurrency: number} {
  if (argv.some((arg) => arg !== "--help" && arg !== "--apply" && !arg.startsWith("--concurrency")) ||
    (argv.includes("--help") && argv.length !== 1) || argv.filter((arg) => arg === "--apply").length > 1) {
    throw new Error("Invalid arguments.");
  }
  return {help: argv.includes("--help"), apply: argv.includes("--apply"), concurrency: parseConcurrency(argv)};
}

if (require.main === module) {
  let args: ReturnType<typeof parseArgs> | undefined;
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
      backfillSmartWallKeys({apply: args.apply, concurrency: args.concurrency}).catch((error: unknown) => {
        console.error(`Smart wall keys backfill failed: ${error instanceof Error ? error.message : String(error)}`);
        process.exitCode = 1;
      });
    }
  }
}
