import { verifyFirebaseIdTokenFromRequest } from './firebase_auth';

export interface AiEnvBindings {
  AI_STATE_KV: KVNamespace;
  AI_QUOTA_DO: DurableObjectNamespace;
  AI_IMAGES?: R2Bucket;
  FAL_API_KEY?: string;
  GEMINI_API_KEY?: string;
  BROWSER_RENDERING_ACCOUNT_ID?: string;
  BROWSER_RENDERING_API_TOKEN?: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_AUTH_DEBUG?: string;
  AI_REQUIRE_CHARGE?: string;
}

type AiProviderName = 'fal' | 'gemini';
type AiQualityTier = 'fast' | 'balanced' | 'quality';
type AiErrorCode =
  | 'unauthorized'
  | 'invalid_json'
  | 'invalid_request'
  | 'rate_limited'
  | 'budget_exhausted'
  | 'provider_timeout'
  | 'provider_error'
  | 'unsafe_prompt'
  | 'unsafe_output'
  | 'generation_not_found'
  | 'service_disabled'
  | 'charge_required'
  | 'charge_invalid'
  | 'charge_in_progress';
type BudgetThresholdLevel = 0 | 70 | 85 | 95;

interface AuthContext {
  token: string;
  userId: string;
}

interface AiGenerateRequest {
  prompt: string;
  stylePreset: string;
  qualityTier: AiQualityTier;
  targetSize: string;
  seed?: number;
  chargeTxId?: unknown;
}

interface AiVariationRequest {
  variationPrompt?: string;
  strength?: number;
  chargeTxId?: unknown;
}

interface AiGenerationRecord {
  generationId: string;
  userId: string;
  createdAt: string;
  parentGenerationId?: string;
  prompt: string;
  stylePreset: string;
  qualityTier: AiQualityTier;
  provider: AiProviderName;
  model: string;
  seed: number;
  width: number;
  height: number;
  imageUrl: string;
  watermarkedImageUrl: string;
  safety: {
    promptSafe: boolean;
    outputSafe: boolean;
  };
  estimatedCostUsd: number;
  latencyMs: number;
}

interface AiProviderResult {
  model: string;
  seed: number;
  width: number;
  height: number;
  contentType: string;
  imageBytes: Uint8Array;
  estimatedCostUsd: number;
}

interface AiProviderAdapter {
  readonly providerName: AiProviderName;
  generate(params: {
    prompt: string;
    qualityTier: AiQualityTier;
    model: string;
    estimatedCostUsd: number;
    targetSize: string;
    seed: number;
    stylePreset: string;
    timeoutMs: number;
    env: AiEnvBindings;
    onProviderBilled: () => Promise<void>;
  }): Promise<AiProviderResult>;
}

interface AiRoutingProviderConfig {
  enabled: boolean;
  weight: number;
  modelByQuality: Record<AiQualityTier, string>;
  estimatedCostByQualityUsd: Record<AiQualityTier, number>;
  dailyBudgetUsd: number;
  monthlyBudgetUsd: number;
  timeoutMs: number;
}

interface AiRoutingConfig {
  enabled: boolean;
  version: string;
  hardUserDailyCap: number;
  fallbackOrder: AiProviderName[];
  providers: Record<AiProviderName, AiRoutingProviderConfig>;
}

interface BudgetStatus {
  dailySpentUsd: number;
  monthlySpentUsd: number;
}

interface ProviderBudgetSnapshot {
  provider: AiProviderName;
  dailySpentUsd: number;
  monthlySpentUsd: number;
  dailyUsageRatio: number;
  monthlyUsageRatio: number;
  usageRatio: number;
  estimatedCostUsd: number;
  thresholdLevel: BudgetThresholdLevel;
}

interface RoutingPlan {
  order: AiProviderName[];
  snapshots: Record<AiProviderName, ProviderBudgetSnapshot>;
  guardrailLevel: BudgetThresholdLevel;
  effectiveQualityTier: AiQualityTier;
  reason: string;
}

const AI_CONFIG_KEY = 'ai:routing:active';
const AI_DEFAULT_CONFIG: AiRoutingConfig = {
  enabled: true,
  version: 'v1',
  hardUserDailyCap: 50,
  fallbackOrder: ['fal'],
  providers: {
    fal: {
      enabled: true,
      weight: 100,
      modelByQuality: {
        fast: 'fal-ai/flux/schnell',
        balanced: 'fal-ai/bytedance/seedream/v5/lite/text-to-image',
        quality: 'fal-ai/bytedance/seedream/v4.5/text-to-image',
      },
      estimatedCostByQualityUsd: { fast: 0.006, balanced: 0.04, quality: 0.04 },
      dailyBudgetUsd: 30,
      monthlyBudgetUsd: 600,
      timeoutMs: 25000,
    },
    gemini: {
      enabled: false,
      weight: 0,
      modelByQuality: {
        fast: 'gemini-2.5-flash-image',
        balanced: 'gemini-2.5-flash-image',
        quality: 'gemini-2.5-flash-image',
      },
      estimatedCostByQualityUsd: { fast: 0.02, balanced: 0.04, quality: 0.07 },
      dailyBudgetUsd: 30,
      monthlyBudgetUsd: 600,
      timeoutMs: 25000,
    },
  },
};

const BLOCKED_PROMPT_TERMS = [
  'child porn',
  'rape',
  'bestiality',
  'deepfake nude',
  'non consensual',
  'gore kill',
];
const BLOCKED_PROMPT_REGEX = new RegExp(
  `\\b(?:${BLOCKED_PROMPT_TERMS.map((term) => term.replaceAll(' ', '\\s+')).join('|')})(?:s|d|ed|ing)?\\b`,
  'i',
);

const AI_COIN_COST_BY_TIER: Record<AiQualityTier, number> = { fast: 10, balanced: 75, quality: 100 };
const CHARGE_TX_ID_REGEX = /^[A-Za-z0-9_-]{8,220}$/;
const CHARGE_RECORD_TTL_MS = 24 * 60 * 60 * 1000;
const CHARGE_STALE_IN_PROGRESS_MS = 5 * 60 * 1000;
const CHARGE_MAX_AGE_MS = 15 * 60 * 1000;
const CHARGE_CLOCK_SKEW_MS = 60 * 1000;

const AI_QUOTA_OBJECT_NAME = 'global';
const AI_QUOTA_RPC_URL = 'https://quota.internal/rpc';

type AiQuotaRpcOp =
  | 'user_daily_cap_try_increment'
  | 'user_daily_cap_release'
  | 'provider_budget_read'
  | 'provider_budget_reserve'
  | 'provider_budget_release'
  | 'provider_budget_commit'
  | 'charge_claim'
  | 'charge_status'
  | 'charge_finish'
  | 'charge_release'
  | 'rate_limit_bump';

interface AiQuotaRpcBaseRequest {
  op: AiQuotaRpcOp;
}

interface AiQuotaUserDailyCapRequest extends AiQuotaRpcBaseRequest {
  op: 'user_daily_cap_try_increment';
  userId: string;
  dayKey: string;
  cap: number;
}

interface AiQuotaUserDailyCapReleaseRequest extends AiQuotaRpcBaseRequest {
  op: 'user_daily_cap_release';
  userId: string;
  dayKey: string;
}

interface AiQuotaProviderBudgetReadRequest extends AiQuotaRpcBaseRequest {
  op: 'provider_budget_read';
  provider: AiProviderName;
  dayKey: string;
  monthKey: string;
}

interface AiQuotaProviderBudgetReserveRequest extends AiQuotaRpcBaseRequest {
  op: 'provider_budget_reserve';
  provider: AiProviderName;
  dayKey: string;
  monthKey: string;
  estimatedCostUsd: number;
  dailyBudgetUsd: number;
  monthlyBudgetUsd: number;
}

interface AiQuotaProviderBudgetMutationRequest extends AiQuotaRpcBaseRequest {
  op: 'provider_budget_release' | 'provider_budget_commit';
  reservationId: string;
  actualCostUsd?: number;
}

interface AiQuotaChargeRequest extends AiQuotaRpcBaseRequest {
  op: 'charge_claim' | 'charge_status' | 'charge_release';
  txId: string;
}

interface AiQuotaChargeFinishRequest extends AiQuotaRpcBaseRequest {
  op: 'charge_finish';
  txId: string;
  outcome: 'succeeded' | 'failed';
  response?: string;
}

interface AiQuotaRateLimitRequest extends AiQuotaRpcBaseRequest {
  op: 'rate_limit_bump';
  key: string;
  limit: number;
  ttlSeconds: number;
}

type AiQuotaRpcRequest =
  | AiQuotaChargeRequest
  | AiQuotaChargeFinishRequest
  | AiQuotaRateLimitRequest
  | AiQuotaUserDailyCapRequest
  | AiQuotaUserDailyCapReleaseRequest
  | AiQuotaProviderBudgetReadRequest
  | AiQuotaProviderBudgetReserveRequest
  | AiQuotaProviderBudgetMutationRequest;

interface AiQuotaRpcErrorResponse {
  ok: false;
  error: string;
}

interface AiQuotaUserDailyCapResponse {
  ok: true;
  allowed: boolean;
  current: number;
}

interface AiQuotaUserDailyCapReleaseResponse {
  ok: true;
  current: number;
}

interface AiQuotaProviderBudgetReadResponse {
  ok: true;
  dailySpentUsd: number;
  monthlySpentUsd: number;
}

interface AiQuotaProviderBudgetReserveResponse {
  ok: true;
  allowed: boolean;
  reservationId?: string;
  dailySpentUsd: number;
  monthlySpentUsd: number;
}

interface AiQuotaProviderBudgetReleaseResponse {
  ok: true;
  released: boolean;
}

interface AiQuotaProviderBudgetCommitResponse {
  ok: true;
  committed: boolean;
}

type AiChargeClaimStatus = 'new' | 'in_progress' | 'done' | 'failed';
type AiChargeEvidenceStatus = 'not_started' | 'in_progress' | 'succeeded' | 'failed';

interface AiQuotaChargeClaimResponse {
  ok: true;
  status: AiChargeClaimStatus;
  response?: string;
}

interface AiQuotaChargeStatusResponse {
  ok: true;
  status: AiChargeEvidenceStatus;
}

interface AiQuotaChargeMutationResponse {
  ok: true;
}

interface AiQuotaRateLimitResponse {
  ok: true;
  allowed: boolean;
  current: number;
}

interface AiChargeRecord {
  state: 'in_progress' | 'succeeded' | 'failed';
  at: number;
  expiresAt: number;
  response?: string;
}

interface AiRateLimitRecord {
  count: number;
  expiresAt: number;
}

type AiQuotaRpcResponse =
  | AiQuotaChargeClaimResponse
  | AiQuotaChargeStatusResponse
  | AiQuotaChargeMutationResponse
  | AiQuotaRateLimitResponse
  | AiQuotaRpcErrorResponse
  | AiQuotaUserDailyCapResponse
  | AiQuotaUserDailyCapReleaseResponse
  | AiQuotaProviderBudgetReadResponse
  | AiQuotaProviderBudgetReserveResponse
  | AiQuotaProviderBudgetReleaseResponse
  | AiQuotaProviderBudgetCommitResponse;

interface AiQuotaReservationRecord {
  provider: AiProviderName;
  dayKey: string;
  monthKey: string;
  costUsd: number;
  createdAt: string;
}

interface ProviderBudgetReservationResult {
  allowed: boolean;
  reservationId?: string;
  status: BudgetStatus;
}

export class AiQuotaCoordinator {
  private readonly state: DurableObjectState;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    if (request.method !== 'POST') {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'method_not_allowed' }, 405);
    }
    const body = await readJson<AiQuotaRpcRequest>(request);
    if (body == null || !isNonEmptyString(body.op)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    try {
      switch (body.op) {
        case 'user_daily_cap_try_increment':
          return this.handleUserDailyCapTryIncrement(body);
        case 'user_daily_cap_release':
          return this.handleUserDailyCapRelease(body);
        case 'provider_budget_read':
          return this.handleProviderBudgetRead(body);
        case 'provider_budget_reserve':
          return this.handleProviderBudgetReserve(body);
        case 'provider_budget_release':
          return this.handleProviderBudgetRelease(body);
        case 'provider_budget_commit':
          return this.handleProviderBudgetCommit(body);
        case 'charge_claim':
          return this.handleChargeClaim(body);
        case 'charge_status':
          return this.handleChargeStatus(body);
        case 'charge_finish':
          return this.handleChargeFinish(body);
        case 'charge_release':
          return this.handleChargeRelease(body);
        case 'rate_limit_bump':
          return this.handleRateLimitBump(body);
      }
    } catch (error) {
      console.error('[ai] quota_coordinator_error', { error: `${error ?? ''}` });
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'internal_error' }, 500);
    }
  }

  private async handleUserDailyCapTryIncrement(request: AiQuotaUserDailyCapRequest): Promise<Response> {
    const userId = clipText(asString(request.userId), 128);
    const dayKey = clipText(asString(request.dayKey), 16);
    const cap = Math.max(1, Math.round(asNumber(request.cap, 1)));
    if (!isNonEmptyString(userId) || !isNonEmptyString(dayKey)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const key = this.userDailyCapKey(userId, dayKey);
    const current = this.readStoredNumber(await this.state.storage.get<number | string>(key), 0);
    if (current >= cap) {
      return quotaJson<AiQuotaUserDailyCapResponse>({ ok: true, allowed: false, current });
    }
    const next = current + 1;
    await this.state.storage.put(key, next);
    return quotaJson<AiQuotaUserDailyCapResponse>({ ok: true, allowed: true, current: next });
  }

  private async handleUserDailyCapRelease(request: AiQuotaUserDailyCapReleaseRequest): Promise<Response> {
    const userId = clipText(asString(request.userId), 128);
    const dayKey = clipText(asString(request.dayKey), 16);
    if (!isNonEmptyString(userId) || !isNonEmptyString(dayKey)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const key = this.userDailyCapKey(userId, dayKey);
    const current = this.readStoredNumber(await this.state.storage.get<number | string>(key), 0);
    const next = Math.max(0, current - 1);
    await this.state.storage.put(key, next);
    return quotaJson<AiQuotaUserDailyCapReleaseResponse>({ ok: true, current: next });
  }

  private async handleProviderBudgetRead(request: AiQuotaProviderBudgetReadRequest): Promise<Response> {
    const status = await this.readProviderBudgetStatus(request.provider, request.dayKey, request.monthKey);
    return quotaJson<AiQuotaProviderBudgetReadResponse>({
      ok: true,
      dailySpentUsd: roundFloat(status.dailySpentUsd, 6),
      monthlySpentUsd: roundFloat(status.monthlySpentUsd, 6),
    });
  }

  private async handleProviderBudgetReserve(request: AiQuotaProviderBudgetReserveRequest): Promise<Response> {
    const provider = request.provider;
    const dayKey = clipText(asString(request.dayKey), 16);
    const monthKey = clipText(asString(request.monthKey), 16);
    if (!isNonEmptyString(dayKey) || !isNonEmptyString(monthKey) || (provider !== 'fal' && provider !== 'gemini')) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const estimatedCostUsd = Math.max(0, asNumber(request.estimatedCostUsd, 0));
    const dailyBudgetUsd = Math.max(0, asNumber(request.dailyBudgetUsd, 0));
    const monthlyBudgetUsd = Math.max(0, asNumber(request.monthlyBudgetUsd, 0));

    const current = await this.readProviderBudgetStatus(provider, dayKey, monthKey);
    const nextDaily = roundFloat(current.dailySpentUsd + estimatedCostUsd, 6);
    const nextMonthly = roundFloat(current.monthlySpentUsd + estimatedCostUsd, 6);
    const allowed = (nextDaily <= dailyBudgetUsd) && (nextMonthly <= monthlyBudgetUsd);
    if (!allowed) {
      return quotaJson<AiQuotaProviderBudgetReserveResponse>({
        ok: true,
        allowed: false,
        dailySpentUsd: roundFloat(current.dailySpentUsd, 6),
        monthlySpentUsd: roundFloat(current.monthlySpentUsd, 6),
      });
    }

    const reservationId = crypto.randomUUID();
    const reservation: AiQuotaReservationRecord = {
      provider,
      dayKey,
      monthKey,
      costUsd: roundFloat(estimatedCostUsd, 6),
      createdAt: new Date().toISOString(),
    };
    await this.state.storage.put(this.providerDailyBudgetKey(provider, dayKey), nextDaily);
    await this.state.storage.put(this.providerMonthlyBudgetKey(provider, monthKey), nextMonthly);
    await this.state.storage.put(this.providerBudgetReservationKey(reservationId), reservation);
    return quotaJson<AiQuotaProviderBudgetReserveResponse>({
      ok: true,
      allowed: true,
      reservationId,
      dailySpentUsd: nextDaily,
      monthlySpentUsd: nextMonthly,
    });
  }

  private async handleProviderBudgetRelease(request: AiQuotaProviderBudgetMutationRequest): Promise<Response> {
    const reservationId = clipText(asString(request.reservationId), 128);
    if (!isNonEmptyString(reservationId)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const reservationKey = this.providerBudgetReservationKey(reservationId);
    const reservation = await this.state.storage.get<AiQuotaReservationRecord>(reservationKey);
    if (reservation == null) {
      return quotaJson<AiQuotaProviderBudgetReleaseResponse>({ ok: true, released: false });
    }

    const current = await this.readProviderBudgetStatus(reservation.provider, reservation.dayKey, reservation.monthKey);
    const nextDaily = roundFloat(Math.max(0, current.dailySpentUsd - reservation.costUsd), 6);
    const nextMonthly = roundFloat(Math.max(0, current.monthlySpentUsd - reservation.costUsd), 6);
    await this.state.storage.put(this.providerDailyBudgetKey(reservation.provider, reservation.dayKey), nextDaily);
    await this.state.storage.put(this.providerMonthlyBudgetKey(reservation.provider, reservation.monthKey), nextMonthly);
    await this.state.storage.delete(reservationKey);
    return quotaJson<AiQuotaProviderBudgetReleaseResponse>({ ok: true, released: true });
  }

  private async handleProviderBudgetCommit(request: AiQuotaProviderBudgetMutationRequest): Promise<Response> {
    const reservationId = clipText(asString(request.reservationId), 128);
    if (!isNonEmptyString(reservationId)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const reservationKey = this.providerBudgetReservationKey(reservationId);
    const reservation = await this.state.storage.get<AiQuotaReservationRecord>(reservationKey);
    if (reservation == null) {
      return quotaJson<AiQuotaProviderBudgetCommitResponse>({ ok: true, committed: false });
    }

    const actualCostUsd = Math.max(0, asNumber(request.actualCostUsd, reservation.costUsd));
    const adjustment = roundFloat(actualCostUsd - reservation.costUsd, 6);
    if (adjustment !== 0) {
      const current = await this.readProviderBudgetStatus(reservation.provider, reservation.dayKey, reservation.monthKey);
      const nextDaily = roundFloat(Math.max(0, current.dailySpentUsd + adjustment), 6);
      const nextMonthly = roundFloat(Math.max(0, current.monthlySpentUsd + adjustment), 6);
      await this.state.storage.put(this.providerDailyBudgetKey(reservation.provider, reservation.dayKey), nextDaily);
      await this.state.storage.put(this.providerMonthlyBudgetKey(reservation.provider, reservation.monthKey), nextMonthly);
    }
    await this.state.storage.delete(reservationKey);
    const committed = true;
    return quotaJson<AiQuotaProviderBudgetCommitResponse>({ ok: true, committed });
  }

  private async handleChargeClaim(request: AiQuotaChargeRequest): Promise<Response> {
    const txId = chargeTxIdOrNull(request.txId);
    if (txId == null) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const record = await this.readChargeRecord(txId);
    if (record == null) {
      const now = Date.now();
      await this.state.storage.put<AiChargeRecord>(this.chargeKey(txId), {
        state: 'in_progress',
        at: now,
        expiresAt: now + CHARGE_RECORD_TTL_MS,
      });
      return quotaJson<AiQuotaChargeClaimResponse>({ ok: true, status: 'new' });
    }
    const state = effectiveChargeState(record);
    if (state === 'succeeded') {
      return quotaJson<AiQuotaChargeClaimResponse>({ ok: true, status: 'done', response: record.response ?? '' });
    }
    return quotaJson<AiQuotaChargeClaimResponse>({ ok: true, status: state });
  }

  private async handleChargeStatus(request: AiQuotaChargeRequest): Promise<Response> {
    const txId = chargeTxIdOrNull(request.txId);
    if (txId == null) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const record = await this.readChargeRecord(txId);
    return quotaJson<AiQuotaChargeStatusResponse>({
      ok: true,
      status: record == null ? 'not_started' : effectiveChargeState(record),
    });
  }

  private async handleChargeFinish(request: AiQuotaChargeFinishRequest): Promise<Response> {
    const txId = chargeTxIdOrNull(request.txId);
    if (txId == null || (request.outcome !== 'succeeded' && request.outcome !== 'failed')) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const record = await this.readChargeRecord(txId);
    if (record != null && record.state === 'in_progress') {
      const now = Date.now();
      await this.state.storage.put<AiChargeRecord>(this.chargeKey(txId), {
        state: request.outcome,
        at: now,
        expiresAt: now + CHARGE_RECORD_TTL_MS,
        response: request.outcome === 'succeeded' ? asString(request.response) : undefined,
      });
    }
    return quotaJson<AiQuotaChargeMutationResponse>({ ok: true });
  }

  private async handleChargeRelease(request: AiQuotaChargeRequest): Promise<Response> {
    const txId = chargeTxIdOrNull(request.txId);
    if (txId == null) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const record = await this.readChargeRecord(txId);
    if (record != null && record.state === 'in_progress') {
      await this.state.storage.delete(this.chargeKey(txId));
    }
    return quotaJson<AiQuotaChargeMutationResponse>({ ok: true });
  }

  private async handleRateLimitBump(request: AiQuotaRateLimitRequest): Promise<Response> {
    const key = clipText(asString(request.key), 200);
    const limit = Math.max(1, Math.round(asNumber(request.limit, 1)));
    const ttlSeconds = Math.max(1, Math.round(asNumber(request.ttlSeconds, 60)));
    if (!isNonEmptyString(key)) {
      return quotaJson<AiQuotaRpcErrorResponse>({ ok: false, error: 'invalid_request' }, 400);
    }
    const storageKey = `ratelimit:${key}`;
    const now = Date.now();
    const stored = await this.state.storage.get<AiRateLimitRecord>(storageKey);
    const current = stored != null && stored.expiresAt > now ? stored : null;
    const count = current?.count ?? 0;
    if (count >= limit) {
      return quotaJson<AiQuotaRateLimitResponse>({ ok: true, allowed: false, current: count });
    }
    await this.state.storage.put<AiRateLimitRecord>(storageKey, {
      count: count + 1,
      expiresAt: current?.expiresAt ?? now + ttlSeconds * 1000,
    });
    return quotaJson<AiQuotaRateLimitResponse>({ ok: true, allowed: true, current: count + 1 });
  }

  private async readChargeRecord(txId: string): Promise<AiChargeRecord | null> {
    const key = this.chargeKey(txId);
    const record = await this.state.storage.get<AiChargeRecord>(key);
    if (record == null) {
      return null;
    }
    if (record.expiresAt <= Date.now()) {
      await this.state.storage.delete(key);
      return null;
    }
    return record;
  }

  private chargeKey(txId: string): string {
    return `charge:${txId}`;
  }

  private async readProviderBudgetStatus(provider: AiProviderName, dayKey: string, monthKey: string): Promise<BudgetStatus> {
    const [daily, monthly] = await Promise.all([
      this.state.storage.get<number | string>(this.providerDailyBudgetKey(provider, dayKey)),
      this.state.storage.get<number | string>(this.providerMonthlyBudgetKey(provider, monthKey)),
    ]);
    return {
      dailySpentUsd: this.readStoredNumber(daily, 0),
      monthlySpentUsd: this.readStoredNumber(monthly, 0),
    };
  }

  private readStoredNumber(raw: number | string | undefined, fallback: number): number {
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return raw;
    }
    if (typeof raw === 'string') {
      return parseNumber(raw);
    }
    return fallback;
  }

  private userDailyCapKey(userId: string, dayKey: string): string {
    return `user:${userId}:daily:${dayKey}`;
  }

  private providerDailyBudgetKey(provider: AiProviderName, dayKey: string): string {
    return `provider:${provider}:daily:${dayKey}`;
  }

  private providerMonthlyBudgetKey(provider: AiProviderName, monthKey: string): string {
    return `provider:${provider}:monthly:${monthKey}`;
  }

  private providerBudgetReservationKey(reservationId: string): string {
    return `budget-reservation:${reservationId}`;
  }
}

export async function handleAiApiRequest(
  request: Request,
  url: URL,
  env: AiEnvBindings,
): Promise<Response | null> {
  if (!url.pathname.startsWith('/api/ai')) {
    return null;
  }

  if (request.method === 'GET' && url.pathname === '/api/ai/health') {
    return handleAiHealth(request, env);
  }

  const chargeMatch = /^\/api\/ai\/charges\/([^/]+)$/.exec(url.pathname);
  if (request.method === 'GET' && chargeMatch != null) {
    return handleChargeEvidence(chargeMatch[1], env);
  }

  if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname.startsWith('/api/ai/assets/')) {
    return handleAssetRead(url.pathname, request.method, env);
  }

  if (request.method === 'POST' && url.pathname === '/api/ai/generations') {
    return handleGenerate(request, env);
  }

  const variationMatch = /^\/api\/ai\/generations\/([^/]+)\/variations$/.exec(url.pathname);
  if (request.method === 'POST' && variationMatch != null) {
    return handleVariation(request, env, variationMatch[1]);
  }

  if (request.method === 'POST' && url.pathname === '/api/ai/metadata/prefill') {
    return handlePrefill(request, env);
  }

  return aiError('invalid_request', 404, 'Unsupported AI endpoint');
}

async function handleAssetRead(pathname: string, method: string, env: AiEnvBindings): Promise<Response> {
  const objectKey = pathname.replace('/api/ai/assets/', '').trim();
  if (!isNonEmptyString(objectKey)) {
    return aiError('invalid_request', 400, 'Invalid asset key');
  }

  if (env.AI_IMAGES != null) {
    let object = await env.AI_IMAGES.get(objectKey);
    if (object == null && (await ensureDeferredWatermark(objectKey, env))) {
      object = await env.AI_IMAGES.get(objectKey);
    }
    if (object == null) {
      return assetNotFound(objectKey, env);
    }
    if (method === 'HEAD') {
      return new Response(null, {
        status: 200,
        headers: {
          'content-type': object.httpMetadata?.contentType ?? 'image/png',
          'cache-control': object.httpMetadata?.cacheControl ?? 'public, max-age=31536000, immutable',
        },
      });
    }
    return new Response(object.body, {
      status: 200,
      headers: {
        'content-type': object.httpMetadata?.contentType ?? 'image/png',
        'cache-control': object.httpMetadata?.cacheControl ?? 'public, max-age=31536000, immutable',
      },
    });
  }

  let encoded = await env.AI_STATE_KV.get(`ai:asset:${objectKey}`);
  if (!isNonEmptyString(encoded) && (await ensureDeferredWatermark(objectKey, env))) {
    encoded = await env.AI_STATE_KV.get(`ai:asset:${objectKey}`);
  }
  if (!isNonEmptyString(encoded)) {
    return assetNotFound(objectKey, env);
  }
  const bytes = fromBase64(encoded);
  if (method === 'HEAD') {
    return new Response(null, {
      status: 200,
      headers: {
        'content-type': 'image/png',
        'cache-control': 'public, max-age=2592000',
      },
    });
  }
  return new Response(bytes, {
    status: 200,
    headers: {
      'content-type': 'image/png',
      'cache-control': 'public, max-age=2592000',
    },
  });
}

async function assetNotFound(objectKey: string, env: AiEnvBindings): Promise<Response> {
  const match = PUBLIC_ASSET_KEY_REGEX.exec(objectKey);
  if (match != null && isNonEmptyString(await env.AI_STATE_KV.get(watermarkPendingKey(match[1])))) {
    const response = aiError('provider_error', 503, 'Watermarked image is not ready yet');
    response.headers.set('retry-after', '30');
    return response;
  }
  return aiError('generation_not_found', 404, 'Asset not found');
}

async function handleChargeEvidence(rawTxId: string, env: AiEnvBindings): Promise<Response> {
  const txId = chargeTxIdOrNull(rawTxId);
  if (txId == null) {
    return aiError('invalid_request', 404, 'Unknown charge id');
  }
  try {
    const response = await sendQuotaRequest<AiQuotaChargeStatusResponse>(env, { op: 'charge_status', txId });
    return aiJson({ status: response.status });
  } catch (error) {
    console.error('[ai] charge_status_failed', { error: `${error ?? ''}` });
    return aiError('provider_error', 502, 'Quota coordinator unavailable');
  }
}

async function handleAiHealth(request: Request, env: AiEnvBindings): Promise<Response> {
  if (await parseAuth(request, env) == null) {
    return aiJson({ ok: true });
  }
  const config = await readRoutingConfig(env);
  let snapshots: Record<AiProviderName, ProviderBudgetSnapshot>;
  try {
    snapshots = await readProviderBudgetSnapshots(config, 'balanced', env);
  } catch (error) {
    console.error('[ai] health_budget_snapshot_failed', { error: `${error ?? ''}` });
    return aiError('provider_error', 502, 'Quota coordinator unavailable');
  }
  return aiJson({
    ok: true,
    version: config.version,
    enabled: config.enabled,
    guardrailLevel: resolveHighestThreshold(Object.values(snapshots).map((snapshot) => snapshot.thresholdLevel)),
    providers: {
      fal: {
        configured: isNonEmptyString(env.FAL_API_KEY),
        enabled: config.providers.fal.enabled,
        model: config.providers.fal.modelByQuality.balanced,
        budget: serializeBudgetSnapshot(snapshots.fal, config.providers.fal),
      },
      gemini: {
        configured: isNonEmptyString(env.GEMINI_API_KEY),
        enabled: config.providers.gemini.enabled,
        model: config.providers.gemini.modelByQuality.balanced,
        budget: serializeBudgetSnapshot(snapshots.gemini, config.providers.gemini),
      },
    },
    checkedAt: new Date().toISOString(),
  });
}

async function handleGenerate(request: Request, env: AiEnvBindings): Promise<Response> {
  const auth = await parseAuth(request, env);
  if (auth == null) {
    return aiError('unauthorized', 401, 'Missing or invalid bearer token');
  }

  const body = await readJson<AiGenerateRequest>(request);
  if (body == null) {
    return aiError('invalid_json', 400, 'Invalid JSON body');
  }

  const charge = readChargeTxId(body.chargeTxId, env);
  if (charge instanceof Response) {
    return charge;
  }

  const parsed = normalizeGenerateRequest(body);
  if (parsed == null) {
    return aiError('invalid_request', 400, 'Invalid generation payload');
  }

  if (!isPromptSafe(parsed.prompt)) {
    return aiError('unsafe_prompt', 422, 'Prompt rejected by safety policy');
  }

  return executeGeneration({
    env,
    auth,
    chargeTxId: charge,
    prompt: parsed.prompt,
    stylePreset: parsed.stylePreset,
    qualityTier: parsed.qualityTier,
    targetSize: parsed.targetSize,
    seed: parsed.seed,
  });
}

async function handleVariation(request: Request, env: AiEnvBindings, parentGenerationId: string): Promise<Response> {
  const auth = await parseAuth(request, env);
  if (auth == null) {
    return aiError('unauthorized', 401, 'Missing or invalid bearer token');
  }

  const original = await readGenerationRecord(parentGenerationId, env);
  if (original == null) {
    return aiError('generation_not_found', 404, 'Generation not found');
  }
  if (original.userId !== auth.userId) {
    return aiError('unauthorized', 403, 'Generation access denied');
  }

  const body = await readJson<AiVariationRequest>(request);
  if (body == null) {
    return aiError('invalid_json', 400, 'Invalid JSON body');
  }

  const charge = readChargeTxId(body.chargeTxId, env);
  if (charge instanceof Response) {
    return charge;
  }

  const variationPrompt = clipText(sanitizeText(body.variationPrompt ?? ''), 160);
  const strength = clampNumber(asNumber(body.strength, 0.45), 0.1, 1.0);
  const mergedPrompt = variationPrompt.length === 0
    ? original.prompt
    : `${original.prompt}. Variation request (${strength.toFixed(2)}): ${variationPrompt}`;
  if (!isPromptSafe(mergedPrompt)) {
    return aiError('unsafe_prompt', 422, 'Variation prompt rejected by safety policy');
  }

  return executeGeneration({
    env,
    auth,
    chargeTxId: charge,
    prompt: mergedPrompt,
    stylePreset: original.stylePreset,
    qualityTier: original.qualityTier,
    targetSize: `${original.width}x${original.height}`,
    seed: randomSeed(),
    parentGenerationId: parentGenerationId,
  });
}

async function handlePrefill(request: Request, env: AiEnvBindings): Promise<Response> {
  const auth = await parseAuth(request, env);
  if (auth == null) {
    return aiError('unauthorized', 401, 'Missing or invalid bearer token');
  }
  const body = await readJson<{ generationId?: string }>(request);
  if (body == null || !isNonEmptyString(body.generationId)) {
    return aiError('invalid_request', 400, 'generationId is required');
  }

  const generation = await readGenerationRecord(body.generationId, env);
  if (generation == null) {
    return aiError('generation_not_found', 404, 'Generation not found');
  }
  if (generation.userId !== auth.userId) {
    return aiError('unauthorized', 403, 'Generation access denied');
  }

  const title = buildTitleFromPrompt(generation.prompt, generation.stylePreset);
  const tags = deriveTagsFromPrompt(generation.prompt, generation.stylePreset);
  const description = `Generated with Prism AI (${generation.stylePreset}) using prompt: ${generation.prompt}`;
  const category = classifyCategory(generation.stylePreset, tags);
  return aiJson({
    generationId: generation.generationId,
    title,
    description: clipText(description, 280),
    tags,
    category,
  });
}

interface ExecuteGenerationParams {
  env: AiEnvBindings;
  auth: AuthContext;
  prompt: string;
  stylePreset: string;
  qualityTier: AiQualityTier;
  targetSize: string;
  seed: number;
  parentGenerationId?: string;
  chargeTxId?: string;
}

function chargeTxIdOrNull(value: unknown): string | null {
  return typeof value === 'string' && CHARGE_TX_ID_REGEX.test(value) ? value : null;
}

function effectiveChargeState(record: AiChargeRecord): 'in_progress' | 'succeeded' | 'failed' {
  if (record.state === 'in_progress' && Date.now() - record.at > CHARGE_STALE_IN_PROGRESS_MS) {
    return 'failed';
  }
  return record.state;
}

function readChargeTxId(value: unknown, env: AiEnvBindings): string | undefined | Response {
  if (value == null) {
    return env.AI_REQUIRE_CHARGE === 'true'
      ? aiError('charge_required', 402, 'A paid charge id is required')
      : undefined;
  }
  const txId = chargeTxIdOrNull(value);
  return txId ?? aiError('invalid_request', 400, 'Invalid chargeTxId');
}

async function executeGeneration(params: ExecuteGenerationParams): Promise<Response> {
  const txId = params.chargeTxId;
  if (txId == null) {
    return runQuotaGatedGeneration(params);
  }

  let claim: AiQuotaChargeClaimResponse;
  try {
    claim = await sendQuotaRequest<AiQuotaChargeClaimResponse>(params.env, { op: 'charge_claim', txId });
  } catch (error) {
    console.error('[ai] charge_claim_failed', { userId: params.auth.userId, error: `${error ?? ''}` });
    return aiError('provider_error', 502, 'Quota coordinator unavailable');
  }
  if (claim.status === 'done') {
    return new Response(claim.response ?? '', {
      status: 200,
      headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
    });
  }
  if (claim.status === 'in_progress') {
    return aiError('charge_in_progress', 409, 'This charge is already being processed');
  }
  if (claim.status === 'failed') {
    return aiError('charge_invalid', 402, 'This charge already failed. Request a refund.');
  }

  const verdict = await verifyCharge(txId, params.qualityTier, params.auth, params.env);
  if (verdict !== 'ok') {
    await sendChargeMutation(params.env, { op: 'charge_release', txId });
    return verdict === 'invalid'
      ? aiError('charge_invalid', 402, 'Charge could not be verified')
      : aiError('provider_error', 502, 'Charge verification unavailable');
  }

  let response: Response;
  try {
    response = await runQuotaGatedGeneration(params);
  } catch (error) {
    await sendChargeMutation(params.env, { op: 'charge_finish', txId, outcome: 'failed' });
    throw error;
  }
  await sendChargeMutation(
    params.env,
    response.ok
      ? { op: 'charge_finish', txId, outcome: 'succeeded', response: await response.clone().text() }
      : { op: 'charge_finish', txId, outcome: 'failed' },
  );
  return response;
}

async function sendChargeMutation(env: AiEnvBindings, body: AiQuotaChargeRequest | AiQuotaChargeFinishRequest): Promise<void> {
  try {
    await sendQuotaRequest<AiQuotaChargeMutationResponse>(env, body);
  } catch (error) {
    console.error('[ai] charge_update_failed', { op: body.op, txId: body.txId, error: `${error ?? ''}` });
  }
}

async function verifyCharge(
  txId: string,
  qualityTier: AiQualityTier,
  auth: AuthContext,
  env: AiEnvBindings,
): Promise<'ok' | 'invalid' | 'unavailable'> {
  if (!isNonEmptyString(env.FIREBASE_PROJECT_ID)) {
    console.error('[ai] charge_verify_missing_project_id');
    return 'unavailable';
  }
  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}`
    + `/databases/(default)/documents/coinTransactions/${encodeURIComponent(txId)}`;
  let response: Response;
  try {
    response = await fetch(url, {
      headers: { authorization: `Bearer ${auth.token}` },
      signal: AbortSignal.timeout(8000),
    });
  } catch (error) {
    console.error('[ai] charge_verify_fetch_failed', { error: `${error ?? ''}` });
    return 'unavailable';
  }
  if (response.status === 404 || response.status === 403 || response.status === 401) {
    return 'invalid';
  }
  if (!response.ok) {
    console.error('[ai] charge_verify_http_error', { status: response.status });
    return 'unavailable';
  }
  const doc = await readJson<{ fields?: Record<string, Record<string, unknown> | undefined> }>(response);
  const fields = doc?.fields;
  if (fields == null) {
    return 'invalid';
  }
  const delta = firestoreNumber(fields.delta);
  const createdAtMs = typeof fields.createdAt?.timestampValue === 'string'
    ? Date.parse(fields.createdAt.timestampValue)
    : Number.NaN;
  const ageMs = Date.now() - createdAtMs;
  const matches = fields.userId?.stringValue === auth.userId
    && fields.action?.stringValue === 'aiGeneration'
    && fields.type?.stringValue === 'debit'
    && fields.status?.stringValue === 'completed'
    && delta != null
    && -delta === AI_COIN_COST_BY_TIER[qualityTier]
    && Number.isFinite(ageMs)
    && ageMs >= -CHARGE_CLOCK_SKEW_MS
    && ageMs <= CHARGE_MAX_AGE_MS;
  return matches ? 'ok' : 'invalid';
}

function firestoreNumber(field: Record<string, unknown> | undefined): number | null {
  if (field == null) {
    return null;
  }
  const raw = field.integerValue ?? field.doubleValue;
  const value = typeof raw === 'string' ? Number(raw) : raw;
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

async function runQuotaGatedGeneration(params: ExecuteGenerationParams): Promise<Response> {
  const config = await readRoutingConfig(params.env);
  if (!config.enabled) {
    return aiError('service_disabled', 503, 'AI generation is disabled');
  }
  let dailyCapStatus: { allowed: boolean; current: number; dayKey: string };
  try {
    dailyCapStatus = await checkAndIncrementUserDailyCap(params.auth.userId, config.hardUserDailyCap, params.env);
  } catch (error) {
    console.error('[ai] quota_cap_check_failed', {
      userId: params.auth.userId,
      error: `${error ?? ''}`,
    });
    return aiError('provider_error', 502, 'Quota coordinator unavailable');
  }
  if (!dailyCapStatus.allowed) {
    return aiError('rate_limited', 429, 'User daily generation limit reached');
  }

  const billing = { billed: false };
  let response: Response;
  try {
    response = await runGenerationAttempts(params, config, billing);
  } catch (error) {
    if (!billing.billed) {
      await releaseUserDailyCap(params.auth.userId, dailyCapStatus.dayKey, params.env);
    }
    throw error;
  }
  if (!response.ok && !billing.billed) {
    await releaseUserDailyCap(params.auth.userId, dailyCapStatus.dayKey, params.env);
  }
  return response;
}

async function runGenerationAttempts(
  params: ExecuteGenerationParams,
  config: AiRoutingConfig,
  billing: { billed: boolean },
): Promise<Response> {
  let routingPlan: RoutingPlan;
  try {
    routingPlan = await buildProviderAttemptOrder(config, params.qualityTier, params.env);
  } catch (error) {
    console.error('[ai] quota_budget_snapshot_failed', {
      userId: params.auth.userId,
      error: `${error ?? ''}`,
    });
    return aiError('provider_error', 502, 'Quota coordinator unavailable');
  }
  if (routingPlan.order.length === 0) {
    return aiError('service_disabled', 503, 'No AI providers are enabled');
  }
  const effectiveQualityTier = routingPlan.effectiveQualityTier;
  if (params.chargeTxId != null && effectiveQualityTier !== params.qualityTier) {
    console.warn('[ai] paid_request_not_downgraded', {
      userId: params.auth.userId,
      requestedQualityTier: params.qualityTier,
      effectiveQualityTier,
      guardrailLevel: routingPlan.guardrailLevel,
    });
    return aiError('budget_exhausted', 429, 'The requested quality is unavailable right now');
  }
  const attemptedProviders: AiProviderName[] = [];
  const requestStartedAt = Date.now();
  if (routingPlan.guardrailLevel > 0) {
    console.warn('[ai] budget_guardrail_active', {
      userId: params.auth.userId,
      requestedQualityTier: params.qualityTier,
      effectiveQualityTier,
      guardrailLevel: routingPlan.guardrailLevel,
      reason: routingPlan.reason,
    });
  }

  let lastErrorCode: AiErrorCode = 'provider_error';
  let lastErrorMessage = 'No provider could generate image';
  for (const providerName of routingPlan.order) {
    attemptedProviders.push(providerName);
    const providerConfig = config.providers[providerName];
    if (!providerConfig.enabled) {
      continue;
    }

    const estimatedCost = providerConfig.estimatedCostByQualityUsd[effectiveQualityTier];
    let budgetReservation: ProviderBudgetReservationResult;
    try {
      budgetReservation = await reserveProviderBudget(providerName, estimatedCost, providerConfig, params.env);
    } catch (error) {
      lastErrorCode = 'provider_error';
      lastErrorMessage = 'Quota coordinator unavailable';
      console.error('[ai] budget_reservation_failed', {
        provider: providerName,
        requestedQualityTier: params.qualityTier,
        effectiveQualityTier,
        estimatedCostUsd: estimatedCost,
        error: `${error ?? ''}`,
      });
      continue;
    }
    if (!budgetReservation.allowed) {
      lastErrorCode = 'budget_exhausted';
      lastErrorMessage = `Budget exhausted for ${providerName}`;
      console.warn('[ai] budget_exhausted', {
        provider: providerName,
        requestedQualityTier: params.qualityTier,
        effectiveQualityTier,
        estimatedCostUsd: estimatedCost,
      });
      continue;
    }
    const reservationId = budgetReservation.reservationId;

    const adapter = providerName === 'fal' ? new FalProviderAdapter() : new GeminiProviderAdapter();
    const model = providerConfig.modelByQuality[effectiveQualityTier];
    const startedAt = Date.now();
    let shouldReleaseReservation = true;
    let reservationCommitted = false;
    const markBilled = async (): Promise<void> => {
      if (reservationCommitted) {
        return;
      }
      reservationCommitted = true;
      if (isNonEmptyString(reservationId)) {
        await commitBilledReservation(reservationId, providerName, estimatedCost, params.env);
      }
      shouldReleaseReservation = false;
      billing.billed = true;
    };
    try {
      const result = await adapter.generate({
        prompt: params.prompt,
        qualityTier: effectiveQualityTier,
        model,
        estimatedCostUsd: estimatedCost,
        targetSize: params.targetSize,
        seed: params.seed,
        stylePreset: params.stylePreset,
        timeoutMs: providerConfig.timeoutMs,
        env: params.env,
        onProviderBilled: markBilled,
      });

      await markBilled();

      if (!isOutputSafe(result.imageBytes, result.contentType)) {
        lastErrorCode = 'unsafe_output';
        lastErrorMessage = `Output blocked by safety policy (${providerName})`;
        console.warn('[ai] unsafe_output_block', {
          provider: providerName,
          model: result.model,
          contentType: result.contentType,
        });
        break;
      }

      const generationId = createId('gen');
      const persisted = await persistGenerationArtifacts(
        generationId,
        result.imageBytes,
        result.contentType,
        result.width,
        result.height,
        params.env,
      );
      const latencyMs = Date.now() - startedAt;

      const record: AiGenerationRecord = {
        generationId,
        userId: params.auth.userId,
        createdAt: new Date().toISOString(),
        parentGenerationId: params.parentGenerationId,
        prompt: params.prompt,
        stylePreset: params.stylePreset,
        qualityTier: effectiveQualityTier,
        provider: providerName,
        model: result.model,
        seed: result.seed,
        width: result.width,
        height: result.height,
        imageUrl: persisted.imageUrl,
        watermarkedImageUrl: persisted.watermarkedImageUrl,
        safety: {
          promptSafe: true,
          outputSafe: true,
        },
        estimatedCostUsd: estimatedCost,
        latencyMs,
      };

      await saveGenerationRecord(record, params.env);

      console.info('[ai] generation_success', {
        generationId: record.generationId,
        userId: params.auth.userId,
        provider: providerName,
        model: result.model,
        requestedQualityTier: params.qualityTier,
        effectiveQualityTier,
        guardrailLevel: routingPlan.guardrailLevel,
        attemptedProviders,
        latencyMs: record.latencyMs,
        estimatedCostUsd: record.estimatedCostUsd,
        totalRequestLatencyMs: Date.now() - requestStartedAt,
      });

      return aiJson({
        generationId: record.generationId,
        provider: record.provider,
        model: record.model,
        qualityTier: record.qualityTier,
        requestedQualityTier: params.qualityTier,
        seed: record.seed,
        width: record.width,
        height: record.height,
        imageUrls: {
          imageUrl: record.imageUrl,
          watermarkedImageUrl: record.watermarkedImageUrl,
        },
        safety: record.safety,
        estimatedCostUsd: record.estimatedCostUsd,
        latencyMs: record.latencyMs,
      });
    } catch (error) {
      lastErrorCode = isTimeoutError(error) ? 'provider_timeout' : 'provider_error';
      lastErrorMessage = `${providerName} generation failed`;
      console.warn('[ai] provider_failed', {
        provider: providerName,
        requestedQualityTier: params.qualityTier,
        effectiveQualityTier,
        error: `${error ?? ''}`,
      });
      if (reservationCommitted) {
        break;
      }
    } finally {
      if (shouldReleaseReservation && isNonEmptyString(reservationId)) {
        try {
          await releaseProviderBudgetReservation(reservationId, params.env);
        } catch (releaseError) {
          console.error('[ai] budget_reservation_release_failed', {
            provider: providerName,
            reservationId,
            error: `${releaseError ?? ''}`,
          });
        }
      }
    }
  }

  console.warn('[ai] generation_failed', {
    userId: params.auth.userId,
    requestedQualityTier: params.qualityTier,
    effectiveQualityTier,
    guardrailLevel: routingPlan.guardrailLevel,
    attemptedProviders,
    errorCode: lastErrorCode,
  });

  return aiError(lastErrorCode, lastErrorCode === 'budget_exhausted' ? 429 : 502, lastErrorMessage);
}

function normalizeGenerateRequest(body: AiGenerateRequest): AiGenerateRequest | null {
  if (!isNonEmptyString(body.prompt)) {
    return null;
  }
  const qualityTier = normalizeQualityTier(body.qualityTier);
  if (qualityTier == null) {
    return null;
  }
  return {
    prompt: clipText(sanitizeText(body.prompt), 160),
    stylePreset: clipText(sanitizeText(body.stylePreset ?? 'abstract'), 40),
    qualityTier,
    targetSize: normalizeTargetSize(body.targetSize),
    seed: Number.isInteger(body.seed) ? Number(body.seed) : randomSeed(),
  };
}

function normalizeQualityTier(value: unknown): AiQualityTier | null {
  if (value === 'fast' || value === 'balanced' || value === 'quality') {
    return value;
  }
  return null;
}

function normalizeTargetSize(value: unknown): string {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  const match = /^(\d{2,5})x(\d{2,5})$/.exec(raw);
  if (match == null) {
    return '1080x1920';
  }
  const width = clampNumber(Number.parseInt(match[1], 10), 256, 2048);
  const height = clampNumber(Number.parseInt(match[2], 10), 256, 2048);
  return `${width.toFixed(0)}x${height.toFixed(0)}`;
}

async function parseAuth(request: Request, env: AiEnvBindings): Promise<AuthContext | null> {
  const verified = await verifyFirebaseIdTokenFromRequest(request, env);
  if (verified == null) {
    return null;
  }
  return {
    token: verified.token,
    userId: clipText(verified.userId, 128),
  };
}

async function readRoutingConfig(env: AiEnvBindings): Promise<AiRoutingConfig> {
  const raw = await env.AI_STATE_KV.get(AI_CONFIG_KEY);
  if (!isNonEmptyString(raw)) {
    return AI_DEFAULT_CONFIG;
  }
  try {
    const parsed = JSON.parse(raw) as Partial<AiRoutingConfig>;
    return mergeRoutingConfig(parsed);
  } catch {
    return AI_DEFAULT_CONFIG;
  }
}

function mergeRoutingConfig(raw: Partial<AiRoutingConfig>): AiRoutingConfig {
  const providers = raw.providers ?? {};
  return {
    enabled: typeof raw.enabled === 'boolean' ? raw.enabled : AI_DEFAULT_CONFIG.enabled,
    version: asString(raw.version) || AI_DEFAULT_CONFIG.version,
    hardUserDailyCap: Math.round(clampNumber(raw.hardUserDailyCap ?? AI_DEFAULT_CONFIG.hardUserDailyCap, 1, 500)),
    fallbackOrder: normalizeFallbackOrder(raw.fallbackOrder),
    providers: {
      fal: mergeProviderConfig('fal', providers.fal, AI_DEFAULT_CONFIG.providers.fal),
      gemini: mergeProviderConfig('gemini', providers.gemini, AI_DEFAULT_CONFIG.providers.gemini),
    },
  };
}

function mergeProviderConfig(
  provider: AiProviderName,
  raw: Partial<AiRoutingProviderConfig> | undefined,
  fallback: AiRoutingProviderConfig,
): AiRoutingProviderConfig {
  const source = raw ?? {};
  return {
    enabled: typeof source.enabled === 'boolean' ? source.enabled : fallback.enabled,
    weight: clampNumber(source.weight ?? fallback.weight, 0, 1000),
    modelByQuality: {
      fast: normalizeProviderModel(provider, source.modelByQuality?.fast, fallback.modelByQuality.fast),
      balanced: normalizeProviderModel(provider, source.modelByQuality?.balanced, fallback.modelByQuality.balanced),
      quality: normalizeProviderModel(provider, source.modelByQuality?.quality, fallback.modelByQuality.quality),
    },
    estimatedCostByQualityUsd: {
      fast: clampNumber(source.estimatedCostByQualityUsd?.fast ?? fallback.estimatedCostByQualityUsd.fast, 0, 10),
      balanced: clampNumber(source.estimatedCostByQualityUsd?.balanced ?? fallback.estimatedCostByQualityUsd.balanced, 0, 10),
      quality: clampNumber(source.estimatedCostByQualityUsd?.quality ?? fallback.estimatedCostByQualityUsd.quality, 0, 10),
    },
    dailyBudgetUsd: clampNumber(source.dailyBudgetUsd ?? fallback.dailyBudgetUsd, 0, 100000),
    monthlyBudgetUsd: clampNumber(source.monthlyBudgetUsd ?? fallback.monthlyBudgetUsd, 0, 1000000),
    timeoutMs: clampNumber(source.timeoutMs ?? fallback.timeoutMs, 1000, 60000),
  };
}

function normalizeProviderModel(provider: AiProviderName, value: unknown, fallback: string): string {
  const model = asString(value) || fallback;
  if (provider === 'gemini' && isDeprecatedGeminiModel(model)) {
    return fallback;
  }
  return model;
}

function isDeprecatedGeminiModel(model: string): boolean {
  return model === 'imagen-3.0-fast-generate-001' || model === 'imagen-3.0-generate-002';
}

function normalizeFallbackOrder(raw: unknown): AiProviderName[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return AI_DEFAULT_CONFIG.fallbackOrder;
  }
  const normalized = raw
    .map((value) => (value === 'fal' || value === 'gemini' ? value : null))
    .filter((value): value is AiProviderName => value != null);
  if (normalized.length === 0) {
    return AI_DEFAULT_CONFIG.fallbackOrder;
  }
  return Array.from(new Set<AiProviderName>(normalized));
}

async function buildProviderAttemptOrder(
  config: AiRoutingConfig,
  requestedQualityTier: AiQualityTier,
  env: AiEnvBindings,
): Promise<RoutingPlan> {
  const snapshots = await readProviderBudgetSnapshots(config, requestedQualityTier, env);
  const guardrailLevel = resolveHighestThreshold(Object.values(snapshots).map((snapshot) => snapshot.thresholdLevel));
  const effectiveQualityTier = applyBudgetQualityGuardrail(requestedQualityTier, guardrailLevel);
  const enabledProviders = (Object.entries(config.providers) as Array<[AiProviderName, AiRoutingProviderConfig]>)
    .filter(([, providerConfig]) => providerConfig.enabled)
    .map(([providerName, providerConfig]) => ({ providerName, providerConfig }));

  if (enabledProviders.length === 0) {
    return {
      order: [],
      snapshots,
      guardrailLevel,
      effectiveQualityTier,
      reason: 'no_enabled_providers',
    };
  }

  const weighted = enabledProviders
    .filter((provider) => provider.providerConfig.weight > 0)
    .map((provider) => ({ providerName: provider.providerName, weight: provider.providerConfig.weight }));
  let primaryPool = weighted.length > 0
    ? weighted
    : enabledProviders.map((provider) => ({ providerName: provider.providerName, weight: 1 }));

  const poolWithoutCriticalBudget = primaryPool.filter(
    (provider) => snapshots[provider.providerName].thresholdLevel < 95,
  );
  if (poolWithoutCriticalBudget.length > 0) {
    primaryPool = poolWithoutCriticalBudget;
  }

  let reason = 'weighted_primary';
  let primary = pickWeightedProvider(primaryPool);
  if (guardrailLevel >= 85) {
    const cheapest = [...primaryPool].sort(
      (a, b) => snapshots[a.providerName].estimatedCostUsd - snapshots[b.providerName].estimatedCostUsd,
    );
    if (cheapest.length > 0) {
      primary = cheapest[0].providerName;
      reason = `threshold_${guardrailLevel}_cheapest_primary`;
    }
  }

  const candidates = enabledProviders
    .map((provider) => provider.providerName)
    .filter((providerName) => providerName !== primary);
  const remainingCandidates = poolWithoutCriticalBudget.length > 0
    ? candidates.filter((providerName) => snapshots[providerName].thresholdLevel < 95)
    : candidates;
  const order: AiProviderName[] = [primary];
  if (guardrailLevel >= 70) {
    reason = reason === 'weighted_primary' ? `threshold_${guardrailLevel}_cost_optimized` : reason;
    const byEstimatedCost = [...remainingCandidates].sort(
      (a, b) => snapshots[a].estimatedCostUsd - snapshots[b].estimatedCostUsd,
    );
    for (const providerName of byEstimatedCost) {
      if (!order.includes(providerName)) {
        order.push(providerName);
      }
    }
  } else {
    for (const providerName of config.fallbackOrder) {
      if (!order.includes(providerName) && remainingCandidates.includes(providerName)) {
        order.push(providerName);
      }
    }
    for (const providerName of remainingCandidates) {
      if (!order.includes(providerName)) {
        order.push(providerName);
      }
    }
  }

  return {
    order,
    snapshots,
    guardrailLevel,
    effectiveQualityTier,
    reason,
  };
}

function pickWeightedProvider(candidates: Array<{ providerName: AiProviderName; weight: number }>): AiProviderName {
  const totalWeight = candidates.reduce((sum, value) => sum + value.weight, 0);
  if (totalWeight <= 0) {
    return candidates[0].providerName;
  }
  const random = randomInt(0, totalWeight - 1);
  let running = 0;
  for (const candidate of candidates) {
    running += candidate.weight;
    if (random < running) {
      return candidate.providerName;
    }
  }
  return candidates[0].providerName;
}

async function readProviderBudgetSnapshots(
  config: AiRoutingConfig,
  qualityTier: AiQualityTier,
  env: AiEnvBindings,
): Promise<Record<AiProviderName, ProviderBudgetSnapshot>> {
  const [falStatus, geminiStatus] = await Promise.all([readBudgetStatus('fal', env), readBudgetStatus('gemini', env)]);
  return {
    fal: createBudgetSnapshot('fal', falStatus, config.providers.fal, qualityTier),
    gemini: createBudgetSnapshot('gemini', geminiStatus, config.providers.gemini, qualityTier),
  };
}

function createBudgetSnapshot(
  provider: AiProviderName,
  status: BudgetStatus,
  providerConfig: AiRoutingProviderConfig,
  qualityTier: AiQualityTier,
): ProviderBudgetSnapshot {
  const dailyUsageRatio = normalizeBudgetUsageRatio(status.dailySpentUsd, providerConfig.dailyBudgetUsd);
  const monthlyUsageRatio = normalizeBudgetUsageRatio(status.monthlySpentUsd, providerConfig.monthlyBudgetUsd);
  const usageRatio = Math.max(dailyUsageRatio, monthlyUsageRatio);
  return {
    provider,
    dailySpentUsd: status.dailySpentUsd,
    monthlySpentUsd: status.monthlySpentUsd,
    dailyUsageRatio,
    monthlyUsageRatio,
    usageRatio,
    estimatedCostUsd: providerConfig.estimatedCostByQualityUsd[qualityTier],
    thresholdLevel: resolveBudgetThreshold(usageRatio),
  };
}

function normalizeBudgetUsageRatio(spent: number, budget: number): number {
  if (!Number.isFinite(budget) || budget <= 0) {
    return spent > 0 ? 1 : 0;
  }
  return spent / budget;
}

function resolveBudgetThreshold(usageRatio: number): BudgetThresholdLevel {
  if (usageRatio >= 0.95) {
    return 95;
  }
  if (usageRatio >= 0.85) {
    return 85;
  }
  if (usageRatio >= 0.70) {
    return 70;
  }
  return 0;
}

function resolveHighestThreshold(levels: BudgetThresholdLevel[]): BudgetThresholdLevel {
  let highest: BudgetThresholdLevel = 0;
  for (const level of levels) {
    if (level > highest) {
      highest = level;
    }
  }
  return highest;
}

function applyBudgetQualityGuardrail(
  requestedQualityTier: AiQualityTier,
  guardrailLevel: BudgetThresholdLevel,
): AiQualityTier {
  if (guardrailLevel >= 95) {
    if (requestedQualityTier === 'quality') {
      return 'balanced';
    }
    if (requestedQualityTier === 'balanced') {
      return 'fast';
    }
  }
  if (guardrailLevel >= 85 && requestedQualityTier === 'quality') {
    return 'balanced';
  }
  return requestedQualityTier;
}

function serializeBudgetSnapshot(snapshot: ProviderBudgetSnapshot, config: AiRoutingProviderConfig): Record<string, unknown> {
  return {
    dailySpentUsd: roundFloat(snapshot.dailySpentUsd, 6),
    dailyBudgetUsd: config.dailyBudgetUsd,
    dailyUsagePercent: roundFloat(snapshot.dailyUsageRatio * 100, 2),
    monthlySpentUsd: roundFloat(snapshot.monthlySpentUsd, 6),
    monthlyBudgetUsd: config.monthlyBudgetUsd,
    monthlyUsagePercent: roundFloat(snapshot.monthlyUsageRatio * 100, 2),
    thresholdLevel: snapshot.thresholdLevel,
    estimatedCostUsd: snapshot.estimatedCostUsd,
  };
}

async function readBudgetStatus(provider: AiProviderName, env: AiEnvBindings): Promise<BudgetStatus> {
  const dayKey = utcDayKey();
  const monthKey = utcMonthKey();
  const response = await sendQuotaRequest<AiQuotaProviderBudgetReadResponse>(env, {
    op: 'provider_budget_read',
    provider,
    dayKey,
    monthKey,
  });
  return {
    dailySpentUsd: roundFloat(asNumber(response.dailySpentUsd, 0), 6),
    monthlySpentUsd: roundFloat(asNumber(response.monthlySpentUsd, 0), 6),
  };
}

async function reserveProviderBudget(
  provider: AiProviderName,
  estimatedCostUsd: number,
  config: AiRoutingProviderConfig,
  env: AiEnvBindings,
): Promise<ProviderBudgetReservationResult> {
  const response = await sendQuotaRequest<AiQuotaProviderBudgetReserveResponse>(env, {
    op: 'provider_budget_reserve',
    provider,
    dayKey: utcDayKey(),
    monthKey: utcMonthKey(),
    estimatedCostUsd,
    dailyBudgetUsd: config.dailyBudgetUsd,
    monthlyBudgetUsd: config.monthlyBudgetUsd,
  });
  return {
    allowed: response.allowed,
    reservationId: isNonEmptyString(response.reservationId) ? response.reservationId : undefined,
    status: {
      dailySpentUsd: roundFloat(asNumber(response.dailySpentUsd, 0), 6),
      monthlySpentUsd: roundFloat(asNumber(response.monthlySpentUsd, 0), 6),
    },
  };
}

async function commitProviderBudgetReservation(
  reservationId: string,
  actualCostUsd: number,
  env: AiEnvBindings,
): Promise<void> {
  await sendQuotaRequest<AiQuotaProviderBudgetCommitResponse>(env, {
    op: 'provider_budget_commit',
    reservationId,
    actualCostUsd,
  });
}

async function commitBilledReservation(
  reservationId: string,
  provider: AiProviderName,
  billedCostUsd: number,
  env: AiEnvBindings,
): Promise<void> {
  try {
    await commitProviderBudgetReservation(reservationId, billedCostUsd, env);
  } catch (commitError) {
    console.error('[ai] budget_reservation_commit_failed', {
      provider,
      reservationId,
      error: `${commitError ?? ''}`,
    });
  }
}

async function releaseProviderBudgetReservation(reservationId: string, env: AiEnvBindings): Promise<void> {
  await sendQuotaRequest<AiQuotaProviderBudgetReleaseResponse>(env, {
    op: 'provider_budget_release',
    reservationId,
  });
}

async function checkAndIncrementUserDailyCap(
  userId: string,
  cap: number,
  env: AiEnvBindings,
): Promise<{ allowed: boolean; current: number; dayKey: string }> {
  const dayKey = utcDayKey();
  const response = await sendQuotaRequest<AiQuotaUserDailyCapResponse>(env, {
    op: 'user_daily_cap_try_increment',
    userId,
    dayKey,
    cap,
  });
  return {
    allowed: response.allowed,
    current: Math.max(0, Math.round(asNumber(response.current, 0))),
    dayKey,
  };
}

async function releaseUserDailyCap(userId: string, dayKey: string, env: AiEnvBindings): Promise<void> {
  try {
    await sendQuotaRequest<AiQuotaUserDailyCapReleaseResponse>(env, {
      op: 'user_daily_cap_release',
      userId,
      dayKey,
    });
  } catch (error) {
    console.error('[ai] quota_cap_release_failed', { userId, error: `${error ?? ''}` });
  }
}

async function sendQuotaRequest<T extends AiQuotaRpcResponse>(env: AiEnvBindings, body: AiQuotaRpcRequest): Promise<T> {
  const stub = quotaCoordinatorStub(env);
  const response = await stub.fetch(AI_QUOTA_RPC_URL, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`quota_rpc_http_${response.status}`);
  }
  const parsed = await readJson<AiQuotaRpcResponse>(response);
  if (parsed == null || parsed.ok !== true) {
    const errorCode = parsed != null && parsed.ok === false ? parsed.error : 'invalid_response';
    throw new Error(`quota_rpc_error_${errorCode}`);
  }
  return parsed as T;
}

export async function bumpRateLimit(env: AiEnvBindings, key: string, limit: number, ttlSeconds: number): Promise<boolean> {
  const response = await sendQuotaRequest<AiQuotaRateLimitResponse>(env, {
    op: 'rate_limit_bump',
    key,
    limit,
    ttlSeconds,
  });
  return response.allowed;
}

function quotaCoordinatorStub(env: AiEnvBindings): DurableObjectStub {
  const id = env.AI_QUOTA_DO.idFromName(AI_QUOTA_OBJECT_NAME);
  return env.AI_QUOTA_DO.get(id);
}

const WATERMARK_MIN_BYTES = 1024;
const WATERMARK_RENDER_ATTEMPTS = 2;
const WATERMARK_PENDING_TTL_SECONDS = 60 * 60 * 24 * 30;
const PUBLIC_ASSET_KEY_REGEX = /^ai\/public\/([A-Za-z0-9_-]+)\.png$/;
const ASSET_CACHE_CONTROL = 'public, max-age=31536000, immutable';

interface WatermarkPendingRecord {
  contentType: string;
  width: number;
  height: number;
}

async function persistGenerationArtifacts(
  generationId: string,
  imageBytes: Uint8Array,
  contentType: string,
  width: number,
  height: number,
  env: AiEnvBindings,
): Promise<{ imageUrl: string; watermarkedImageUrl: string }> {
  const originalKey = `ai/original/${generationId}.png`;
  const publicKey = `ai/public/${generationId}.png`;
  await storeAsset(originalKey, imageBytes, contentType, env);

  let watermarked: { bytes: Uint8Array; contentType: string } | null = null;
  for (let attempt = 1; attempt <= WATERMARK_RENDER_ATTEMPTS && watermarked == null; attempt += 1) {
    try {
      const rendered = await renderPublicWatermarkedBytes(imageBytes, contentType, width, height, env);
      if (rendered.bytes.length >= WATERMARK_MIN_BYTES) {
        watermarked = rendered;
      }
    } catch (error) {
      console.warn('[ai] watermark_attempt_failed', { generationId, attempt, error: `${error ?? ''}` });
    }
  }

  if (watermarked != null) {
    await storeAsset(publicKey, watermarked.bytes, watermarked.contentType, env);
  } else {
    const pending: WatermarkPendingRecord = { contentType, width, height };
    await env.AI_STATE_KV.put(watermarkPendingKey(generationId), JSON.stringify(pending), {
      expirationTtl: WATERMARK_PENDING_TTL_SECONDS,
    });
    console.warn('[ai] watermark_deferred', { generationId });
  }

  return {
    imageUrl: `https://prismwalls.com/api/ai/assets/${originalKey}`,
    watermarkedImageUrl: `https://prismwalls.com/api/ai/assets/${publicKey}`,
  };
}

function watermarkPendingKey(generationId: string): string {
  return `ai:wmpending:${generationId}`;
}

async function storeAsset(key: string, bytes: Uint8Array, contentType: string, env: AiEnvBindings): Promise<void> {
  if (env.AI_IMAGES != null) {
    await env.AI_IMAGES.put(key, bytes, { httpMetadata: { contentType, cacheControl: ASSET_CACHE_CONTROL } });
    return;
  }
  await env.AI_STATE_KV.put(`ai:asset:${key}`, toBase64(bytes), { expirationTtl: 60 * 60 * 24 * 30 });
}

async function readAssetBytes(key: string, env: AiEnvBindings): Promise<Uint8Array | null> {
  if (env.AI_IMAGES != null) {
    const object = await env.AI_IMAGES.get(key);
    return object == null ? null : new Uint8Array(await object.arrayBuffer());
  }
  const encoded = await env.AI_STATE_KV.get(`ai:asset:${key}`);
  return isNonEmptyString(encoded) ? fromBase64(encoded) : null;
}

async function ensureDeferredWatermark(objectKey: string, env: AiEnvBindings): Promise<boolean> {
  const match = PUBLIC_ASSET_KEY_REGEX.exec(objectKey);
  if (match == null) {
    return false;
  }
  const generationId = match[1];
  const rawPending = await env.AI_STATE_KV.get(watermarkPendingKey(generationId));
  if (!isNonEmptyString(rawPending)) {
    return false;
  }
  let pending: WatermarkPendingRecord;
  try {
    pending = JSON.parse(rawPending) as WatermarkPendingRecord;
  } catch {
    return false;
  }
  const original = await readAssetBytes(`ai/original/${generationId}.png`, env);
  if (original == null) {
    return false;
  }
  try {
    const rendered = await renderPublicWatermarkedBytes(
      original,
      asString(pending.contentType),
      asNumber(pending.width, 1080),
      asNumber(pending.height, 1920),
      env,
    );
    if (rendered.bytes.length < WATERMARK_MIN_BYTES) {
      return false;
    }
    await storeAsset(objectKey, rendered.bytes, rendered.contentType, env);
  } catch (error) {
    console.warn('[ai] watermark_deferred_failed', { generationId, error: `${error ?? ''}` });
    return false;
  }
  await env.AI_STATE_KV.delete(watermarkPendingKey(generationId));
  return true;
}

async function renderPublicWatermarkedBytes(
  imageBytes: Uint8Array,
  contentType: string,
  width: number,
  height: number,
  env: AiEnvBindings,
): Promise<{ bytes: Uint8Array; contentType: string }> {
  if (!contentType.startsWith('image/')) {
    throw new Error('watermark_invalid_content_type');
  }
  const normalizedWidth = Math.round(clampNumber(width, 256, 4096));
  const normalizedHeight = Math.round(clampNumber(height, 256, 4096));

  const canvasResult = await tryRenderWatermarkWithCanvas(imageBytes, contentType, normalizedWidth, normalizedHeight);
  if (canvasResult != null) {
    return canvasResult;
  }

  const browserRenderingResult = await tryRenderWatermarkWithBrowserRendering(
    imageBytes,
    contentType,
    normalizedWidth,
    normalizedHeight,
    env,
  );
  if (browserRenderingResult != null) {
    return browserRenderingResult;
  }

  console.warn('[ai] watermark_renderer_unavailable', { width, height, contentType });
  throw new Error('watermark_generation_failed');
}

async function tryRenderWatermarkWithCanvas(
  imageBytes: Uint8Array,
  contentType: string,
  width: number,
  height: number,
): Promise<{ bytes: Uint8Array; contentType: string } | null> {
  try {
    const globalValue = globalThis as unknown as {
      OffscreenCanvas?: new (width: number, height: number) => {
        getContext: (id: string) => unknown;
        convertToBlob: (options?: { type?: string; quality?: number }) => Promise<Blob>;
      };
      createImageBitmap?: (source: Blob) => Promise<{ close?: () => void }>;
    };
    if (typeof globalValue.OffscreenCanvas !== 'function' || typeof globalValue.createImageBitmap !== 'function') {
      return null;
    }
    const sourceBlob = new Blob([imageBytes], { type: contentType });
    const bitmap = await globalValue.createImageBitmap(sourceBlob);
    try {
      const canvas = new globalValue.OffscreenCanvas(width, height);
      const ctx = canvas.getContext('2d') as {
        drawImage: (...args: unknown[]) => void;
        font: string;
        fillStyle: string;
        shadowColor: string;
        shadowBlur: number;
        shadowOffsetX: number;
        shadowOffsetY: number;
        textBaseline: string;
        beginPath: () => void;
        moveTo: (x: number, y: number) => void;
        lineTo: (x: number, y: number) => void;
        quadraticCurveTo: (cpx: number, cpy: number, x: number, y: number) => void;
        closePath: () => void;
        fill: () => void;
        fillText: (text: string, x: number, y: number) => void;
        measureText: (text: string) => { width: number };
      } | null;
      if (ctx == null) {
        return null;
      }
      ctx.drawImage(bitmap, 0, 0, width, height);
      drawPrismWatermarkBadge(ctx, width, height);
      const preferredType = preferredWatermarkMimeType(contentType);
      const outputBlob = await canvas.convertToBlob({
        type: preferredType,
        quality: preferredType === 'image/jpeg' ? 0.95 : 0.98,
      });
      const outputType = isNonEmptyString(outputBlob.type) ? outputBlob.type : preferredType;
      return {
        bytes: new Uint8Array(await outputBlob.arrayBuffer()),
        contentType: outputType,
      };
    } finally {
      if (typeof bitmap.close === 'function') {
        bitmap.close();
      }
    }
  } catch (error) {
    console.warn('[ai] watermark_canvas_failed', { error: `${error ?? ''}` });
    return null;
  }
}

async function tryRenderWatermarkWithBrowserRendering(
  imageBytes: Uint8Array,
  contentType: string,
  width: number,
  height: number,
  env: AiEnvBindings,
): Promise<{ bytes: Uint8Array; contentType: string } | null> {
  if (!isNonEmptyString(env.BROWSER_RENDERING_ACCOUNT_ID) || !isNonEmptyString(env.BROWSER_RENDERING_API_TOKEN)) {
    return null;
  }
  try {
    const endpoint =
      `https://api.cloudflare.com/client/v4/accounts/${env.BROWSER_RENDERING_ACCOUNT_ID}/browser-rendering/screenshot`;
    const imageDataUrl = `data:${contentType};base64,${toBase64(imageBytes)}`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.BROWSER_RENDERING_API_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        html: renderAiWatermarkHtml(imageDataUrl, width, height),
        gotoOptions: {
          waitUntil: 'load',
          timeout: 25000,
        },
        viewport: {
          width,
          height,
        },
        screenshotOptions: {
          type: 'png',
        },
      }),
    });
    if (!response.ok) {
      console.warn('[ai] watermark_browser_rendering_failed', {
        status: response.status,
        body: await readErrorDetails(response),
      });
      return null;
    }
    return {
      bytes: new Uint8Array(await response.arrayBuffer()),
      contentType: 'image/png',
    };
  } catch (error) {
    console.warn('[ai] watermark_browser_rendering_failed', { error: `${error ?? ''}` });
    return null;
  }
}

function preferredWatermarkMimeType(contentType: string): string {
  const normalized = contentType.trim().toLowerCase();
  if (normalized === 'image/png') {
    return 'image/png';
  }
  if (normalized === 'image/webp') {
    return 'image/webp';
  }
  if (normalized === 'image/jpeg' || normalized === 'image/jpg') {
    return 'image/jpeg';
  }
  return 'image/png';
}

function drawPrismWatermarkBadge(
  ctx: {
    font: string;
    fillStyle: string;
    shadowColor: string;
    shadowBlur: number;
    shadowOffsetX: number;
    shadowOffsetY: number;
    textBaseline: string;
    beginPath: () => void;
    moveTo: (x: number, y: number) => void;
    lineTo: (x: number, y: number) => void;
    quadraticCurveTo: (cpx: number, cpy: number, x: number, y: number) => void;
    closePath: () => void;
    fill: () => void;
    fillText: (text: string, x: number, y: number) => void;
    measureText: (text: string) => { width: number };
  },
  width: number,
  height: number,
): void {
  const label = 'Made with Prism AI';
  const minEdge = Math.min(width, height);
  const paddingY = Math.max(8, Math.round(minEdge * 0.012));
  const paddingX = Math.max(12, Math.round(minEdge * 0.018));
  const margin = Math.max(10, Math.round(minEdge * 0.018));
  const fontSize = Math.max(14, Math.round(minEdge * 0.032));
  const radius = Math.max(8, Math.round(minEdge * 0.018));
  ctx.font = `700 ${fontSize}px system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif`;
  const textWidth = Math.ceil(ctx.measureText(label).width);
  const badgeWidth = textWidth + paddingX * 2;
  const badgeHeight = fontSize + paddingY * 2;
  const x = width - badgeWidth - margin;
  const y = height - badgeHeight - margin;
  drawRoundedRect(ctx, x, y, badgeWidth, badgeHeight, radius);
  ctx.fillStyle = 'rgba(9, 12, 18, 0.52)';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.38)';
  ctx.shadowBlur = Math.max(8, Math.round(minEdge * 0.02));
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = Math.max(2, Math.round(minEdge * 0.004));
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 0;
  ctx.shadowColor = 'transparent';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.92)';
  ctx.textBaseline = 'top';
  ctx.fillText(label, x + paddingX, y + paddingY);
}

function drawRoundedRect(
  ctx: {
    beginPath: () => void;
    moveTo: (x: number, y: number) => void;
    lineTo: (x: number, y: number) => void;
    quadraticCurveTo: (cpx: number, cpy: number, x: number, y: number) => void;
    closePath: () => void;
  },
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
): void {
  const r = Math.max(0, Math.min(radius, Math.min(width, height) / 2));
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + width - r, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + r);
  ctx.lineTo(x + width, y + height - r);
  ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  ctx.lineTo(x + r, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function renderAiWatermarkHtml(imageDataUrl: string, width: number, height: number): string {
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * { box-sizing: border-box; }
  html, body { margin: 0; width: ${width}px; height: ${height}px; overflow: hidden; background: #000; }
  body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; }
</style>
</head>
<body>
  <img src="${imageDataUrl}" alt="wallpaper" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;" />
  <div style="position:absolute;right:${Math.max(10, Math.round(Math.min(width, height) * 0.018))}px;bottom:${Math.max(10, Math.round(Math.min(width, height) * 0.018))}px;padding:${Math.max(8, Math.round(Math.min(width, height) * 0.012))}px ${Math.max(12, Math.round(Math.min(width, height) * 0.018))}px;border-radius:${Math.max(8, Math.round(Math.min(width, height) * 0.018))}px;background:rgba(9,12,18,.52);color:rgba(255,255,255,.92);font-size:${Math.max(14, Math.round(Math.min(width, height) * 0.032))}px;font-weight:700;line-height:1;letter-spacing:.1px;box-shadow:0 6px 18px rgba(0,0,0,.38);">
    Made with Prism AI
  </div>
</body>
</html>`;
}

async function saveGenerationRecord(record: AiGenerationRecord, env: AiEnvBindings): Promise<void> {
  await env.AI_STATE_KV.put(`ai:gen:${record.generationId}`, JSON.stringify(record), {
    expirationTtl: 60 * 60 * 24 * 90,
  });
}

async function readGenerationRecord(generationId: string, env: AiEnvBindings): Promise<AiGenerationRecord | null> {
  const raw = await env.AI_STATE_KV.get(`ai:gen:${generationId}`);
  if (!isNonEmptyString(raw)) {
    return null;
  }
  try {
    return JSON.parse(raw) as AiGenerationRecord;
  } catch {
    return null;
  }
}

function isPromptSafe(prompt: string): boolean {
  return !BLOCKED_PROMPT_REGEX.test(prompt);
}

function isOutputSafe(imageBytes: Uint8Array, contentType: string): boolean {
  if (!contentType.startsWith('image/')) {
    return false;
  }
  return imageBytes.length >= 1024;
}

function buildTitleFromPrompt(prompt: string, stylePreset: string): string {
  const clean = sanitizeText(prompt).replace(/[^\w\s-]/g, '').trim();
  const first = clean.split(' ').slice(0, 8).join(' ');
  return clipText(`${toTitleCase(first)} (${toTitleCase(stylePreset)})`, 60);
}

function deriveTagsFromPrompt(prompt: string, stylePreset: string): string[] {
  const words = sanitizeText(prompt)
    .toLowerCase()
    .split(' ')
    .map((word) => word.replace(/[^a-z0-9-]/g, '').trim())
    .filter((word) => word.length >= 3);
  const unique = Array.from(new Set<string>([stylePreset.toLowerCase(), ...words]));
  return unique.slice(0, 12);
}

function classifyCategory(stylePreset: string, tags: string[]): string {
  const style = stylePreset.toLowerCase();
  if (style.includes('nature') || tags.includes('nature')) {
    return 'Nature';
  }
  if (style.includes('anime')) {
    return 'Anime';
  }
  if (style.includes('cyber')) {
    return 'Technology';
  }
  return 'General';
}

class FalProviderAdapter implements AiProviderAdapter {
  public readonly providerName: AiProviderName = 'fal';

  public async generate(params: {
    prompt: string;
    qualityTier: AiQualityTier;
    model: string;
    estimatedCostUsd: number;
    targetSize: string;
    seed: number;
    stylePreset: string;
    timeoutMs: number;
    env: AiEnvBindings;
    onProviderBilled: () => Promise<void>;
  }): Promise<AiProviderResult> {
    if (!isNonEmptyString(params.env.FAL_API_KEY)) {
      throw new Error('FAL_API_KEY missing');
    }
    const endpoint = `https://fal.run/${params.model}`;
    const { width: rawWidth, height: rawHeight } = parseSize(params.targetSize);
    const isSeedream = params.model.includes('seedream');
    // Seedream requires dimensions between 1920–4096; scale up if below minimum.
    const SEEDREAM_MIN = 1920;
    const width = isSeedream ? Math.max(rawWidth, SEEDREAM_MIN) : rawWidth;
    const height = isSeedream ? Math.max(rawHeight, SEEDREAM_MIN) : rawHeight;
    const requestBody = {
      prompt: `${params.prompt}, ${params.stylePreset} style`,
      image_size: { width, height },
      seed: params.seed,
    };
    const response = await fetchWithTimeout(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Key ${params.env.FAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    }, params.timeoutMs);

    if (!response.ok) {
      const details = await readErrorDetails(response);
      throw new Error(`fal_failed_${response.status}${details}`);
    }
    await params.onProviderBilled();
    const payload = await response.json() as {
      images?: Array<{ url?: string }>;
      image?: { url?: string };
    };
    const imageUrl = payload.images?.[0]?.url ?? payload.image?.url;
    if (!isNonEmptyString(imageUrl)) {
      throw new Error('fal_missing_image');
    }
    const imageResponse = await fetchWithTimeout(imageUrl, { method: 'GET' }, params.timeoutMs);
    if (!imageResponse.ok) {
      throw new Error(`fal_image_fetch_${imageResponse.status}`);
    }
    const contentType = imageResponse.headers.get('content-type') ?? 'image/png';
    const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
    return {
      model: params.model,
      seed: params.seed,
      width,
      height,
      contentType,
      imageBytes,
      estimatedCostUsd: params.estimatedCostUsd,
    };
  }
}

class GeminiProviderAdapter implements AiProviderAdapter {
  public readonly providerName: AiProviderName = 'gemini';

  public async generate(params: {
    prompt: string;
    qualityTier: AiQualityTier;
    model: string;
    estimatedCostUsd: number;
    targetSize: string;
    seed: number;
    stylePreset: string;
    timeoutMs: number;
    env: AiEnvBindings;
    onProviderBilled: () => Promise<void>;
  }): Promise<AiProviderResult> {
    if (!isNonEmptyString(params.env.GEMINI_API_KEY)) {
      throw new Error('GEMINI_API_KEY missing');
    }
    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${params.model}:generateContent`;
    const { width, height } = parseSize(params.targetSize);
    const response = await fetchWithTimeout(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': params.env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: `${params.prompt}, ${params.stylePreset} style` }],
        }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
        },
      }),
    }, params.timeoutMs);

    if (!response.ok) {
      const details = await readErrorDetails(response);
      throw new Error(`gemini_failed_${response.status}${details}`);
    }
    await params.onProviderBilled();
    const payload = await response.json() as {
      candidates?: Array<{
        content?: {
          parts?: Array<{
            inlineData?: {
              data?: string;
              mimeType?: string;
            };
          }>;
        };
      }>;
    };
    const parts = payload.candidates?.[0]?.content?.parts ?? [];
    const imagePart = parts.find((part) => isNonEmptyString(part.inlineData?.data));
    const encoded = imagePart?.inlineData?.data ?? '';
    if (!isNonEmptyString(encoded)) {
      throw new Error('gemini_missing_image');
    }
    const imageBytes = fromBase64(encoded);
    return {
      model: params.model,
      seed: params.seed,
      width,
      height,
      contentType: imagePart?.inlineData?.mimeType ?? 'image/png',
      imageBytes,
      estimatedCostUsd: params.estimatedCostUsd,
    };
  }
}

function parseSize(raw: string): { width: number; height: number } {
  const match = /^(\d+)x(\d+)$/.exec(raw);
  if (match == null) {
    return { width: 1080, height: 1920 };
  }
  return {
    width: Number.parseInt(match[1], 10),
    height: Number.parseInt(match[2], 10),
  };
}

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => {
    controller.abort('timeout');
  }, timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}

function isTimeoutError(error: unknown): boolean {
  const message = `${error ?? ''}`.toLowerCase();
  return message.includes('timeout') || message.includes('aborted');
}

async function readErrorDetails(response: Response): Promise<string> {
  try {
    const text = await response.text();
    if (!isNonEmptyString(text)) {
      return '';
    }
    return `: ${clipText(text.replace(/\s+/g, ' ').trim(), 280)}`;
  } catch {
    return '';
  }
}

function randomSeed(): number {
  return randomInt(1, 2147483646);
}

function randomInt(min: number, max: number): number {
  const upper = Math.max(min, max);
  const lower = Math.min(min, max);
  const range = upper - lower + 1;
  const bytes = crypto.getRandomValues(new Uint32Array(1));
  return lower + (bytes[0] % range);
}

function utcDayKey(): string {
  const now = new Date();
  const month = `${now.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${now.getUTCDate()}`.padStart(2, '0');
  return `${now.getUTCFullYear()}-${month}-${day}`;
}

function utcMonthKey(): string {
  const now = new Date();
  const month = `${now.getUTCMonth() + 1}`.padStart(2, '0');
  return `${now.getUTCFullYear()}-${month}`;
}

function parseNumber(raw: string | null): number {
  if (!isNonEmptyString(raw)) {
    return 0;
  }
  const parsed = Number.parseFloat(raw);
  return Number.isFinite(parsed) ? parsed : 0;
}

function roundFloat(value: number, precision: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Number(value.toFixed(precision));
}

function clipText(value: string, max: number): string {
  if (value.length <= max) {
    return value;
  }
  return value.substring(0, max);
}

function sanitizeText(value: string): string {
  return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function toTitleCase(input: string): string {
  return input
    .split(' ')
    .filter((value) => value.length > 0)
    .map((value) => `${value[0].toUpperCase()}${value.substring(1).toLowerCase()}`)
    .join(' ');
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(max, Math.max(min, value));
}

function createId(prefix: string): string {
  const random = crypto.getRandomValues(new Uint8Array(8));
  let out = '';
  for (const item of random) {
    out += item.toString(16).padStart(2, '0');
  }
  return `${prefix}_${Date.now().toString(36)}_${out}`;
}

function toBase64(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.length; i += 1) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function readJson<T>(request: Request | Response): Promise<T | null> {
  try {
    return await request.json() as T;
  } catch {
    return null;
  }
}

function quotaJson<T extends AiQuotaRpcResponse>(payload: T, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function aiError(code: AiErrorCode, status: number, message: string): Response {
  return aiJson({ error: code, message }, status);
}

function aiJson(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}
