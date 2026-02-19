#!/usr/bin/env node

import { execSync } from 'node:child_process';

function parseArgs(argv) {
  const args = {
    project: process.env.FIREBASE_PROJECT_ID || 'prism-wallpapers',
    pageSize: 100,
    maxPages: 200,
    dryRun: false,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const current = argv[i];
    if (current === '--dry-run') {
      args.dryRun = true;
      continue;
    }
    if (current === '--project' && argv[i + 1] != null) {
      args.project = argv[i + 1];
      i += 1;
      continue;
    }
    if (current === '--page-size' && argv[i + 1] != null) {
      args.pageSize = Number.parseInt(argv[i + 1], 10);
      i += 1;
      continue;
    }
    if (current === '--max-pages' && argv[i + 1] != null) {
      args.maxPages = Number.parseInt(argv[i + 1], 10);
      i += 1;
      continue;
    }
    if (current === '--help' || current === '-h') {
      printUsageAndExit(0);
    }
    console.error(`Unknown arg: ${current}`);
    printUsageAndExit(1);
  }

  if (!Number.isFinite(args.pageSize) || args.pageSize < 1 || args.pageSize > 1000) {
    console.error('--page-size must be between 1 and 1000');
    process.exit(1);
  }
  if (!Number.isFinite(args.maxPages) || args.maxPages < 1) {
    console.error('--max-pages must be >= 1');
    process.exit(1);
  }
  return args;
}

function printUsageAndExit(code) {
  console.log(`
Usage:
  node tool/backfill_ai_watermarked_walls.mjs [--dry-run] [--project <id>] [--page-size <n>] [--max-pages <n>]

Authentication:
  1) Preferred: export FIRESTORE_ACCESS_TOKEN="<oauth token>"
  2) Fallback: gcloud auth application-default login + gcloud auth application-default print-access-token

Examples:
  node tool/backfill_ai_watermarked_walls.mjs --dry-run
  node tool/backfill_ai_watermarked_walls.mjs --project prism-wallpapers --page-size 200
`);
  process.exit(code);
}

function getAccessToken() {
  const envToken = process.env.FIRESTORE_ACCESS_TOKEN?.trim();
  if (envToken?.length > 0) {
    return envToken;
  }
  try {
    const token = execSync('gcloud auth application-default print-access-token', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    if (token.length === 0) {
      throw new Error('empty token');
    }
    return token;
  } catch (error) {
    console.error('Unable to get access token from gcloud. Set FIRESTORE_ACCESS_TOKEN or run gcloud auth.');
    console.error(String(error));
    process.exit(1);
  }
}

function readStringField(fields, key) {
  const raw = fields?.[key];
  if (raw == null || typeof raw !== 'object') return '';
  return typeof raw.stringValue === 'string' ? raw.stringValue : '';
}

function readBoolField(fields, key) {
  const raw = fields?.[key];
  if (raw == null || typeof raw !== 'object') return false;
  return raw.booleanValue === true;
}

async function fetchJson(url, init) {
  const response = await fetch(url, init);
  const text = await response.text();
  let body = null;
  if (text.length > 0) {
    try {
      body = JSON.parse(text);
    } catch {
      body = null;
    }
  }
  return { ok: response.ok, status: response.status, body };
}

const args = parseArgs(process.argv);
const token = getAccessToken();
const project = args.project;
const baseUrl = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const authHeaders = {
  Authorization: `Bearer ${token}`,
  Accept: 'application/json',
};

const stats = {
  pages: 0,
  docsScanned: 0,
  aiDocs: 0,
  alreadyMigrated: 0,
  missingGenerationId: 0,
  missingGenerationDoc: 0,
  missingImageUrls: 0,
  eligible: 0,
  updated: 0,
  updateFailed: 0,
};

let pageToken = '';
for (let page = 1; page <= args.maxPages; page += 1) {
  const listUrl = new URL(`${baseUrl}/walls`);
  listUrl.searchParams.set('pageSize', String(args.pageSize));
  if (pageToken.length > 0) {
    listUrl.searchParams.set('pageToken', pageToken);
  }

  const pageResult = await fetchJson(listUrl.toString(), { method: 'GET', headers: authHeaders });
  if (!pageResult.ok) {
    console.error(`Failed to list walls (page ${page}). status=${pageResult.status}`);
    console.error(JSON.stringify(pageResult.body));
    process.exit(1);
  }

  const docs = Array.isArray(pageResult.body?.documents) ? pageResult.body.documents : [];
  const nextPageToken = typeof pageResult.body?.nextPageToken === 'string' ? pageResult.body.nextPageToken : '';
  stats.pages += 1;

  for (const doc of docs) {
    stats.docsScanned += 1;
    const docName = typeof doc?.name === 'string' ? doc.name : '';
    const fields = doc?.fields ?? {};

    if (!readBoolField(fields, 'isAiGenerated')) {
      continue;
    }
    stats.aiDocs += 1;

    if (fields.aiWatermarkMigratedAt != null) {
      stats.alreadyMigrated += 1;
      continue;
    }

    const generationId = readStringField(fields, 'aiGenerationId');
    if (generationId.length === 0) {
      stats.missingGenerationId += 1;
      continue;
    }

    const generationUrl = `${baseUrl}/aiGenerations/${encodeURIComponent(generationId)}`;
    const generationResult = await fetchJson(generationUrl, { method: 'GET', headers: authHeaders });
    if (!generationResult.ok) {
      if (generationResult.status === 404) {
        stats.missingGenerationDoc += 1;
        continue;
      }
      console.error(`Failed to load aiGenerations/${generationId}. status=${generationResult.status}`);
      console.error(JSON.stringify(generationResult.body));
      process.exit(1);
    }

    const generationFields = generationResult.body?.fields ?? {};
    const watermarkedUrl = readStringField(generationFields, 'watermarkedImageUrl');
    const originalUrl = readStringField(generationFields, 'imageUrl');
    if (watermarkedUrl.length === 0 || originalUrl.length === 0) {
      stats.missingImageUrls += 1;
      continue;
    }

    stats.eligible += 1;
    if (args.dryRun) {
      console.log(`[DRY-RUN] ${docName} -> watermarked=${watermarkedUrl} original=${originalUrl}`);
      continue;
    }

    const patchUrl = new URL(`https://firestore.googleapis.com/v1/${docName}`);
    patchUrl.searchParams.append('updateMask.fieldPaths', 'wallpaper_url');
    patchUrl.searchParams.append('updateMask.fieldPaths', 'wallpaper_thumb');
    patchUrl.searchParams.append('updateMask.fieldPaths', 'aiOriginalImageUrl');
    patchUrl.searchParams.append('updateMask.fieldPaths', 'aiWatermarkMigratedAt');

    const patchBody = {
      fields: {
        wallpaper_url: { stringValue: watermarkedUrl },
        wallpaper_thumb: { stringValue: watermarkedUrl },
        aiOriginalImageUrl: { stringValue: originalUrl },
        aiWatermarkMigratedAt: { timestampValue: new Date().toISOString() },
      },
    };

    const patchResult = await fetchJson(patchUrl.toString(), {
      method: 'PATCH',
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(patchBody),
    });

    if (!patchResult.ok) {
      stats.updateFailed += 1;
      console.error(`Failed to update ${docName}. status=${patchResult.status}`);
      console.error(JSON.stringify(patchResult.body));
      continue;
    }

    stats.updated += 1;
    if (stats.updated % 25 === 0) {
      console.log(`Updated ${stats.updated} AI wall docs so far...`);
    }
  }

  if (nextPageToken.length === 0) {
    break;
  }
  pageToken = nextPageToken;
}

console.log('Backfill summary:');
console.log(JSON.stringify(stats, null, 2));
if (args.dryRun) {
  console.log('Dry-run mode: no documents were updated.');
}
