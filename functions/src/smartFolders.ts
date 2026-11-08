import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {CALLABLE_REGIONS, db, readDailyCount, REGION, str, utcDateString} from "./common";
import {isPreviewUrl} from "./pushGallery";
import {isPublicWall, publicFolderDeps} from "./publicFolders";
import {parseDesktopVariant} from "./studio/desktop";
import {CATEGORY_NAMES} from "./wallCategory";
import {PALETTE} from "./wallColors";
import {matchesMood, MOODS} from "./wallMoods";

type Doc = admin.firestore.DocumentData;
type Tx = admin.firestore.Transaction;

export const SMART_WALL_KEYS = "smartWallKeys";
export const SMART_FOLDER_INDEX = "smartFolderIndex";
const FOLDERS = "folders";
const ITEMS = "items";
const FOLDER_ID = /^[A-Za-z0-9_-]{1,128}$/;
const UID = /^[A-Za-z0-9]{1,128}$/;
export const MAX_SMART_KINDS = 3;
export const MAX_VALUES_PER_KIND = 6;
export const MAX_SMART_FOLDERS = 20;
export const SMART_FILL_LIMIT = 100;
export const SMART_PREVIEW_WALLS = 12;
export const MAX_FOLDER_ITEMS = 500;
const PAGE = 200;
const MAX_SCAN_PER_CHUNK = 1000;
const ANY_LIMIT = 30;
// ponytail: a followed-creators fill reads at most 10 chunks of 30 creators. Approvals have no cap. Raise when
// users follow more than 300 creators.
const MAX_FOLLOW_CHUNKS = 10;
const MAX_PREVIEWS_PER_DAY = 300;
const MAX_RULE_EDITS_PER_DAY = 50;
const PREVIEW_RATE = "smartFolderPreviewRateDaily";
const EDIT_RATE = "smartFolderEditRateDaily";

/** Anchor order: the kind that a new wall is least likely to match goes first, so the index returns few candidates. */
export const SMART_KINDS = ["creator", "editorsChoice", "followed", "desktop", "category", "colour", "mood"] as const;
export type SmartRuleKind = typeof SMART_KINDS[number];
export interface SmartRule {kind: SmartRuleKind; value: string}

const VALUELESS: ReadonlySet<SmartRuleKind> = new Set(["followed", "desktop", "editorsChoice"]);
const MOOD_IDS: ReadonlySet<string> = new Set(MOODS.map((mood) => mood.id));
const CATEGORIES: ReadonlySet<string> = new Set(CATEGORY_NAMES);
const COLOURS: ReadonlySet<string> = new Set(PALETTE.map((colour) => colour.id));

function validValue(kind: SmartRuleKind, value: string): boolean {
  switch (kind) {
  case "mood": return MOOD_IDS.has(value);
  case "category": return CATEGORIES.has(value);
  case "colour": return COLOURS.has(value);
  case "creator": return UID.test(value);
  default: return value === "";
  }
}

/** Parses client rules into a sorted, deduplicated list, or null when they are not a valid rule set. */
export function parseSmartRules(raw: unknown): SmartRule[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_SMART_KINDS * MAX_VALUES_PER_KIND) return null;
  const seen = new Map<string, SmartRule>();
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") return null;
    const kind = (entry as {kind?: unknown}).kind;
    const value = (entry as {value?: unknown}).value ?? "";
    if (typeof kind !== "string" || !(SMART_KINDS as readonly string[]).includes(kind) || typeof value !== "string") {
      return null;
    }
    const rule = {kind: kind as SmartRuleKind, value: VALUELESS.has(kind as SmartRuleKind) ? "" : value};
    if (!validValue(rule.kind, rule.value)) return null;
    seen.set(`${rule.kind}:${rule.value}`, rule);
  }
  const rules = [...seen.values()].sort((a, b) =>
    SMART_KINDS.indexOf(a.kind) - SMART_KINDS.indexOf(b.kind) || a.value.localeCompare(b.value));
  const kinds = new Set(rules.map((rule) => rule.kind));
  if (kinds.size > MAX_SMART_KINDS) return null;
  for (const kind of kinds) if (rules.filter((rule) => rule.kind === kind).length > MAX_VALUES_PER_KIND) return null;
  return rules;
}

function requireRules(raw: unknown): SmartRule[] {
  const rules = parseSmartRules(raw);
  if (!rules) throw new HttpsError("invalid-argument", "rules");
  return rules;
}

const ruleKey = (rule: SmartRule): string => VALUELESS.has(rule.kind) ? rule.kind : `${rule.kind}:${rule.value}`;
const creatorKey = (uid: string) => `creator:${uid}`;
export const creatorOf = (keys: readonly string[]): string =>
  keys.find((key) => key.startsWith("creator:"))?.slice("creator:".length) ?? "";

/**
 * The keys a wall can match, or none when the wall must stay out of every smart folder. A smart folder holds only walls
 * that pass the free gallery gate, so a public smart folder never shows a premium, drop or held wall.
 */
export function wallSmartKeys(wall: Doc | undefined, premium: string[]): string[] {
  if (!isPublicWall(wall, premium) || !isPreviewUrl(str(wall.wallpaper_thumb))) return [];
  const keys = MOODS.filter((mood) => matchesMood(mood, wall)).map((mood) => `mood:${mood.id}`);
  if (CATEGORIES.has(str(wall.category))) keys.push(`category:${str(wall.category)}`);
  if (Array.isArray(wall.colors)) {
    for (const colour of new Set(wall.colors)) if (COLOURS.has(str(colour))) keys.push(`colour:${colour}`);
  }
  if (UID.test(str(wall.creatorUid))) keys.push(creatorKey(str(wall.creatorUid)));
  if (parseDesktopVariant(wall.desktopVariant)) keys.push("desktop");
  if (wall.editorsChoiceAt != null) keys.push("editorsChoice");
  return keys;
}

/** AND across kinds, OR inside one kind. [followsCreator] says if the folder owner follows the wall's creator. */
export function matchesSmartRules(rules: readonly SmartRule[], keys: readonly string[], followsCreator: boolean): boolean {
  if (rules.length === 0) return false;
  const have = new Set(keys);
  const byKind = new Map<SmartRuleKind, SmartRule[]>();
  for (const rule of rules) byKind.set(rule.kind, [...(byKind.get(rule.kind) ?? []), rule]);
  return [...byKind].every(([kind, group]) =>
    kind === "followed" ? have.size > 0 && followsCreator : group.some((rule) => have.has(ruleKey(rule))));
}

/** The rule kind the index stores, and its keys. A followed-creators anchor stores one key per followed creator. */
export function anchorFor(rules: readonly SmartRule[], follows: readonly string[]): {kind: SmartRuleKind; keys: string[]} {
  const kind = SMART_KINDS.find((k) => rules.some((rule) => rule.kind === k)) ?? "mood";
  const keys = kind === "followed" ? follows.filter((uid) => UID.test(uid)).map(creatorKey) :
    rules.filter((rule) => rule.kind === kind).map(ruleKey);
  return {kind, keys: [...new Set(keys)]};
}

/** Without the preview base no thumb passes the gate, so a sync would empty every smart folder. Fail and retry. */
function requirePreviewBase(): void {
  if (!process.env.R2_PREVIEW_BASE_URL) throw new Error("R2_PREVIEW_BASE_URL is not set; run make functions-env.");
}

const needsFollows = (rules: readonly SmartRule[]) => rules.some((rule) => rule.kind === "followed");
const folderRef = (folderId: string) => db.collection(FOLDERS).doc(folderId);
const indexRef = (folderId: string) => db.collection(SMART_FOLDER_INDEX).doc(folderId);
const keysRef = (wallDocId: string) => db.collection(SMART_WALL_KEYS).doc(wallDocId);
const followRef = (ownerId: string, creatorUid: string) =>
  db.collection("profiles").doc(ownerId).collection("following").doc(creatorUid);

async function followsOf(ownerId: string): Promise<string[]> {
  return (await db.collection("profiles").doc(ownerId).collection("following").get()).docs.map((edge) => edge.id);
}

const asTimestamp = (value: unknown): admin.firestore.Timestamp =>
  value instanceof admin.firestore.Timestamp ? value : admin.firestore.Timestamp.now();
const wallIdOf = (wall: Doc, docId: string) => /^[A-Za-z0-9_-]{1,200}$/.test(str(wall.id)) ? str(wall.id) : docId;
export const smartItemKey = (wall: Doc, docId: string) => `prism_${wallIdOf(wall, docId)}`;

/** A folder item in the shape the app writes for a Prism favourite, plus `smart`. */
function smartItemDoc(wall: Doc, docId: string, ownerId: string, addedAt: admin.firestore.Timestamp): Doc {
  const now = admin.firestore.Timestamp.now();
  return {
    id: wallIdOf(wall, docId), url: str(wall.wallpaper_url), thumb: str(wall.wallpaper_thumb), provider: "Prism",
    ...(str(wall.category) ? {category: str(wall.category)} : {}), views: "", fav: "",
    ...(str(wall.resolution) ? {resolution: str(wall.resolution)} : {}),
    ...(str(wall.size) ? {size: str(wall.size)} : {}),
    ...(str(wall.by) ? {photographer: str(wall.by)} : {}),
    ...(Array.isArray(wall.collections) ? {collections: wall.collections} : {}),
    ...(wall.depth && typeof wall.depth === "object" ? {depth: wall.depth} : {}),
    ...(wall.spatial && typeof wall.spatial === "object" ? {spatial: wall.spatial} : {}),
    createdAt: asTimestamp(wall.createdAt), favouritedAt: now, ownerId, addedAt: addedAt.toMillis() > now.toMillis() ? now : addedAt,
    wallpaperDocumentId: docId, smart: true,
  };
}

interface Match {docId: string; wallId: string; thumb: string; createdAt: admin.firestore.Timestamp}

/**
 * The newest walls that match, newest first. The anchor kind maps to one `array-contains-any` query per 30 keys on
 * smartWallKeys (index: keys CONTAINS, createdAt DESC). The other kinds are checked on each result.
 */
export async function findSmartMatches(rules: readonly SmartRule[], follows: readonly string[], limit: number):
  Promise<{matches: Match[]; more: boolean}> {
  const anchor = anchorFor(rules, follows);
  const followed = new Set(follows);
  const chunks: string[][] = [];
  for (let i = 0; i < anchor.keys.length && chunks.length < MAX_FOLLOW_CHUNKS; i += ANY_LIMIT) {
    chunks.push(anchor.keys.slice(i, i + ANY_LIMIT));
  }
  let more = false;
  const found = await Promise.all(chunks.map(async (chunk) => {
    const out: Match[] = [];
    let last: admin.firestore.QueryDocumentSnapshot | undefined;
    for (let scanned = 0; scanned < MAX_SCAN_PER_CHUNK;) {
      let query = db.collection(SMART_WALL_KEYS).where("keys", "array-contains-any", chunk)
        .orderBy("createdAt", "desc").limit(PAGE);
      if (last) query = query.startAfter(last);
      const page = await query.get();
      scanned += page.size;
      for (const doc of page.docs) {
        const keys = Array.isArray(doc.data().keys) ? doc.data().keys.map(str) : [];
        if (!matchesSmartRules(rules, keys, followed.has(creatorOf(keys)))) continue;
        out.push({docId: doc.id, wallId: str(doc.data().wallId), thumb: str(doc.data().thumb),
          createdAt: asTimestamp(doc.data().createdAt)});
        if (out.length > limit) return out;
      }
      if (page.size < PAGE) return out;
      last = page.docs[page.docs.length - 1];
    }
    more = true;
    return out;
  }));
  const seen = new Set<string>();
  const merged = found.flat().sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
    .filter((match) => !seen.has(match.docId) && Boolean(seen.add(match.docId)));
  return {matches: merged.slice(0, limit), more: more || merged.length > limit};
}

/** Deletes the oldest items so the folder keeps at most [MAX_FOLDER_ITEMS] after [adding] more. Reads first. */
async function trimPlan(tx: Tx, folderId: string, adding: number): Promise<admin.firestore.DocumentReference[]> {
  const items = folderRef(folderId).collection(ITEMS);
  const count = (await tx.get(items.count())).data().count;
  const over = count + adding - MAX_FOLDER_ITEMS;
  if (over <= 0) return [];
  return (await tx.get(items.orderBy("addedAt", "asc").limit(over))).docs.map((doc) => doc.ref);
}

/**
 * Adds one wall to one smart folder when it still matches. The transaction reads the folder rules, the wall and the
 * follow edge at commit time, so a stale trigger, a rule edit or a reject in between cannot add a wrong wall.
 */
export async function addWallToSmartFolder(folderId: string, wallDocId: string, premium: string[]): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const [folder, wall] = await Promise.all([tx.get(folderRef(folderId)), tx.get(db.collection("walls").doc(wallDocId))]);
    const rules = parseSmartRules(folder.data()?.smartRules);
    const ownerId = str(folder.data()?.ownerId);
    const data = wall.data();
    if (!folder.exists || !rules || !ownerId || !wall.exists || !data) return false;
    const keys = wallSmartKeys(data, premium);
    const creator = creatorOf(keys);
    const follows = needsFollows(rules) && creator ? (await tx.get(followRef(ownerId, creator))).exists : false;
    if (!matchesSmartRules(rules, keys, follows)) return false;
    const itemRef = folderRef(folderId).collection(ITEMS).doc(smartItemKey(data, wallDocId));
    if ((await tx.get(itemRef)).exists) return false;
    for (const ref of await trimPlan(tx, folderId, 1)) tx.delete(ref);
    tx.set(itemRef, smartItemDoc(data, wallDocId, ownerId, admin.firestore.Timestamp.now()));
    return true;
  });
}

/** Removes a smart item whose wall no longer matches the folder, in one transaction. */
async function reconcileSmartItem(folderId: string, itemKey: string, premium: string[]): Promise<void> {
  const item = folderRef(folderId).collection(ITEMS).doc(itemKey);
  await db.runTransaction(async (tx) => {
    const current = await tx.get(item);
    if (!current.exists || current.data()?.smart !== true) return;
    const folder = await tx.get(folderRef(folderId));
    const wall = await tx.get(db.collection("walls").doc(str(current.data()?.wallpaperDocumentId) || "-"));
    const rules = parseSmartRules(folder.data()?.smartRules);
    const keys = wallSmartKeys(wall.data(), premium);
    const creator = creatorOf(keys);
    const ownerId = str(folder.data()?.ownerId);
    const follows = rules && needsFollows(rules) && creator && ownerId ? (await tx.get(followRef(ownerId, creator))).exists : false;
    if (!rules || !folder.exists || !matchesSmartRules(rules, keys, follows)) tx.delete(item);
  });
}

async function inChunks<T>(values: T[], run: (value: T) => Promise<unknown>): Promise<void> {
  for (let i = 0; i < values.length; i += 25) await Promise.all(values.slice(i, i + 25).map(run));
}

/** True when a wall write can change the wall's smart keys. Counter writes return false and cost no reads. */
export function changesSmartKeys(before: Doc | undefined, after: Doc | undefined): boolean {
  if (!before || !after) return true;
  const fields = ["review", "originalProtected", "is_streak_exclusive", "dropReserved", "dropWeek", "collections", "colors",
    "visionLabels", "tags", "spatial", "depth", "category", "creatorUid", "desktopVariant", "editorsChoiceAt",
    "wallpaper_thumb", "id", "createdAt"];
  return fields.some((field) => JSON.stringify(before[field]) !== JSON.stringify(after[field]));
}

/**
 * Brings every smart folder up to date for one wall. It reads the wall again, so a late or repeated event converges on
 * the current wall. Existing smart items are checked again. New candidates come from the rule index: one
 * `array-contains-any` query with the wall's keys (at most 14) returns only the folders whose anchor the wall has.
 */
export async function syncWallSmartFolders(wallDocId: string): Promise<{added: number; checked: number}> {
  requirePreviewBase();
  const wall = await db.collection("walls").doc(wallDocId).get();
  const premium = await publicFolderDeps.premium();
  const keys = wallSmartKeys(wall.data(), premium);
  if (keys.length === 0) {
    await keysRef(wallDocId).delete();
  } else {
    const data = wall.data() ?? {};
    await keysRef(wallDocId).set({keys, wallId: wallIdOf(data, wallDocId), thumb: str(data.wallpaper_thumb),
      createdAt: asTimestamp(data.createdAt)});
  }
  const held = (await db.collectionGroup(ITEMS).where("wallpaperDocumentId", "==", wallDocId).get()).docs
    .map((item) => ({path: item.ref.path.split("/"), smart: item.data().smart === true}))
    .filter(({path, smart}) => smart && path.length === 4 && path[0] === FOLDERS && path[2] === ITEMS);
  await inChunks(held, ({path}) => reconcileSmartItem(path[1], path[3], premium));
  if (keys.length === 0) return {added: 0, checked: held.length};
  const heldFolders = new Set(held.map(({path}) => path[1]));
  const candidates = (await db.collection(SMART_FOLDER_INDEX)
    .where("anchors", "array-contains-any", keys.slice(0, ANY_LIMIT)).get()).docs.filter((doc) => !heldFolders.has(doc.id));
  let added = 0;
  await inChunks(candidates, async (candidate) => {
    if (await addWallToSmartFolder(candidate.id, wallDocId, premium)) added++;
  });
  return {added, checked: held.length + candidates.length};
}

export const onWallSmartFolders = onDocumentWritten(
  {document: "walls/{wallId}", region: REGION, retry: true},
  async (event) => {
    if (!changesSmartKeys(event.data?.before?.data(), event.data?.after?.data())) return;
    await syncWallSmartFolders(event.params.wallId);
  },
);

/** Keeps the followed-creators anchor of the user's smart folders in step with their follows. */
export const onSmartFollowWritten = onDocumentWritten(
  {document: "profiles/{uid}/following/{targetUid}", region: REGION, retry: true},
  async (event) => {
    const {uid, targetUid} = event.params;
    if (!UID.test(targetUid) || Boolean(event.data?.before?.exists) === Boolean(event.data?.after?.exists)) return;
    const following = Boolean(event.data?.after?.exists);
    const folders = await db.collection(SMART_FOLDER_INDEX).where("ownerId", "==", uid)
      .where("anchorKind", "==", "followed").get();
    await Promise.all(folders.docs.map((doc) => doc.ref.update({
      anchors: following ? admin.firestore.FieldValue.arrayUnion(creatorKey(targetUid)) :
        admin.firestore.FieldValue.arrayRemove(creatorKey(targetUid)),
    })));
  },
);

/**
 * Fills a smart folder with its newest matches and removes items that no longer match. Run after a create or a rule
 * edit. Items that still match keep their addedAt. Returns the item count after the fill.
 */
export async function fillSmartFolder(folderId: string): Promise<number> {
  requirePreviewBase();
  const folder = await folderRef(folderId).get();
  const rules = parseSmartRules(folder.data()?.smartRules);
  const ownerId = str(folder.data()?.ownerId);
  if (!folder.exists || !rules || !ownerId) return 0;
  const follows = needsFollows(rules) ? await followsOf(ownerId) : [];
  const followed = new Set(follows);
  const premium = await publicFolderDeps.premium();
  const {matches} = await findSmartMatches(rules, follows, SMART_FILL_LIMIT);
  const items = await folderRef(folderId).collection(ITEMS).get();
  const present = new Map(items.docs.map((item) => [str(item.data().wallpaperDocumentId), item]));
  const keyDocs = items.empty ? [] : await db.getAll(...items.docs.map((item) =>
    keysRef(str(item.data().wallpaperDocumentId) || "-")));
  const stale = items.docs.filter((item, i) => {
    const keys = Array.isArray(keyDocs[i]?.data()?.keys) ? (keyDocs[i].data()?.keys as unknown[]).map(str) : [];
    return !matchesSmartRules(rules, keys, followed.has(creatorOf(keys)));
  });
  const fresh = matches.filter((match) => !present.has(match.docId));
  const walls = fresh.length === 0 ? [] : await db.getAll(...fresh.map((match) => db.collection("walls").doc(match.docId)));
  const writes: Array<(batch: admin.firestore.WriteBatch) => void> = stale.map((item) => (batch) => batch.delete(item.ref));
  walls.forEach((wall, i) => {
    const data = wall.data();
    if (!data || !matchesSmartRules(rules, wallSmartKeys(data, premium), followed.has(str(data.creatorUid)))) return;
    const ref = folderRef(folderId).collection(ITEMS).doc(smartItemKey(data, wall.id));
    writes.push((batch) => batch.set(ref, smartItemDoc(data, wall.id, ownerId, fresh[i].createdAt)));
  });
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    writes.slice(i, i + 400).forEach((write) => write(batch));
    await batch.commit();
  }
  await db.runTransaction(async (tx) => {
    for (const ref of await trimPlan(tx, folderId, 0)) tx.delete(ref);
  });
  return (await folderRef(folderId).collection(ITEMS).count().get()).data().count;
}

/** Removes the rule index entry and the items of a deleted smart folder. */
export async function removeSmartFolder(folderId: string): Promise<void> {
  await indexRef(folderId).delete();
  const items = await folderRef(folderId).collection(ITEMS).where("smart", "==", true).get();
  for (let i = 0; i < items.size; i += 400) {
    const batch = db.batch();
    items.docs.slice(i, i + 400).forEach((item) => batch.delete(item.ref));
    await batch.commit();
  }
}

/** Account deletion: the user's rule index entries. Their folders and items go with the other owned folders. */
export async function removeOwnerSmartFolders(uid: string): Promise<void> {
  const owned = await db.collection(SMART_FOLDER_INDEX).where("ownerId", "==", uid).get();
  await Promise.all(owned.docs.map((doc) => doc.ref.delete()));
}

async function accountOpen(uid: string): Promise<boolean> {
  const [user, barrier] = await Promise.all([
    db.collection("usersv2").doc(uid).get(), db.collection("creatorDeletionState").doc(uid).get(),
  ]);
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true;
}

async function spendDaily(collection: string, uid: string, max: number): Promise<void> {
  const ref = db.collection(collection).doc(`${uid}_${utcDateString()}`);
  await db.runTransaction(async (tx) => {
    const today = utcDateString();
    const count = readDailyCount(await tx.get(ref), today);
    if (count >= max) throw new HttpsError("resource-exhausted", "Too many changes today. Try again tomorrow.");
    tx.set(ref, {day: today, count: count + 1}, {merge: true});
  });
}

function signedIn(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to use smart folders.");
  return uid;
}

function folderName(raw: unknown): string {
  const name = typeof raw === "string" ? raw.trim() : "";
  if (name.length < 1 || name.length > 50) throw new HttpsError("invalid-argument", "name");
  return name;
}

const indexDoc = (ownerId: string, rules: SmartRule[], follows: string[]) => {
  const anchor = anchorFor(rules, follows);
  return {ownerId, rules, anchorKind: anchor.kind, anchors: anchor.keys,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()};
};

const OPTIONS = {region: CALLABLE_REGIONS, cors: true, timeoutSeconds: 120};

export const previewSmartFolder = onCall(OPTIONS, async (request: CallableRequest<{rules?: unknown}>) => {
  const uid = signedIn(request);
  const rules = requireRules(request.data?.rules);
  await spendDaily(PREVIEW_RATE, uid, MAX_PREVIEWS_PER_DAY);
  const {matches, more} = await findSmartMatches(rules, needsFollows(rules) ? await followsOf(uid) : [], SMART_FILL_LIMIT);
  return {count: matches.length, more,
    walls: matches.slice(0, SMART_PREVIEW_WALLS).map((m) => ({id: m.wallId, docId: m.docId, thumb: m.thumb}))};
});

export const createSmartFolder = onCall(OPTIONS, async (request: CallableRequest<{name?: unknown; rules?: unknown}>) => {
  const uid = signedIn(request);
  const name = folderName(request.data?.name);
  const rules = requireRules(request.data?.rules);
  if (!(await accountOpen(uid))) throw new HttpsError("failed-precondition", "account");
  const owned = (await db.collection(SMART_FOLDER_INDEX).where("ownerId", "==", uid).count().get()).data().count;
  if (owned >= MAX_SMART_FOLDERS) throw new HttpsError("resource-exhausted", "limit");
  const follows = needsFollows(rules) ? await followsOf(uid) : [];
  const ref = db.collection(FOLDERS).doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.create(ref, {ownerId: uid, name, createdAt: now, updatedAt: now, itemCount: 0, covers: [], smartRules: rules});
  batch.set(indexRef(ref.id), indexDoc(uid, rules, follows));
  await batch.commit();
  return {folderId: ref.id, count: await fillSmartFolder(ref.id)};
});

export const updateSmartFolderRules = onCall(OPTIONS, async (request: CallableRequest<{folderId?: unknown; rules?: unknown}>) => {
  const uid = signedIn(request);
  const folderId = typeof request.data?.folderId === "string" && FOLDER_ID.test(request.data.folderId) ?
    request.data.folderId : "";
  if (!folderId) throw new HttpsError("invalid-argument", "folderId");
  const rules = requireRules(request.data?.rules);
  await spendDaily(EDIT_RATE, uid, MAX_RULE_EDITS_PER_DAY);
  const follows = needsFollows(rules) ? await followsOf(uid) : [];
  await db.runTransaction(async (tx) => {
    const folder = await tx.get(folderRef(folderId));
    if (!folder.exists || str(folder.data()?.ownerId) !== uid || !Array.isArray(folder.data()?.smartRules)) {
      throw new HttpsError("permission-denied", "Only the owner can edit the rules.");
    }
    tx.update(folderRef(folderId), {smartRules: rules, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    tx.set(indexRef(folderId), indexDoc(uid, rules, follows));
  });
  return {count: await fillSmartFolder(folderId)};
});
