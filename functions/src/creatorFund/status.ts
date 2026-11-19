import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, int, US_REGION} from "../common";
import {parseEconomy} from "../economy";
import {previousWeek} from "./load";
import {CREATOR_FUND, creatorFundIo, FUND_ROWS} from "./settle";

export type FundReason = "noActivity" | "fewUsers" | "smallShare" | "moderation" | "team";
export type CreatorFundStatus = {schemaVersion: 1; week: string; distinctUsers: number; minDistinctUsers: number;
  minPayout: number} & (
  | {state: "off"}
  | {state: "pending"}
  | {state: "paid"; coins: number; shareBps: number}
  | {state: "notQualified"; reason: FundReason; shareBps: number});

const REASONS = new Set<FundReason>(["fewUsers", "smallShare", "moderation", "team"]);

/** The caller's result for the last complete week. Rows hold no names, and only the owner can read theirs. */
export async function creatorFundStatus(uid: string, nowMs: number): Promise<CreatorFundStatus> {
  const week = previousWeek(nowMs);
  const weekRef = db.collection(CREATOR_FUND).doc(week);
  const [weekSnap, rowSnap] = await db.getAll(weekRef, weekRef.collection(FUND_ROWS).doc(uid));
  const weekData = weekSnap.data();
  const rules = weekData ? parseEconomy({creatorFund: weekData.rules}).creatorFund : await creatorFundIo.economy();
  const base = {schemaVersion: 1 as const, week, distinctUsers: 0, minDistinctUsers: rules.minDistinctUsers,
    minPayout: rules.minPayout};
  if (!weekData) return {...base, state: rules.pool === 0 ? "off" : "pending"};
  if (weekData.state === "computing") return {...base, state: "pending"};
  const row = rowSnap.data();
  if (!row) return {...base, state: "notQualified", reason: "noActivity", shareBps: 0};
  const counted = {...base, distinctUsers: int(row.distinctUsers, 0), shareBps: int(row.shareBps, 0)};
  if (row.status === "paid" && row.payState === "due") return {...base, state: "pending"};
  if (row.status === "paid" && row.payState === "done") {
    const coins = int(row.coins, 0);
    return {...counted, state: "paid", coins, shareBps: rules.pool > 0 ? Math.floor(coins * 10_000 / rules.pool) : 0};
  }
  const reason = REASONS.has(row.reason) ? row.reason as FundReason : "noActivity";
  return {...counted, state: "notQualified", reason};
}

// The app calls us-central1 only, and only builds with the fund row call this, so asia-south1 keeps its CPU budget.
export const getCreatorFundStatus = onCall({region: US_REGION, cors: true},
  async (request: CallableRequest<unknown>) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to see the Creator fund.");
    const data = request.data;
    if (data !== undefined && data !== null &&
      (typeof data !== "object" || Array.isArray(data) || Object.keys(data).length > 0)) {
      throw new HttpsError("invalid-argument", "Send an empty object.");
    }
    return creatorFundStatus(uid, Date.now());
  });
