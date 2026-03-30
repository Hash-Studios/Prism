import * as admin from "firebase-admin";
import * as fs from "node:fs";
import * as path from "node:path";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const DEFAULT_OUTPUT_PATH = path.resolve(process.cwd(), "tmp", "usersv2-emails.csv");
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type ExportRow = {
  email: string;
  userId: string;
  username: string;
  subscriptionTier: string;
  premium: string;
  createdAt: string;
  lastLoginAt: string;
};

type ExportStats = {
  scanned: number;
  exported: number;
  skippedMissing: number;
  skippedInvalid: number;
  skippedDuplicate: number;
};

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (!args.allowAllEmails) {
    console.error("Refusing to export all users without --all-emails.");
    process.exitCode = 1;
    return;
  }

  const outputPath = path.resolve(process.cwd(), args.outputPath);
  const snapshot = await db.collection("usersv2").get();
  const seenEmails = new Set<string>();
  const rows: ExportRow[] = [];
  const stats: ExportStats = {
    scanned: snapshot.size,
    exported: 0,
    skippedMissing: 0,
    skippedInvalid: 0,
    skippedDuplicate: 0,
  };

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const normalizedEmail = normalizeEmail(data.email);

    if (!normalizedEmail) {
      stats.skippedMissing += 1;
      continue;
    }

    if (!EMAIL_PATTERN.test(normalizedEmail)) {
      stats.skippedInvalid += 1;
      continue;
    }

    if (seenEmails.has(normalizedEmail)) {
      stats.skippedDuplicate += 1;
      continue;
    }

    seenEmails.add(normalizedEmail);
    rows.push({
      email: normalizedEmail,
      userId: doc.id,
      username: stringifyValue(data.username),
      subscriptionTier: stringifyValue(data.subscriptionTier),
      premium: stringifyBoolean(data.premium),
      createdAt: stringifyTimestamp(data.createdAt),
      lastLoginAt: stringifyTimestamp(data.lastLoginAt),
    });
  }

  rows.sort((a, b) => a.email.localeCompare(b.email));
  stats.exported = rows.length;

  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, toCsv(rows), "utf8");

  console.log(`Scanned usersv2 documents: ${stats.scanned}`);
  console.log(`Exported emails: ${stats.exported}`);
  console.log(`Skipped missing emails: ${stats.skippedMissing}`);
  console.log(`Skipped invalid emails: ${stats.skippedInvalid}`);
  console.log(`Skipped duplicate emails: ${stats.skippedDuplicate}`);
  console.log(`CSV written to: ${outputPath}`);
}

function parseArgs(argv: string[]): {allowAllEmails: boolean; outputPath: string} {
  let allowAllEmails = false;
  let outputPath = DEFAULT_OUTPUT_PATH;

  for (const arg of argv) {
    if (arg === "--all-emails") {
      allowAllEmails = true;
      continue;
    }
    if (arg.startsWith("--out=")) {
      const candidate = arg.slice("--out=".length).trim();
      if (candidate) {
        outputPath = candidate;
      }
      continue;
    }
    if (arg === "--help") {
      printUsage();
      process.exit(0);
    }

    console.error(`Unknown argument: ${arg}`);
    printUsage();
    process.exit(1);
  }

  return {allowAllEmails, outputPath};
}

function printUsage(): void {
  console.log(
    "Usage: node lib/scripts/exportUsersV2Emails.js --all-emails [--out=tmp/usersv2-emails.csv]",
  );
}

function normalizeEmail(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }
  return value.toString().trim().toLowerCase();
}

function stringifyValue(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }
  return value.toString().trim();
}

function stringifyBoolean(value: unknown): string {
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  return "";
}

function stringifyTimestamp(value: unknown): string {
  if (typeof value === "string") {
    return value.trim();
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (
    typeof value === "object" &&
    value !== null &&
    "toDate" in value &&
    typeof (value as {toDate: unknown}).toDate === "function"
  ) {
    try {
      return ((value as {toDate: () => Date}).toDate()).toISOString();
    } catch (_) {
      return "";
    }
  }
  return "";
}

function toCsv(rows: ExportRow[]): string {
  const headers: Array<keyof ExportRow> = [
    "email",
    "userId",
    "username",
    "subscriptionTier",
    "premium",
    "createdAt",
    "lastLoginAt",
  ];

  const lines = [
    headers.join(","),
    ...rows.map((row) => headers.map((header) => escapeCsv(row[header])).join(",")),
  ];

  return `${lines.join("\n")}\n`;
}

function escapeCsv(value: string): string {
  if (value.includes(",") || value.includes("\"") || value.includes("\n")) {
    return `"${value.replace(/"/g, "\"\"")}"`;
  }
  return value;
}

void main().catch((error: unknown) => {
  console.error("Failed to export usersv2 emails.", error);
  process.exitCode = 1;
});
