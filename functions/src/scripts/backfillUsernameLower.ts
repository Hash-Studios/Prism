import * as admin from "firebase-admin";

import {usernameLowerOf} from "../usernameLower";

if (!admin.apps.length) {
  admin.initializeApp();
}

// Sets usersv2.usernameLower on every user. Dry run unless --apply is passed.
async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const db = admin.firestore();
  const snapshot = await db.collection("usersv2").select("username", "usernameLower").get();
  const writer = db.bulkWriter();
  let changed = 0;

  for (const doc of snapshot.docs) {
    const usernameLower = usernameLowerOf(doc.get("username"));
    if (doc.get("usernameLower") === usernameLower) {
      continue;
    }
    changed += 1;
    if (apply) {
      writer.update(doc.ref, {usernameLower});
    }
  }

  await writer.close();
  console.log(`scanned=${snapshot.size} changed=${changed} applied=${apply}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
