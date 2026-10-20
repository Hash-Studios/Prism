import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onDocumentCreated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, int, REGION} from "./common";
import {dayKey, grantXp, loadEconomy, weekBounds, weekKey} from "./economy";
import {rankRewardsFor} from "./rankRewards";
import {stored} from "./ownedAssetDelivery";

type Data = admin.firestore.DocumentData;
type Snapshot = admin.firestore.DocumentSnapshot;
type Metric = "approvedWalls" | "uniqueMembers";
type Week = {weekKey: string; approvedWalls: number; newMembers: number; xp: number};

/** Finite server-owned awards. Clients render this materialized catalog, never compute grants. */
export const CREATOR_MILESTONES = [
  ...[[1, 50], [5, 100], [10, 150], [25, 250], [50, 500]].map(([target, xp]) =>
    ({id: `approvedWalls_${target}`, metric: "approvedWalls" as Metric, target, xp})),
  ...[[1, 25], [10, 50], [25, 100], [100, 250], [250, 500]].map(([target, xp]) =>
    ({id: `uniqueMembers_${target}`, metric: "uniqueMembers" as Metric, target, xp})),
];

const DAY_MS = 86400000;
const PROVIDERS = new Set(["prism", "wall_of_the_day", "walloftheday"]);
const validId = (value: unknown): value is string => typeof value === "string" &&
  value.length > 0 && value.length <= 200 && value.trim() === value && !value.includes("/") && !value.includes("..");
const validUid = (value: unknown): value is string => validId(value) && value.length <= 128;
const text = (value: unknown): string => typeof value === "string" ? value.trim() : "";
const email = (value: unknown): string => text(value).toLowerCase();
const count = (value: unknown): number => typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : 0;
const hash = (value: string): string => createHash("sha256").update(value).digest("hex");
const receiptRef = (id: string) => db.collection("creatorWallCredits").doc(hash(id));
const barrierRef = (uid: string) => db.collection("creatorDeletionState").doc(uid);

type Asset = {repo: string; path: string; sha: string; url: string};

/** GitHub's returned download URL must reference the same protected repository and stored file path. */
function asset(data: Data, prefix: "wallpaper" | "thumb"): Asset | null {
  const repo = text(process.env.GH_REPO_WALLS);
  const owner = text(process.env.GH_USERNAME);
  const path = text(data[`${prefix}_path`]);
  const sha = text(data[`${prefix}_sha`]);
  if (!repo || !owner || !path || path.length > 1024 || path.startsWith("/") || path.includes("\\") ||
    path.split("/").some((part) => !part || part === "." || part === "..") || !/^[a-f0-9]{40}$/.test(sha)) return null;
  try {
    const url = new URL(text(data[prefix === "thumb" ? "wallpaper_thumb" : "wallpaper_url"]));
    const parts = url.pathname.split("/").slice(1).map(decodeURIComponent);
    const fileParts = path.split("/").length;
    if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.username || url.password ||
      url.port || url.search || url.hash || parts[0].toLowerCase() !== owner.toLowerCase() ||
      parts[1] !== repo || parts.length <= fileParts + 2 || parts.slice(-fileParts).join("/") !== path) return null;
    return {repo, path, sha, url: url.href};
  } catch {
    return null;
  }
}

/** Also inspect conflicting records, including legacy SHA-keyed records, instead of trusting a copied UID. */
export async function verifiedUploadOwner(canonical: Snapshot, tx?: admin.firestore.Transaction): Promise<string | null> {
  const canonicalData = canonical.data();
  if (!canonicalData) return null;
  let data: Data = canonicalData;
  let privateOriginal: Asset | undefined;
  let boundOwner: string | undefined;
  let retainedAssets: Data[] | undefined;
  if (data.originalProtected === true) {
    if (!validId(data.id) || !canonical.createTime || data.wallpaper_url !== "" ||
      ["wallpaper_path", "wallpaper_sha", "thumb_path", "thumb_sha"].some((field) => data[field] !== "")) return null;
    const ref = db.collection("ownedAssets").doc(data.id);
    const manifest = (tx ? await tx.get(ref) : await ref.get()).data();
    if (manifest?.status !== "ready" || !["github", "owned"].includes(manifest.provenance?.kind) ||
      !stored(manifest.original) || !stored(manifest.thumb) ||
      manifest.canonicalPath !== canonical.ref.path ||
      manifest.incarnation !== canonical.createTime.toMillis() ||
      manifest.incarnationNanos !== canonical.createTime.nanoseconds ||
      manifest.original?.generation !== data.originalGeneration) return null;
    if (!validUid(manifest.provenance.uid)) return null;
    boundOwner = manifest.provenance.uid;
    retainedAssets = [manifest.original, manifest.thumb];
    if (manifest.provenance.kind === "owned") {
      const original = manifest.original;
      if (manifest.originalUrl !== "" || original.repo !== text(process.env.GH_REPO_WALLS) ||
        typeof original.path !== "string" || !original.path || original.path.length > 1024 || original.path.startsWith("/") ||
        original.path.includes("\\") || original.path.split("/").some((part: string) => !part || part === "." || part === "..") ||
        typeof original.sha !== "string" || !/^[a-f0-9]{40}$/.test(original.sha)) return null;
      privateOriginal = {repo: original.repo, path: original.path, sha: original.sha, url: ""};
    }
    data = {...data, wallpaper_url: manifest.originalUrl, wallpaper_thumb: manifest.thumbUrl,
      wallpaper_path: manifest.original?.path, wallpaper_sha: manifest.original?.sha,
      thumb_path: manifest.thumb?.path, thumb_sha: manifest.thumb?.sha};
  }
  const assets = [privateOriginal ?? asset(data, "wallpaper"), asset(data, "thumb")];
  if (assets.some((value) => value === null)) return null;
  let owner: string | null = null;
  for (const [index, file] of (assets as Asset[]).entries()) {
    const owned = file === privateOriginal;
    const keyPrefix = owned ? "owned_" : "";
    let query = db.collection("githubUploads").where("path", "==", file.path)
      .orderBy(admin.firestore.FieldPath.documentId()).limit(8);
    const records: admin.firestore.QueryDocumentSnapshot[] = [];
    while (true) {
      const rows = tx ? await tx.get(query) : await query.get();
      records.push(...rows.docs.filter((doc) => doc.data().repo === file.repo &&
        (owned ? doc.data().sourceKind === "owned" : doc.data().sourceKind !== "owned")));
      if (records.length >= 8) return null;
      if (rows.size < 8) break;
      query = query.startAfter(rows.docs[rows.docs.length - 1]);
    }
    const exact = records.find((doc) => doc.id === `${keyPrefix}file_${hash(`${file.repo}\0${file.path}\0${file.sha}`)}` &&
      doc.data().sha === file.sha);
    const uid = exact?.data().uid;
    if (!validUid(uid) || records.some((doc) => doc.data().uid !== uid) || owner !== null && owner !== uid) return null;
    const intentRef = db.collection("githubUploadIntents").doc(`${keyPrefix}path_${hash(`${file.repo}\0${file.path}`)}`);
    const intent = (tx ? await tx.get(intentRef) : await intentRef.get()).data();
    const content = intent?.response?.content;
    if (intent?.status !== "complete" || intent.uid !== uid || intent.repo !== file.repo || intent.path !== file.path ||
      intent.blobSha !== file.sha || content?.path !== file.path || content?.sha !== file.sha || content?.download_url !== file.url) return null;
    if (!owned && intent.sourceKind === "owned") return null;
    if (owned && (exact?.data().sourceKind !== "owned" || intent.sourceKind !== "owned" ||
      exact.data().retainedAsset?.generation !== data.originalGeneration ||
      intent.retainedAsset?.generation !== data.originalGeneration)) return null;
    if (retainedAssets) {
      const retained = retainedAssets[index];
      const proofs = [exact?.data().retainedAsset,
        ...(owned || intent.retainedAsset !== undefined ? [intent.retainedAsset] : [])];
      if (!retained || retained.uid !== uid || retained.repo !== file.repo || retained.path !== file.path ||
        retained.sha !== file.sha || (retained.sourceKind === "owned") !== owned ||
        retained.object !== `${owned ? "private-originals" : "retained"}/${hash(`${file.repo}\0${file.path}\0${file.sha}`)}` ||
        proofs.some((proof) => !proof ||
          ["repo", "path", "sha", "uid", "bucket", "object", "generation", "sha256", "sourceKind"]
            .some((field) => proof[field] !== retained[field]))) return null;
    }
    owner = uid;
  }
  return boundOwner !== undefined && boundOwner !== owner ? null : owner;
}

async function authUser(uid: string): Promise<admin.auth.UserRecord | null> {
  try {
    return await admin.auth().getUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return null;
    throw error;
  }
}

function eligibleMember(user: admin.auth.UserRecord | null, sourceMs: number): boolean {
  const createdMs = Date.parse(user?.metadata?.creationTime ?? "");
  return !!user && !user.disabled && user.emailVerified === true && !!email(user.email) &&
    user.providerData?.some((provider) => provider.providerId !== "anonymous" && !!provider.providerId) &&
    Number.isFinite(createdMs) && createdMs >= 0 && sourceMs - createdMs >= 7 * DAY_MS;
}

function sameIncarnation(current: Snapshot, source: Snapshot): boolean {
  return current.exists && !!current.createTime && !!source.createTime && current.createTime.isEqual(source.createTime);
}

function approvedWall(data: Data): boolean {
  // Studio cannot prove both modern GitHub assets. Reject its marker too, even if a client copied it.
  return data.review === true && data.origin !== "studio" &&
    text(data.wallpaper_provider).toLowerCase() === "prism";
}

type Source = {logicalId: string; snapshot: Snapshot; memberUid?: string};

/** Direct receipt/count/XP transaction. Auth failures retry; permanent ineligibility has no writes. */
async function recordCreator(source: Source): Promise<void> {
  const {logicalId, snapshot, memberUid} = source;
  const sourceMs = (memberUid ? snapshot.createTime : snapshot.updateTime)?.toMillis();
  if (sourceMs === undefined || !Number.isFinite(sourceMs)) return;
  const canonical = await db.collection("walls").where("id", "==", logicalId).limit(2).get();
  if (canonical.size !== 1 || !approvedWall(canonical.docs[0].data())) return;
  const candidate = canonical.docs[0];
  if (!memberUid && (candidate.ref.path !== snapshot.ref.path || !sameIncarnation(candidate, snapshot))) return;
  const owner = await verifiedUploadOwner(candidate);
  if (!owner || memberUid === owner) return;
  const [creatorAuth, memberAuth, binding] = await Promise.all([
    authUser(owner), memberUid ? authUser(memberUid) : Promise.resolve(null), receiptRef(logicalId).get(),
  ]);
  if (!creatorAuth || creatorAuth.disabled || memberUid && !eligibleMember(memberAuth, sourceMs)) return;
  if (!binding.exists && (!email(candidate.data().email) || email(creatorAuth.email) !== email(candidate.data().email))) return;
  const config = await loadEconomy();
  const nowMs = Date.now();
  const creatorRef = db.collection("usersv2").doc(owner);
  const privateRef = creatorRef.collection("private").doc("economy");
  await db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("id", "==", logicalId).limit(2));
    if (rows.size !== 1) return;
    const wall = rows.docs[0];
    if (!approvedWall(wall.data()) || wall.ref.path !== candidate.ref.path ||
      !memberUid && !sameIncarnation(wall, snapshot) || await verifiedUploadOwner(wall, tx) !== owner) return;
    const [receipt, creator, privateSnap, creatorBarrier] = await Promise.all([
      tx.get(receiptRef(logicalId)), tx.get(creatorRef), tx.get(privateRef), tx.get(barrierRef(owner)),
    ]);
    const bound = receipt.data();
    if (!creator.exists || creator.data()?.deleted === true || creatorBarrier.exists || bound?.closed === true ||
      bound && (bound.creatorUid !== owner || bound.ownerEmail !== email(wall.data().email) ||
        bound.canonicalPath !== wall.ref.path)) return;
    if (!receipt.exists && (!email(wall.data().email) || email(wall.data().email) !== email(creatorAuth.email))) return;
    if (!memberUid && bound?.approvalCredited === true) return;

    let pairRef: admin.firestore.DocumentReference | undefined;
    let rateRef: admin.firestore.DocumentReference | undefined;
    let rateCount = 0;
    if (memberUid) {
      const memberRef = db.collection("usersv2").doc(memberUid);
      pairRef = privateRef.collection("creatorMembers").doc(memberUid);
      rateRef = db.collection("creatorMemberRateDaily").doc(`${memberUid}_${dayKey(nowMs)}`);
      const [member, memberBarrier, pair, rate, currentSource, blocking, blocked] = await Promise.all([
        tx.get(memberRef), tx.get(barrierRef(memberUid)), tx.get(pairRef), tx.get(rateRef), tx.get(snapshot.ref),
        tx.get(memberRef.collection("blockedUsers").doc(owner)),
        tx.get(creatorRef.collection("blockedUsers").doc(memberUid)),
      ]);
      const currentData = currentSource.data();
      if (!member.exists || member.data()?.deleted === true || memberBarrier.exists || pair.exists ||
        blocking.exists || blocked.exists || !sameIncarnation(currentSource, snapshot) ||
        currentData?.id !== logicalId || !PROVIDERS.has(text(currentData?.provider).toLowerCase())) return;
      rateCount = rate.data()?.day === dayKey(nowMs) ? count(rate.data()?.count) : 0;
      if (rateCount >= 20) return;
    }

    const privateData = privateSnap.data() ?? {};
    const old = privateData.creator?.version === 1 ? privateData.creator : {};
    const approvedWalls = count(old.approvedWalls) + (memberUid ? 0 : 1);
    const uniqueMembers = count(old.uniqueMembers) + (memberUid ? 1 : 0);
    const awarded = new Set<string>(Array.isArray(old.awardedIds) ? old.awardedIds.filter((id: unknown) =>
      CREATOR_MILESTONES.some((milestone) => milestone.id === id)) : []);
    let xp = 0;
    for (const milestone of CREATOR_MILESTONES) {
      if (!awarded.has(milestone.id) && (milestone.metric === "approvedWalls" ? approvedWalls : uniqueMembers) >= milestone.target) {
        awarded.add(milestone.id); xp += milestone.xp;
      }
    }
    const currentKey = weekKey(nowMs);
    const previousKey = weekKey(weekBounds(nowMs).start - 1);
    const weeks: Week[] = [];
    for (const key of [currentKey, previousKey]) {
      const previous = Array.isArray(old.weeks) ? old.weeks.find((week: Week) => week?.weekKey === key) : undefined;
      if (key !== currentKey && !previous) continue;
      weeks.push({weekKey: key, approvedWalls: count(previous?.approvedWalls) + (key === currentKey && !memberUid ? 1 : 0),
        newMembers: count(previous?.newMembers) + (key === currentKey && memberUid ? 1 : 0),
        xp: count(previous?.xp) + (key === currentKey ? xp : 0)});
    }
    const xpFields = grantXp(creator.data() ?? {}, xp, nowMs);
    const rawOwned: unknown = privateData.inventory?.owned;
    let owned: Record<string, unknown> | null = null;
    if (rawOwned === undefined) owned = {};
    else if (Array.isArray(rawOwned)) {
      owned = Object.fromEntries(rawOwned.filter((id: unknown): id is string => typeof id === "string").map((id) => [id, 0]));
    } else if (rawOwned && typeof rawOwned === "object") {
      owned = Object.fromEntries(Object.entries(rawOwned));
    }
    const rankOwnership = Object.fromEntries(Object.keys(owned ?? {}).map((id) => [id, 0]));
    const ranks = owned === null ? null : rankRewardsFor(xpFields.xp, rankOwnership, config, nowMs);
    tx.set(receiptRef(logicalId), {
      ...(bound ?? {}), creatorUid: owner, ownerEmail: email(wall.data().email), canonicalPath: wall.ref.path,
      approvalCredited: bound?.approvalCredited === true || !memberUid,
      ...(memberUid ? {} : {approvalSourceTimeMs: sourceMs, approvalRecordedAtMs: nowMs}),
      ...(receipt.exists ? {} : {boundAtMs: nowMs}),
    });
    if (pairRef && rateRef) {
      tx.create(pairRef, {memberUid, sourceTimeMs: sourceMs, recordedAtMs: nowMs});
      tx.set(rateRef, {memberUid, day: dayKey(nowMs), count: rateCount + 1,
        expireAt: admin.firestore.Timestamp.fromMillis(nowMs + 2 * DAY_MS)});
    }
    tx.update(creatorRef, {...xpFields});
    tx.set(privateRef, {...privateData, rev: int(privateData.rev, 0) + 1,
      ...(ranks?.added.length ? {inventory: {...(privateData.inventory ?? {}),
        owned: {...owned, ...Object.fromEntries(ranks.added.map((id) => [id, nowMs]))}}} : {}),
      creator: {version: 1, trackedSinceMs: count(old.trackedSinceMs) || nowMs,
        approvedWalls, uniqueMembers, awardedIds: [...awarded], milestones: CREATOR_MILESTONES, weeks}});
  });
}

export const onCreatorWallWritten = onDocumentWritten(
  {document: "walls/{wallId}", region: REGION, retry: true},
  async (event) => {
    const after = event.data?.after;
    const data = after?.data();
    const before = event.data?.before.data();
    const becameProtected = data?.originalProtected === true && before?.originalProtected !== true;
    if (!after?.exists || !data || !validId(data.id) || data.review !== true ||
      (before?.review === true && !becameProtected) ||
      after.ref.id !== event.params.wallId) return;
    await recordCreator({logicalId: data.id, snapshot: after});
  },
);

export const onCreatorFavouriteCreated = onDocumentCreated(
  {document: "usersv2/{uid}/images/{wallId}", region: REGION, retry: true},
  async (event) => {
    const source = event.data;
    const data = source?.data();
    if (!source || !data || !validUid(event.params.uid) || !validId(event.params.wallId) ||
      data.id !== event.params.wallId || !PROVIDERS.has(text(data.provider).toLowerCase()) ||
      source.ref.path !== `usersv2/${event.params.uid}/images/${event.params.wallId}`) return;
    await recordCreator({logicalId: event.params.wallId, snapshot: source, memberUid: event.params.uid});
  },
);
