import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {resolve} from "node:path";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {aiCommunityId, type AiGenerationRecord} from "../aiWallSource";
import {backfillAiGenerationReceipts} from "../scripts/backfillAiGenerationReceipts";
import {type Doc, installFakeDb} from "./fakeDb";

const ASSETS = "https://prismwalls.com/api/ai/assets";
const gen = (n: number) => `gen_mlt7o22q_${n.toString(16).padStart(16, "0")}`;
const record = (id: string): AiGenerationRecord => ({generationId: id, userId: "maker", width: 1179, height: 2048,
  imageUrl: `${ASSETS}/ai/original/${id}.png`, watermarkedImageUrl: `${ASSETS}/ai/public/${id}.png`});
const aiWall = (id: string, extra: Doc = {}): Doc => ({id: aiCommunityId(id), email: "maker@example.com",
  review: false, isAiGenerated: true, aiGenerationId: id, wallpaper_url: record(id).imageUrl,
  wallpaper_thumb: record(id).watermarkedImageUrl, ...extra});

const SEED: Record<string, Doc> = {
  "walls/a": aiWall(gen(1)),
  "walls/b": aiWall(gen(2)),
  [`aiGenerationReceipts/${gen(2)}`]: {generationId: gen(2), userId: "first"},
  "walls/c": aiWall(gen(3)),
  "walls/d": aiWall(gen(4), {review: true}),
  "walls/e": aiWall(gen(5), {aiGenerationId: undefined}),
  "walls/f": {review: false, wallpaper_url: "https://raw.githubusercontent.com/o/r/main/f.jpg"},
  "walls/g": aiWall(gen(7)),
};
const reader = (reads: string[]) => async (id: string) => {
  reads.push(id);
  if (id === gen(7)) throw new Error("worker unavailable");
  return id === gen(3) ? null : record(id);
};

test("the AI receipt backfill is a dry run by default and reads only pending walls without a receipt", async (t) => {
  const store = installFakeDb(t, SEED);
  const before = JSON.stringify([...store.entries()]);
  const reads: string[] = [];
  const logs: string[] = [];
  const counts = await backfillAiGenerationReceipts(db, {apply: false}, reader(reads), (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 5, skipped: 1, hadReceipt: 1, receiptReady: 1, recordGone: 1, failed: 1});
  assert.deepEqual(reads, [gen(1), gen(3), gen(7)]);
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(logs.slice(0, 4), [`a ${gen(1)} would-write`, `b ${gen(2)} had-receipt`,
    `c ${gen(3)} record-gone`, `g ${gen(7)} failed worker unavailable`]);
});

test("the AI receipt backfill with apply writes the live record and keeps existing receipts", async (t) => {
  const store = installFakeDb(t, SEED);
  const counts = await backfillAiGenerationReceipts(db, {apply: true}, reader([]), () => undefined);

  assert.deepEqual(counts, {scanned: 5, skipped: 1, hadReceipt: 1, receiptReady: 1, recordGone: 1, failed: 1});
  const {recordedAt, ...receipt} = store.get(`aiGenerationReceipts/${gen(1)}`) as Doc;
  assert.ok(recordedAt instanceof admin.firestore.Timestamp);
  const {generationId, userId, imageUrl, watermarkedImageUrl} = record(gen(1));
  assert.deepEqual(receipt, {generationId, userId, imageUrl, watermarkedImageUrl});
  assert.equal(store.get(`aiGenerationReceipts/${gen(2)}`)?.userId, "first");
  for (const n of [3, 4, 5, 7]) assert.equal(store.has(`aiGenerationReceipts/${gen(n)}`), false);
});

test("the AI receipt backfill paginates past 300 walls", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let n = 1; n <= 301; n++) seed[`walls/w${String(n).padStart(3, "0")}`] = aiWall(gen(n));
  installFakeDb(t, seed);
  const reads: string[] = [];

  const counts = await backfillAiGenerationReceipts(db, {apply: false}, async (id) => {
    reads.push(id);
    return null;
  }, () => undefined);

  assert.equal(counts.scanned, 301);
  assert.equal(counts.recordGone, 301);
  assert.deepEqual(reads, Array.from({length: 301}, (_, index) => gen(index + 1)));
});

test("the AI receipt backfill stops after exactly 300 walls even when the last wall is skipped", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let n = 1; n <= 299; n++) seed[`walls/w${String(n).padStart(3, "0")}`] = aiWall(gen(n));
  seed["walls/w300"] = aiWall(gen(300), {aiGenerationId: "invalid"});
  installFakeDb(t, seed);
  const reads: string[] = [];

  const counts = await backfillAiGenerationReceipts(db, {apply: false}, async (id) => {
    reads.push(id);
    return null;
  }, () => undefined);

  assert.deepEqual(counts, {scanned: 300, skipped: 1, hadReceipt: 0, receiptReady: 0, recordGone: 299, failed: 0});
  assert.equal(reads.length, 299);
});

test("the AI receipt backfill handles an empty walls collection", async (t) => {
  installFakeDb(t);
  const reads: string[] = [];

  const counts = await backfillAiGenerationReceipts(db, {apply: false}, async (id) => {
    reads.push(id);
    return null;
  }, () => undefined);

  assert.deepEqual(counts, {scanned: 0, skipped: 0, hadReceipt: 0, receiptReady: 0, recordGone: 0, failed: 0});
  assert.deepEqual(reads, []);
});

test("a wall failure does not undo a receipt already written for an earlier wall", async (t) => {
  const seed = {"walls/a": aiWall(gen(1)), "walls/b": aiWall(gen(2))};
  const store = installFakeDb(t, seed);

  const counts = await backfillAiGenerationReceipts(db, {apply: true}, async (id) => {
    if (id === gen(2)) throw new Error("worker unavailable");
    return record(id);
  }, () => undefined);

  assert.deepEqual(counts, {scanned: 2, skipped: 0, hadReceipt: 0, receiptReady: 1, recordGone: 0, failed: 1});
  assert.equal(counts.failed, 1);
  assert.equal(store.get(`aiGenerationReceipts/${gen(1)}`)?.generationId, gen(1));
  assert.equal(store.has(`aiGenerationReceipts/${gen(2)}`), false);

  const firstReceipt = store.get(`aiGenerationReceipts/${gen(1)}`);
  const retried = await backfillAiGenerationReceipts(db, {apply: true}, async (id) => record(id), () => undefined);
  assert.deepEqual(retried, {scanned: 2, skipped: 0, hadReceipt: 1, receiptReady: 1, recordGone: 0, failed: 0});
  assert.equal(store.get(`aiGenerationReceipts/${gen(1)}`), firstReceipt);
  assert.equal(store.get(`aiGenerationReceipts/${gen(2)}`)?.generationId, gen(2));
});

test("a concurrent create winner is counted as receipt-ready and its data is kept", async (t) => {
  const store = installFakeDb(t, {"walls/a": aiWall(gen(1))});
  const winner = {generationId: gen(1), userId: "trigger", imageUrl: "trigger-original", watermarkedImageUrl: "trigger-thumb"};
  const logs: string[] = [];

  const counts = await backfillAiGenerationReceipts(db, {apply: true}, async () => {
    store.set(`aiGenerationReceipts/${gen(1)}`, winner);
    return record(gen(1));
  }, (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 1, skipped: 0, hadReceipt: 0, receiptReady: 1, recordGone: 0, failed: 0});
  assert.equal(counts.failed, 0);
  assert.equal(store.get(`aiGenerationReceipts/${gen(1)}`), winner);
  assert.ok(logs.includes(`a ${gen(1)} receipt-ready`));
});

test("a missing Worker record is rechecked against a concurrent receipt in apply and dry-run modes", async (t) => {
  for (const apply of [false, true]) {
    await t.test(`apply=${apply}`, async (st) => {
      const store = installFakeDb(st, {"walls/a": aiWall(gen(1))});
      const concurrentReceipt = {generationId: gen(1), userId: "trigger"};

      const counts = await backfillAiGenerationReceipts(db, {apply}, async () => {
        store.set(`aiGenerationReceipts/${gen(1)}`, concurrentReceipt);
        return null;
      }, () => undefined);

      assert.equal(counts.hadReceipt, 1);
      assert.equal(counts.recordGone, 0);
      assert.deepEqual(counts, {scanned: 1, skipped: 0, hadReceipt: 1, receiptReady: 0, recordGone: 0, failed: 0});
      assert.equal(store.get(`aiGenerationReceipts/${gen(1)}`), concurrentReceipt);
    });
  }
});

test("receipt read and write failures are counted as per-wall failures", async (t) => {
  for (const failingOperation of ["read", "write"] as const) {
    await t.test(failingOperation, async (st) => {
      installFakeDb(st, {"walls/a": aiWall(gen(1))});
      const collection = db.collection.bind(db);
      st.mock.method(db, "collection", ((name: string) => {
        const result = collection(name);
        if (name !== "aiGenerationReceipts") return result;
        const originalDoc = result.doc.bind(result);
        return {
          ...result,
          doc: (id: string) => {
            const ref = originalDoc(id);
            return failingOperation === "read" ? {...ref, get: async () => {
              throw new Error("receipt read failed");
            }} : {...ref, create: async () => {
              throw new Error("receipt write failed");
            }};
          },
        };
      }) as typeof db.collection);

      const counts = await backfillAiGenerationReceipts(db, {apply: true}, async (id) => record(id), () => undefined);

      assert.equal(counts.failed, 1);
      assert.deepEqual(counts, {scanned: 1, skipped: 0, hadReceipt: 0, receiptReady: 0, recordGone: 0, failed: 1});
    });
  }
});

test("a walls query failure rejects the backfill instead of reporting partial counts as complete", async (t) => {
  installFakeDb(t);
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", ((name: string) => {
    const result = collection(name);
    if (name !== "walls") return result;
    const query = {
      where: () => query,
      orderBy: () => query,
      limit: () => query,
      startAfter: () => query,
      get: async () => {
        throw new Error("walls query failed");
      },
    };
    return query as unknown as typeof result;
  }) as typeof db.collection);

  await assert.rejects(backfillAiGenerationReceipts(db, {apply: false}, async () => null), /walls query failed/);
});

test("the migration CLI handles help and rejects unknown arguments before checking secrets", () => {
  const script = resolve(__dirname, "../scripts/backfillAiGenerationReceipts.js");
  const env = {...process.env};
  delete env.STUDIO_SECRET;

  const help = spawnSync(process.execPath, [script, "--help"], {encoding: "utf8", env, timeout: 5000});
  assert.equal(help.status, 0);
  assert.match(help.stdout, /Usage: node lib\/scripts\/backfillAiGenerationReceipts\.js/);
  assert.doesNotMatch(help.stderr, /STUDIO_SECRET is required/);

  const missingSecret = spawnSync(process.execPath, [script, "--apply"], {encoding: "utf8", env, timeout: 5000});
  assert.equal(missingSecret.status, 1);
  assert.match(missingSecret.stderr, /STUDIO_SECRET is required/);

  const typo = spawnSync(process.execPath, [script, "--aply"], {encoding: "utf8", env, timeout: 5000});
  assert.equal(typo.status, 1);
  assert.match(typo.stderr, /unknown argument/i);
  assert.doesNotMatch(typo.stderr, /--aply/);
  assert.doesNotMatch(typo.stderr, /STUDIO_SECRET is required/);

  const helpWithTypo = spawnSync(process.execPath, [script, "--help", "--aply"],
    {encoding: "utf8", env, timeout: 5000});
  assert.equal(helpWithTypo.status, 1);
  assert.match(helpWithTypo.stderr, /unknown argument/i);
  assert.doesNotMatch(helpWithTypo.stderr, /--aply|STUDIO_SECRET is required/i);
});

test("the migration CLI exits on completed, per-wall failure, and fatal query failure without services", () => {
  const script = resolve(__dirname, "../scripts/backfillAiGenerationReceipts.js");
  const commonModule = resolve(__dirname, "../common.js");
  const fakeDbModule = resolve(__dirname, "./fakeDb.js");
  const aiSourceModule = resolve(__dirname, "../aiWallSource.js");
  const bootstrap = `
    const mode = process.argv[1];
    const script = process.argv[2];
    const {db} = require(process.argv[3]);
    const {installFakeDb} = require(process.argv[4]);
    const {aiCommunityId} = require(process.argv[5]);
    const {mock} = require('node:test');
    const id = 'gen_mlt7o22q_0000000000000001';
    const seed = mode === 'worker-failure' || mode === 'success' ? {'walls/a': {
      id: aiCommunityId(id), isAiGenerated: true, review: false, aiGenerationId: id,
      wallpaper_url: 'https://prismwalls.com/api/ai/assets/ai/original/' + id + '.png',
      wallpaper_thumb: 'https://prismwalls.com/api/ai/assets/ai/public/' + id + '.png',
    }} : {};
    const store = installFakeDb({mock}, seed);
    if (mode === 'worker-failure') global.fetch = async () => new Response('{}', {status: 503});
    if (mode === 'success') {
      global.fetch = async () => new Response(JSON.stringify({
        generationId: id, userId: 'maker', width: 1179, height: 2048,
        imageUrl: 'https://prismwalls.com/api/ai/assets/ai/original/' + id + '.png',
        watermarkedImageUrl: 'https://prismwalls.com/api/ai/assets/ai/public/' + id + '.png',
      }), {status: 200});
      process.on('exit', () => require('node:assert/strict').equal(store.has('aiGenerationReceipts/' + id), false));
    }
    if (mode === 'query-failure') mock.method(db, 'collection', () => {throw new Error('query failed');});
    process.argv = [process.execPath, script, ...(mode === 'unknown-argument' ? ['--aply'] : [])];
    require('node:module').runMain(script);
  `;
  const env = {PATH: process.env.PATH ?? "", STUDIO_SECRET: "test-secret"};
  const run = (mode: string) => spawnSync(process.execPath,
    ["-e", bootstrap, mode, script, commonModule, fakeDbModule, aiSourceModule], {encoding: "utf8", env, timeout: 5000});

  const success = run("success");
  assert.equal(success.status, 0, success.stderr);
  assert.match(success.stdout, /done [^\n]*"receiptReady":1[^\n]*"failed":0/);

  const wallFailure = run("worker-failure");
  assert.equal(wallFailure.status, 1, wallFailure.stderr);
  assert.match(wallFailure.stdout, /done [^\n]*"failed":1/);

  const queryFailure = run("query-failure");
  assert.equal(queryFailure.status, 1, queryFailure.stderr);
  assert.match(queryFailure.stderr, /query failed/);
  assert.doesNotMatch(queryFailure.stdout, /done /);

  const unknownArgument = run("unknown-argument");
  assert.equal(unknownArgument.status, 1, unknownArgument.stderr);
  assert.match(unknownArgument.stderr, /unknown argument/i);
  assert.doesNotMatch(unknownArgument.stdout, /done /);
});

test("the backfill classifies malformed, missing, and unavailable Worker records without dry-run writes", async (t) => {
  const previousSecret = process.env.STUDIO_SECRET;
  const previousBase = process.env.STUDIO_WORKER_BASE_URL;
  process.env.STUDIO_SECRET = "test-secret";
  process.env.STUDIO_WORKER_BASE_URL = "https://worker.example/";
  t.after(() => {
    if (previousSecret === undefined) delete process.env.STUDIO_SECRET;
    else process.env.STUDIO_SECRET = previousSecret;
    if (previousBase === undefined) delete process.env.STUDIO_WORKER_BASE_URL;
    else process.env.STUDIO_WORKER_BASE_URL = previousBase;
  });

  const store = installFakeDb(t, Object.fromEntries([1, 2, 3, 4].map((n) => [`walls/w${n}`, aiWall(gen(n))])));
  const before = JSON.stringify([...store.entries()]);
  const responses = [new Response("not-json", {status: 200}),
    new Response(JSON.stringify({error: "generation_not_found"}), {status: 404}),
    new Response("{}", {status: 404}), new Response("{}", {status: 503})];
  const fetchMock = t.mock.method(globalThis, "fetch", async (input: string | URL | Request, init?: RequestInit) => {
    assert.match(String(input), /^https:\/\/worker\.example\/api\/ai\/studio\/generation-records\//);
    assert.equal(new Headers(init?.headers).get("x-studio-secret"), "test-secret");
    return responses.shift() as Response;
  });
  const logs: string[] = [];

  const counts = await backfillAiGenerationReceipts(db, {apply: false}, undefined, (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 4, skipped: 0, hadReceipt: 0, receiptReady: 0, recordGone: 1, failed: 3});
  assert.ok(logs.some((line) => line.includes("AI generation record is invalid JSON")));
  assert.ok(logs.some((line) => line.includes("AI generation record route returned an unexpected 404")));
  assert.ok(logs.some((line) => line.includes("AI generation record read failed: 503")));
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.equal(fetchMock.mock.callCount(), 4);
});
