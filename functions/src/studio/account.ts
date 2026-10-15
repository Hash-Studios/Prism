import * as admin from "firebase-admin";
import {db} from "../common";

/**
 * The Prism Studio profile. Nobody signs in with this email. Sign-in finds a profile by Auth uid, so a sign-in
 * would make a second profile with the same email.
 */
export const STUDIO_ACCOUNT = {
  id: "prism-studio",
  name: "Prism Studio",
  username: "PrismStudio",
  email: "studio@prismwalls.com",
  profilePhoto: "https://raw.githubusercontent.com/Hash-Studios/Prism/master/assets/images/prism.webp",
  bio: "New wallpapers every day. Curated by Akshay.",
};

/** Remote Config list of the creators that onboarding suggests. The 3 lowest ranks are ticked by default. */
export const STARTER_PACK_KEY = "onboarding_starter_pack_v1";
/** The onboarding creator card shows 5 walls. With fewer, it shows empty tiles. */
export const STARTER_PACK_MIN_WALLS = 5;
const STARTER_PACK_TICKED = 3;

export interface StarterPackEntry {
  email: string;
  rank: number;
}

/** A `usersv2` doc in the shape the app writes at first sign-in. */
export function studioUserDoc(now: string): Record<string, unknown> {
  return {
    ...STUDIO_ACCOUNT,
    coverPhoto: "",
    links: {},
    followers: [],
    following: [],
    badges: [],
    premium: false,
    loggedIn: false,
    coins: 0,
    subPrisms: [],
    transactions: [],
    createdAt: now,
    lastLoginAt: now,
  };
}

/** Returns the `raw` JSON list with `entry` added or re-ranked, or null when it already holds `entry`. */
export function withStarterPackEntry(raw: string, entry: StarterPackEntry): string | null {
  const list: unknown = raw.trim() === "" ? [] : JSON.parse(raw);
  if (!Array.isArray(list)) throw new Error(`${STARTER_PACK_KEY} is not a JSON list.`);
  const at = list.findIndex((e) => e?.email === entry.email);
  if (at >= 0 && list[at].rank === entry.rank) return null;
  return JSON.stringify(at >= 0 ? list.map((e, i) => i === at ? {...e, rank: entry.rank} : e) : [...list, entry]);
}

/** The `--rank` operand, or 0 when the flag is absent. Throws when the operand is not a whole number. */
export function parseRankArg(argv: string[]): number {
  const at = argv.indexOf("--rank");
  if (at < 0) return 0;
  const raw = argv[at + 1]?.trim() ?? "";
  if (!/^-?\d+$/.test(raw)) throw new Error("--rank must be a whole number.");
  return Number(raw);
}

/** The starter pack parameter of `template`, at the top level or in a group. Adds it when it is missing. */
function starterPackParameter(template: admin.remoteConfig.RemoteConfigTemplate): admin.remoteConfig.RemoteConfigParameter {
  return template.parameters[STARTER_PACK_KEY] ??
    Object.values(template.parameterGroups).map((g) => g.parameters[STARTER_PACK_KEY]).find(Boolean) ??
    (template.parameters[STARTER_PACK_KEY] = {valueType: "JSON"});
}

/**
 * Adds `entry` to the starter pack in `template`, in the default value and in each condition value. A default that
 * uses the in-app default (`[]`) gets a value. Other condition values stay. Returns the names of the changed values.
 */
export function addToStarterPack(template: admin.remoteConfig.RemoteConfigTemplate, entry: StarterPackEntry): string[] {
  const parameter = starterPackParameter(template);
  const changed: string[] = [];
  const update = (name: string, raw: string): admin.remoteConfig.ExplicitParameterValue | null => {
    const next = withStarterPackEntry(raw, entry);
    if (next === null) return null;
    changed.push(name);
    return {value: next};
  };

  const fallback = parameter.defaultValue;
  let defaultRaw: string | null = null;
  if (fallback === undefined || "useInAppDefault" in fallback) defaultRaw = "[]";
  else if ("value" in fallback) defaultRaw = fallback.value;
  const nextDefault = defaultRaw === null ? null : update("default", defaultRaw);
  if (nextDefault) parameter.defaultValue = nextDefault;
  const conditions = parameter.conditionalValues ?? {};
  for (const [name, value] of Object.entries(conditions)) {
    const next = "value" in value ? update(`condition "${name}"`, value.value) : null;
    if (next) conditions[name] = next;
  }
  return changed;
}

/** "a, b, c ticked; d listed": the order onboarding shows for the `raw` list. */
export function starterPackOrder(raw: string): string {
  const list = (JSON.parse(raw) as StarterPackEntry[]).slice().sort((a, b) => a.rank - b.rank);
  const names = (entries: StarterPackEntry[]) => entries.map((e) => `${e.email} (${e.rank})`).join(", ");
  const listed = list.slice(STARTER_PACK_TICKED);
  return `${names(list.slice(0, STARTER_PACK_TICKED))} ticked` + (listed.length ? `; ${names(listed)} listed` : "");
}

/**
 * Creates the Studio profile and the `studioConfig/current` identity. When Studio has enough live walls, it also
 * adds Studio to the onboarding starter pack. Writes nothing unless `apply`. Returns one line for each step.
 */
export async function setupStudioAccount(options: {apply: boolean; rank: number; now?: Date}): Promise<string[]> {
  const {apply, rank, now = new Date()} = options;
  const log: string[] = [];
  const users = db.collection("usersv2");
  const configRef = db.collection("studioConfig").doc("current");
  const [profile, config] = await Promise.all([
    users.where("email", "==", STUDIO_ACCOUNT.email).limit(1).get(),
    configRef.get(),
  ]);
  const current: Record<string, unknown> = config.data()?.identity ?? {};
  if (current.email && current.email !== STUDIO_ACCOUNT.email) {
    throw new Error(`studioConfig/current posts as ${current.email}, not ${STUDIO_ACCOUNT.email}. ` +
      "Make them the same, then run again.");
  }
  // Fills only empty identity fields, so a name or photo set in the console stays.
  const wanted = {by: STUDIO_ACCOUNT.name, email: STUDIO_ACCOUNT.email, userPhoto: STUDIO_ACCOUNT.profilePhoto};
  const identity = Object.fromEntries(Object.entries(wanted).map(([key, value]) => [key, current[key] || value]));
  const missing = Object.keys(wanted).filter((key) => !current[key]);

  if (!profile.empty) {
    log.push(`Profile: usersv2/${profile.docs[0].id} exists.`);
  } else {
    log.push(`Profile: create usersv2/${STUDIO_ACCOUNT.id} for ${STUDIO_ACCOUNT.email}.`);
    if (apply) await users.doc(STUDIO_ACCOUNT.id).create(studioUserDoc(now.toISOString()));
  }

  if (missing.length === 0) {
    log.push("Config: studioConfig/current has the identity.");
  } else {
    log.push(config.exists ? `Config: set ${missing.join(", ")} of the identity in studioConfig/current.` :
      "Config: create studioConfig/current with the identity and generation off.");
    if (apply) await configRef.set(config.exists ? {identity} : {generationEnabled: false, identity}, {merge: true});
  }

  const live = (await db.collection("walls").where("email", "==", STUDIO_ACCOUNT.email)
    .where("review", "==", true).count().get()).data().count;
  if (live < STARTER_PACK_MIN_WALLS) {
    log.push(`Starter pack: skipped. Studio has ${live} live walls and the onboarding card shows ` +
      `${STARTER_PACK_MIN_WALLS}. Approve more Studio walls, then run again.`);
    return log;
  }
  const rc = admin.remoteConfig();
  const template = await rc.getTemplate();
  const changed = addToStarterPack(template, {email: STUDIO_ACCOUNT.email, rank});
  if (changed.length === 0) {
    log.push(`Starter pack: has Studio at rank ${rank}.`);
    return log;
  }
  const value = starterPackParameter(template).defaultValue;
  const order = value && "value" in value ? ` New order: ${starterPackOrder(value.value)}.` : "";
  log.push(`Starter pack: add Studio at rank ${rank} to the ${changed.join(", ")} value.${order}`);
  if (apply) await rc.publishTemplate(await rc.validateTemplate(template));
  return log;
}
