import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {db} from "../common";
import * as delivery from "../ownedAssetDelivery";
import {STUDIO_SERIES} from "../studio/series";
import {STUDIO_ACCOUNT} from "../studio/account";
import {STUDIO_ASSET_BASE} from "../studio/assetSource";
import {studioPrompt} from "../studio/plan";
import {
  onStudioWallApproved,
  postDay,
  postFirstStudioWallOfDay,
  sendStudioPost,
  studioPostCaption,
  telegramBotToken,
  telegramChatId,
} from "../studio/telegram";
import {installFakeDb} from "./fakeDb";

function installTelegramFakeDb(t: TestContext, seed: Record<string, Record<string, unknown>> = {}) {
  const store = installFakeDb(t, seed);
  const getCollection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    const collection = getCollection(name);
    if (name !== "studioTelegramPosts") return collection;
    return {
      ...collection,
      doc: (id?: string) => {
        const ref = id === undefined ? collection.doc() : collection.doc(id);
        return {
          ...ref,
          create: async (data: Record<string, unknown>) => {
            await ref.create(data);
            return {writeTime: (await ref.get()).updateTime};
          },
          delete: async (precondition?: {lastUpdateTime: unknown}) => {
            const current = await ref.get();
            const currentVersion = (current.updateTime as {version?: number} | undefined)?.version;
            const expectedVersion = (precondition?.lastUpdateTime as {version?: number} | undefined)?.version;
            if (precondition && currentVersion !== expectedVersion) {
              throw Object.assign(new Error("claim changed"), {code: 9});
            }
            await ref.delete();
          },
        };
      },
    };
  });
  return store;
}

test("the caption is the subject scene, the collection line and up to five hashtags", () => {
  const series = STUDIO_SERIES.find((s) => s.id === "paper-worlds");
  assert.ok(series);
  const subject = series.subjects.find((s) => s.id === "autumn-road");
  const palette = series.palettes.find((p) => p.id === "autumn");
  assert.ok(subject && palette);
  const caption = studioPostCaption({
    seriesId: series.id,
    aiPrompt: studioPrompt(series, subject, palette),
    tags: ["illustration", "paper", "autumn", "road", "Nature", "extra"],
  });
  assert.equal(caption,
    "A winding road through layered autumn hills and round trees.\n\n" +
    "Part of the Paper Worlds collection by @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n" +
    "#wallpaper #illustration #paper #autumn #road");
});

test("an unknown series falls back to the prompt up to its first comma", () => {
  assert.equal(studioPostCaption({seriesId: "gone", aiPrompt: "a red kite, sunset palette. Style.", tags: ["kite"]}),
    "A red kite.\n\nBy @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n#wallpaper #kite");
});

test("caption tags keep only distinct nonempty strings, with at most five tags total", () => {
  assert.equal(
    studioPostCaption({seriesId: "gone", aiPrompt: "kite", tags: [null, 123, {}, "sky", "sky", "", "#", "wind", "blue", "extra", "sixth"]}),
    "Kite.\n\nBy @PrismWallpapers. Available now in the Prism Wallpapers app.\n\n#wallpaper #sky #wind #blue #extra",
  );
});

test("an empty or non-string prompt keeps useful collection and tag text", () => {
  const empty = studioPostCaption({seriesId: "paper-worlds", aiPrompt: "", tags: ["paper"]});
  assert.match(empty, /Part of the Paper Worlds collection/);
  assert.match(empty, /#wallpaper #paper$/);
  assert.doesNotMatch(empty, /^\./);
  const invalid = studioPostCaption({seriesId: "gone", aiPrompt: 42, tags: ["kite"]});
  assert.match(invalid, /By @PrismWallpapers/);
  assert.match(invalid, /#wallpaper #kite$/);
  assert.doesNotMatch(invalid, /42/);
});

/** Fakes the image download and Telegram. Returns the chat ids of the posts that reached Telegram. */
function fakeTelegram(t: TestContext, ok = () => true): string[] {
  const posts: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string, init?: {body?: FormData}) => {
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    if (!ok()) return new Response("down", {status: 502});
    posts.push(String(init?.body?.get("chat_id")));
    return new Response(JSON.stringify({ok: true, result: {message_id: 1}}));
  });
  return posts;
}

test("sendStudioPost sanitizes Telegram response errors that contain the token", async (t) => {
  const token = "sentinel-bot-token";
  const response = new Response(JSON.stringify({
    ok: false,
    description: `invalid token ${token}`,
  }), {status: 502});
  t.mock.method(globalThis, "fetch", async (url: string) =>
    url.includes("api.telegram.org") ? response : new Response(new Uint8Array([1])));
  await assert.rejects(sendStudioPost(token, "-100", wall), (error: unknown) => {
    assert.doesNotMatch(String(error), new RegExp(token));
    return true;
  });
});

test("sendStudioPost rejects a Telegram ok=false response with HTTP 200", async (t) => {
  const token = "sentinel-bot-token";
  const response = new Response(JSON.stringify({ok: false, description: "chat not found"}), {status: 200});
  t.mock.method(globalThis, "fetch", async (url: string) =>
    url.includes("api.telegram.org") ? response : new Response(new Uint8Array([1])));
  await assert.rejects(sendStudioPost(token, "-100", wall));
});

test("sendStudioPost sanitizes fetch exceptions that contain the token", async (t) => {
  const token = "sentinel-bot-token";
  t.mock.method(globalThis, "fetch", async (url: string) => {
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    throw new Error(`request ${token} failed`);
  });
  await assert.rejects(sendStudioPost(token, "-100", wall), (error: unknown) => {
    assert.doesNotMatch(String(error), new RegExp(token));
    return true;
  });
});

const wall = {wallpaper_url: "https://cdn.example/w.jpg", seriesId: "paper-worlds", aiPrompt: "a kite", tags: []};
const morning = new Date("2026-10-17T03:00:00Z");

test("the approval trigger retries transient failures", () => {
  assert.equal(onStudioWallApproved.__endpoint.eventTrigger?.retry, true);
});

test("only the first wall approved in a day is posted, and the next day posts again", async (t) => {
  const store = installTelegramFakeDb(t);
  const posts = fakeTelegram(t);
  const results = await Promise.all(["w1", "w2", "w3"].map((id) =>
    postFirstStudioWallOfDay(id, wall, "token", "-100", morning)));
  assert.deepEqual(results.filter(Boolean).length, 1);
  assert.deepEqual(posts, ["-100"]);
  assert.equal(await postFirstStudioWallOfDay("w4", wall, "token", "-100", new Date("2026-10-18T03:00:00Z")), true);
  assert.equal(posts.length, 2);
  assert.ok(store.has("studioTelegramPosts/2026-10-17") && store.has("studioTelegramPosts/2026-10-18"));
});

test("a failed send frees the day for the next approval", async (t) => {
  installTelegramFakeDb(t);
  let up = false;
  const posts = fakeTelegram(t, () => up);
  await assert.rejects(postFirstStudioWallOfDay("w1", wall, "token", "-100", morning), /502/);
  up = true;
  assert.equal(await postFirstStudioWallOfDay("w2", wall, "token", "-100", morning), true);
  assert.equal(posts.length, 1);
});

test("a timed-out image transfer releases the daily claim for the next approval", async (t) => {
  const store = installTelegramFakeDb(t);
  let deadlines = 0;
  t.mock.method(AbortSignal, "timeout", () =>
    deadlines++ === 0 ? AbortSignal.abort() : new AbortController().signal);
  const posts: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string, init?: RequestInit) => {
    init?.signal?.throwIfAborted();
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    posts.push(url);
    return new Response(JSON.stringify({ok: true, result: {message_id: 1}}));
  });
  await assert.rejects(postFirstStudioWallOfDay("w1", wall, "token", "-100", morning));
  assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
  assert.equal(await postFirstStudioWallOfDay("w2", wall, "token", "-100", morning), true);
  assert.equal(posts.length, 1);
});

test("a lost Telegram response keeps the day claimed, so a possibly accepted post is not repeated", async (t) => {
  const first = verifiedStudioWall();
  const second = {...first, studioRunId: "run-2", studioCandidateId: "candidate-2",
    wallpaper_url: `${STUDIO_ASSET_BASE}/ai/studio/candidate-2.jpg`,
    wallpaper_thumb: `${STUDIO_ASSET_BASE}/ai/studio/thumb_candidate-2.jpg`};
  installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "studioRuns/run-2/candidates/candidate-2": {wallId: "wall-2"},
    "walls/wall-1": first,
    "walls/wall-2": second,
  });
  mockTelegramSecrets(t);
  t.mock.method(logger, "error", () => undefined);
  let accepted = 0;
  t.mock.method(globalThis, "fetch", async (url: string) => {
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    accepted++;
    if (accepted === 1) throw new Error("connection lost after Telegram accepted the photo");
    return new Response(JSON.stringify({ok: true, result: {message_id: accepted}}));
  });
  await onStudioWallApproved.run(approvalEvent({...first, review: false}, first, "wall-1"));
  await onStudioWallApproved.run(approvalEvent({...second, review: false}, second, "wall-2"));
  assert.equal(accepted, 1);
});

test("a failed post cannot delete a replacement daily claim during a retried delete", async (t) => {
  installFakeDb(t);
  const tokenA = {writeTime: "claim-a"};
  const tokenB = {writeTime: "claim-b"};
  let activeClaim: typeof tokenA | undefined;
  let replaced = false;
  t.mock.method(db, "collection", (name: string) => {
    if (name !== "studioTelegramPosts") {
      return {
        doc: () => {
          throw new Error(`unexpected collection ${name}`);
        },
      };
    }
    return {
      doc: () => ({
        create: async () => {
          if (activeClaim) throw Object.assign(new Error("exists"), {code: 6});
          activeClaim = tokenA;
          return tokenA;
        },
        delete: async (precondition?: {lastUpdateTime: typeof tokenA.writeTime}) => {
          // Model a delete committed before its response was lost. Another invocation claims the now-free day,
          // then the SDK retries the original delete with its original precondition.
          if (activeClaim === tokenA) activeClaim = undefined;
          if (!replaced) {
            activeClaim = tokenB;
            replaced = true;
          }
          if (precondition && activeClaim === tokenB && precondition.lastUpdateTime === tokenA.writeTime) {
            throw Object.assign(new Error("replacement claim is newer"), {code: 9});
          }
          activeClaim = undefined;
        },
      }),
    };
  });
  t.mock.method(globalThis, "fetch", async (url: string) => url.includes("api.telegram.org") ?
    new Response("down", {status: 502}) : new Response(new Uint8Array([1])));
  await assert.rejects(postFirstStudioWallOfDay("w1", wall, "token", "-100", morning), /502/);
  assert.equal(activeClaim, tokenB);
});

test("the day turns at midnight in India, not UTC", () => {
  assert.equal(postDay(new Date("2026-10-17T18:29:00Z")), "2026-10-17");
  assert.equal(postDay(new Date("2026-10-17T18:31:00Z")), "2026-10-18");
});

function approvalEvent(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
  wallId = "wall-1",
  time = "2026-10-17T03:00:00Z",
) {
  return {
    id: "approval-event-1",
    time,
    params: {wallId},
    data: before && after ? {
      before: {data: () => before},
      after: {data: () => after, createTime: admin.firestore.Timestamp.fromMillis(1),
        ref: {get: async () => ({data: () => after})}},
    } : undefined,
  } as unknown as Parameters<typeof onStudioWallApproved.run>[0];
}

function mockTelegramSecrets(t: TestContext, token = "sentinel-bot-token") {
  t.mock.method(telegramBotToken, "value", () => token);
  t.mock.method(telegramChatId, "value", () => "-100");
}

function verifiedStudioWall() {
  return {
    ...wall,
    email: STUDIO_ACCOUNT.email,
    wallpaper_url: `${STUDIO_ASSET_BASE}/ai/studio/candidate-1.jpg`,
    wallpaper_thumb: `${STUDIO_ASSET_BASE}/ai/studio/thumb_candidate-1.jpg`,
    origin: "studio",
    studioRunId: "run-1",
    studioCandidateId: "candidate-1",
    review: true,
  };
}

function mockApprovalPost(t: TestContext, onFetch: (url: string, init?: {body?: FormData}) => Promise<Response>) {
  const posts: Array<{url: string; body?: FormData}> = [];
  t.mock.method(globalThis, "fetch", async (url: string, init?: {body?: FormData}) => {
    posts.push({url, body: init?.body});
    return onFetch(url, init);
  });
  return posts;
}

test("only a false-to-true verified Studio approval posts", async (t) => {
  const studio = verifiedStudioWall();
  installTelegramFakeDb(t, {"studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"}, "walls/wall-1": studio});
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async (url) => url.includes("api.telegram.org") ?
    new Response(JSON.stringify({ok: true, result: {message_id: 1}})) : new Response(new Uint8Array([1])));
  await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio));
  assert.equal(posts.length, 2);
  assert.equal(posts[1].body?.get("chat_id"), "-100");
  assert.equal(posts[1].url.includes("sentinel-bot-token"), true);
});

for (const forged of [
  {email: "attacker@example.com", wallpaper_url: "https://foreign.example/arbitrary.jpg"},
  {email: STUDIO_ACCOUNT.email, wallpaper_url: "https://foreign.example/arbitrary.jpg"},
  {email: "attacker@example.com", originalProtected: true, wallpaper_url: ""},
]) {
  test(`a copied Studio candidate backlink cannot authorize forged wall content: ${JSON.stringify(forged)}`, async (t) => {
    const studio = {...verifiedStudioWall(), ...forged};
    const store = installTelegramFakeDb(t, {
      "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
      "walls/wall-1": studio,
    });
    mockTelegramSecrets(t);
    let signatures = 0;
    t.mock.method(delivery, "signOriginalDelivery", async () => {
      signatures++;
      return {url: "https://r2.example/original.jpg?sig=1", expiresAt: Date.now() + 60_000, objectId: "a".repeat(64)};
    });
    let downloads = 0;
    t.mock.method(globalThis, "fetch", async () => {
      downloads++;
      return new Response(new Uint8Array([1]));
    });
    await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio));
    assert.equal(downloads, 0);
    assert.equal(signatures, 0);
    assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
  });
}

test("non-transitions, missing snapshots, ordinary walls, and spoofed Studio walls do not post", async (t) => {
  const studio = verifiedStudioWall();
  const ordinary = {...studio, origin: "user"};
  const invalidId = {...studio, studioRunId: "../bad"};
  const missingRun = {...studio, studioRunId: "run-2", studioCandidateId: "candidate-2"};
  const missingCandidate = {...studio, studioCandidateId: undefined};
  const store = installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "someone-else"},
    "walls/not-transition": studio,
    "walls/ordinary": ordinary,
    "walls/invalid-id": invalidId,
    "walls/missing-run": missingRun,
    "walls/missing-candidate": missingCandidate,
    "walls/mismatch": studio,
  });
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async () => new Response(JSON.stringify({ok: true, result: {message_id: 1}})));
  await onStudioWallApproved.run(approvalEvent(studio, studio, "not-transition"));
  await onStudioWallApproved.run(approvalEvent({...ordinary, review: false}, ordinary, "ordinary"));
  await onStudioWallApproved.run(approvalEvent({...invalidId, review: false}, invalidId, "invalid-id"));
  await onStudioWallApproved.run(approvalEvent({...missingRun, review: false}, missingRun, "missing-run"));
  await onStudioWallApproved.run(approvalEvent({...missingCandidate, review: false}, missingCandidate, "missing-candidate"));
  await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio, "mismatch"));
  const missing = approvalEvent({...studio, review: false}, studio, "no-snapshot");
  (missing as unknown as {data?: unknown}).data = undefined;
  await onStudioWallApproved.run(missing);
  assert.equal(posts.length, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("studioTelegramPosts/")), false);
});

test("a stale approval snapshot does not post when the current wall is no longer approved", async (t) => {
  const stale = verifiedStudioWall();
  installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "walls/wall-1": {...stale, review: false},
  });
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async () => new Response(JSON.stringify({ok: true, result: {message_id: 1}})));
  await onStudioWallApproved.run(approvalEvent({...stale, review: false}, stale));
  assert.equal(posts.length, 0);
});

test("a stale approval snapshot does not post after the current wall was deleted", async (t) => {
  const stale = verifiedStudioWall();
  installTelegramFakeDb(t, {"studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"}});
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async () => new Response(JSON.stringify({ok: true, result: {message_id: 1}})));
  await onStudioWallApproved.run(approvalEvent({...stale, review: false}, stale));
  assert.equal(posts.length, 0);
});

test("an approval from a deleted wall cannot post a recreated wall at the same path", async (t) => {
  const studio = verifiedStudioWall();
  const store = installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "walls/wall-1": studio,
  });
  mockTelegramSecrets(t);
  const posts = fakeTelegram(t);
  const event = approvalEvent({...studio, review: false}, studio);
  assert.ok(event.data);
  Object.assign(event.data.after, {createTime: admin.firestore.Timestamp.fromMillis(0)});
  await onStudioWallApproved.run(event);
  assert.deepEqual(posts, []);
  assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
});

for (const failure of ["signing", "download"]) {
  test(`a transient original ${failure} failure retries the same approval without duplicating its post`, async (t) => {
    const studio = {...verifiedStudioWall(), originalProtected: true, wallpaper_url: ""};
    const store = installTelegramFakeDb(t, {
      "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
      "walls/wall-1": studio,
    });
    mockTelegramSecrets(t);
    let up = false;
    let posts = 0;
    t.mock.method(delivery, "signOriginalDelivery", async () => {
      if (!up && failure === "signing") throw new Error("temporary R2 signing failure");
      return {url: "https://r2.example/original.jpg?sig=1", expiresAt: Date.now() + 60_000, objectId: "a".repeat(64)};
    });
    t.mock.method(globalThis, "fetch", async (url: string) => {
      if (!url.includes("api.telegram.org")) {
        if (!up && failure === "download") throw new Error("temporary R2 download failure");
        return new Response(new Uint8Array([1]));
      }
      posts++;
      return new Response(JSON.stringify({ok: true, result: {message_id: 1}}));
    });
    const event = approvalEvent({...studio, review: false}, studio);
    await assert.rejects(onStudioWallApproved.run(event), /retry/i);
    assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
    assert.equal(posts, 0);
    up = true;
    await onStudioWallApproved.run(event);
    await onStudioWallApproved.run(event);
    assert.equal(posts, 1);
    assert.equal(store.get("studioTelegramPosts/2026-10-17")?.wallId, "wall-1");
  });
}

for (const [target, status] of [["telegram", 400], ["telegram", 403], ["image", 404]] as const) {
  test(`a permanent ${target} HTTP ${status} stops retrying the approval and frees the day`, async (t) => {
    const studio = verifiedStudioWall();
    const store = installTelegramFakeDb(t, {
      "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
      "walls/wall-1": studio,
    });
    mockTelegramSecrets(t);
    let rejectedAttempts = 0;
    t.mock.method(globalThis, "fetch", async (url: string) => {
      if (url.includes("api.telegram.org") === (target === "telegram")) {
        rejectedAttempts++;
        return new Response("permanent rejection", {status});
      }
      return new Response(new Uint8Array([1]));
    });
    await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio));
    assert.equal(rejectedAttempts, 1);
    assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
  });
}

test("a permanent protected-original integrity failure does not retry the approval", async (t) => {
  const studio = {...verifiedStudioWall(), originalProtected: true, wallpaper_url: ""};
  const store = installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "walls/wall-1": studio,
  });
  mockTelegramSecrets(t);
  t.mock.method(delivery, "signOriginalDelivery", async () => {
    throw new delivery.PermanentOwnedAssetError("Retained upload mismatch");
  });
  let requests = 0;
  t.mock.method(globalThis, "fetch", async () => {
    requests++;
    return new Response();
  });
  await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio));
  assert.equal(requests, 0);
  assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
});

for (const status of [408, 429, 500]) {
  test(`Telegram HTTP ${status} still retries the approval`, async (t) => {
    const studio = verifiedStudioWall();
    const store = installTelegramFakeDb(t, {
      "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
      "walls/wall-1": studio,
    });
    mockTelegramSecrets(t);
    t.mock.method(globalThis, "fetch", async (url: string) => url.includes("api.telegram.org") ?
      new Response("try later", {status}) : new Response(new Uint8Array([1])));
    await assert.rejects(onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio)), /retry/i);
    assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
  });
}

test("an approval event posts the current wall content, not its stale snapshot", async (t) => {
  const stale = verifiedStudioWall();
  const current = {...stale, studioCandidateId: "candidate-2", aiPrompt: "current scene",
    wallpaper_url: `${STUDIO_ASSET_BASE}/ai/studio/candidate-2.jpg`,
    wallpaper_thumb: `${STUDIO_ASSET_BASE}/ai/studio/thumb_candidate-2.jpg`};
  installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "studioRuns/run-1/candidates/candidate-2": {wallId: "wall-1"},
    "walls/wall-1": current,
  });
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async (url) => url.includes("api.telegram.org") ?
    new Response(JSON.stringify({ok: true, result: {message_id: 1}})) : new Response(new Uint8Array([1])));
  await onStudioWallApproved.run(approvalEvent({...stale, review: false}, stale));
  assert.ok(posts.some(({url}) => url === current.wallpaper_url));
  assert.ok(!posts.some(({url}) => url === stale.wallpaper_url));
  const telegramPost = posts.find(({url}) => url.includes("api.telegram.org"));
  assert.match(String(telegramPost?.body?.get("caption")), /Current scene\./);
  assert.doesNotMatch(String(telegramPost?.body?.get("caption")), /A kite\./);
});

test("replayed approval events use event time, and a fresh next-day approval may post", async (t) => {
  const studio = verifiedStudioWall();
  const store = installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "walls/wall-1": studio,
    "studioTelegramPosts/2026-10-15": {wallId: "already-posted"},
  });
  mockTelegramSecrets(t);
  const posts = mockApprovalPost(t, async (url) => url.includes("api.telegram.org") ?
    new Response(JSON.stringify({ok: true, result: {message_id: 1}})) : new Response(new Uint8Array([1])));
  const replayed = approvalEvent({...studio, review: false}, studio, "wall-1", "2026-10-15T03:00:00Z");
  await onStudioWallApproved.run(replayed);
  await onStudioWallApproved.run(replayed);
  assert.equal(posts.length, 0);
  assert.equal(store.has("studioTelegramPosts/2026-10-16"), false);
  await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio, "wall-1", "2026-10-16T03:00:00Z"));
  assert.equal(posts.length, 2);
  assert.equal(store.has("studioTelegramPosts/2026-10-16"), true);
});

test("approval failures never write the bot token to function logs", async (t) => {
  const token = "sentinel-bot-token";
  const studio = verifiedStudioWall();
  installTelegramFakeDb(t, {
    "studioRuns/run-1/candidates/candidate-1": {wallId: "wall-1"},
    "walls/wall-1": studio,
  });
  mockTelegramSecrets(t, token);
  const errors: unknown[][] = [];
  t.mock.method(logger, "error", (...args: unknown[]) => errors.push(args));
  t.mock.method(globalThis, "fetch", async (url: string) => {
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    throw new Error(`request ${token} failed`);
  });
  await onStudioWallApproved.run(approvalEvent({...studio, review: false}, studio));
  assert.doesNotMatch(JSON.stringify(errors), new RegExp(token));
});

test("a converted wall is posted from its signed original, never from the redacted wallpaper_url", async (t) => {
  installTelegramFakeDb(t);
  const signed: string[] = [];
  t.mock.method(delivery, "signOriginalDelivery", async (wallId: string) => {
    signed.push(wallId);
    return {url: "https://r2.example/original.jpg?sig=1", expiresAt: Date.now() + 60_000, objectId: "a".repeat(64)};
  });
  const fetched: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string) => {
    fetched.push(url);
    if (!url.includes("api.telegram.org")) return new Response(new Uint8Array([1]));
    return new Response(JSON.stringify({ok: true, result: {message_id: 1}}));
  });
  const converted = {...wall, wallpaper_url: "", originalProtected: true};
  assert.equal(await postFirstStudioWallOfDay("w1", converted, "token", "-100", morning), true);
  assert.deepEqual(signed, ["w1"]);
  assert.ok(fetched.includes("https://r2.example/original.jpg?sig=1"));
  assert.ok(!fetched.includes(""));
});

test("an unprotected wall with no public image fails and frees the day", async (t) => {
  const store = installTelegramFakeDb(t);
  t.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify({ok: true})));
  await assert.rejects(postFirstStudioWallOfDay("w1", {...wall, wallpaper_url: ""}, "token", "-100", morning),
    /no readable image/);
  assert.equal(store.has("studioTelegramPosts/2026-10-17"), false);
});
