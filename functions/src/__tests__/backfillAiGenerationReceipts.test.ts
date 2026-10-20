import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {aiCommunityId, type AiGenerationRecord} from "../aiWallSource";
import {backfillAiGenerationReceipts} from "../scripts/backfillAiGenerationReceipts";
import {type Doc, installFakeDb} from "./fakeDb";

const ASSETS = "https://prismwalls.com/api/ai/assets";
const gen = (n: number) => `gen_mlt7o22q_7a9688a037a47de${n}`;
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

  assert.deepEqual(counts, {scanned: 5, skipped: 1, hadReceipt: 1, receiptWritten: 1, recordGone: 1, failed: 1});
  assert.deepEqual(reads, [gen(1), gen(3), gen(7)]);
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(logs.slice(0, 4), [`a ${gen(1)} receipt-written`, `b ${gen(2)} had-receipt`,
    `c ${gen(3)} record-gone`, `g ${gen(7)} failed worker unavailable`]);
});

test("the AI receipt backfill with apply writes the live record and keeps existing receipts", async (t) => {
  const store = installFakeDb(t, SEED);
  const counts = await backfillAiGenerationReceipts(db, {apply: true}, reader([]), () => undefined);

  assert.deepEqual(counts, {scanned: 5, skipped: 1, hadReceipt: 1, receiptWritten: 1, recordGone: 1, failed: 1});
  const {recordedAt, ...receipt} = store.get(`aiGenerationReceipts/${gen(1)}`) as Doc;
  assert.ok(recordedAt instanceof admin.firestore.Timestamp);
  const {generationId, userId, imageUrl, watermarkedImageUrl} = record(gen(1));
  assert.deepEqual(receipt, {generationId, userId, imageUrl, watermarkedImageUrl});
  assert.equal(store.get(`aiGenerationReceipts/${gen(2)}`)?.userId, "first");
  for (const n of [3, 4, 5, 7]) assert.equal(store.has(`aiGenerationReceipts/${gen(n)}`), false);
});
