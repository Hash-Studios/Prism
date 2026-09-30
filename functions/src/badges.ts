import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, REGION} from "./common";

const USERS = "usersv2";
const COOLDOWN_MS = 60_000;
const DAY_MS = 86_400_000;
const DEFAULT_PROFILE_PHOTO = "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/" +
  "Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4";

interface BadgeDef {
  id: string;
  name: string;
  description: string;
  /** Coins only for badges backed by server-owned data, so client-written data cannot farm them. */
  coins: number;
}

export const BADGES: readonly BadgeDef[] = [
  {id: "week_warrior", name: "Week Warrior", description: "Reach a 7 day streak", coins: 25},
  {id: "streak_master", name: "Streak Master", description: "Reach a 28 day streak", coins: 100},
  {id: "creator", name: "Creator", description: "Get a wallpaper approved", coins: 50},
  {id: "ai_artist", name: "AI Artist", description: "Generate 10 AI wallpapers", coins: 30},
  {id: "prism_veteran", name: "Prism Veteran", description: "Use Prism for 30 days and reach a 7 day streak", coins: 75},
  {id: "collector", name: "Collector", description: "Favourite 10 wallpapers", coins: 0},
  {id: "art_curator", name: "Art Curator", description: "Favourite 50 wallpapers", coins: 0},
  {id: "social_butterfly", name: "Social Butterfly", description: "Follow 10 creators", coins: 0},
  {id: "profile_complete", name: "Profile Complete", description: "Add a photo, username, bio and a link", coins: 0},
];

export interface BadgeFacts {
  streakBest: number;
  approvedWalls: number;
  aiSpends: number;
  accountAgeDays: number;
  favourites: number;
  following: number;
  profileComplete: boolean;
}

/** Badge ids the facts qualify for. Pure, so every threshold is unit-tested. */
export function evaluateBadges(f: BadgeFacts): string[] {
  const checks: Record<string, boolean> = {
    week_warrior: f.streakBest >= 7,
    streak_master: f.streakBest >= 28,
    creator: f.approvedWalls >= 1,
    ai_artist: f.aiSpends >= 10,
    prism_veteran: f.accountAgeDays >= 30 && f.streakBest >= 7,
    collector: f.favourites >= 10,
    art_curator: f.favourites >= 50,
    social_butterfly: f.following >= 10,
    profile_complete: f.profileComplete,
  };
  return BADGES.filter((b) => checks[b.id]).map((b) => b.id);
}

export function isProfileComplete(data: admin.firestore.DocumentData): boolean {
  const text = (v: unknown) => typeof v === "string" && v.trim().length > 0;
  const photo = typeof data.profilePhoto === "string" ? data.profilePhoto.trim() : "";
  const links = data.links && typeof data.links === "object" ? Object.values(data.links) : [];
  return photo.length > 0 && photo !== DEFAULT_PROFILE_PHOTO && text(data.username) && text(data.bio) && links.some(text);
}

/** Overridable in tests. Auth creation time is server-owned, unlike `usersv2.createdAt`, which owners may edit. */
export const badgeIo = {
  async accountCreatedMs(uid: string): Promise<number> {
    const created = (await admin.auth().getUser(uid)).metadata.creationTime;
    return Date.parse(created);
  },
};

async function countUpTo(query: admin.firestore.Query, limit: number): Promise<number> {
  const snap = await query.limit(limit).count().get();
  return snap.data().count;
}

async function gatherFacts(
  uid: string, data: admin.firestore.DocumentData, owned: Set<string>, nowMs: number, email: string,
): Promise<BadgeFacts> {
  const need = (...ids: string[]) => ids.some((id) => !owned.has(id));
  const state = data.coinState && typeof data.coinState === "object" ? data.coinState : {};
  const streakBest = Math.max(int(state.streakBest, 0), int(state.streakCount, 0));
  const [approvedWalls, aiSpends, favourites, createdMs] = await Promise.all([
    need("creator") && email ?
      countUpTo(db.collection("walls").where("email", "==", email).where("review", "==", true), 1) : 0,
    need("ai_artist") ?
      countUpTo(db.collection("coinTransactions").where("userId", "==", uid).where("action", "==", "aiGeneration")
        .where("type", "==", "debit").where("status", "==", "completed"), 10) : 0,
    need("collector", "art_curator") ? countUpTo(db.collection(`${USERS}/${uid}/images`), 50) : 0,
    need("prism_veteran") && streakBest >= 7 ? badgeIo.accountCreatedMs(uid) : nowMs,
  ]);
  return {
    streakBest,
    approvedWalls,
    aiSpends,
    accountAgeDays: Math.floor((nowMs - createdMs) / DAY_MS),
    favourites,
    following: Array.isArray(data.following) ? data.following.length : 0,
    profileComplete: isProfileComplete(data),
  };
}

function ownedIds(badges: unknown): Set<string> {
  const list = Array.isArray(badges) ? badges : [];
  return new Set(list.map((b) => (b as {id?: unknown})?.id).filter((id): id is string => typeof id === "string"));
}

export const checkBadges = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<unknown>) => {
    const uid = request.auth?.uid?.trim() ?? "";
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to earn badges.");
    const email = typeof request.auth?.token.email === "string" ? request.auth.token.email : "";
    const userRef = db.collection(USERS).doc(uid);
    const rateRef = db.collection("badgeCheckRate").doc(uid);
    const nowMs = Date.now();
    const cooling = (snap: admin.firestore.DocumentSnapshot) => nowMs - int(snap.data()?.lastAt, 0) < COOLDOWN_MS;
    let existing: admin.firestore.DocumentData = {};
    let isCooling = false;
    await db.runTransaction(async (tx) => {
      const [userTx, rateTx] = await Promise.all([tx.get(userRef), tx.get(rateRef)]);
      if (!userTx.exists) throw new HttpsError("not-found", "User profile was not found.");
      existing = userTx.data() ?? {};
      isCooling = cooling(rateTx);
      if (!isCooling) tx.set(rateRef, {lastAt: nowMs});
    });

    const skip = () => ({
      newBadges: [] as {id: string; coins: number}[],
      badges: (Array.isArray(existing.badges) ? existing.badges : []) as Record<string, unknown>[],
      currentBalance: int(existing.coins, 0),
    });
    if (isCooling) return skip();

    const facts = await gatherFacts(uid, existing, ownedIds(existing.badges), nowMs, email);

    let response = skip();
    await db.runTransaction(async (tx) => {
      const userTx = await tx.get(userRef);
      if (!userTx.exists) throw new HttpsError("not-found", "User profile was not found.");
      const data = userTx.data() ?? {};
      const badges: Record<string, unknown>[] = Array.isArray(data.badges) ? [...data.badges] : [];
      const previous = int(data.coins, 0);
      const state = data.coinState && typeof data.coinState === "object" ? data.coinState : {};
      const streakBest = Math.max(int(state.streakBest, 0), int(state.streakCount, 0));
      response = {newBadges: [], badges, currentBalance: previous};

      const owned = ownedIds(badges);
      const accountAgeDays = facts.streakBest < 7 && streakBest >= 7 && !owned.has("prism_veteran") ?
        Math.floor((nowMs - await badgeIo.accountCreatedMs(uid)) / DAY_MS) : facts.accountAgeDays;
      const earned = evaluateBadges({...facts, streakBest, accountAgeDays});
      const fresh = BADGES.filter((b) => earned.includes(b.id) && !owned.has(b.id));
      if (fresh.length === 0) return;

      const at = admin.firestore.Timestamp.now();
      let balance = previous;
      for (const b of fresh) {
        badges.push({
          id: b.id, name: b.name, description: b.description, awardedAt: at.toDate().toISOString(),
          imageUrl: "", color: "", url: "",
        });
        if (b.coins <= 0) continue;
        const txId = `ctx_badgeReward_${uid}_${b.id}`;
        tx.set(db.collection("coinTransactions").doc(txId), coinTransactionDoc({
          id: txId,
          userId: uid,
          at,
          delta: b.coins,
          balanceBefore: balance,
          action: "badgeReward",
          description: `${b.name} badge`,
          sourceTag: "badges.check.callable",
          reason: `badge_${b.id}`,
        }));
        balance += b.coins;
      }
      tx.update(userRef, balance === previous ? {badges} : {badges, coins: balance});
      response = {newBadges: fresh.map((b) => ({id: b.id, coins: b.coins})), badges, currentBalance: balance};
    });
    return response;
  },
);
