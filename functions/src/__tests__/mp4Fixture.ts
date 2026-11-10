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
  headerOnly?: boolean;
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
  const fields: number[] = [];
  const bits = (value: number, count: number) => {
    for (let i = count - 1; i >= 0; i--) fields.push((value >>> i) & 1);
  };
  const ue = (value: number) => {
    const size = Math.floor(Math.log2(value + 1)); bits(0, size); bits(value + 1, size + 1);
  };
  bits(66, 8); bits(0, 8); bits(40, 8);
  ue(0); ue(0); ue(0); ue(0); ue(1); bits(0, 1);
  ue(Math.ceil(width / 16) - 1); ue(Math.ceil(height / 16) - 1); bits(1, 1); bits(1, 1); bits(1, 1);
  ue(0); ue((Math.ceil(width / 16) * 16 - width) / 2); ue(0); ue((Math.ceil(height / 16) * 16 - height) / 2);
  bits(0, 1); bits(1, 1);
  while (fields.length % 8) fields.push(0);
  const sps = Buffer.from([0x67, ...Array.from({length: fields.length / 8}, (_, i) =>
    fields.slice(i * 8, i * 8 + 8).reduce((n, b) => n * 2 + b, 0))]);
  const spsSize = Buffer.alloc(2); spsSize.writeUInt16BE(sps.length);
  const avcC = box("avcC", Buffer.from([1, 66, 0, 40, 255, 225]), spsSize, sps,
    Buffer.from([1, 0, 2, 0x68, 0x80]));
  const visual = Buffer.alloc(78);
  visual.writeUInt16BE(1, 6);
  visual.writeUInt16BE(width, 24); visual.writeUInt16BE(height, 26);
  const stsd = box("stsd", Buffer.alloc(4), ints(1), box(codec, visual, ...(options.headerOnly ? [] : [avcC])));
  const sample = Buffer.from([0, 0, 0, 2, 0x65, 0x80]);
  const stco = box("stco", ints(0, 1, 0));
  const tables = options.headerOnly ? [] : [box("stts", ints(0, 1, 1, duration)), box("stsz", ints(0, sample.length, 1)),
    box("stsc", ints(0, 1, 1, 1, 1)), stco];
  const mdhd = box("mdhd", Buffer.alloc(12), ints(timescale, duration), Buffer.alloc(4));
  const trak = box("trak", tkhd, box("mdia", hdlr, ...(options.headerOnly ? [] : [mdhd]),
    box("minf", box("dinf", box("dref", ints(0, 1), box("url ", ints(1)))), box("stbl", stsd, ...tables))));
  const moov = box("moov", mvhd, trak);
  if (!options.headerOnly) moov.writeUInt32BE(ftyp.length + moov.length + 8, moov.indexOf(Buffer.from("stco")) + 12);

  const parts = [ftyp, moov];
  if (mdat) parts.push(box("mdat", ...(options.headerOnly ? [] : [sample])));
  return Buffer.concat(parts);
}
