/** Builds small MP4 files for the live video tests. Writes only the boxes that inspectLiveVideo reads. */

/** One ISO BMFF box: 4-byte big-endian size, 4-char type, then the payloads. */
export function box(type: string, ...payloads: Buffer[]): Buffer {
  const body = Buffer.concat(payloads);
  const head = Buffer.alloc(8);
  head.writeUInt32BE(body.length + 8, 0);
  head.write(type, 4, "latin1");
  return Buffer.concat([head, body]);
}

const ints = (...values: number[]): Buffer => {
  const out = Buffer.alloc(values.length * 4);
  values.forEach((value, index) => out.writeUInt32BE(value >>> 0, index * 4));
  return out;
};

export type Mp4Options = {
  brand?: string;
  codec?: string;
  timescale?: number;
  duration?: number;
  width?: number;
  height?: number;
  rotate?: boolean;
  video?: boolean;
  mdat?: boolean;
  mvhdVersion?: 0 | 1;
};

/** A minimal MP4: ftyp, moov (mvhd, one trak) and mdat. Stored width and height are the tkhd values. */
export function mp4(options: Mp4Options = {}): Buffer {
  const {brand = "isom", codec = "avc1", timescale = 1000, duration = 5000, width = 1080, height = 1920,
    rotate = false, video = true, mdat = true, mvhdVersion = 0} = options;
  const ftyp = box("ftyp", Buffer.from(brand, "latin1"), ints(0), Buffer.from(brand, "latin1"));

  const version = Buffer.alloc(4);
  version[0] = mvhdVersion;
  const times = Buffer.alloc(mvhdVersion === 1 ? 16 : 8);
  const durationField = Buffer.alloc(mvhdVersion === 1 ? 8 : 4);
  if (mvhdVersion === 1) durationField.writeBigUInt64BE(BigInt(duration));
  else durationField.writeUInt32BE(duration, 0);
  const mvhd = box("mvhd", version, times, ints(timescale), durationField,
    Buffer.alloc(100 - 8 - times.length - durationField.length));

  const matrix = rotate ? [0, 0x10000, 0, -65536, 0, 0, 0, 0, 0x40000000] :
    [0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000];
  const tkhd = box("tkhd", Buffer.alloc(4), Buffer.alloc(20), Buffer.alloc(16), ints(...matrix),
    ints(width * 65536, height * 65536));
  const hdlr = box("hdlr", Buffer.alloc(4), Buffer.alloc(4), Buffer.from(video ? "vide" : "soun", "latin1"),
    Buffer.alloc(12), Buffer.from([0]));
  const stsd = box("stsd", Buffer.alloc(4), ints(1), box(codec, Buffer.alloc(78)));
  const trak = box("trak", tkhd, box("mdia", hdlr, box("minf", box("stbl", stsd))));
  const moov = box("moov", mvhd, trak);

  const parts = [ftyp, moov];
  if (mdat) parts.push(box("mdat"));
  return Buffer.concat(parts);
}
