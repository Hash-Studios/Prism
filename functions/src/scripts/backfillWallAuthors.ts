import * as admin from "firebase-admin";

import {db, findUserByEmail, str} from "../common";
import {AUTHORED_COLLECTIONS, authorUpdate} from "../wallAuthor";

export type AuthorBackfillOptions = {apply: boolean};
export type AuthorBackfillCounts = {scanned: number; noOwner: number; changed: number; written: number; failed: number};

const BATCH_SIZE = 300;

export const USAGE = `Usage: node lib/scripts/backfillWallAuthors.js [--apply]

Sets by and userPhoto on every wall and setup to the current name and photo of its owner.
The owner is the usersv2 doc with the same email, as typed or in lower case.
A doc with no owner is not changed. An empty name or photo is not copied.
A dry run reads only and writes nothing. The run can be stopped and run again.
Credentials come from Application Default Credentials, as in the other backfills.`;

/** Fixes stale author fields on walls and setups, one batch at a time in document id order. */
export async function backfillWallAuthors(
  options: AuthorBackfillOptions,
  log: (line: string) => void = console.log,
): Promise<AuthorBackfillCounts> {
  const counts: AuthorBackfillCounts = {scanned: 0, noOwner: 0, changed: 0, written: 0, failed: 0};
  const owners = new Map<string, Promise<admin.firestore.DocumentData | undefined>>();
  const ownerOf = (email: string) => {
    if (!owners.has(email)) owners.set(email, findUserByEmail(email).then((user) => user?.data()));
    return owners.get(email) as Promise<admin.firestore.DocumentData | undefined>;
  };
  const writer = options.apply ? db.bulkWriter() : undefined;

  for (const collection of AUTHORED_COLLECTIONS) {
    let last: admin.firestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let query = db.collection(collection)
        .select("email", "by", "userPhoto")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(BATCH_SIZE);
      if (last) query = query.startAfter(last);
      const snapshot = await query.get();
      for (const doc of snapshot.docs) {
        counts.scanned += 1;
        const email = str(doc.data().email);
        const owner = email ? await ownerOf(email) : undefined;
        if (!owner) {
          counts.noOwner += 1;
          continue;
        }
        const update = authorUpdate(doc.data(), owner);
        if (Object.keys(update).length === 0) continue;
        counts.changed += 1;
        log(`${doc.ref.path} ${Object.keys(update).join(",")}`);
        if (writer) {
          void writer.update(doc.ref, update).then(() => {
            counts.written += 1;
          }, () => {
            counts.failed += 1;
          });
        }
      }
      await writer?.flush();
      if (snapshot.size < BATCH_SIZE) break;
      last = snapshot.docs[snapshot.docs.length - 1];
    }
  }

  await writer?.close();
  log(`done ${JSON.stringify(counts)} applied=${options.apply}`);
  return counts;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    backfillWallAuthors({apply: argv.includes("--apply")}).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
