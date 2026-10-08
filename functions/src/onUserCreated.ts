import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION} from "./common";
import {usernameLowerOf} from "./usernameLower";

const SUFFIX_LENGTHS = [4, 8, 12];

/** Another profile already holds this lowercase username. */
async function isTaken(lower: string, uid: string): Promise<boolean> {
  const rows = await db.collection("usersv2").where("usernameLower", "==", lower).limit(2).get();
  return rows.docs.some((doc) => doc.id !== uid);
}

/**
 * A new profile starts with the username made from the sign-in name, so two people called "John Smith" both
 * arrive with `JohnSmith`. The later profile gets a short suffix from its uid. The trigger also stores
 * `usernameLower` and `nameLower` for search.
 */
export const onUserCreated = onDocumentCreated(
  {
    document: "usersv2/{uid}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const uid = event.params.uid;
    let username = typeof data.username === "string" ? data.username.trim() : "";
    const update: Record<string, string> = {};

    if (username) {
      let lower = usernameLowerOf(username);
      if (await isTaken(lower, uid)) {
        const base = username;
        for (const length of SUFFIX_LENGTHS) {
          username = `${base}_${uid.slice(0, length).toLowerCase()}`;
          lower = usernameLowerOf(username);
          if (!(await isTaken(lower, uid))) break;
        }
        update.username = username;
        logger.info("onUserCreated: username was taken; added a suffix.", {uid});
      }
      if (data.usernameLower !== lower) update.usernameLower = lower;
    }
    if (typeof data.name === "string") {
      const nameLower = usernameLowerOf(data.name);
      if (data.nameLower !== nameLower) update.nameLower = nameLower;
    }
    if (Object.keys(update).length > 0) await event.data?.ref.update(update);
  },
);
