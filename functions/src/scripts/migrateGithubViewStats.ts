/**
 * One-time migration: GitHub dummy.json wallpapers/setups view counters -> Firestore.
 *
 * Usage (from functions/ after npm run build):
 *   node lib/scripts/migrateGithubViewStats.js
 *
 * Either set DUMMY_JSON_PATH to a local JSON file, or provide GitHub credentials:
 *   GH_TOKEN (or GITHUB_TOKEN), GH_USERNAME (or GH_OWNER), GH_REPO_DATA
 * Optional: GH_DATA_JSON_FILE (default dummy.json)
 *
 * Requires: GOOGLE_APPLICATION_CREDENTIALS or gcloud application-default login.
 */
import * as admin from "firebase-admin";
import * as fs from "node:fs";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const WALLPAPER_STATS = "wallpaper_stats";
const SETUP_STATS = "setup_stats";
const BATCH_SIZE = 450;

interface SectionMap {
  [id: string]: Record<string, unknown>;
}

function parseViews(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === "string") {
    const n = parseInt(value, 10);
    return Number.isFinite(n) && n >= 0 ? n : 0;
  }
  return 0;
}

async function loadDummyJson(): Promise<Record<string, unknown>> {
  const fromFile = process.env.DUMMY_JSON_PATH?.trim();
  if (fromFile) {
    const raw = fs.readFileSync(fromFile, "utf8");
    return JSON.parse(raw) as Record<string, unknown>;
  }

  const token = (process.env.GH_TOKEN ?? process.env.GITHUB_TOKEN ?? "").trim();
  const owner = (process.env.GH_USERNAME ?? process.env.GH_OWNER ?? "").trim();
  const repo = (process.env.GH_REPO_DATA ?? "").trim();
  const filePath = (process.env.GH_DATA_JSON_FILE ?? "dummy.json").trim();

  if (!token || !owner || !repo) {
    throw new Error(
      "Set DUMMY_JSON_PATH to a local dummy.json, or set GH_TOKEN, GH_USERNAME, GH_REPO_DATA",
    );
  }

  const url = `https://api.github.com/repos/${owner}/${repo}/contents/${filePath}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GitHub API ${res.status}: ${text.slice(0, 500)}`);
  }
  const body = (await res.json()) as {content?: string; encoding?: string};
  const b64 = (body.content ?? "").replace(/\n/g, "");
  const decoded = Buffer.from(b64, "base64").toString("utf8");
  return JSON.parse(decoded) as Record<string, unknown>;
}

function asSection(data: Record<string, unknown>, key: string): SectionMap {
  const v = data[key];
  if (!v || typeof v !== "object" || Array.isArray(v)) {
    return {};
  }
  return v as SectionMap;
}

async function commitBatch(
  writes: Array<{collection: string; id: string; views: number}>,
): Promise<void> {
  let batch = db.batch();
  let count = 0;
  for (const w of writes) {
    const ref = db.collection(w.collection).doc(w.id);
    batch.set(ref, {views: w.views}, {merge: true});
    count++;
    if (count >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

async function main(): Promise<void> {
  const root = await loadDummyJson();
  const wallpapers = asSection(root, "wallpapers");
  const setups = asSection(root, "setups");

  const writes: Array<{collection: string; id: string; views: number}> = [];

  for (const [id, entry] of Object.entries(wallpapers)) {
    const upper = id.trim().toUpperCase();
    if (!upper) continue;
    const views = parseViews(entry?.views);
    writes.push({collection: WALLPAPER_STATS, id: upper, views});
  }

  for (const [id, entry] of Object.entries(setups)) {
    const upper = id.trim().toUpperCase();
    if (!upper) continue;
    const views = parseViews(entry?.views);
    writes.push({collection: SETUP_STATS, id: upper, views});
  }

  console.log(
    `Migrating ${Object.keys(wallpapers).length} wallpaper rows and ${Object.keys(setups).length} setup rows (${writes.length} docs)...`,
  );
  await commitBatch(writes);
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
