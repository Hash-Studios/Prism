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
  return wide ? Number(buf.readBigUInt64BE(at)) : buf.readUInt32BE(at);
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

    const mvhd = need(buf, child(buf, moov, "mvhd"), 20);
    const mvhdWide = buf[mvhd.start] === 1;
    const timescaleAt = mvhd.start + 4 + (mvhdWide ? 16 : 8);
    need(buf, mvhd, timescaleAt - mvhd.start + (mvhdWide ? 12 : 8));
    const timescale = buf.readUInt32BE(timescaleAt);
    const duration = uint(buf, timescaleAt + 4, mvhdWide);
    if (timescale === 0) return {ok: false, error: "malformed"};
    const durationMs = Math.round((duration * 1000) / timescale);

    const video = boxes(buf, moov.start, moov.end).filter((b) => b.type === "trak").map((trak) => {
      const mdia = need(buf, child(buf, trak, "mdia"), 8);
      const hdlr = need(buf, child(buf, mdia, "hdlr"), 12);
      return {trak, mdia, handler: buf.toString("latin1", hdlr.start + 8, hdlr.start + 12)};
    }).filter((track) => track.handler === "vide");
    if (video.length !== 1) return {ok: false, error: "no_video_track"};
    const {trak, mdia} = video[0];

    const stbl = need(buf, child(buf, need(buf, child(buf, mdia, "minf"), 8), "stbl"), 8);
    const stsd = need(buf, child(buf, stbl, "stsd"), 16);
    const codec = buf.toString("latin1", stsd.start + 12, stsd.start + 16);
    if (!H264.has(codec)) return {ok: false, error: "codec"};

    const tkhd = need(buf, child(buf, trak, "tkhd"), 84);
    const tkhdWide = buf[tkhd.start] === 1;
    const matrixAt = tkhd.start + 4 + (tkhdWide ? 32 : 20) + 16;
    need(buf, tkhd, matrixAt - tkhd.start + 44);
    const a = buf.readInt32BE(matrixAt);
    const d = buf.readInt32BE(matrixAt + 16);
    const storedWidth = Math.round(buf.readUInt32BE(matrixAt + 36) / 65536);
    const storedHeight = Math.round(buf.readUInt32BE(matrixAt + 40) / 65536);
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
