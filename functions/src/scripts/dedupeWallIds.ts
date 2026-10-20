import * as admin from "firebase-admin";

import {randomWallId, type Rng} from "../studio/ids";

export type WallRow = {docId: string; id: string; review: boolean; createdAtMs: number; url: string; thumb: string};
export type DedupeOptions = {apply: boolean; rng?: Rng};
export type DedupeCounts = {groups: number; renamed: number; favouritesMoved: number; favouritesAmbiguous: number};

const USER_CONCURRENCY = 50;

export const USAGE = `Usage: node lib/scripts/dedupeWallIds.js [--apply]

Finds walls that share one logical id (old 4-character ids collided). In each group it keeps the approved,
oldest wall and gives every other wall a new 10-character id. Favourites under usersv2/*/images/{oldId}
whose url or thumb matches a renamed wall move to the new id. A dry run reads only and writes nothing.`;

const text = (value: unknown): string => typeof value === "string" ? value.trim() : "";

function millis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") return Date.parse(value) || Number.MAX_SAFE_INTEGER;
  return Number.MAX_SAFE_INTEGER;
}

export function toWallRow(docId: string, data: admin.firestore.DocumentData): WallRow {
  return {
    docId,
    id: text(data.id) || docId,
    review: data.review === true,
    createdAtMs: millis(data.createdAt),
    url: text(data.wallpaper_url),
    thumb: text(data.wallpaper_thumb),
  };
}

/** Groups of two or more walls with one logical id. The first wall of each group keeps the id. */
export function duplicateGroups(walls: WallRow[]): WallRow[][] {
  const byId = new Map<string, WallRow[]>();
  for (const wall of walls) byId.set(wall.id, [...byId.get(wall.id) ?? [], wall]);
  return [...byId.values()].filter((group) => group.length > 1).map((group) => [...group].sort((a, b) =>
    Number(b.review) - Number(a.review) || a.createdAtMs - b.createdAtMs || a.docId.localeCompare(b.docId)));
}

/** The wall in [group] that a favourite doc shows, by its url or thumb. Undefined when none or several match. */
export function favouriteTarget(fav: admin.firestore.DocumentData, group: WallRow[]): WallRow | undefined {
  const url = text(fav.url);
  const thumb = text(fav.thumb);
  const hits = group.filter((wall) => url !== "" && url === wall.url || thumb !== "" && thumb === wall.thumb);
  return hits.length === 1 ? hits[0] : undefined;
}

export async function dedupeWallIds(
  db: admin.firestore.Firestore,
  options: DedupeOptions,
  log: (line: string) => void = console.log,
): Promise<DedupeCounts> {
  const counts: DedupeCounts = {groups: 0, renamed: 0, favouritesMoved: 0, favouritesAmbiguous: 0};
  const walls = (await db.collection("walls").select("id", "review", "createdAt", "wallpaper_url", "wallpaper_thumb")
    .get()).docs.map((doc) => toWallRow(doc.id, doc.data()));
  const taken = new Set(walls.map((wall) => wall.id));
  const groups = duplicateGroups(walls);
  counts.groups = groups.length;
  const newIds = new Map<string, string>();

  for (const [keeper, ...others] of groups) {
    log(`id ${keeper.id}: keep walls/${keeper.docId} review=${keeper.review} ` +
      `createdAt=${new Date(keeper.createdAtMs).toISOString()} url=${keeper.url || keeper.thumb}`);
    for (const wall of others) {
      let next = randomWallId(options.rng);
      while (taken.has(next)) next = randomWallId(options.rng);
      taken.add(next);
      newIds.set(wall.docId, next);
      log(`id ${wall.id}: rename walls/${wall.docId} to ${next} review=${wall.review} ` +
        `createdAt=${new Date(wall.createdAtMs).toISOString()} url=${wall.url || wall.thumb}`);
      if (!options.apply) continue;
      await db.runTransaction(async (tx) => {
        const ref = db.collection("walls").doc(wall.docId);
        const [current, clash] = await Promise.all([
          tx.get(ref),
          tx.get(db.collection("walls").where("id", "==", next).limit(1)),
        ]);
        if (text(current.data()?.id) !== wall.id || !clash.empty) {
          throw new Error(`walls/${wall.docId} changed or ${next} is taken; run again`);
        }
        tx.update(ref, {id: next});
      });
      counts.renamed += 1;
    }
  }
  if (groups.length === 0) {
    log("done: no duplicate ids");
    return counts;
  }

  const users = (await db.collection("usersv2").select().get()).docs;
  log(`checking favourites of ${users.length} users`);
  for (let i = 0; i < users.length; i += USER_CONCURRENCY) {
    await Promise.all(users.slice(i, i + USER_CONCURRENCY).map(async (user) => {
      for (const group of groups) {
        const oldRef = user.ref.collection("images").doc(group[0].id);
        const fav = await oldRef.get();
        if (!fav.exists) continue;
        const target = favouriteTarget(fav.data() ?? {}, group);
        if (!target) {
          counts.favouritesAmbiguous += 1;
          log(`${oldRef.path}: matches no single wall, left as is`);
          continue;
        }
        const next = newIds.get(target.docId);
        if (!next) continue;
        counts.favouritesMoved += 1;
        log(`${oldRef.path}: move to ${next}`);
        if (!options.apply) continue;
        const newRef = user.ref.collection("images").doc(next);
        await db.runTransaction(async (tx) => {
          const [current, existing] = await Promise.all([tx.get(oldRef), tx.get(newRef)]);
          if (!current.exists) return;
          if (!existing.exists) tx.set(newRef, {...current.data(), id: next});
          tx.delete(oldRef);
        });
      }
    }));
  }

  log(`done groups=${counts.groups} renamed=${counts.renamed} favouritesMoved=${counts.favouritesMoved} ` +
    `favouritesAmbiguous=${counts.favouritesAmbiguous} applied=${options.apply}`);
  return counts;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  console.log(USAGE);
  if (!argv.includes("--help")) {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    dedupeWallIds(admin.firestore(), {apply: argv.includes("--apply")}).catch((err) => {
      console.error(err);
      process.exitCode = 1;
    });
  }
}
