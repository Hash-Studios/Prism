import * as admin from "firebase-admin";
import type {Firestore, Query, QueryDocumentSnapshot} from "firebase-admin/firestore";
import {str} from "../common";
import {normalizeId} from "../viewStats";
import {MAX_FUND_EVENTS} from "./load";
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
    for await (const doc of ranged.stream()) each(doc as unknown as QueryDocumentSnapshot);
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
  function add(event: FundEvent) {
    if (events.length >= MAX_FUND_EVENTS) throw new Error("Creator fund legacy event capacity exceeded.");
    events.push(event);
  }
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
        add({wallId, metric: "saves", actorUid: doc.id});
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
        add({wallId, metric, actorUid});
      }
    });

  const query = db.collection("wallRemixes").where("creditedAt", ">=", lo).where("creditedAt", "<", hi)
    .orderBy("creditedAt").orderBy(admin.firestore.FieldPath.documentId()).select("remixId", "originalId", "creditedAt").limit(50);
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    const page = await (last ? query.startAfter(last) : query).get();
    const ids = new Set(page.docs.flatMap((doc) => [str(doc.data().remixId), str(doc.data().originalId)])
      .filter((id) => id && !id.includes("/")));
    const snaps = ids.size ? await db.getAll(...[...ids].map((id) => db.collection("walls").doc(id)),
      {fieldMask: ["id", "creatorUid"]}) : [];
    const walls = new Map(snaps.map((snap) => [snap.id, snap.data()]));
    for (const doc of page.docs) {
      const actorUid = str(walls.get(str(doc.data().remixId))?.creatorUid);
      const wallId = normalized(walls.get(str(doc.data().originalId))?.id);
      if (actorUid && wallId) add({wallId, metric: "remixes", actorUid});
    }
    if (page.size < 50) break;
    last = page.docs[page.size - 1];
  }
  modes.remixes = "range";

  for await (const raw of db.collectionGroup("items").select("id", "provider", "ownerId", "addedBy").stream()) {
    const doc = raw as unknown as QueryDocumentSnapshot;
    const parts = doc.ref.path.split("/");
    const data = doc.data();
    const wallId = normalized(data.id);
    if (parts.length === 4 && parts[0] === "folders" && wallId && str(data.ownerId) &&
      ["prism", "wall_of_the_day", "walloftheday"].includes(str(data.provider).toLowerCase()) &&
      inRange(doc.createTime.toMillis(), range)) {
      const folder = await doc.ref.parent.parent?.get();
      if (folder?.exists && folder.data()?.ownerId === data.ownerId && folder.data()?.smartRules === undefined) {
        add({wallId, metric: "folderAdds", actorUid: str(data.addedBy ?? data.ownerId)});
      }
    }
  }
  modes.folderAdds = "scan";
  return {events, modes};
}
