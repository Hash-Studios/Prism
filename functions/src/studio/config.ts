import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db, str} from "../common";

/** No day makes more candidates than this, counting manual runs. */
export const STUDIO_MAX_CANDIDATES_PER_DAY = 30;

export interface StudioIdentity {
  by: string;
  email: string;
  userPhoto: string;
}

export interface StudioConfig {
  /** False unless the doc says true and holds an identity with an email. */
  generationEnabled: boolean;
  dailyCandidates: number;
  maxCandidatesPerDay: number;
  model: string;
  width: number;
  height: number;
  /** Series id -> weight. A series that is not in the map has weight 1. */
  seriesWeights: Record<string, number>;
  identity: StudioIdentity | null;
}

const DEFAULTS = {
  dailyCandidates: 10,
  model: "openai/gpt-image-2.5/sunburst/text-to-image",
  width: 1440,
  height: 3200,
};

function clampInt(value: unknown, fallback: number, min: number, max: number): number {
  const n = typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : fallback;
  return Math.min(max, Math.max(min, n));
}

function positiveInt(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : fallback;
}

function parseIdentity(raw: unknown): StudioIdentity | null {
  if (typeof raw !== "object" || raw === null) return null;
  const data = raw as Record<string, unknown>;
  const email = str(data.email);
  if (email === "") return null;
  return {by: str(data.by) || "Prism Studio", email, userPhoto: str(data.userPhoto)};
}

function parseWeights(raw: unknown): Record<string, number> {
  if (typeof raw !== "object" || raw === null) return {};
  const weights: Record<string, number> = {};
  for (const [id, weight] of Object.entries(raw as Record<string, unknown>)) {
    if (typeof weight === "number" && Number.isFinite(weight) && weight >= 0) weights[id] = weight;
  }
  return weights;
}

/** Reads `studioConfig/current`. A missing doc, flag or identity turns generation off. */
export function parseStudioConfig(data: admin.firestore.DocumentData | undefined): StudioConfig {
  const identity = parseIdentity(data?.identity);
  if (data?.generationEnabled === true && identity === null) {
    logger.warn("studio: studioConfig/current has no identity email; generation is off.");
  }
  return {
    generationEnabled: data?.generationEnabled === true && identity !== null,
    dailyCandidates: clampInt(data?.dailyCandidates, DEFAULTS.dailyCandidates, 1, STUDIO_MAX_CANDIDATES_PER_DAY),
    maxCandidatesPerDay: clampInt(data?.maxCandidatesPerDay, STUDIO_MAX_CANDIDATES_PER_DAY, 0,
      STUDIO_MAX_CANDIDATES_PER_DAY),
    model: str(data?.model) || DEFAULTS.model,
    width: positiveInt(data?.width, DEFAULTS.width),
    height: positiveInt(data?.height, DEFAULTS.height),
    seriesWeights: parseWeights(data?.seriesWeights),
    identity,
  };
}

export async function loadStudioConfig(): Promise<StudioConfig> {
  return parseStudioConfig((await db.collection("studioConfig").doc("current").get()).data());
}
