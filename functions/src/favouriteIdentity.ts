import * as admin from "firebase-admin";
import {str} from "./common";

/** The same favourite can exist under its legacy id and its provider-qualified document id. */
export function favouriteIdentity(docId: string, data: admin.firestore.DocumentData): string {
  const provider = str(data.provider).toLowerCase();
  const id = str(data.id) || docId;
  return provider ? `${provider}:${id}` : `document:${docId}`;
}
