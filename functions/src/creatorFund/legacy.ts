import * as admin from "firebase-admin";
import type {Firestore, Query, QueryDocumentSnapshot} from "firebase-admin/firestore";
import {str} from "../common";
import {normalizeId} from "../viewStats";
import type {FundEvent} from "./score";

/**
 * Rebuilds a week of fund events from records that existed before `creatorFundEvents`, for the dry run only. Sets and
 * downloads come from action receipts, which only some app builds send, so this undercounts them.
 */
type Range = {start: number; end: number};

const inRange = (ms: number | null, range: Range) => ms !== null && ms >= range.start && ms < range.end;
const millis = (value: unknown): number | null =>
  value instanceof admin.firestore.Timestamp ? value.toMillis() : typeof value === "number" ? value : null;
const normalized = (raw: unknown): string | null => {
  try {
    return normalizeId(raw);
  } catch {
    return null;
  }
};

/** Runs the indexed range query, or scans the whole group when the collection-group index is missing. */
async function rangeOrScan(ranged: Query, scan: Query, each: (doc: QueryDocumentSnapshot) => void): Promise<"range" | "scan"> {
  try {
    (await ranged.get()).forEach(each);
    return "range";
  } catch (err) {
    if ((err as {code?: number}).code !== 9) throw err;
  }
  for await (const doc of scan.stream()) each(doc as unknown as QueryDocumentSnapshot);
  return "scan";
}

export interface LegacyEvents {
  events: FundEvent[];
  modes: Record<string, "range" | "scan">;
}

export async function loadLegacyEvents(db: Firestore, range: Range): Promise<LegacyEvents> {
  const events: FundEvent[] = [];
  const modes: Record<string, "range" | "scan"> = {};
  const lo = admin.firestore.Timestamp.fromMillis(range.start);
  const hi = admin.firestore.Timestamp.fromMillis(range.end);

  const favourites = db.collectionGroup("favouriteContributions");
  modes.saves = await rangeOrScan(
    favourites.where("acceptedAt", ">=", lo).where("acceptedAt", "<", hi).select("active", "acceptedAt"),
    favourites.select("active", "acceptedAt"),
    (doc) => {
      const wallId = doc.ref.parent.parent?.id;
      if (doc.data().active === true && wallId && inRange(millis(doc.data().acceptedAt), range)) {
        events.push({wallId, metric: "saves", actorUid: doc.id});
      }
    });

  const receipts = db.collectionGroup("wallActionReceipts");
  modes.actions = await rangeOrScan(
    receipts.where("acceptedAt", ">=", range.start).where("acceptedAt", "<", range.end).select("wallId", "action", "counted", "acceptedAt"),
    receipts.select("wallId", "action", "counted", "acceptedAt"),
    (doc) => {
      const data = doc.data();
      const actorUid = doc.ref.parent.parent?.id;
      const wallId = normalized(data.wallId);
      const metric = data.action === "set" ? "sets" : data.action === "download" ? "downloads" : null;
      if (data.counted === true && actorUid && wallId && metric && inRange(millis(data.acceptedAt), range)) {
        events.push({wallId, metric, actorUid});
      }
    });

  const remixes = await db.collection("wallRemixes").where("creditedAt", ">=", lo).where("creditedAt", "<", hi).get();
  const wallRefs = remixes.docs.flatMap((doc) => [str(doc.data().remixId), str(doc.data().originalId)])
    .filter((id) => id && !id.includes("/")).map((id) => db.collection("walls").doc(id));
  const walls = new Map<string, admin.firestore.DocumentData | undefined>();
  for (let i = 0; i < wallRefs.length; i += 100) {
    for (const snap of await db.getAll(...wallRefs.slice(i, i + 100))) walls.set(snap.id, snap.data());
  }
  for (const doc of remixes.docs) {
    const actorUid = str(walls.get(str(doc.data().remixId))?.creatorUid);
    const wallId = normalized(walls.get(str(doc.data().originalId))?.id);
    if (actorUid && wallId) events.push({wallId, metric: "remixes", actorUid});
  }
  modes.remixes = "range";

  for await (const raw of db.collectionGroup("items").select("id", "provider", "ownerId").stream()) {
    const doc = raw as unknown as QueryDocumentSnapshot;
    const parts = doc.ref.path.split("/");
    const data = doc.data();
    const wallId = normalized(data.id);
    if (parts.length === 4 && parts[0] === "folders" && wallId && str(data.ownerId) &&
      ["prism", "wall_of_the_day", "walloftheday"].includes(str(data.provider).toLowerCase()) &&
      inRange(doc.createTime.toMillis(), range)) {
      events.push({wallId, metric: "folderAdds", actorUid: str(data.ownerId)});
    }
  }
  modes.folderAdds = "scan";
  return {events, modes};
}
