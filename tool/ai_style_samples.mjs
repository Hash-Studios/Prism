#!/usr/bin/env node
// Makes one sample image per AI style and uploads a tile and a sheet size to R2.
//
//   node tool/ai_style_samples.mjs --dry-run
//   doppler run --project prism --config prd -- node tool/ai_style_samples.mjs --skip-upload
//   doppler run --project prism --config prd -- node tool/ai_style_samples.mjs
//
// Options: --dry-run (no secret, no spend, no writes), --skip-upload (generate and convert only, to review the
// files in --out first), --only=<slug,slug>, --out=<dir> (default build/ai-style-samples), --replace=<slug,slug>
// (make and upload those styles again even when their files exist; only before the samples ship in a release,
// because apps cache the URLs as immutable).
// The real run needs STUDIO_SECRET and sharp from functions/node_modules (cd functions && npm ci).

import { mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { stylePromptSuffix } from '../infra/cloudflare/worker/src/ai_style_prompt.ts';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const STYLE_ENUM = path.join(REPO_ROOT, 'lib/features/ai_wallpaper/domain/entities/ai_style_preset.dart');

export const VERSION = 'v1';
export const SUBJECT = 'a lighthouse on a cliff at dusk';
// The balanced tier model. The studio route refuses the fast tier model (Z-Image is consumer only).
export const MODEL = 'fal-ai/bytedance/seedream/v5/lite/text-to-image';
export const COST_PER_IMAGE_USD = 0.04;
export const WIDTH = 1080;
export const HEIGHT = 1920;
// Seedream 5 Lite takes no seed, so the seed only names the attempt. A new seed for a style makes a new image, but
// only before upload: an uploaded file is skipped, and its URL is cached as immutable. To replace uploaded samples,
// bump VERSION and AiStylePreset.sampleVersion together.
export const DEFAULT_SEED = 20261029;
export const SEED_OVERRIDES = { 'mesh-gradient': 20261030, '3d-render': 20261031 };
export const SIZES = { tile: { width: 288, height: 360 }, sheet: { width: 540, height: 960 } };

const API_BASE = 'https://prismwalls.com/api/ai';
export const ASSET_BASE = `${API_BASE}/assets/ai/studio`;

/** Reads `name('apiValue', ...)` entries from the Dart enum, so the script and the app share one style list. */
export function readStyles(dartSource) {
  const styles = [...dartSource.matchAll(/^\s+(\w+)\('([^']+)',\s*'[^']*',/gm)].map((m) => ({
    name: m[1],
    apiValue: m[2],
    slug: slugOf(m[2]),
  }));
  if (styles.length === 0) throw new Error(`No styles found in ${STYLE_ENUM}`);
  return styles;
}

/** Same rule as AiStylePreset.sampleSlug: 'mesh gradient' is 'mesh-gradient'. */
export function slugOf(apiValue) {
  return apiValue.replace(/[^a-z0-9]+/g, '-');
}

export const fileName = (slug, size) => `style-samples-${VERSION}-${slug}-${size}.webp`;
export const sampleUrl = (slug, size) => `${ASSET_BASE}/${fileName(slug, size)}`;
export const seedFor = (slug) => SEED_OVERRIDES[slug] ?? DEFAULT_SEED;
export const generationId = (slug) => `style-samples-${VERSION}-${slug}-${seedFor(slug)}`;
// The same text the worker adds for an app generation.
export const promptFor = (style) => `${SUBJECT}, ${stylePromptSuffix(style.apiValue)}`;

/** One row per style and size. A style needs a generation only when one of its sizes is missing or replaced. */
export async function planSamples({ styles, exists, replace = [] }) {
  const items = [];
  for (const style of styles) {
    for (const size of Object.keys(SIZES)) {
      const url = sampleUrl(style.slug, size);
      const present = !replace.includes(style.slug) && (await exists(url));
      items.push({ style, size, url, fileName: fileName(style.slug, size), exists: present });
    }
  }
  const generate = styles.filter((style) => items.some((i) => i.style === style && !i.exists));
  return { items, generate, costUsd: Number((generate.length * COST_PER_IMAGE_USD).toFixed(2)) };
}

export async function remoteExists(url, fetchImpl = fetch) {
  const response = await fetchImpl(url, { method: 'HEAD' });
  if (response.status === 200) return true;
  if (response.status === 404) return false;
  throw new Error(`HEAD ${url} returned ${response.status}`);
}

function parseArgs(argv) {
  const value = (name) => argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
  return {
    dryRun: argv.includes('--dry-run'),
    skipUpload: argv.includes('--skip-upload'),
    only: value('only')?.split(',').filter(Boolean),
    replace: value('replace')?.split(',').filter(Boolean) ?? [],
    out: path.resolve(value('out') ?? path.join(REPO_ROOT, 'build/ai-style-samples')),
  };
}

const fileExists = (file) => access(file).then(() => true, () => false);

async function studioFetch(pathname, init, secret) {
  const response = await fetch(`${API_BASE}/studio/${pathname}`, {
    ...init,
    headers: { ...init.headers, 'x-studio-secret': secret },
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${init.method} ${pathname} returned ${response.status}: ${text}`);
  return JSON.parse(text);
}

/** The raw image for [style]. A cached file skips the call; the worker replays a finished id without a second bill. */
async function rawImage(style, out, secret) {
  const id = generationId(style.slug);
  const cached = path.join(out, 'raw', `${id}.img`);
  if (await fileExists(cached)) return readFile(cached);
  const result = await studioFetch(
    'generations',
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ id, prompt: promptFor(style), model: MODEL, width: WIDTH, height: HEIGHT, seed: seedFor(style.slug) }),
    },
    secret,
  );
  const image = await fetch(result.imageUrl);
  if (!image.ok) throw new Error(`GET ${result.imageUrl} returned ${image.status}`);
  const bytes = Buffer.from(await image.arrayBuffer());
  await mkdir(path.dirname(cached), { recursive: true });
  await writeFile(cached, bytes);
  console.log(`generated ${style.slug} (${id}, ${result.width}x${result.height})`);
  return bytes;
}

function loadSharp() {
  try {
    return createRequire(path.join(REPO_ROOT, 'functions/package.json'))('sharp');
  } catch {
    throw new Error('sharp is missing. Run: cd functions && npm ci');
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const all = readStyles(await readFile(STYLE_ENUM, 'utf8'));
  const unknown = [...(args.only ?? []), ...args.replace].filter((slug) => !all.some((s) => s.slug === slug));
  if (unknown.length > 0) throw new Error(`Unknown style: ${unknown.join(', ')}`);
  const styles = args.only ? all.filter((s) => args.only.includes(s.slug)) : all;
  const plan = await planSamples({ styles, exists: (url) => remoteExists(url), replace: args.replace });

  for (const item of plan.items) {
    console.log(`${item.exists ? 'skip  ' : 'create'} ${item.fileName}`);
  }
  console.log(
    `${plan.items.length} files (${styles.length} styles x ${Object.keys(SIZES).length} sizes), ` +
      `${plan.items.filter((i) => !i.exists).length} missing, ${plan.generate.length} generations, ` +
      `about $${plan.costUsd.toFixed(2)} at $${COST_PER_IMAGE_USD} each (${MODEL}).`,
  );
  if (args.dryRun || plan.generate.length === 0) return;

  const secret = process.env.STUDIO_SECRET;
  if (!secret) throw new Error('STUDIO_SECRET is not set. Run through doppler (see the header).');
  const sharp = loadSharp();
  const versionDir = path.join(args.out, VERSION);
  await mkdir(versionDir, { recursive: true });
  for (const style of plan.generate) {
    const raw = await rawImage(style, args.out, secret);
    for (const item of plan.items.filter((i) => i.style === style && !i.exists)) {
      const { width, height } = SIZES[item.size];
      const webp = await sharp(raw).resize(width, height, { fit: 'cover', position: 'centre' }).webp({ quality: 80 }).toBuffer();
      await writeFile(path.join(versionDir, item.fileName), webp);
      if (args.skipUpload) continue;
      await studioFetch(
        `assets/ai/studio/${item.fileName}`,
        { method: 'PUT', headers: { 'content-type': 'image/webp' }, body: webp },
        secret,
      );
      console.log(`uploaded ${item.url}`);
    }
  }
  console.log(args.skipUpload ? `Review the files in ${versionDir}, then run again without --skip-upload.` : 'Done.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message ?? error);
    process.exitCode = 1;
  });
}
