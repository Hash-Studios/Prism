import assert from "node:assert/strict";
import test from "node:test";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {inspectLiveVideo, isLiveFramePath, isLiveVideoPath} from "../liveVideo";
import {box, mp4} from "./mp4Fixture";

test("real encoded fixtures are accepted and metadata cannot disguise their media", () => {
  const real = (name: string) => readFileSync(resolve(__dirname, "../../../test/fixtures/live", name));
  assert.equal(inspectLiveVideo(real("p.mp4")).ok, true);
  assert.equal(inspectLiveVideo(real("rot.mp4")).ok, true);
  assert.deepEqual(inspectLiveVideo(real("h.mp4")), {ok: false, error: "codec"});
  const long = real("long.mp4");
  long.writeUInt32BE(1000, long.indexOf(Buffer.from("mvhd")) + 20);
  assert.deepEqual(inspectLiveVideo(long), {ok: false, error: "too_long"});
  const outside = real("p.mp4");
  outside.writeUInt32BE(outside.length + 1, outside.indexOf(Buffer.from("stco")) + 12);
  assert.equal(inspectLiveVideo(outside).ok, false);
  const absentConfig = real("p.mp4");
  absentConfig.write("free", absentConfig.indexOf(Buffer.from("avcC")));
  assert.equal(inspectLiveVideo(absentConfig).ok, false);
});

test("sample metadata, SPS dimensions, local references and unit rotations are enforced", () => {
  const real = () => readFileSync(resolve(__dirname, "../../../test/fixtures/live/p.mp4"));
  const mutate = (type: string, offset: number, value: number) => {
    const bytes = real();
    bytes.writeUInt32BE(value, bytes.indexOf(Buffer.from(type), type === "avc1" ? 32 : 0) + offset);
    return bytes;
  };
  assert.equal(inspectLiveVideo(mutate("stsd", 8, 0)).ok, false);
  assert.equal(inspectLiveVideo(mutate("stsz", 12, 999999)).ok, false);
  assert.equal(inspectLiveVideo(mutate("url ", 4, 0)).ok, false);
  assert.equal(inspectLiveVideo(mutate("tkhd", 44, 0)).ok, false);
  assert.equal(inspectLiveVideo(mutate("avc1", 28, (1080 << 16) | 1920)).ok, false);
  assert.equal(inspectLiveVideo(mutate("mdat", 4, 0xffffffff)).ok, false);
  assert.equal(inspectLiveVideo(Buffer.concat([real(), box("moof")])).ok, false);
});

test("empty media, absent track timing, and an empty codec entry are not a playable MP4", () => {
  assert.equal(inspectLiveVideo(mp4({headerOnly: true})).ok, false);
});

test("an in-band SPS cannot change the encoded frame size after avcC", () => {
  const video = mp4();
  const other = mp4({width: 1600, height: 3200});
  const cfg = other.indexOf(Buffer.from("avcC"));
  const sps = other.subarray(cfg + 12, cfg + 12 + other.readUInt16BE(cfg + 10));
  const length = Buffer.alloc(4); length.writeUInt32BE(sps.length);
  const mdat = video.indexOf(Buffer.from("mdat"));
  const payload = Buffer.concat([length, sps, video.subarray(mdat + 4)]);
  video.writeUInt32BE(payload.length, video.indexOf(Buffer.from("stsz")) + 8);
  const changed = Buffer.concat([video.subarray(0, mdat - 4), box("mdat", payload)]);
  assert.equal(inspectLiveVideo(changed).ok, false);
});

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
