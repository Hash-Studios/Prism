import {db} from "./common";
import {HttpsError} from "firebase-functions/v2/https";

/** This minimal UID-keyed safety record is intentionally retained permanently. */
export async function closeCreatorProgressForDeletion(uid: string): Promise<void> {
  // Reward transactions read this document. A grant either commits before it, or retries and refuses.
  await db.collection("creatorDeletionState").doc(uid).set({closed: true});
  const writer = db.bulkWriter();
  const outcomes: Promise<boolean>[] = [];
  const track = (write: Promise<unknown>) => outcomes.push(write.then(() => true, () => false));
  try {
    const walls = await db.collection("creatorWallCredits").where("creatorUid", "==", uid).get();
    for (const wall of walls.docs) {
      // Keep only logical-ID-hash dedupe. Remove creator, email, asset path and event times.
      track(writer.set(wall.ref, {closed: true, approvalCredited: true}));
    }
    const pairs = await db.collectionGroup("creatorMembers").where("memberUid", "==", uid).get();
    for (const pair of pairs.docs) track(writer.delete(pair.ref));
    const rates = await db.collection("creatorMemberRateDaily").where("memberUid", "==", uid).get();
    for (const rate of rates.docs) track(writer.delete(rate.ref));
  } finally {
    await writer.close();
  }
  if ((await Promise.all(outcomes)).includes(false)) {
    throw new HttpsError("internal", "Could not close creator progress. Retry account deletion.");
  }
}
