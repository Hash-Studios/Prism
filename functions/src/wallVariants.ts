import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";
import {DOC_ID} from "./wallRemix";

export const VARIANT_GROUPS = "wallVariantGroups";
export const MAX_VARIANTS = 5;
/** Largest relative difference of width / height between two colourways of one wall. */
export const ASPECT_TOLERANCE = 0.02;

export type VariantDropReason = "not_found" | "not_owner" | "not_approved" | "group_full" | "aspect_ratio";
/** Server-owned `variantLink` on a wall: `linked`, or why its `variantOf` was dropped. */
export type VariantLink = "linked" | VariantDropReason;

type Wall = admin.firestore.DocumentData;

/** The wall a new upload names in `variantOf`, when the id is well formed. The wall is not checked here. */
export function variantTarget(data: Wall | undefined): string | null {
  const target = data?.variantOf;
  return typeof target === "string" && DOC_ID.test(target) ? target : null;
}

/** Width / height from a `WxH` resolution, or null. */
export function aspectOf(resolution: unknown): number | null {
  const match = /^\s*(\d{1,5})\s*[x×]\s*(\d{1,5})\s*$/i.exec(str(resolution));
  if (!match) return null;
  const width = Number(match[1]);
  const height = Number(match[2]);
  return width > 0 && height > 0 ? width / height : null;
}

/** Same email, without case or spaces. When both walls carry a server-set `creatorUid`, it must match too. */
export function sameCreator(a: Wall | undefined, b: Wall | undefined): boolean {
  const email = str(a?.email).trim().toLowerCase();
  if (email === "" || email !== str(b?.email).trim().toLowerCase()) return false;
  const uidA = str(a?.creatorUid);
  const uidB = str(b?.creatorUid);
  return uidA === "" || uidB === "" || uidA === uidB;
}

/** Why `wall` cannot join the colourways of `target`, or null when it can. `members` is the target's group now. */
export function variantDropReason(wallId: string, wall: Wall, targetId: string, target: Wall | undefined,
  members: string[]): VariantDropReason | null {
  if (targetId === wallId || !target) return "not_found";
  if (target.review !== true) return "not_approved";
  if (!sameCreator(wall, target)) return "not_owner";
  const own = aspectOf(wall.resolution);
  const theirs = aspectOf(target.resolution);
  if (own === null || theirs === null || Math.abs(own - theirs) / theirs > ASPECT_TOLERANCE) return "aspect_ratio";
  const after = new Set([...members, targetId, wallId]);
  return after.size > MAX_VARIANTS ? "group_full" : null;
}

/** The group a variant of `target` joins: the one the target is in, or a new one named after the target. */
const groupIdFor = (targetId: string, target: Wall | undefined) => str(target?.variantGroupId) || targetId;

/**
 * Checks `variantOf` on a new wall. A failed check removes the link and records the reason in `variantLink`. The
 * upload itself stays. Approval checks again, in a transaction, because the group can fill while the wall waits.
 */
export async function checkSubmittedVariantOf(snapshot: admin.firestore.DocumentSnapshot): Promise<VariantLink | null> {
  const data = snapshot.data();
  if (data?.variantOf === undefined) return null;
  return db.runTransaction(async (tx) => {
    const current = await tx.get(snapshot.ref);
    const wall = current.data();
    if (!wall || !snapshot.createTime || !current.createTime?.isEqual(snapshot.createTime) ||
      JSON.stringify(wall.variantOf) !== JSON.stringify(data.variantOf)) return null;
    if (wall.review === true) return null;
    const targetId = variantTarget(wall);
    const target = targetId ? (await tx.get(db.doc(`walls/${targetId}`))).data() : undefined;
    const groupId = targetId && target ? groupIdFor(targetId, target) : null;
    const group = groupId ? (await tx.get(db.doc(`${VARIANT_GROUPS}/${groupId}`))).data() : undefined;
    const live: string[] = [];
    let ownerMismatch = false;
    for (const id of members(group)) {
      const member = (await tx.get(db.doc(`walls/${id}`))).data();
      if (member?.review !== true || member.variantGroupId !== groupId) continue;
      live.push(id);
      if (!sameCreator(wall, member)) ownerMismatch = true;
    }
    const reason = targetId === null ? "not_found" :
      variantDropReason(snapshot.id, wall, targetId, target, live) ?? (ownerMismatch ? "not_owner" : null);
    if (reason === null) return null;
    tx.update(snapshot.ref, {variantOf: admin.firestore.FieldValue.delete(), variantLink: reason});
    return reason;
  });
}

const members = (group: Wall | undefined): string[] =>
  Array.isArray(group?.walls) ? [...new Set(group.walls.filter((id: unknown): id is string =>
    typeof id === "string" && DOC_ID.test(id)))] : [];

/**
 * Joins approved variants and repairs existing sets, including survivors of a deleted target. Every written wall
 * and group is read in the transaction. `knownGroups` also repairs membership from a delayed removal event.
 */
export async function syncVariantMembership(wallId: string, knownGroups: string[] = []): Promise<VariantLink | null> {
  const wallRef = db.doc(`walls/${wallId}`);
  return db.runTransaction(async (tx) => {
    const wall = (await tx.get(wallRef)).data();
    const targetId = wall?.review === true ? variantTarget(wall) : null;
    const target = targetId ? (await tx.get(db.doc(`walls/${targetId}`))).data() : undefined;
    const joinId = targetId && target ? groupIdFor(targetId, target) : null;
    const groupIds = [...new Set([joinId, str(wall?.variantGroupId), ...knownGroups].filter((id): id is string =>
      !!id && DOC_ID.test(id)))];
    const groups = new Map<string, {exists: boolean; walls: string[]; creatorUid: string}>();
    const docs = new Map<string, Wall | undefined>([[wallId, wall]]);
    if (targetId) docs.set(targetId, target);
    for (const groupId of groupIds) {
      const snap = await tx.get(db.doc(`${VARIANT_GROUPS}/${groupId}`));
      const ids = members(snap.data());
      groups.set(groupId, {exists: snap.exists, walls: ids, creatorUid: str(snap.data()?.creatorUid)});
      for (const id of ids) {
        if (!docs.has(id)) docs.set(id, (await tx.get(db.doc(`walls/${id}`))).data());
      }
    }

    let link: VariantLink | null = null;
    const next = new Map<string, string[]>();
    const existingId = str(wall?.variantGroupId);
    const existing = wall?.review === true && groups.get(existingId)?.walls.includes(wallId);
    for (const [groupId, group] of groups) {
      next.set(groupId, group.walls.filter((id) => id !== wallId && docs.get(id)?.review === true &&
        docs.get(id)?.variantGroupId === groupId));
    }
    if (wall && existing) {
      const peers = next.get(existingId) ?? [];
      if (peers.some((id) => !sameCreator(wall, docs.get(id)))) link = "not_owner";
      if (link === null && targetId && peers.includes(targetId)) {
        link = variantDropReason(wallId, wall, targetId, target, peers);
      }
      for (const id of peers) {
        if (link) break;
        const member = docs.get(id);
        if (member && variantTarget(member) === wallId) {
          link = variantDropReason(id, member, wallId, wall, peers);
        }
      }
      if (link === null) {
        const order = [...peers];
        order.splice(Math.min(groups.get(existingId)?.walls.indexOf(wallId) ?? 0, order.length), 0, wallId);
        next.set(existingId, order);
        if (wall.variantOf !== undefined || wall.variantLink === "linked") link = "linked";
      }
    } else if (wall && targetId) {
      const current = joinId ? next.get(joinId) ?? [] : [];
      link = variantDropReason(wallId, wall, targetId, target, current) ??
        (current.some((id) => !sameCreator(wall, docs.get(id))) ? "not_owner" : "linked");
      if (link === "linked" && joinId) {
        const order = [...current];
        if (!order.includes(targetId)) order.push(targetId);
        order.push(wallId);
        next.set(joinId, order);
      }
    }

    const placed = new Map<string, {groupId: string; index: number}>();
    for (const [groupId, ids] of next) {
      const ref = db.doc(`${VARIANT_GROUPS}/${groupId}`);
      if (ids.length < 2) {
        if (groups.get(groupId)?.exists) tx.delete(ref);
        continue;
      }
      ids.forEach((id, index) => placed.set(id, {groupId, index}));
      const creatorUid = ids.map((id) => str(docs.get(id)?.creatorUid)).find(Boolean) ?? "";
      if (JSON.stringify(ids) !== JSON.stringify(groups.get(groupId)?.walls ?? []) ||
        creatorUid !== groups.get(groupId)?.creatorUid) {
        tx.set(ref, {walls: ids, creatorUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      }
    }
    if (link === "linked" && !placed.has(wallId)) link = null;
    const touched = new Set<string>([wallId, ...[...groups.values()].flatMap((group) => group.walls), ...placed.keys()]);
    for (const id of touched) {
      const doc = docs.get(id);
      if (!doc) continue;
      const spot = placed.get(id);
      const update: Record<string, unknown> = {};
      if (spot) {
        if (doc.variantGroupId !== spot.groupId) update.variantGroupId = spot.groupId;
        if (doc.variantIndex !== spot.index) update.variantIndex = spot.index;
      } else if (id === wallId || groups.has(str(doc.variantGroupId))) {
        if (doc.variantLink === "linked") update.variantLink = admin.firestore.FieldValue.delete();
        if (doc.variantGroupId !== undefined) update.variantGroupId = admin.firestore.FieldValue.delete();
        if (doc.variantIndex !== undefined) update.variantIndex = admin.firestore.FieldValue.delete();
      }
      if (id === wallId) {
        if (link !== null && link !== "linked") update.variantOf = admin.firestore.FieldValue.delete();
        if (link !== null && doc.variantLink !== link) update.variantLink = link;
        if (link === null && doc.variantLink === "linked") update.variantLink = admin.firestore.FieldValue.delete();
      }
      if (Object.keys(update).length > 0) tx.update(db.doc(`walls/${id}`), update);
    }
    return link;
  });
}

/**
 * Keeps colourway groups in step with every wall write. Approval joins a variant to its group. A withdraw, a delete,
 * a reject (the wall moves to `rejectedWalls`), or a changed owner takes it out and renumbers the rest.
 */
export const onWallVariantWritten = onDocumentWritten(
  {
    document: "walls/{wallId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const involved = [before, after].some((wall) => wall &&
      ["variantOf", "variantGroupId", "variantIndex", "variantLink"].some((field) => wall[field] !== undefined));
    if (!involved) return;
    const changed = !before || !after || before.review !== after.review || before.variantOf !== after.variantOf ||
      before.email !== after.email || before.creatorUid !== after.creatorUid || before.resolution !== after.resolution;
    if (!changed) return;
    await syncVariantMembership(event.params.wallId, [str(before?.variantGroupId), str(after?.variantGroupId)]);
  },
);
