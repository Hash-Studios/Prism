import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {REGION} from "./common";
import {reserveInitialUsername} from "./claimUsername";
import {usernameLowerOf} from "./usernameLower";

/**
 * Publish a provisional candidate only after the shared reservation transaction succeeds.
 * Legacy clients supplied `username` instead; accept it as a candidate during the server-first rollout.
 */
export const onUserCreated = onDocumentCreated(
  {
    document: "usersv2/{uid}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const candidate = data.usernameCandidate ?? data.username;
    if (typeof candidate !== "string" || !candidate.trim()) {
      if (typeof data.name === "string") await event.data?.ref.update({nameLower: usernameLowerOf(data.name)});
      return;
    }
    await reserveInitialUsername(event.params.uid, candidate);
  },
);
