import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REGION = "asia-south1";
const USERS_V2 = "usersv2";
const BLOCKED_USERS = "blockedUsers";
const RATE_DAILY = "userBlockRateDaily";
const RATE_TARGET = "userBlockRateByTarget";

const MAX_ACTIONS_PER_DAY = 200;
const MIN_MS_BETWEEN_SAME_TARGET = 60 * 1000;

const MAX_UID_LEN = 128;

function utcDateString(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function normalizeUid(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "targetUserId must be a string.");
  }
  const t = raw.trim();
  if (t.length === 0 || t.length > MAX_UID_LEN) {
    throw new HttpsError("invalid-argument", "targetUserId has invalid length.");
  }
  if (t.includes("/") || t.includes("..")) {
    throw new HttpsError("invalid-argument", "targetUserId is invalid.");
  }
  return t;
}

function normalizeEmailForMatch(email: string): string {
  return email.trim().toLowerCase();
}

/** Entries in following/followers arrays that match normalized target (case-insensitive). */
function matchingEmailsFromList(list: unknown, normalizedTarget: string): string[] {
  if (!Array.isArray(list)) {
    return [];
  }
  const out: string[] = [];
  for (const e of list) {
    const s = (e ?? "").toString().trim();
    if (s && normalizeEmailForMatch(s) === normalizedTarget) {
      out.push(s);
    }
  }
  return out;
}

interface BlockUserResponse {
  ok: true;
}

interface UnblockUserResponse {
  ok: true;
}

export const blockUser = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{targetUserId?: string}>): Promise<BlockUserResponse> => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Sign in to block a user.");
    }

    const blockedUid = normalizeUid(request.data?.targetUserId);
    if (blockedUid === callerUid) {
      throw new HttpsError("invalid-argument", "You cannot block yourself.");
    }

    const callerRef = db.collection(USERS_V2).doc(callerUid);
    const blockedRef = db.collection(USERS_V2).doc(blockedUid);
    const blockDocRef = callerRef.collection(BLOCKED_USERS).doc(blockedUid);

    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();
    const today = utcDateString(new Date(nowMs));

    const dailyRateRef = db.collection(RATE_DAILY).doc(`${callerUid}_${today}`);
    const targetRateRef = db.collection(RATE_TARGET).doc(`${callerUid}_${blockedUid}`);

    await db.runTransaction(async (tx) => {
      const [callerSnap, blockedSnap, blockSnap, dailyRateSnap, targetRateSnap] = await Promise.all([
        tx.get(callerRef),
        tx.get(blockedRef),
        tx.get(blockDocRef),
        tx.get(dailyRateRef),
        tx.get(targetRateRef),
      ]);

      if (!callerSnap.exists) {
        throw new HttpsError("failed-precondition", "Your profile was not found.");
      }
      if (!blockedSnap.exists) {
        throw new HttpsError("not-found", "User not found.");
      }

      const blockedData = blockedSnap.data()!;
      const blockedEmailRaw = (blockedData.email ?? "").toString().trim();
      if (!blockedEmailRaw) {
        throw new HttpsError("failed-precondition", "Target user has no email.");
      }
      const blockedEmailNorm = normalizeEmailForMatch(blockedEmailRaw);

      const callerData = callerSnap.data()!;
      const callerEmailRaw = (callerData.email ?? "").toString().trim();
      const callerEmailNorm = callerEmailRaw ? normalizeEmailForMatch(callerEmailRaw) : "";

      if (targetRateSnap.exists) {
        const last = targetRateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
        if (last) {
          const elapsed = nowMs - last.toMillis();
          if (elapsed >= 0 && elapsed < MIN_MS_BETWEEN_SAME_TARGET) {
            throw new HttpsError("resource-exhausted", "Please wait a moment before changing this block.");
          }
        }
      }

      let dailyCount = 0;
      if (dailyRateSnap.exists) {
        const d = dailyRateSnap.data()?.day as string | undefined;
        const c = dailyRateSnap.data()?.count;
        if (d === today && typeof c === "number") {
          dailyCount = c;
        }
      }
      if (dailyCount >= MAX_ACTIONS_PER_DAY) {
        throw new HttpsError("resource-exhausted", "Daily limit reached. Try again tomorrow.");
      }

      const blockedUsername = ((blockedData.username ?? blockedData.name ?? "") as string).toString().trim();

      tx.set(
        blockDocRef,
        {
          blockedUid,
          blockedEmail: blockedEmailNorm,
          blockedUsername: blockedUsername || null,
          createdAt: blockSnap.exists ? (blockSnap.data()?.createdAt ?? now) : now,
        },
        {merge: true},
      );

      const followingRemoves = matchingEmailsFromList(callerData.following, blockedEmailNorm);
      const followersRemoves = callerEmailNorm
        ? matchingEmailsFromList(blockedData.followers, callerEmailNorm)
        : [];

      if (followingRemoves.length > 0) {
        tx.update(callerRef, {
          following: admin.firestore.FieldValue.arrayRemove(...followingRemoves),
        });
      }
      if (followersRemoves.length > 0) {
        tx.update(blockedRef, {
          followers: admin.firestore.FieldValue.arrayRemove(...followersRemoves),
        });
      }

      tx.set(
        targetRateRef,
        {
          lastAt: now,
          action: "block",
          callerUid,
          blockedUid,
        },
        {merge: true},
      );

      tx.set(
        dailyRateRef,
        {
          day: today,
          count: dailyCount + 1,
          userId: callerUid,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    logger.info("blockUser: success", {callerUid, blockedUid});

    return {ok: true};
  },
);

export const unblockUser = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (request: CallableRequest<{targetUserId?: string}>): Promise<UnblockUserResponse> => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Sign in to unblock a user.");
    }

    const blockedUid = normalizeUid(request.data?.targetUserId);
    if (blockedUid === callerUid) {
      throw new HttpsError("invalid-argument", "Invalid target.");
    }

    const callerRef = db.collection(USERS_V2).doc(callerUid);
    const blockDocRef = callerRef.collection(BLOCKED_USERS).doc(blockedUid);

    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();
    const today = utcDateString(new Date(nowMs));

    const dailyRateRef = db.collection(RATE_DAILY).doc(`${callerUid}_${today}`);
    const targetRateRef = db.collection(RATE_TARGET).doc(`${callerUid}_${blockedUid}`);

    await db.runTransaction(async (tx) => {
      const [blockSnap, dailyRateSnap, targetRateSnap] = await Promise.all([
        tx.get(blockDocRef),
        tx.get(dailyRateRef),
        tx.get(targetRateRef),
      ]);

      if (!blockSnap.exists) {
        throw new HttpsError("not-found", "This user is not blocked.");
      }

      if (targetRateSnap.exists) {
        const last = targetRateSnap.data()?.lastAt as admin.firestore.Timestamp | undefined;
        if (last) {
          const elapsed = nowMs - last.toMillis();
          if (elapsed >= 0 && elapsed < MIN_MS_BETWEEN_SAME_TARGET) {
            throw new HttpsError("resource-exhausted", "Please wait a moment before changing this block.");
          }
        }
      }

      let dailyCount = 0;
      if (dailyRateSnap.exists) {
        const d = dailyRateSnap.data()?.day as string | undefined;
        const c = dailyRateSnap.data()?.count;
        if (d === today && typeof c === "number") {
          dailyCount = c;
        }
      }
      if (dailyCount >= MAX_ACTIONS_PER_DAY) {
        throw new HttpsError("resource-exhausted", "Daily limit reached. Try again tomorrow.");
      }

      tx.delete(blockDocRef);

      tx.set(
        targetRateRef,
        {
          lastAt: now,
          action: "unblock",
          callerUid,
          blockedUid,
        },
        {merge: true},
      );

      tx.set(
        dailyRateRef,
        {
          day: today,
          count: dailyCount + 1,
          userId: callerUid,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    logger.info("unblockUser: success", {callerUid, blockedUid});

    return {ok: true};
  },
);
