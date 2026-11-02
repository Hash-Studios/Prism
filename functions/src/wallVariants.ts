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
    const targetId = variantTarget(wall);
    const target = targetId ? (await tx.get(db.doc(`walls/${targetId}`))).data() : undefined;
    const group = targetId && target ? (await tx.get(db.doc(`${VARIANT_GROUPS}/${groupIdFor(targetId, target)}`))).data() : undefined;
    const reason = targetId === null ? "not_found" : variantDropReason(snapshot.id, wall, targetId, target, members(group));
    if (reason === null) return null;
    tx.update(snapshot.ref, {variantOf: admin.firestore.FieldValue.delete(), variantLink: reason});
    return reason;
  });
}

const members = (group: Wall | undefined): string[] =>
  Array.isArray(group?.walls) ? group.walls.filter((id: unknown): id is string => typeof id === "string") : [];

/**
 * Converges one wall's colourway membership in one transaction. An approved wall with a valid `variantOf` is in its
 * target's group. Any other wall is in no group. Every group it touches drops deleted or unapproved members and is
 * renumbered. A group with fewer than 2 walls is deleted. `knownGroups` are groups the wall was in before this write.
 * The group doc is read in the transaction, so two variants approved at once are serialized on it.
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
    const groups = new Map<string, {exists: boolean; walls: string[]}>();
    const docs = new Map<string, Wall | undefined>([[wallId, wall]]);
    if (targetId) docs.set(targetId, target);
    for (const groupId of groupIds) {
      const snap = await tx.get(db.doc(`${VARIANT_GROUPS}/${groupId}`));
      const ids = members(snap.data());
      groups.set(groupId, {exists: snap.exists, walls: ids});
      for (const id of ids) {
        if (!docs.has(id)) docs.set(id, (await tx.get(db.doc(`walls/${id}`))).data());
      }
    }

    let link: VariantLink | null = null;
    const next = new Map<string, string[]>();
    for (const [groupId, group] of groups) {
      next.set(groupId, group.walls.filter((id) => (id !== wallId || targetId === null) && docs.get(id)?.review === true));
    }
    if (wall && targetId) {
      const current = joinId ? next.get(joinId) ?? [] : [];
      link = variantDropReason(wallId, wall, targetId, target, current) ?? "linked";
      if (link === "linked" && joinId) {
        const order = [...current];
        if (!order.includes(targetId)) order.push(targetId);
        const at = groups.get(joinId)?.walls.indexOf(wallId) ?? -1;
        if (at >= 0) order.splice(Math.min(at, order.length), 0, wallId);
        else order.push(wallId);
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
      if (JSON.stringify(ids) !== JSON.stringify(groups.get(groupId)?.walls ?? [])) {
        tx.set(ref, {walls: ids, creatorUid: str(docs.get(ids[0])?.creatorUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      }
    }
    const touched = new Set<string>([wallId, ...[...groups.values()].flatMap((group) => group.walls), ...placed.keys()]);
    for (const id of touched) {
      const doc = docs.get(id);
      if (!doc) continue;
      const spot = placed.get(id);
      const update: Record<string, unknown> = {};
      if (spot) {
        if (doc.variantGroupId !== spot.groupId) update.variantGroupId = spot.groupId;
        if (doc.variantIndex !== spot.index) update.variantIndex = spot.index;
      } else {
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
    const involved = [before?.variantOf, after?.variantOf, before?.variantGroupId, after?.variantGroupId]
      .some((value) => typeof value === "string");
    if (!involved) return;
    const changed = !before || !after || before.review !== after.review || before.variantOf !== after.variantOf ||
      before.email !== after.email || before.creatorUid !== after.creatorUid || before.resolution !== after.resolution;
    if (!changed) return;
    await syncVariantMembership(event.params.wallId, [str(before?.variantGroupId), str(after?.variantGroupId)]);
  },
);
