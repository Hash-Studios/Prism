import * as admin from "firebase-admin";
import {isDeepStrictEqual} from "node:util";
import {db} from "./common";
import {sameTimestamp} from "./wallEditingCommon";
import {boundedText, parseWallText} from "./wallMetadataValidation";
import {wallSearchTermsFor} from "./wallSearchTerms";

export async function sanitizeSubmissionText(expected: admin.firestore.DocumentSnapshot): Promise<boolean> {
  const original = expected.data();
  if (!original || !expected.createTime) return false;
  const patch: admin.firestore.DocumentData = {};
  for (const [key, max] of [["title", 60], ["desc", 500]] as const) {
    if (!(key in original)) continue;
    try {
      const value = original[key];
      if (typeof value === "string" && /[\r\n]/.test(value)) {
        patch[key] = boundedText(value.replace(/\r\n|\r|\n/g, " "), max);
      } else {
        boundedText(value, max);
      }
    } catch {
      patch[key] = "";
    }
  }
  if ("tags" in original) {
    try {
      parseWallText({title: "", desc: "", tags: original.tags});
    } catch {
      patch.tags = [];
    }
  }
  if (Object.keys(patch).length === 0) return false;
  return db.runTransaction(async (tx) => {
    const current = await tx.get(expected.ref);
    if (!current.exists || !sameTimestamp(current.createTime, expected.createTime)) return false;
    const latest = current.data()!;
    const safePatch = Object.fromEntries(Object.entries(patch).filter(([key]) => isDeepStrictEqual(latest[key], original[key])));
    if (!Object.keys(safePatch).length) return false;
    tx.update(expected.ref, {...safePatch, searchTerms: wallSearchTermsFor({...latest, ...safePatch})});
    return true;
  });
}
