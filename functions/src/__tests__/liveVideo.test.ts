import assert from "node:assert/strict";
import test from "node:test";
import {inspectLiveVideo, isLiveFramePath, isLiveVideoPath} from "../liveVideo";
import {mp4} from "./mp4Fixture";

test("a portrait H.264 clip is read from its box headers", () => {
  const bytes = mp4();
  assert.deepEqual(inspectLiveVideo(bytes), {
    ok: true,
    info: {durationMs: 5000, width: 1080, height: 1920, codec: "avc1", bytes: bytes.length},
  });
});

test("a stored landscape clip with a rotate-90 matrix is read as portrait", () => {
  const result = inspectLiveVideo(mp4({width: 1920, height: 1080, rotate: true}));
  assert.ok(result.ok);
  assert.deepEqual([result.info.width, result.info.height], [1080, 1920]);
});

test("an HEVC clip is refused by codec", () => {
  assert.deepEqual(inspectLiveVideo(mp4({codec: "hvc1"})), {ok: false, error: "codec"});
});

test("a QuickTime brand is refused as not MP4", () => {
  assert.deepEqual(inspectLiveVideo(mp4({brand: "qt  "})), {ok: false, error: "not_mp4"});
});

test("a JPEG header is refused as not MP4", () => {
  const buf = Buffer.alloc(64);
  Buffer.from([0xff, 0xd8, 0xff]).copy(buf, 0);
  assert.deepEqual(inspectLiveVideo(buf), {ok: false, error: "not_mp4"});
});

test("a PNG header is refused as not MP4", () => {
  const buf = Buffer.alloc(64);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buf, 0);
  assert.deepEqual(inspectLiveVideo(buf), {ok: false, error: "not_mp4"});
});

test("a JPEG whose bytes 4 to 8 spell ftyp is refused, not read as an MP4", () => {
  const buf = Buffer.alloc(64, 0xab);
  Buffer.from([0xff, 0xd8, 0xff, 0xe0]).copy(buf, 0);
  buf.write("ftyp", 4, "latin1");
  const result = inspectLiveVideo(buf);
  assert.equal(result.ok, false);
});

test("a clip of 15001 ms is too long and a clip of 15000 ms is allowed", () => {
  assert.deepEqual(inspectLiveVideo(mp4({duration: 15001})), {ok: false, error: "too_long"});
  const result = inspectLiveVideo(mp4({duration: 15000}));
  assert.ok(result.ok);
  assert.equal(result.info.durationMs, 15000);
});

test("a file over 20 MB is too large", () => {
  const big = Buffer.alloc(20 * 1024 * 1024 + 1);
  mp4().copy(big, 0);
  assert.deepEqual(inspectLiveVideo(big), {ok: false, error: "too_large"});
});

test("a square frame is refused as landscape", () => {
  assert.deepEqual(inspectLiveVideo(mp4({width: 1080, height: 1080})), {ok: false, error: "landscape"});
});

test("a frame wider than 1440 px is too big", () => {
  assert.deepEqual(inspectLiveVideo(mp4({width: 1600, height: 3200})), {ok: false, error: "too_big_frame"});
});

test("a file with only a sound track has no video track", () => {
  assert.deepEqual(inspectLiveVideo(mp4({video: false})), {ok: false, error: "no_video_track"});
});

test("a truncated clip is refused", () => {
  const full = mp4();
  const cut = full.subarray(0, full.length - 20);
  assert.equal(inspectLiveVideo(cut).ok, false);
});

test("a file without an mdat box is malformed", () => {
  assert.deepEqual(inspectLiveVideo(mp4({mdat: false})), {ok: false, error: "malformed"});
});

test("a version 1 movie header is read with 64-bit times", () => {
  const result = inspectLiveVideo(mp4({mvhdVersion: 1, duration: 4000}));
  assert.ok(result.ok);
  assert.equal(result.info.durationMs, 4000);
});

test("live video and frame names are recognised by prefix and extension", () => {
  assert.equal(isLiveVideoPath("live_a.mp4"), true);
  assert.equal(isLiveVideoPath("a.mp4"), false);
  assert.equal(isLiveVideoPath("live_a.jpg"), false);
  assert.equal(isLiveFramePath("frame_1_a.jpg"), true);
});
