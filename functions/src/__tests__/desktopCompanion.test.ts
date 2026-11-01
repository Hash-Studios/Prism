import assert from "node:assert/strict";
import * as admin from "firebase-admin";
import test, {type TestContext} from "node:test";
import sharp from "sharp";
import {STUDIO_ACCOUNT} from "../studio/account";
import type {VisionResult} from "../studio/gates";
import {
  DESKTOP_COMPOSITION, type DesktopDeps, desktopCostUsd, desktopEligibility, desktopPrompt, makeDesktopCompanion,
  onStudioWallDesktop, parseDesktopVariant, removeDesktopCompanion, renderDesktop,
} from "../studio/desktop";
import {STUDIO_COMPOSITION, STUDIO_DEPTH_COMPOSITION} from "../studio/series";
import {R2Storage} from "../r2Storage";
import {buildPages, projectWall, type WebDesktopCard, type WebWall, webCatalogDeps} from "../webCatalog";
import {resolveOriginalAccess} from "../originalAccess";
import {type Doc, installFakeDb} from "./fakeDb";

const PREVIEW = "https://images.example.com";
const MODEL = "openai/gpt-image-2.5/sunburst/text-to-image";
const VERSION = "0123456789abcdef";
const SCENE_PROMPT = "a lighthouse, ember light. Calm style.";
const DESKTOP_PROMPT = `${SCENE_PROMPT} ${DESKTOP_COMPOSITION} The image contains no text, no letters, no numbers, ` +
  "no signature, no watermark, no logo and no people.";
const BLUR = "data:image/jpeg;base64,AAAA";
const NOW = new Date("2026-11-01T00:00:00.000Z");

function setEnv(t: TestContext) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: PREVIEW});
}

const desktopThumb = (sha = "cd".repeat(32)) => `${PREVIEW}/previews/desktop-${sha}.jpg`;
const variant = (thumb = desktopThumb()) => ({v: VERSION, width: 2560, height: 1600, wideHeight: 1440, thumb});

const studioWall = (extra: Doc = {}): Doc => ({
  id: "WALL1", review: true, origin: "studio", email: STUDIO_ACCOUNT.email, studioRunId: "run1",
  studioCandidateId: "cand0001", aiModel: MODEL, aiPrompt: `${SCENE_PROMPT} ${STUDIO_COMPOSITION}`, tags: [], ...extra,
});

async function metadataOf(bytes: Buffer) {
  const meta = await sharp(bytes).metadata();
  return {format: meta.format, width: meta.width, height: meta.height};
}

test("desktopPrompt swaps the phone composition for the desktop one and keeps the scene and style", () => {
  const prompt = desktopPrompt(`a lighthouse, ember light. Calm style. ${STUDIO_COMPOSITION}`);
  assert.equal(prompt, DESKTOP_PROMPT);
  assert.equal(prompt?.includes("Vertical phone"), false);
});

test("desktopPrompt keeps the depth exclusions and drops the depth percentages", () => {
  const depth = `${SCENE_PROMPT} ${STUDIO_DEPTH_COMPOSITION}`;
  const prompt = desktopPrompt(depth);
  assert.ok(prompt?.endsWith(
    "The image contains no text, no letters, no numbers, no signature, no watermark and no logo."));
  assert.equal(prompt?.includes("24%"), false);
  assert.equal(prompt?.includes("Vertical phone"), false);
});

test("desktopPrompt returns null without a known composition or without a scene", () => {
  assert.equal(desktopPrompt("a cat"), null);
  assert.equal(desktopPrompt(STUDIO_COMPOSITION), null);
});

test("desktopEligibility gives each skip reason, and the prompt and model when eligible", (t) => {
  setEnv(t);
  const base = studioWall();
  assert.deepEqual(desktopEligibility(undefined), {skip: "not_approved"});
  assert.deepEqual(desktopEligibility({...base, review: false}), {skip: "not_approved"});
  assert.deepEqual(desktopEligibility({...base, origin: "user"}), {skip: "not_studio"});
  assert.deepEqual(desktopEligibility({...base, tags: ["duo"]}), {skip: "duo"});
  assert.deepEqual(desktopEligibility({...base, aiModel: "unknown/model"}), {skip: "model"});
  assert.deepEqual(desktopEligibility({...base, aiPrompt: "a cat"}), {skip: "prompt"});
  assert.deepEqual(desktopEligibility({...base, desktopVariant: variant()}), {skip: "exists"});
  assert.deepEqual(desktopEligibility(base), {prompt: DESKTOP_PROMPT, model: MODEL});
});

test("desktopCostUsd adds the Vision check to the model cost", () => {
  assert.equal(desktopCostUsd("openai/gpt-image-2.5/sunburst/text-to-image"), 0.0745);
  assert.equal(desktopCostUsd("fal-ai/bytedance/seedream/v4.5/text-to-image"), 0.0445);
});

test("renderDesktop makes a 16:10 original, a 16:9 crop and a thumbnail, all JPEG", async () => {
  const bytes = await sharp({create: {width: 2600, height: 1700, channels: 3, background: "navy"}}).png().toBuffer();
  const out = await renderDesktop(bytes);
  assert.deepEqual(await metadataOf(out.original), {format: "jpeg", width: 2560, height: 1600});
  assert.deepEqual(await metadataOf(out.wide), {format: "jpeg", width: 2560, height: 1440});
  assert.deepEqual(await metadataOf(out.thumb), {format: "jpeg", width: 960, height: 600});
});

test("renderDesktop refuses an output smaller than 2560x1600", async () => {
  const small = await sharp({create: {width: 2000, height: 1250, channels: 3, background: "navy"}}).png().toBuffer();
  await assert.rejects(renderDesktop(small), {code: "desktop_size"});
});

const GEN_URL = "https://worker.test/api/ai/studio/generations";
const RAW_KEY = "ai/studio/raw/desk.png";
const STUDIO_ASSET_URL = `https://worker.test/api/ai/studio/assets/${RAW_KEY}`;
const ASSET_URL = `https://worker.test/api/ai/studio/assets/${RAW_KEY}`;
const GENERATED = {imageUrl: `https://worker.test/api/ai/assets/${RAW_KEY}`, key: RAW_KEY, width: 2560, height: 1600,
  model: MODEL, provider: "fal"};
const CLEAN: VisionResult = {
  safeSearchAnnotation: {adult: "VERY_UNLIKELY", racy: "VERY_UNLIKELY", violence: "VERY_UNLIKELY",
    medical: "VERY_UNLIKELY"},
  textAnnotations: [],
  logoAnnotations: [],
};

async function setupCompanion(t: TestContext, opts: {
  wall?: Doc;
  candidate?: Doc;
  generate?: () => Response | Promise<Response>;
  vision?: VisionResult;
  put?: (kind: "private" | "preview", object: string, body: Buffer, metadata: Record<string, string>,
    contentType: string) => Promise<boolean>;
  head?: (kind: "private" | "preview", object: string) => Promise<Awaited<ReturnType<R2Storage["head"]>>>;
} = {}) {
  setEnv(t);
  const store = installFakeDb(t, {
    "walls/WALL1": studioWall(opts.wall),
    "studioRuns/run1/candidates/cand0001": opts.candidate ?? {wallId: "WALL1", seed: 7},
  });
  const put = t.mock.method(R2Storage.prototype, "put", opts.put ?? (async () => true));
  t.mock.method(R2Storage.prototype, "head", opts.head ?? (async () => null));
  const remove = t.mock.method(R2Storage.prototype, "delete", async () => undefined);
  const png = await sharp({create: {width: 2560, height: 1600, channels: 3, background: "teal"}}).png().toBuffer();
  const calls: Array<{method: string; url: string; body: Record<string, unknown> | undefined;
    headers: Record<string, string>}> = [];
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit = {}) => {
    const url = String(rawUrl);
    const method = init.method ?? "GET";
    const body = typeof init.body === "string" ? JSON.parse(init.body) as Record<string, unknown> : undefined;
    const headers = init.headers as Record<string, string> | undefined;
    calls.push({method, url, body, headers: headers ?? {}});
    if (method === "POST" && url === GEN_URL) return opts.generate?.() ?? Response.json(GENERATED);
    if (method === "GET" && url === STUDIO_ASSET_URL && headers?.["x-studio-secret"] === "s") {
      return new Response(new Uint8Array(png));
    }
    if (method === "DELETE" && url === ASSET_URL) return Response.json({deleted: true});
    throw new Error(`unexpected fetch ${method} ${url}`);
  });
  const deps: DesktopDeps = {
    worker: {base: "https://worker.test", secret: "s"},
    annotate: async () => opts.vision ?? CLEAN,
    nowMs: () => Date.now(),
  };
  return {store, put, remove, calls, deps};
}

test("makeDesktopCompanion makes a ready companion for an approved Studio wall, and skips it the second time",
  async (t) => {
    const {store, put, remove, calls, deps} = await setupCompanion(t);

    assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "ready");

    const generation = calls.find((call) => call.method === "POST" && call.url === GEN_URL)?.body;
    assert.equal(generation?.width, 2560);
    assert.equal(generation?.height, 1600);
    assert.equal(generation?.seed, 7);
    assert.equal(generation?.model, MODEL);
    assert.equal(generation?.prompt, DESKTOP_PROMPT);
    assert.match(String(generation?.id), /^desk_[a-f0-9]{48}$/);

    const wall = store.get("walls/WALL1")?.desktopVariant as Doc;
    assert.equal(wall.width, 2560);
    assert.equal(wall.height, 1600);
    assert.equal(wall.wideHeight, 1440);
    assert.match(String(wall.v), /^[a-f0-9]{16}$/);
    assert.ok(String(wall.thumb).startsWith(`${PREVIEW}/previews/desktop-`));

    const manifest = store.get("desktopCompanions/WALL1");
    assert.equal(manifest?.status, "ready");
    assert.equal(manifest?.costUsd, 0.0745);
    assert.equal((manifest?.original as Doc).width, 2560);
    assert.equal((manifest?.wide as Doc).height, 1440);

    assert.deepEqual(put.mock.calls.map((call) => call.arguments[0]), ["private", "private", "preview"]);
    const objects = put.mock.calls.map((call) => String(call.arguments[1]));
    assert.ok(objects[0].startsWith("desktop-originals/WALL1/"));
    assert.ok(objects[1].startsWith("desktop-originals/WALL1/"));
    assert.match(objects[2], /^previews\/desktop-[a-f0-9]{64}\.jpg$/);

    assert.equal(remove.mock.callCount(), 0);
    assert.ok(calls.some((call) => call.method === "GET" && call.url === STUDIO_ASSET_URL));
    assert.ok(calls.some((call) => call.method === "GET" && call.url === STUDIO_ASSET_URL &&
      call.headers["x-studio-secret"] === "s"));
    assert.deepEqual(calls.filter((call) => call.method === "DELETE").map((call) => call.url), [ASSET_URL]);

    const before = calls.length;
    assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "skipped");
    assert.equal(calls.length, before);
  });

test("makeDesktopCompanion rejects a companion that Vision reads text in, and links nothing", async (t) => {
  const {store, deps} = await setupCompanion(t, {
    vision: {...CLEAN, textAnnotations: [{description: "whole"}, {description: "HELLO"}]},
  });

  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "rejected");

  const manifest = store.get("desktopCompanions/WALL1");
  assert.equal(manifest?.status, "rejected");
  assert.deepEqual(manifest?.reasons, ["text"]);
  assert.equal(store.get("walls/WALL1")?.desktopVariant, undefined);
});

test("identical thumbnail pixels on different walls have independently deletable objects", async (t) => {
  const h = await setupCompanion(t);
  h.store.set("walls/WALL2", studioWall({id: "WALL2", studioCandidateId: "cand0002"}));
  h.store.set("studioRuns/run1/candidates/cand0002", {wallId: "WALL2", seed: 7});
  assert.equal(await makeDesktopCompanion("walls/WALL1", h.deps), "ready");
  assert.equal(await makeDesktopCompanion("walls/WALL2", h.deps), "ready");
  const first = h.store.get("desktopCompanions/WALL1")?.thumb as Doc;
  const second = h.store.get("desktopCompanions/WALL2")?.thumb as Doc;

  assert.equal(first.sha256, second.sha256);
  assert.notEqual(first.object, second.object);
  await removeDesktopCompanion("WALL1", h.deps);
  assert.equal(h.remove.mock.calls.some((call) => call.arguments[1] === second.object), false);
  assert.equal(h.store.get("desktopCompanions/WALL2")?.status, "ready");
});

test("makeDesktopCompanion defers, without using an attempt, when the Studio budget is used up", async (t) => {
  const {store, calls, deps} = await setupCompanion(t, {
    generate: () => Response.json({error: "budget_exhausted"}, {status: 429}),
  });

  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "deferred");

  const manifest = store.get("desktopCompanions/WALL1");
  assert.equal(manifest?.status, "deferred");
  assert.equal(manifest?.attempts, 0);
  assert.equal(store.get("walls/WALL1")?.desktopVariant, undefined);
  assert.equal(calls.filter((call) => call.method === "DELETE").length, 0);
});

test("makeDesktopCompanion reuses its Worker generation id after a transient retry", async (t) => {
  let calls = 0;
  const {store, calls: requests, deps} = await setupCompanion(t, {
    generate: () => ++calls === 1 ? Response.json({error: "provider_error"}, {status: 502}) : Response.json(GENERATED),
  });

  await assert.rejects(makeDesktopCompanion("walls/WALL1", deps));
  assert.equal(store.get("desktopCompanions/WALL1")?.status, "queued");
  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "ready");

  const ids = requests.filter((call) => call.method === "POST" && call.url === GEN_URL)
    .map((call) => call.body?.id);
  assert.equal(ids.length, 2);
  assert.equal(ids[0], ids[1]);
});

test("makeDesktopCompanion keeps the Worker source through a retryable R2 failure", async (t) => {
  let puts = 0;
  const {store, calls, deps} = await setupCompanion(t, {
    put: async () => {
      puts++;
      if (puts === 1) throw new Error("R2 unavailable");
      return true;
    },
  });

  await assert.rejects(makeDesktopCompanion("walls/WALL1", deps), /R2 unavailable/);
  assert.equal(store.get("desktopCompanions/WALL1")?.status, "queued");
  assert.equal(store.get("desktopCompanions/WALL1")?.workerKey, RAW_KEY);
  assert.equal(calls.filter((call) => call.method === "DELETE").length, 0);
  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "ready");
  assert.equal(store.get("desktopCompanions/WALL1")?.workerKey, undefined);

  const ids = calls.filter((call) => call.method === "POST" && call.url === GEN_URL)
    .map((call) => call.body?.id);
  assert.equal(ids[0], ids[1]);
  assert.equal(calls.filter((call) => call.method === "DELETE" && call.url === ASSET_URL).length, 1);
});

test("a losing desktop attempt does not delete R2 objects after another attempt wins", async (t) => {
  const storeRef: {current?: ReturnType<typeof installFakeDb>} = {};
  let puts = 0;
  const stored = new Map<string, {sha256: string; size: number}>();
  const {store, remove, deps} = await setupCompanion(t, {
    put: async (_kind, object, body, metadata) => {
      puts++;
      stored.set(object, {sha256: metadata.sha256, size: body.length});
      if (puts === 3) {
        storeRef.current?.set("desktopCompanions/WALL1", {status: "ready", attempts: 2});
        return false;
      }
      return true;
    },
    head: async (_kind, object) => {
      const asset = stored.get(object);
      return asset ? {...asset, contentType: "image/jpeg", uid: "", objectId: "", repo: "", path: "", gitSha: "",
        uploadId: ""} : null;
    },
  });
  storeRef.current = store;

  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "busy");

  assert.equal(store.get("desktopCompanions/WALL1")?.status, "ready");
  assert.equal(remove.mock.callCount(), 0);
});

test("deletion waits for generation and PUT owners before cleaning their artifacts", async (t) => {
  for (const phase of ["generate", "put"] as const) {
    await t.test(phase, async (subtest) => {
      let resume: () => void = () => undefined;
      let reached: () => void = () => undefined;
      const paused = new Promise<void>((resolve) => {
        reached = resolve;
      });
      const resumed = new Promise<void>((resolve) => {
        resume = resolve;
      });
      let puts = 0;
      const h = await setupCompanion(subtest, {
        generate: async () => {
          if (phase === "generate") {
            reached();
            await resumed;
          }
          return Response.json(GENERATED);
        },
        put: async () => {
          if (phase === "put" && ++puts === 1) {
            reached();
            await resumed;
          }
          return true;
        },
      });
      const making = makeDesktopCompanion("walls/WALL1", h.deps);
      await paused;
      h.store.delete("walls/WALL1");
      try {
        await assert.rejects(removeDesktopCompanion("WALL1", h.deps), /still running/);
        assert.equal(h.remove.mock.callCount(), 0);
        assert.equal(h.calls.filter((call) => call.method === "DELETE").length, 0);
      } finally {
        resume();
      }
      assert.equal(await making, "failed");
      await removeDesktopCompanion("WALL1", h.deps);
      assert.equal(h.store.has("desktopCompanions/WALL1"), false);
      assert.equal(h.remove.mock.callCount(), 3);
      assert.equal(h.calls.filter((call) => call.method === "DELETE").length, 1);
    });
  }
});

test("a changed generation request fails closed without replacing retry artifacts or spending again", async (t) => {
  const h = await setupCompanion(t, {put: async () => {
    throw new Error("R2 unavailable");
  }});
  await assert.rejects(makeDesktopCompanion("walls/WALL1", h.deps), /R2 unavailable/);
  h.store.set("walls/WALL1", studioWall({aiModel: "fal-ai/bytedance/seedream/v4.5/text-to-image"}));

  assert.equal(await makeDesktopCompanion("walls/WALL1", h.deps), "failed");
  assert.equal(h.calls.filter((call) => call.method === "POST").length, 1);
  assert.equal(h.store.get("desktopCompanions/WALL1")?.error, "request_changed");
  assert.equal(h.store.get("desktopCompanions/WALL1")?.workerKey, undefined);
  assert.equal(h.remove.mock.callCount(), 3);
});

test("an ineligible inactive retry cleans pending source and R2 objects without spending again", async (t) => {
  const h = await setupCompanion(t, {put: async () => {
    throw new Error("R2 unavailable");
  }});
  await assert.rejects(makeDesktopCompanion("walls/WALL1", h.deps), /R2 unavailable/);
  h.store.set("walls/WALL1", studioWall({review: false}));

  assert.equal(await makeDesktopCompanion("walls/WALL1", h.deps), "skipped");
  assert.equal(h.store.get("desktopCompanions/WALL1")?.status, "failed");
  assert.equal(h.store.get("desktopCompanions/WALL1")?.workerKey, undefined);
  assert.equal(h.store.get("desktopCompanions/WALL1")?.pendingObjects, undefined);
  assert.equal(h.calls.filter((call) => call.method === "POST").length, 1);
  assert.equal(h.remove.mock.callCount(), 3);
});

test("an expired producer cleans its late raw output instead of uploading after deletion", async (t) => {
  let resume: () => void = () => undefined;
  let reached: () => void = () => undefined;
  const paused = new Promise<void>((resolve) => {
    reached = resolve;
  });
  const resumed = new Promise<void>((resolve) => {
    resume = resolve;
  });
  const h = await setupCompanion(t, {generate: async () => {
    reached();
    await resumed;
    return Response.json(GENERATED);
  }});
  const making = makeDesktopCompanion("walls/WALL1", h.deps);
  await paused;
  h.store.delete("walls/WALL1");
  h.store.set("desktopCompanions/WALL1", {...h.store.get("desktopCompanions/WALL1"),
    claimedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 60_000)});
  await removeDesktopCompanion("WALL1", h.deps);
  resume();

  await assert.rejects(making, /claim was lost/);
  assert.equal(h.store.has("desktopCompanions/WALL1"), false);
  assert.equal(h.put.mock.callCount(), 0);
  assert.equal(h.calls.filter((call) => call.method === "DELETE").length, 1);
});

test("terminal raw cleanup is retried before an already linked wall is skipped", async (t) => {
  const h = await setupCompanion(t);
  const realDelete = globalThis.fetch;
  let deletes = 0;
  t.mock.method(globalThis, "fetch", async (url: string | URL | Request, init: RequestInit = {}) => {
    if (init.method === "DELETE" && ++deletes === 1) return Response.json({}, {status: 503});
    return realDelete(url, init);
  });

  await assert.rejects(makeDesktopCompanion("walls/WALL1", h.deps), /worker 503/);
  assert.equal(h.store.get("desktopCompanions/WALL1")?.status, "ready");
  assert.equal(h.store.get("desktopCompanions/WALL1")?.workerKey, RAW_KEY);
  assert.equal(await makeDesktopCompanion("walls/WALL1", h.deps), "skipped");
  assert.equal(h.store.get("desktopCompanions/WALL1")?.workerKey, undefined);
  assert.equal(h.calls.filter((call) => call.method === "POST").length, 1);
});

test("a wall removed just before claiming cannot start generation", async (t) => {
  const h = await setupCompanion(t);
  h.deps.nowMs = () => {
    h.store.delete("walls/WALL1");
    return Date.now();
  };

  assert.equal(await makeDesktopCompanion("walls/WALL1", h.deps), "skipped");
  assert.equal(h.calls.length, 0);
  assert.equal(h.store.has("desktopCompanions/WALL1"), false);
});

test("terminal pending R2 cleanup retries without generating again", async (t) => {
  const h = await setupCompanion(t);
  h.deps.annotate = async () => {
    h.store.delete("walls/WALL1");
    return CLEAN;
  };
  let deletes = 0;
  t.mock.method(R2Storage.prototype, "delete", async () => {
    if (++deletes === 1) throw new Error("R2 delete unavailable");
  });

  await assert.rejects(makeDesktopCompanion("walls/WALL1", h.deps), /R2 delete unavailable/);
  assert.equal(h.store.get("desktopCompanions/WALL1")?.status, "failed");
  assert.equal((h.store.get("desktopCompanions/WALL1")?.pendingObjects as unknown[]).length, 3);
  await removeDesktopCompanion("WALL1", h.deps);
  assert.equal(h.store.has("desktopCompanions/WALL1"), false);
  assert.equal(deletes, 4);
  assert.equal(h.calls.filter((call) => call.method === "POST").length, 1);
});

test("removeDesktopCompanion keeps its manifest when object cleanup fails, for trigger retry", async (t) => {
  setEnv(t);
  const store = installFakeDb(t, {"desktopCompanions/WALL1": {
    status: "ready", workerKey: RAW_KEY, original: {object: "desktop-originals/WALL1/original.jpg"},
    wide: {object: "desktop-originals/WALL1/wide.jpg"},
    thumb: {object: `previews/desktop-${"cd".repeat(32)}.jpg`},
  }});
  t.mock.method(R2Storage.prototype, "delete", async () => {
    throw new Error("storage unavailable");
  });
  t.mock.method(globalThis, "fetch", async () => Response.json({deleted: true}));

  await assert.rejects(removeDesktopCompanion("WALL1", {worker: {base: "https://worker.test", secret: "s"}}),
    /storage unavailable/);

  assert.equal(store.get("desktopCompanions/WALL1")?.status, "deleting");
});

test("makeDesktopCompanion skips a wall whose candidate points at another wall, without a fetch", async (t) => {
  const {store, calls, deps} = await setupCompanion(t, {candidate: {wallId: "OTHER", seed: 7}});

  assert.equal(await makeDesktopCompanion("walls/WALL1", deps), "skipped");

  assert.equal(calls.length, 0);
  assert.equal(store.get("desktopCompanions/WALL1"), undefined);
});

test("approval trigger retries instead of acknowledging a fresh in-progress claim", async (t) => {
  setEnv(t);
  installFakeDb(t, {
    "walls/WALL1": studioWall(),
    "studioRuns/run1/candidates/cand0001": {wallId: "WALL1", seed: 7},
    "studioConfig/current": {desktopCompanions: true},
    "desktopCompanions/WALL1": {status: "generating", attempts: 1,
      claimedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 310_000)},
  });
  const before = {...studioWall(), review: false};
  const event = {params: {wallId: "WALL1"}, document: "walls/WALL1", data: {
    before: {data: () => before}, after: {data: () => studioWall()},
  }};

  await assert.rejects(onStudioWallDesktop.run(event as never), /another companion attempt is still running/);
});

test("parseDesktopVariant accepts only the 2560x1600 variant with a public preview thumb", (t) => {
  setEnv(t);
  assert.deepEqual(parseDesktopVariant(variant()), variant());
  assert.equal(parseDesktopVariant(variant("https://evil.example/previews/desktop-x.jpg")), null);
  assert.equal(parseDesktopVariant({...variant(), width: 1920}), null);
});

test("projectWall publishes the desktop thumb of a live wall, and nothing of a gated one", async (t) => {
  setEnv(t);
  const originalSha = `${VERSION}${"a".repeat(48)}`;
  const wideSha = "b".repeat(64);
  installFakeDb(t, {"desktopCompanions/W1": {status: "ready",
    original: {object: `desktop-originals/W1/${originalSha}.jpg`, sha256: originalSha, width: 2560, height: 1600},
    wide: {object: `desktop-originals/W1/${wideSha}.jpg`, sha256: wideSha, width: 2560, height: 1440}}});
  t.mock.method(webCatalogDeps, "blur", async () => BLUR);
  const wall: Doc = {id: "W1", review: true, originalProtected: true, collections: ["community"],
    wallpaper_thumb: `${PREVIEW}/previews/aaa.img`, title: "Desk", tags: [], category: "Nature", colors: [],
    desktopVariant: variant()};

  const live = await projectWall(wall, ["abstract"], null, undefined, NOW);
  assert.equal(live.state, "live");
  assert.deepEqual(live.desktop, {v: VERSION, thumb: desktopThumb(), width: 2560, height: 1600});

  const stale = await projectWall({...wall, desktopVariant: {...variant(), v: "f".repeat(16)}},
    ["abstract"], null, live, NOW);
  assert.equal("desktop" in stale, false);

  const gated = await projectWall({...wall, collections: ["abstract"]}, ["abstract"], null, undefined, NOW);
  assert.equal(gated.state, "gated");
  assert.equal("desktop" in gated, false);
  assert.equal("thumb" in gated, false);
});

const LIVE = {state: "live", updatedAt: NOW.toISOString(), title: "Wall", category: "Nature", categorySlug: "nature",
  width: 2560, height: 1600, createdAt: "2026-10-01T00:00:00.000Z", creatorName: "", creator: null} as const;

test("buildPages lists desktop walls under desktop~1 and links the desktop pages from the sitemap", (t) => {
  setEnv(t);
  const thumb = desktopThumb();
  const walls = new Map<string, WebWall>([
    ["W1", {...LIVE, thumb: `${PREVIEW}/previews/W1.img`, desktop: {v: VERSION, thumb, width: 2560, height: 1600}}],
    ["W2", {...LIVE, thumb: `${PREVIEW}/previews/W2.img`}],
  ]);

  const pages = buildPages(walls, [], [], new Map());

  const desk = pages.get("desktop~1") as unknown as {items: WebDesktopCard[]; total: number};
  assert.equal(desk.total, 1);
  assert.equal(desk.items.length, 1);
  assert.equal(desk.items[0].id, "W1");
  assert.equal(desk.items[0].desktop, thumb);
  const sitemap = (pages.get("sitemap~categories-1") as unknown as {entries: string}).entries;
  const paths = sitemap.split("\n").map((line) => line.split("\t")[0]);
  assert.ok(paths.includes("/desktop-wallpapers"));
  assert.ok(paths.includes("/matching-sets"));
});

test("resolveOriginalAccess refuses a desktop variant on edit, any phone variant, and a desktop batch", async (t) => {
  installFakeDb(t);
  const request = (data: Doc = {}) => ({
    auth: {uid: "user", token: {}},
    data: {assetId: "asset", action: "download", requestId: "request_123", ...data},
    rawRequest: {},
  } as unknown as Parameters<typeof resolveOriginalAccess.run>[0]);

  await assert.rejects(() => resolveOriginalAccess.run(request({action: "edit", variant: "desktop"})),
    {code: "invalid-argument"});
  await assert.rejects(() => resolveOriginalAccess.run(request({variant: "phone"})), {code: "invalid-argument"});
  await assert.rejects(() => resolveOriginalAccess.run(request({assetId: undefined, action: undefined,
    assets: [{assetId: "asset", action: "set"}], variant: "desktop"})), {code: "invalid-argument"});
});
