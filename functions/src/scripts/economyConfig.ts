import * as admin from "firebase-admin";

import {db} from "../common";
import {DEFAULT_ECONOMY, ECONOMY_CONFIG_DOC, EconomyConfig, parseEconomy} from "../economy";

export type ConfigArgs = {sets: Array<[string, unknown]>; apply: boolean; init: boolean};
export type ConfigPlan = {next: EconomyConfig; overrides: Record<string, unknown>; diff: string[]};

type Json = Record<string, unknown>;

const isRecord = (value: unknown): value is Json =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** Numbers, booleans, null and JSON arrays or objects parse as JSON. Anything else stays a string. */
export function parseValue(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

/** `--set path=value` or `--set=path=value`, repeatable. */
export function parseConfigArgs(argv: string[]): ConfigArgs {
  const sets: Array<[string, unknown]> = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg !== "--set" && !arg.startsWith("--set=")) continue;
    const pair = arg === "--set" ? argv[++i] ?? "" : arg.slice(6);
    const eq = pair.indexOf("=");
    if (eq < 1) throw new Error(`--set needs path=value, got "${pair}"`);
    sets.push([pair.slice(0, eq), parseValue(pair.slice(eq + 1))]);
  }
  return {sets, apply: argv.includes("--apply"), init: argv.includes("--init")};
}

function segmentsOf(path: string): string[] {
  const segments = path.split(".");
  if (segments.some((s) => s === "" || s === "__proto__" || s === "constructor" || s === "prototype")) {
    throw new Error(`Bad path "${path}"`);
  }
  return segments;
}

function setPath(target: Json, path: string, value: unknown): void {
  const segments = segmentsOf(path);
  let node = target;
  for (const segment of segments.slice(0, -1)) {
    if (!isRecord(node[segment])) node[segment] = {};
    node = node[segment] as Json;
  }
  node[segments[segments.length - 1]] = value;
}

function getPath(source: unknown, path: string): unknown {
  let node = source;
  for (const segment of segmentsOf(path)) {
    if (!isRecord(node)) return undefined;
    node = node[segment];
  }
  return node;
}

function flatten(value: unknown, prefix = "", out: Record<string, unknown> = {}): Record<string, unknown> {
  if (isRecord(value)) {
    for (const [key, child] of Object.entries(value)) flatten(child, prefix ? `${prefix}.${key}` : key, out);
  } else {
    out[prefix] = value;
  }
  return out;
}

/**
 * Applies the overrides onto the live config and checks each one survives `parseEconomy`.
 * parseEconomy drops unknown keys and wrong types, so a dropped override is an error here.
 */
export function planConfig(liveRaw: unknown, sets: Array<[string, unknown]>): ConfigPlan {
  const current = parseEconomy(liveRaw);
  const draft = JSON.parse(JSON.stringify(current)) as Json;
  const overrides: Json = {};
  for (const [path, value] of sets) {
    setPath(draft, path, value);
    setPath(overrides, path, value);
  }
  const next = parseEconomy(draft);
  for (const [path, value] of sets) {
    if (JSON.stringify(getPath(next, path)) !== JSON.stringify(value)) {
      throw new Error(`Rejected ${path}=${JSON.stringify(value)}: unknown key or wrong type`);
    }
  }
  const before = flatten(current);
  const after = flatten(next);
  const diff = Object.keys({...before, ...after})
    .filter((key) => JSON.stringify(before[key]) !== JSON.stringify(after[key]))
    .map((key) => `${key}: ${JSON.stringify(before[key])} -> ${JSON.stringify(after[key])}`);
  return {next, overrides, diff};
}

// Prints the live economy config, or changes it. Dry run unless --apply. Safe to run again.
// Usage: npm run economy:config -- [--init] [--set path=value ...] [--apply]
async function main(): Promise<void> {
  const args = parseConfigArgs(process.argv.slice(2));
  const ref = db.doc(ECONOMY_CONFIG_DOC);
  const snap = await ref.get();
  const updatedAt = admin.firestore.FieldValue.serverTimestamp();

  if (args.init) {
    if (snap.exists) {
      console.log(`${ECONOMY_CONFIG_DOC} already exists. Nothing to initialise.`);
    } else {
      console.log(JSON.stringify(DEFAULT_ECONOMY, null, 2));
      if (args.apply) await ref.set({...DEFAULT_ECONOMY, updatedAt});
      console.log(args.apply ? "Wrote the default config." : "Dry run: nothing was written. Add --apply to write.");
    }
    if (args.sets.length === 0) return;
  }

  if (args.sets.length === 0) {
    console.log(JSON.stringify(parseEconomy(snap.exists ? snap.data() : null), null, 2));
    return;
  }

  const live = args.init && !snap.exists ? DEFAULT_ECONOMY : snap.exists ? snap.data() : null;
  const plan = planConfig(live, args.sets);
  console.log(plan.diff.length ? plan.diff.join("\n") : "No change.");
  if (args.apply) {
    await ref.set({...plan.overrides, updatedAt}, {merge: true});
    console.log("Wrote the config.");
  } else {
    console.log("Dry run: nothing was written. Add --apply to write.");
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
