import * as admin from "firebase-admin";

const PAGE_SIZE = 1000;
const QUALIFIED = new Set(["wallhaven", "pexels"]);

export const USAGE = `Usage: node lib/scripts/qualifyFavouriteKeys.js [--apply]

Moves Wallhaven and Pexels favourites in usersv2/{uid}/images from the raw wall id to the key that new builds
write, <provider>_<id> (#524). The two sources can share an id. Prism favourites keep the raw id.
A dry run is the default. It reads only and prints counts, collisions and 10 sample ids.
--apply copies each doc to its new key, or fills missing pin/favourite timestamps on a matching existing key, then
deletes the raw doc in one transaction per doc. A key for a different favourite is left untouched; a stopped run can
run again. Builds before #524 cannot delete a moved favourite, so run --apply only after most users run a build with
#524, and only with the owner's OK.
Credentials come from Application Default Credentials, as in the other backfills.`;

export type FavouriteKeyCounts = {
  scanned: number;
  rawKept: number;
  alreadyQualified: number;
  toMove: number;
  collisions: number;
  odd: number;
  moved: number;
  failed: number;
  bySource: Record<string, number>;
  samples: string[];
};

/** The new doc id for a favourite doc, or why it stays. */
export function planFavouriteKey(docId: string, data: admin.firestore.DocumentData):
  {target: string} | "keep" | "qualified" | "odd" {
  const id = typeof data.id === "string" ? data.id : "";
  const provider = typeof data.provider === "string" ? data.provider.toLowerCase() : "";
  if (!QUALIFIED.has(provider)) return "keep";
  if (docId === `${provider}_${id}`) return "qualified";
  if (!id || docId !== id) return "odd";
  return {target: `${provider}_${id}`};
}

const uidPrefix = (uid: string) => `${uid.slice(0, 4)}…`;

/** Walks every favourite doc in path order. Logs counts only, never a whole uid or doc data. */
export async function qualifyFavouriteKeys(
  db: admin.firestore.Firestore,
  options: {apply: boolean},
  log: (line: string) => void = console.log,
): Promise<FavouriteKeyCounts> {
  const counts: FavouriteKeyCounts = {scanned: 0, rawKept: 0, alreadyQualified: 0, toMove: 0, collisions: 0, odd: 0,
    moved: 0, failed: 0, bySource: {}, samples: []};
  let last: admin.firestore.QueryDocumentSnapshot | undefined;
  let pages = 0;

  for (;;) {
    // Planning needs only the id and provider; --apply reads the whole doc in its transaction.
    let query = db.collectionGroup("images").orderBy(admin.firestore.FieldPath.documentId())
      .select("id", "provider").limit(PAGE_SIZE);
    if (last) query = query.startAfter(last);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    pages += 1;

    const moves: Array<{doc: admin.firestore.QueryDocumentSnapshot; uid: string; target: string}> = [];
    for (const doc of snapshot.docs) {
      last = doc;
      const parts = doc.ref.path.split("/");
      if (parts.length !== 4 || parts[0] !== "usersv2") continue;
      counts.scanned += 1;
      const plan = planFavouriteKey(doc.id, doc.data());
      if (plan === "keep") {
        counts.rawKept += 1;
        continue;
      }
      if (plan === "qualified") {
        counts.alreadyQualified += 1;
        continue;
      }
      if (plan === "odd") {
        counts.odd += 1;
        continue;
      }
      moves.push({doc, uid: parts[1], target: plan.target});
    }

    const targets = await Promise.all(moves.map((move) => db.doc(`usersv2/${move.uid}/images/${move.target}`).get()));
    for (const [index, {doc, uid, target}] of moves.entries()) {
      const plan = {target};
      counts.toMove += 1;
      const source = target.split("_")[0];
      counts.bySource[source] = (counts.bySource[source] ?? 0) + 1;
      const targetRef = db.doc(`usersv2/${uid}/images/${target}`);
      const collides = targets[index].exists;
      if (collides) counts.collisions += 1;
      if (counts.samples.length < 10) {
        counts.samples.push(`${uidPrefix(uid)}/${doc.id} -> ${target}${collides ? " (key exists)" : ""}`);
      }
      if (!options.apply) continue;
      try {
        const moved = await db.runTransaction(async (tx) => {
          const [raw, target] = await Promise.all([tx.get(doc.ref), tx.get(targetRef)]);
          if (!raw.exists) return false;
          const data = raw.data() ?? {};
          const freshPlan = planFavouriteKey(doc.id, data);
          if (typeof freshPlan !== "object" || freshPlan.target !== plan.target) return false;
          if (target.exists) {
            const existing = target.data() ?? {};
            if (existing.id !== data.id || typeof existing.provider !== "string" ||
              existing.provider.toLowerCase() !== data.provider.toLowerCase()) return false;
            const timestamps = Object.fromEntries(["pinnedAt", "favouritedAt"]
              .filter((field) => existing[field] === undefined && data[field] !== undefined)
              .map((field) => [field, data[field]]));
            if (Object.keys(timestamps).length > 0) tx.set(targetRef, timestamps, {merge: true});
          } else {
            tx.set(targetRef, data);
          }
          tx.delete(doc.ref);
          return true;
        });
        if (moved) counts.moved += 1;
      } catch {
        counts.failed += 1;
      }
    }
    if (pages % 50 === 0) log(`progress pages=${pages} scanned=${counts.scanned} toMove=${counts.toMove}`);
    if (snapshot.size < PAGE_SIZE) break;
  }

  for (const [source, n] of Object.entries(counts.bySource)) log(`to move ${source}: ${n}`);
  log(`samples:\n  ${counts.samples.join("\n  ")}`);
  log(`done scanned=${counts.scanned} rawKept=${counts.rawKept} alreadyQualified=${counts.alreadyQualified} ` +
    `toMove=${counts.toMove} collisions=${counts.collisions} odd=${counts.odd} moved=${counts.moved} ` +
    `failed=${counts.failed} applied=${options.apply}`);
  if (options.apply && counts.failed > 0) throw new Error(`${counts.failed} favourite moves failed`);
  return counts;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!admin.apps.length) admin.initializeApp();
    qualifyFavouriteKeys(admin.firestore(), {apply: argv.includes("--apply")}).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
