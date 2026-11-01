import * as admin from "firebase-admin";
import {appendFileSync, writeFileSync} from "node:fs";
import type {PromoCodeInput} from "../promoCodes";

const DAY_MS = 86_400_000;
const MAX_COUNT = 500;
const MAX_EXPIRES_DAYS = 366;

export const USAGE = "Usage: node lib/scripts/createPromoCodes.js " +
  "--project <project-id> --count <1-500> --type coins|premiumDays --amount <int> --expires-days <1-366> " +
  "[--max <int, default 1>] [--min-age-days <int, default 0>] [--new-users-days <int>] [--label <text>] " +
  "(--out <file.csv> | --dry-run)";

const VALUE_FLAGS = [
  "--project", "--count", "--type", "--amount", "--max", "--expires-days",
  "--min-age-days", "--new-users-days", "--label", "--out",
];

export interface CreatePromoCodesOptions {
  projectId: string;
  count: number;
  type: "coins" | "premiumDays";
  amount: number;
  maxRedemptions: number;
  expiresDays: number;
  minAccountAgeDays: number;
  newUsersOnlyDays: number | null;
  label: string;
  out: string | null;
  dryRun: boolean;
}

export interface CreatePromoCodesDeps {
  now: () => number;
  log: (line: string) => void;
  /** Creates the empty CSV file. Throws when it already exists, before any code is written. */
  claimFile: (path: string) => void;
  appendFile: (path: string, data: string) => void;
  write: (input: PromoCodeInput, createdBy: string, nowMs: number) => Promise<string>;
}

function intFlag(name: string, raw: string, min: number, max: number): number {
  if (!/^-?\d+$/.test(raw)) throw new Error(`${name} must be a whole number. ${USAGE}`);
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be between ${min} and ${max}. ${USAGE}`);
  }
  return value;
}

export function parseCreatePromoCodesArgs(argv: readonly string[]): CreatePromoCodesOptions {
  const values = new Map<string, string>();
  let dryRun = false;
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === "--dry-run" && !dryRun) {
      dryRun = true;
    } else if (VALUE_FLAGS.includes(flag) && !values.has(flag)) {
      const value = argv[++i];
      if (value === undefined || value.startsWith("--")) throw new Error(`Missing value for ${flag}. ${USAGE}`);
      values.set(flag, value);
    } else {
      throw new Error(`Unknown or duplicate argument: ${flag}. ${USAGE}`);
    }
  }
  const required = (flag: string): string => {
    const value = values.get(flag);
    if (value === undefined) throw new Error(`${flag} is required. ${USAGE}`);
    return value;
  };

  const projectId = values.get("--project");
  if (!projectId || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error(`An explicit 6-30 character project ID is required. ${USAGE}`);
  }
  const count = intFlag("--count", required("--count"), 1, MAX_COUNT);
  const type = required("--type");
  if (type !== "coins" && type !== "premiumDays") throw new Error(`--type must be coins or premiumDays. ${USAGE}`);
  // Ranges for amount and max are checked by parsePromoCodeInput, the same check the admin callable uses.
  const amount = intFlag("--amount", required("--amount"), Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER);
  const expiresDays = intFlag("--expires-days", required("--expires-days"), 1, MAX_EXPIRES_DAYS);
  const maxRedemptions = intFlag("--max", values.get("--max") ?? "1", 1, Number.MAX_SAFE_INTEGER);
  const minAccountAgeDays = intFlag("--min-age-days", values.get("--min-age-days") ?? "0", 0, Number.MAX_SAFE_INTEGER);
  const newUsersRaw = values.get("--new-users-days");
  const newUsersOnlyDays = newUsersRaw === undefined ?
    null : intFlag("--new-users-days", newUsersRaw, 1, Number.MAX_SAFE_INTEGER);
  const label = values.get("--label") ?? "";
  const out = values.get("--out") ?? null;
  if (dryRun && out !== null) throw new Error(`--out cannot be used with --dry-run. ${USAGE}`);
  if (!dryRun && out === null) throw new Error(`--out is required unless --dry-run. ${USAGE}`);
  if (out !== null && !out.endsWith(".csv")) throw new Error(`--out must be a .csv path. ${USAGE}`);
  return {
    projectId, count, type, amount, maxRedemptions, expiresDays, minAccountAgeDays,
    newUsersOnlyDays, label, out, dryRun,
  };
}

export const defaultDeps: CreatePromoCodesDeps = {
  now: () => Date.now(),
  log: (line) => console.log(line),
  claimFile: (path) => writeFileSync(path, "", {mode: 0o600, flag: "wx"}),
  appendFile: (path, data) => appendFileSync(path, data),
  // Loaded lazily: promoCodes loads common, which starts the default app, and main must select the project first.
  write: async (input, createdBy, nowMs) =>
    (await import("../promoCodes.js")).writePromoCode(input, createdBy, nowMs),
};

export async function run(argv: readonly string[], deps: CreatePromoCodesDeps = defaultDeps): Promise<void> {
  const options = parseCreatePromoCodesArgs(argv);
  const {parsePromoCodeInput} = await import("../promoCodes.js");
  const now = deps.now();
  // Every code in the batch has the same rules, so one validation covers the whole batch before anything is written.
  const input = parsePromoCodeInput({
    type: options.type,
    amount: options.amount,
    maxRedemptions: options.maxRedemptions,
    expiresAtMs: now + options.expiresDays * DAY_MS,
    minAccountAgeDays: options.minAccountAgeDays,
    newUsersOnlyDays: options.newUsersOnlyDays,
    label: options.label,
  }, now);
  const expiresAt = new Date(input.expiresAtMs).toISOString();

  if (options.dryRun) {
    deps.log("Dry run. Nothing is written and no codes are printed.");
    deps.log(`Count: ${options.count}`);
    deps.log(`Type: ${options.type}`);
    deps.log(`Amount: ${options.amount}`);
    deps.log(`Max redemptions per code: ${options.maxRedemptions}`);
    deps.log(`Expires: ${expiresAt}`);
    deps.log(`Min account age days: ${options.minAccountAgeDays}`);
    deps.log(`New users only days: ${options.newUsersOnlyDays ?? "none"}`);
    deps.log(`Label: ${options.label || "(none)"}`);
    return;
  }

  const out = options.out as string;
  try {
    deps.claimFile(out);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "EEXIST") throw new Error(`Refusing to overwrite ${out}.`);
    throw err;
  }
  const codes: string[] = [];
  deps.appendFile(out, "code,type,amount,maxRedemptions,expiresAt\n");
  try {
    for (let i = 0; i < options.count; i++) {
      const code = await deps.write(input, "cli:createPromoCodes", now);
      codes.push(code);
      deps.appendFile(out, [code, options.type, options.amount, options.maxRedemptions, expiresAt].join(",") + "\n");
    }
  } catch {
    throw new Error(`Stopped after ${codes.length} of ${options.count} codes; check the partial CSV at ${out} before retrying.`);
  }
  deps.log(`Created ${codes.length} promo codes and wrote them to ${out}.`);
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  if (argv.length === 1 && argv[0] === "--help") {
    console.log(USAGE);
    return;
  }
  const options = parseCreatePromoCodesArgs(argv);
  // common.ts starts the default app with no project when it loads, so select the explicit project first.
  if (!admin.apps.length) admin.initializeApp({projectId: options.projectId});
  try {
    await run(argv, defaultDeps);
  } finally {
    await admin.app().delete();
  }
}

if (require.main === module) {
  void main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
