/** Limits of a creator live wall video. lib/features/wallpaper_upload/biz/live_upload_limits.dart mirrors them. */
export const LIVE_VIDEO_LIMITS = {maxBytes: 20 * 1024 * 1024, maxDurationMs: 15_000, maxWidth: 1440, maxHeight: 3200};
export const LIVE_VIDEO_PREFIX = "live_";
export const LIVE_FRAME_PREFIX = "frame_";
export const LIVE_FRAME_COUNT = 3;

export type LiveVideoError = "not_mp4" | "malformed" | "no_video_track" | "codec" | "too_large" | "too_long" |
  "landscape" | "too_big_frame";
export type LiveVideoInfo = {durationMs: number; width: number; height: number; codec: string; bytes: number};

const MP4_BRANDS = new Set(["isom", "iso2", "iso3", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "M4V ", "M4VP",
  "dash", "msnv", "3gp4", "3gp5", "3gp6"]);
const H264 = new Set(["avc1", "avc3"]);

type Box = {type: string; start: number; end: number};

function boxes(buf: Buffer, from: number, to: number): Box[] {
  const found: Box[] = [];
  let at = from;
  while (at < to) {
    if (found.length >= 1024) throw new Error("malformed");
    if (to - at < 8) throw new Error("malformed");
    let size = buf.readUInt32BE(at);
    const type = buf.toString("latin1", at + 4, at + 8);
    let header = 8;
    if (size === 1) {
      if (to - at < 16) throw new Error("malformed");
      const large = buf.readBigUInt64BE(at + 8);
      if (large > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("malformed");
      size = Number(large);
      header = 16;
    } else if (size === 0) {
      size = to - at;
    }
    if (size < header || at + size > to) throw new Error("malformed");
    found.push({type, start: at + header, end: at + size});
    at += size;
  }
  return found;
}

const child = (buf: Buffer, box: Box, type: string) => boxes(buf, box.start, box.end).find((b) => b.type === type);

function need(buf: Buffer, box: Box | undefined, bytes: number): Box {
  if (!box || box.end - box.start < bytes || box.end > buf.length) throw new Error("malformed");
  return box;
}

function uint(buf: Buffer, at: number, wide: boolean): number {
  const value = wide ? Number(buf.readBigUInt64BE(at)) : buf.readUInt32BE(at);
  if (!Number.isSafeInteger(value)) throw new Error("malformed");
  return value;
}

function mediaDuration(buf: Buffer, box: Box): number {
  if (buf[box.start] > 1) throw new Error("malformed");
  const wide = buf[box.start] === 1;
  const at = box.start + (wide ? 20 : 12);
  need(buf, box, at - box.start + (wide ? 12 : 8));
  const scale = buf.readUInt32BE(at);
  if (!scale) throw new Error("malformed");
  return uint(buf, at + 4, wide) * 1000 / scale;
}

/** Reads SPS dimensions, not just the independently editable container display size. */
function spsDimensions(nal: Buffer): [number, number] {
  if ((nal[0] & 31) !== 7) throw new Error("malformed");
  const rbsp = Buffer.from([...nal.subarray(1)].filter((byte, i, all) =>
    !(byte === 3 && i >= 2 && all[i - 1] === 0 && all[i - 2] === 0)));
  let bit = 0;
  const bits = (n: number): number => {
    if (n > 32 || bit + n > rbsp.length * 8) throw new Error("malformed");
    let value = 0;
    for (let i = 0; i < n; i++, bit++) value = value * 2 + ((rbsp[bit >> 3] >> (7 - (bit & 7))) & 1);
    return value;
  };
  const ue = (): number => {
    let zeros = 0;
    while (bits(1) === 0) if (++zeros > 24) throw new Error("malformed");
    return 2 ** zeros - 1 + bits(zeros);
  };
  const se = () => {
    const v = ue(); return v & 1 ? (v + 1) / 2 : -v / 2;
  };
  const profile = bits(8);
  bits(16); ue();
  let chroma = 1;
  let separate = 0;
  if ([100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135].includes(profile)) {
    chroma = ue();
    if (chroma > 3) throw new Error("malformed");
    if (chroma === 3) separate = bits(1);
    ue(); ue(); bits(1);
    if (bits(1)) {
      for (let i = 0; i < (chroma === 3 ? 12 : 8); i++) {
        if (!bits(1)) continue;
        let last = 8;
        let next = 8;
        for (let j = 0; j < (i < 6 ? 16 : 64); j++) {
          if (next) next = (last + se() + 256) % 256;
          last = next || last;
        }
      }
    }
  }
  ue();
  const poc = ue();
  if (poc === 0) ue();
  else if (poc === 1) {
    bits(1); se(); se();
    const count = ue();
    if (count > 256) throw new Error("malformed");
    for (let i = 0; i < count; i++) se();
  } else if (poc !== 2) throw new Error("malformed");
  ue(); bits(1);
  const width = (ue() + 1) * 16;
  const mapHeight = ue() + 1;
  const frameOnly = bits(1);
  if (!frameOnly) bits(1);
  bits(1);
  const crop = bits(1) ? [ue(), ue(), ue(), ue()] : [0, 0, 0, 0];
  const format = separate ? 0 : chroma;
  const unitX = format === 1 || format === 2 ? 2 : 1;
  const unitY = (format === 1 ? 2 : 1) * (2 - frameOnly);
  return [width - (crop[0] + crop[1]) * unitX, mapHeight * 16 * (2 - frameOnly) - (crop[2] + crop[3]) * unitY];
}

function avcConfig(buf: Buffer, entry: Box, width: number, height: number): number {
  const cfg = need(buf, boxes(buf, entry.start + 78, entry.end).find((b) => b.type === "avcC"), 7);
  if (buf[cfg.start] !== 1) throw new Error("malformed");
  const lengthSize = (buf[cfg.start + 4] & 3) + 1;
  if (lengthSize === 3) throw new Error("malformed");
  let at = cfg.start + 6;
  const readNal = () => {
    if (at + 2 > cfg.end) throw new Error("malformed");
    const size = buf.readUInt16BE(at); at += 2;
    if (!size || at + size > cfg.end) throw new Error("malformed");
    const nal = buf.subarray(at, at + size); at += size;
    return nal;
  };
  const count = buf[cfg.start + 5] & 31;
  if (!count) throw new Error("malformed");
  for (let i = 0; i < count; i++) {
    const dims = spsDimensions(readNal());
    if (dims[0] !== width || dims[1] !== height) throw new Error("malformed");
  }
  if (at >= cfg.end) throw new Error("malformed");
  const pps = buf[at++];
  if (!pps) throw new Error("malformed");
  for (let i = 0; i < pps; i++) if ((readNal()[0] & 31) !== 8) throw new Error("malformed");
  return lengthSize;
}

/** Validates bounded, non-fragmented local sample tables and AVC NAL framing. This is not a decoder. */
function sampleDuration(buf: Buffer, stbl: Box, mdia: Box, mdats: Box[], lengthSize: number,
  width: number, height: number): number {
  const table = (type: string, stride: number, prefix = 8): Box => {
    const box = need(buf, child(buf, stbl, type), prefix);
    const count = buf.readUInt32BE(box.start + prefix - 4);
    if (!count || count > 100_000 || box.end - box.start !== prefix + count * stride) throw new Error("malformed");
    return box;
  };
  const sz = need(buf, child(buf, stbl, "stsz"), 12);
  const fixed = buf.readUInt32BE(sz.start + 4);
  const count = buf.readUInt32BE(sz.start + 8);
  if (!count || count > 100_000 || sz.end - sz.start !== 12 + (fixed ? 0 : 4 * count)) throw new Error("malformed");
  const sizes = Array.from({length: count}, (_, i) => fixed || buf.readUInt32BE(sz.start + 12 + i * 4));
  if (sizes.some((n) => !n || n > buf.length) || sizes.reduce((sum, n) => sum + n, 0) > buf.length) {
    throw new Error("malformed");
  }
  const timing = table("stts", 8);
  let samples = 0;
  let ticks = 0;
  for (let at = timing.start + 8; at < timing.end; at += 8) {
    const n = buf.readUInt32BE(at); const delta = buf.readUInt32BE(at + 4);
    if (!n || !delta) throw new Error("malformed");
    samples += n; ticks += n * delta;
  }
  if (samples !== count || !Number.isSafeInteger(ticks)) throw new Error("malformed");
  const mdhd = need(buf, child(buf, mdia, "mdhd"), 20);
  const trackDuration = mediaDuration(buf, mdhd);
  const scale = buf.readUInt32BE(mdhd.start + (buf[mdhd.start] === 1 ? 20 : 12));
  if (Math.abs(trackDuration - ticks * 1000 / scale) > 1) throw new Error("malformed");
  const chunks = child(buf, stbl, "co64") ? table("co64", 8) : table("stco", 4);
  const chunkCount = buf.readUInt32BE(chunks.start + 4);
  const map = table("stsc", 12);
  const runs: {first: number; n: number}[] = [];
  for (let at = map.start + 8; at < map.end; at += 12) {
    const first = buf.readUInt32BE(at); const n = buf.readUInt32BE(at + 4);
    if (!n || first < 1 || first > chunkCount || (runs.length ? first <= runs[runs.length - 1].first : first !== 1) ||
      buf.readUInt32BE(at + 8) !== 1) throw new Error("malformed");
    runs.push({first, n});
  }
  let index = 0; let run = 0; let previousEnd = 0; let nalCount = 0;
  for (let i = 0; i < chunkCount; i++) {
    if (run + 1 < runs.length && runs[run + 1].first === i + 1) run++;
    let offset = uint(buf, chunks.start + 8 + i * (chunks.type === "co64" ? 8 : 4), chunks.type === "co64");
    if (offset < previousEnd) throw new Error("malformed");
    for (let j = 0; j < runs[run].n; j++) {
      if (index >= count) throw new Error("malformed");
      const end = offset + sizes[index++];
      if (!mdats.some((b) => offset >= b.start && end <= b.end)) throw new Error("malformed");
      let slice = false;
      while (offset < end) {
        if (++nalCount > 100_000) throw new Error("malformed");
        if (offset + lengthSize >= end) throw new Error("malformed");
        const size = buf.readUIntBE(offset, lengthSize); offset += lengthSize;
        if (!size || offset + size > end || buf[offset] & 0x80) throw new Error("malformed");
        const type = buf[offset] & 31;
        if (type < 1 || type > 12) throw new Error("malformed");
        if (type === 7) {
          const dims = spsDimensions(buf.subarray(offset, offset + size));
          if (dims[0] !== width || dims[1] !== height) throw new Error("malformed");
        }
        slice ||= type === 1 || type === 5;
        offset += size;
      }
      if (!slice) throw new Error("malformed");
      previousEnd = end;
    }
  }
  if (index !== count) throw new Error("malformed");
  return trackDuration;
}

/** Reads the facts of an MP4 from its box headers. Pure, never trusts a file name or a client value. */
export function inspectLiveVideo(buf: Buffer): {ok: true; info: LiveVideoInfo} | {ok: false; error: LiveVideoError} {
  if (buf.length > LIVE_VIDEO_LIMITS.maxBytes) return {ok: false, error: "too_large"};
  if (buf.length < 16 || buf.toString("latin1", 4, 8) !== "ftyp") return {ok: false, error: "not_mp4"};
  try {
    const top = boxes(buf, 0, buf.length);
    const ftyp = need(buf, top[0], 8);
    const brands = [buf.toString("latin1", ftyp.start, ftyp.start + 4)];
    for (let at = ftyp.start + 8; at + 4 <= ftyp.end; at += 4) brands.push(buf.toString("latin1", at, at + 4));
    if (brands[0] === "qt  " || !brands.some((brand) => MP4_BRANDS.has(brand))) return {ok: false, error: "not_mp4"};
    const moov = top.find((b) => b.type === "moov");
    if (!moov || !top.some((b) => b.type === "mdat")) return {ok: false, error: "malformed"};
    if (top.some((b) => b.type === "moof") || child(buf, moov, "mvex")) return {ok: false, error: "malformed"};

    const mvhd = need(buf, child(buf, moov, "mvhd"), 20);
    if (buf[mvhd.start] > 1) return {ok: false, error: "malformed"};
    const mvhdWide = buf[mvhd.start] === 1;
    const timescaleAt = mvhd.start + 4 + (mvhdWide ? 16 : 8);
    need(buf, mvhd, timescaleAt - mvhd.start + (mvhdWide ? 12 : 8));
    const timescale = buf.readUInt32BE(timescaleAt);
    const duration = uint(buf, timescaleAt + 4, mvhdWide);
    if (timescale === 0) return {ok: false, error: "malformed"};
    let durationMs = Math.ceil((duration * 1000) / timescale);

    const tracks = boxes(buf, moov.start, moov.end).filter((b) => b.type === "trak").map((trak) => {
      const mdia = need(buf, child(buf, trak, "mdia"), 8);
      const hdlr = need(buf, child(buf, mdia, "hdlr"), 12);
      return {trak, mdia, handler: buf.toString("latin1", hdlr.start + 8, hdlr.start + 12)};
    });
    const video = tracks.filter((track) => track.handler === "vide");
    if (video.length !== 1) return {ok: false, error: "no_video_track"};
    for (const track of tracks) {
      durationMs = Math.max(durationMs,
        Math.ceil(mediaDuration(buf, need(buf, child(buf, track.mdia, "mdhd"), 20))));
    }
    const {trak, mdia} = video[0];

    const minf = need(buf, child(buf, mdia, "minf"), 8);
    const dref = need(buf, child(buf, need(buf, child(buf, minf, "dinf"), 8), "dref"), 8);
    const references = boxes(buf, dref.start + 8, dref.end);
    if (buf.readUInt32BE(dref.start + 4) !== 1 || references.length !== 1 || references[0].type !== "url " ||
      references[0].end - references[0].start !== 4 || buf.readUInt32BE(references[0].start) !== 1) {
      return {ok: false, error: "malformed"};
    }
    const stbl = need(buf, child(buf, minf, "stbl"), 8);
    const stsd = need(buf, child(buf, stbl, "stsd"), 16);
    if (buf.readUInt32BE(stsd.start + 4) !== 1) return {ok: false, error: "malformed"};
    const entries = boxes(buf, stsd.start + 8, stsd.end);
    if (entries.length !== 1) return {ok: false, error: "malformed"};
    const entry = need(buf, entries[0], 78);
    const codec = entry.type;
    if (!H264.has(codec)) return {ok: false, error: "codec"};
    if (buf.readUInt16BE(entry.start + 6) !== 1) return {ok: false, error: "malformed"};
    const encodedWidth = buf.readUInt16BE(entry.start + 24);
    const encodedHeight = buf.readUInt16BE(entry.start + 26);
    const lengthSize = avcConfig(buf, entry, encodedWidth, encodedHeight);
    durationMs = Math.max(durationMs, Math.ceil(sampleDuration(buf, stbl, mdia,
      top.filter((b) => b.type === "mdat"), lengthSize, encodedWidth, encodedHeight)));

    const tkhd = need(buf, child(buf, trak, "tkhd"), 84);
    if (buf[tkhd.start] > 1) return {ok: false, error: "malformed"};
    const tkhdWide = buf[tkhd.start] === 1;
    const matrixAt = tkhd.start + 4 + (tkhdWide ? 32 : 20) + 16;
    need(buf, tkhd, matrixAt - tkhd.start + 44);
    const a = buf.readInt32BE(matrixAt);
    const b = buf.readInt32BE(matrixAt + 4);
    const c = buf.readInt32BE(matrixAt + 12);
    const d = buf.readInt32BE(matrixAt + 16);
    if (!((Math.abs(a) === 65536 && a === d && b === 0 && c === 0) ||
      (a === 0 && d === 0 && Math.abs(b) === 65536 && b === -c)) ||
      buf.readInt32BE(matrixAt + 8) !== 0 || buf.readInt32BE(matrixAt + 20) !== 0 ||
      buf.readInt32BE(matrixAt + 32) !== 0x40000000) return {ok: false, error: "malformed"};
    const storedWidth = Math.round(buf.readUInt32BE(matrixAt + 36) / 65536);
    const storedHeight = Math.round(buf.readUInt32BE(matrixAt + 40) / 65536);
    if (storedWidth !== encodedWidth || storedHeight !== encodedHeight) return {ok: false, error: "malformed"};
    const rotated = a === 0 && d === 0;
    const width = rotated ? storedHeight : storedWidth;
    const height = rotated ? storedWidth : storedHeight;
    if (width <= 0 || height <= 0) return {ok: false, error: "malformed"};

    if (durationMs <= 0) return {ok: false, error: "malformed"};
    if (durationMs > LIVE_VIDEO_LIMITS.maxDurationMs) return {ok: false, error: "too_long"};
    if (height <= width) return {ok: false, error: "landscape"};
    if (width > LIVE_VIDEO_LIMITS.maxWidth || height > LIVE_VIDEO_LIMITS.maxHeight) return {ok: false, error: "too_big_frame"};
    return {ok: true, info: {durationMs, width, height, codec, bytes: buf.length}};
  } catch {
    return {ok: false, error: "malformed"};
  }
}

export const isLiveVideoPath = (path: string): boolean => {
  const name = path.split("/").pop() ?? "";
  return name.startsWith(LIVE_VIDEO_PREFIX) && name.endsWith(".mp4");
};

export const isLiveFramePath = (path: string): boolean => (path.split("/").pop() ?? "").startsWith(LIVE_FRAME_PREFIX);
