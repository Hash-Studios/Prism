import sharp from "sharp";

/** Mulberry32: the same seed gives the same numbers in [0, 1). */
export function seededRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** A flat PNG of one colour. */
export function flatPng(width: number, height: number, grey = 40): Promise<Buffer> {
  return sharp({create: {width, height, channels: 3, background: {r: grey, g: grey, b: grey}}}).png().toBuffer();
}

/** A grey PNG that gets brighter from left to right, or from right to left. */
export function gradientPng(width: number, height: number, leftToRight = true): Promise<Buffer> {
  const raw = Buffer.alloc(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const v = Math.round(255 * x / (width - 1));
      raw[y * width + x] = leftToRight ? v : 255 - v;
    }
  }
  return sharp(raw, {raw: {width, height, channels: 1}}).png().toBuffer();
}
