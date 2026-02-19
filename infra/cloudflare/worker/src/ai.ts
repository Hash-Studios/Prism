import { verifyFirebaseIdTokenFromRequest } from './firebase_auth';

export interface AiEnvBindings {
  AI_STATE_KV: KVNamespace;
  AI_IMAGES?: R2Bucket;
  FAL_API_KEY?: string;
  GEMINI_API_KEY?: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_AUTH_DEBUG?: string;
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
  | 'service_disabled';
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
}

interface AiVariationRequest {
  variationPrompt?: string;
  strength?: number;
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
  fallbackOrder: ['fal', 'gemini'],
  providers: {
    fal: {
      enabled: true,
      weight: 60,
      modelByQuality: {
        fast: 'fal-ai/flux/schnell',
        balanced: 'fal-ai/flux/schnell',
        quality: 'fal-ai/flux/dev',
      },
      estimatedCostByQualityUsd: { fast: 0.01, balanced: 0.03, quality: 0.06 },
      dailyBudgetUsd: 30,
      monthlyBudgetUsd: 600,
      timeoutMs: 25000,
    },
    gemini: {
      enabled: true,
      weight: 40,
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

export async function handleAiApiRequest(
  request: Request,
  url: URL,
  env: AiEnvBindings,
): Promise<Response | null> {
  if (!url.pathname.startsWith('/api/ai')) {
    return null;
  }

  if (request.method === 'GET' && url.pathname === '/api/ai/health') {
    return handleAiHealth(env);
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
    const object = await env.AI_IMAGES.get(objectKey);
    if (object == null) {
      return aiError('generation_not_found', 404, 'Asset not found');
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

  const encoded = await env.AI_STATE_KV.get(`ai:asset:${objectKey}`);
  if (!isNonEmptyString(encoded)) {
    return aiError('generation_not_found', 404, 'Asset not found');
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

async function handleAiHealth(env: AiEnvBindings): Promise<Response> {
  const config = await readRoutingConfig(env);
  const snapshots = await readProviderBudgetSnapshots(config, 'balanced', env);
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

async function executeGeneration(params: {
  env: AiEnvBindings;
  auth: AuthContext;
  prompt: string;
  stylePreset: string;
  qualityTier: AiQualityTier;
  targetSize: string;
  seed: number;
  parentGenerationId?: string;
}): Promise<Response> {
  const config = await readRoutingConfig(params.env);
  if (!config.enabled) {
    return aiError('service_disabled', 503, 'AI generation is disabled');
  }

  const dailyCapStatus = await checkAndIncrementUserDailyCap(params.auth.userId, config.hardUserDailyCap, params.env);
  if (!dailyCapStatus.allowed) {
    return aiError('rate_limited', 429, 'User daily generation limit reached');
  }

  const routingPlan = await buildProviderAttemptOrder(config, params.qualityTier, params.env);
  if (routingPlan.order.length === 0) {
    return aiError('service_disabled', 503, 'No AI providers are enabled');
  }
  const effectiveQualityTier = routingPlan.effectiveQualityTier;
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
    const budgetCheck = await canSpendForProvider(providerName, estimatedCost, providerConfig, params.env);
    if (!budgetCheck.allowed) {
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

    const adapter = providerName === 'fal' ? new FalProviderAdapter() : new GeminiProviderAdapter();
    const model = providerConfig.modelByQuality[effectiveQualityTier];
    const startedAt = Date.now();
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
      });

      if (!isOutputSafe(result.imageBytes, result.contentType)) {
        lastErrorCode = 'unsafe_output';
        lastErrorMessage = `Output blocked by safety policy (${providerName})`;
        console.warn('[ai] unsafe_output_block', {
          provider: providerName,
          model: result.model,
          contentType: result.contentType,
        });
        continue;
      }

      const generationId = createId('gen');
      const persisted = await persistGenerationArtifacts(generationId, result.imageBytes, result.contentType, params.env);
      const latencyMs = Date.now() - startedAt;
      const billedCost = result.estimatedCostUsd > 0 ? result.estimatedCostUsd : estimatedCost;

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
        estimatedCostUsd: billedCost,
        latencyMs,
      };

      await saveGenerationRecord(record, params.env);
      await spendProviderBudget(providerName, billedCost, params.env);

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
  const dayKey = dailyBudgetKey(provider);
  const monthKey = monthlyBudgetKey(provider);
  const [dailyRaw, monthlyRaw] = await Promise.all([env.AI_STATE_KV.get(dayKey), env.AI_STATE_KV.get(monthKey)]);
  return {
    dailySpentUsd: parseNumber(dailyRaw),
    monthlySpentUsd: parseNumber(monthlyRaw),
  };
}

async function canSpendForProvider(
  provider: AiProviderName,
  estimatedCostUsd: number,
  config: AiRoutingProviderConfig,
  env: AiEnvBindings,
): Promise<{ allowed: boolean; status: BudgetStatus }> {
  const status = await readBudgetStatus(provider, env);
  const allowed = (status.dailySpentUsd + estimatedCostUsd <= config.dailyBudgetUsd) &&
    (status.monthlySpentUsd + estimatedCostUsd <= config.monthlyBudgetUsd);
  return { allowed, status };
}

async function spendProviderBudget(provider: AiProviderName, costUsd: number, env: AiEnvBindings): Promise<void> {
  const dayKey = dailyBudgetKey(provider);
  const monthKey = monthlyBudgetKey(provider);
  await bumpFloatCounter(env.AI_STATE_KV, dayKey, costUsd, secondsUntilNextUtcDay());
  await bumpFloatCounter(env.AI_STATE_KV, monthKey, costUsd, secondsUntilNextUtcMonth());
}

function dailyBudgetKey(provider: AiProviderName): string {
  return `ai:budget:${provider}:daily:${utcDayKey()}`;
}

function monthlyBudgetKey(provider: AiProviderName): string {
  return `ai:budget:${provider}:monthly:${utcMonthKey()}`;
}

async function checkAndIncrementUserDailyCap(
  userId: string,
  cap: number,
  env: AiEnvBindings,
): Promise<{ allowed: boolean; current: number }> {
  const key = `ai:user:${userId}:daily:${utcDayKey()}`;
  const raw = await env.AI_STATE_KV.get(key);
  const current = Number.parseInt(raw ?? '0', 10);
  if (current >= cap) {
    return { allowed: false, current };
  }
  await env.AI_STATE_KV.put(key, String(current + 1), { expirationTtl: secondsUntilNextUtcDay() });
  return { allowed: true, current: current + 1 };
}

async function persistGenerationArtifacts(
  generationId: string,
  imageBytes: Uint8Array,
  contentType: string,
  env: AiEnvBindings,
): Promise<{ imageUrl: string; watermarkedImageUrl: string }> {
  const originalKey = `ai/original/${generationId}.png`;
  const publicKey = `ai/public/${generationId}.png`;
  const cacheControl = 'public, max-age=31536000, immutable';
  const watermarkedBytes = await renderPublicWatermarkedBytes(imageBytes, contentType);
  if (watermarkedBytes.length < 1024) {
    throw new Error('watermark_generation_failed');
  }

  if (env.AI_IMAGES != null) {
    await env.AI_IMAGES.put(originalKey, imageBytes, {
      httpMetadata: {
        contentType,
        cacheControl,
      },
    });
    await env.AI_IMAGES.put(publicKey, watermarkedBytes, {
      httpMetadata: {
        contentType,
        cacheControl,
      },
    });
    return {
      imageUrl: `https://prismwalls.com/api/ai/assets/${originalKey}`,
      watermarkedImageUrl: `https://prismwalls.com/api/ai/assets/${publicKey}`,
    };
  }

  await env.AI_STATE_KV.put(`ai:asset:${originalKey}`, toBase64(imageBytes), { expirationTtl: 60 * 60 * 24 * 30 });
  await env.AI_STATE_KV.put(`ai:asset:${publicKey}`, toBase64(watermarkedBytes), { expirationTtl: 60 * 60 * 24 * 30 });
  return {
    imageUrl: `https://prismwalls.com/api/ai/assets/${originalKey}`,
    watermarkedImageUrl: `https://prismwalls.com/api/ai/assets/${publicKey}`,
  };
}

async function renderPublicWatermarkedBytes(imageBytes: Uint8Array, contentType: string): Promise<Uint8Array> {
  if (!contentType.startsWith('image/')) {
    throw new Error('watermark_invalid_content_type');
  }
  // Placeholder serving-layer watermark hook: keep a separate public artifact path.
  // This can be upgraded to true raster compositing without changing API contracts.
  return imageBytes;
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
  const normalized = prompt.toLowerCase();
  for (const token of BLOCKED_PROMPT_TERMS) {
    if (normalized.includes(token)) {
      return false;
    }
  }
  return true;
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
  }): Promise<AiProviderResult> {
    if (!isNonEmptyString(params.env.FAL_API_KEY)) {
      throw new Error('FAL_API_KEY missing');
    }
    const endpoint = `https://fal.run/${params.model}`;
    const { width, height } = parseSize(params.targetSize);
    const response = await fetchWithTimeout(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Key ${params.env.FAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt: `${params.prompt}, ${params.stylePreset} style`,
        image_size: `${width}x${height}`,
        seed: params.seed,
      }),
    }, params.timeoutMs);

    if (!response.ok) {
      const details = await readErrorDetails(response);
      throw new Error(`fal_failed_${response.status}${details}`);
    }
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

function secondsUntilNextUtcDay(): number {
  const now = new Date();
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1, 0, 0, 0, 0);
  return Math.max(1, Math.floor((next - now.getTime()) / 1000));
}

function secondsUntilNextUtcMonth(): number {
  const now = new Date();
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1, 0, 0, 0, 0);
  return Math.max(1, Math.floor((next - now.getTime()) / 1000));
}

async function bumpFloatCounter(kv: KVNamespace, key: string, delta: number, ttlSeconds: number): Promise<void> {
  const existing = parseNumber(await kv.get(key));
  const next = existing + delta;
  await kv.put(key, next.toFixed(6), { expirationTtl: ttlSeconds });
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

async function readJson<T>(request: Request): Promise<T | null> {
  try {
    return await request.json() as T;
  } catch {
    return null;
  }
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
