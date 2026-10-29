import type * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";
import {syncPublicFolder, syncPublicFolderItem} from "./publicFolders";
import {r2Secrets} from "./r2Storage";

export const FOLDERS = "folders";
export const FOLDER_ITEMS = "items";
const MAX_COVERS = 4;

/** True for folders/{folderId}/items/{itemKey}. Other collections also have an "items" subcollection. */
export function isFolderItemPath(path: string): boolean {
  const parts = path.split("/");
  return parts.length === 4 && parts[0] === FOLDERS && parts[2] === FOLDER_ITEMS;
}

/**
 * Sets the folder's itemCount and covers from its items. Clients keep both with increments and local covers,
 * which drift when offline batches or two devices write the same folder. Only the owner's items count.
 */
export async function repairFolder(folderId: string): Promise<void> {
  const folderRef = db.collection(FOLDERS).doc(folderId);
  await db.runTransaction(async (tx) => {
    const folder = await tx.get(folderRef);
    // A deleted folder stays deleted.
    if (!folder.exists) return;
    const data = folder.data() ?? {};
    const items = folderRef.collection(FOLDER_ITEMS).where("ownerId", "==", str(data.ownerId));
    const count = (await tx.get(items.count())).data().count;
    const newest = await tx.get(items.orderBy("addedAt", "desc").limit(MAX_COVERS));
    const covers = [...new Set(newest.docs.map((item) => str(item.data().thumb)).filter(Boolean))];
    const current = Array.isArray(data.covers) ? data.covers : [];
    if (data.itemCount === count && JSON.stringify(current) === JSON.stringify(covers)) return;
    tx.update(folderRef, {itemCount: count, covers});
  });
}

export const onFolderItemWritten = onDocumentWritten(
  {document: `${FOLDERS}/{folderId}/${FOLDER_ITEMS}/{itemKey}`, region: REGION, retry: true, secrets: r2Secrets, memory: "512MiB"},
  async (event) => {
    await repairFolder(event.params.folderId);
    await syncPublicFolderItem(event.params.folderId, event.params.itemKey);
  },
);

/** True when a folder write can change its public projection. */
export function changesPublicFolder(before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined): boolean {
  if (before?.public !== true && after?.public !== true) return false;
  return !before || !after || ["public", "name", "ownerId", "moderationHidden"].some((key) => before[key] !== after[key]);
}

export const onFolderWritten = onDocumentWritten(
  {document: `${FOLDERS}/{folderId}`, region: REGION, retry: true, secrets: r2Secrets, memory: "512MiB"},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (changesPublicFolder(before?.data(), after?.data())) await syncPublicFolder(event.params.folderId);
    if (!before?.exists || !after?.exists) return;
    const previousCount = before.data()?.itemCount;
    const currentCount = after.data()?.itemCount;
    if (typeof previousCount !== "number" || typeof currentCount !== "number" || currentCount >= previousCount) return;
    await repairFolder(event.params.folderId);
  },
);
