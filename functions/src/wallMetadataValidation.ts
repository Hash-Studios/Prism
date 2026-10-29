import {HttpsError} from "firebase-functions/v2/https";
import {hasBlockedWord, HIDDEN_CHARACTERS, TEXT_SEGMENTER} from "./textSafety";

export type WallText = {title: string; desc: string; tags: string[]};
export function exactKeys(raw: unknown, allowed: string[], required = allowed): Record<string, unknown> {
  if (!raw || typeof raw !== "object" || Object.getPrototypeOf(raw) !== Object.prototype ||
    Object.keys(raw).some((key) => !allowed.includes(key)) || required.some((key) => !(key in raw))) {
    throw new HttpsError("invalid-argument", "Invalid fields.");
  }
  return raw as Record<string, unknown>;
}
export function wallDocumentId(raw: unknown): string {
  if (typeof raw !== "string" || !raw || raw === "." || raw === ".." || raw.startsWith("__") ||
    Buffer.byteLength(raw, "utf8") > 1024 || /[/\\\p{C}]/u.test(raw)) {
    throw new HttpsError("invalid-argument", "Invalid wall document ID.");
  }
  return raw;
}
export function operationId(raw: unknown): string {
  if (typeof raw !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(raw)) {
    throw new HttpsError("invalid-argument", "Invalid operationId.");
  }
  return raw;
}
/** Type, control-character and size checks shared with private admin reasons, without vocabulary filtering. */
export function boundedDisplayText(raw: unknown, max: number): string {
  if (typeof raw !== "string" || raw.length > max * 4 || Buffer.byteLength(raw, "utf8") > max * 16 ||
    HIDDEN_CHARACTERS.test(raw) || /\p{Cs}/u.test(raw)) throw new HttpsError("invalid-argument", "text-rejected");
  const value = raw.replace(/\s+/g, " ").trim();
  if ([...TEXT_SEGMENTER.segment(value)].length > max) {
    throw new HttpsError("invalid-argument", "text-rejected");
  }
  return value;
}
export function boundedText(raw: unknown, max: number): string {
  const value = boundedDisplayText(raw, max);
  if (hasBlockedWord(value)) throw new HttpsError("invalid-argument", "text-rejected");
  return value;
}
export function parseWallText(raw: unknown): WallText {
  const input = exactKeys(raw, ["title", "desc", "tags"]);
  if (!Array.isArray(input.tags) || input.tags.length > 8) throw new HttpsError("invalid-argument", "tags-invalid");
  const tags = [...new Set(input.tags.map((tag) => boundedText(tag, 24).replace(/^#+/, "").trim().toLowerCase())
    .filter(Boolean))];
  if (hasBlockedWord(tags.join(" "))) throw new HttpsError("invalid-argument", "text-rejected");
  return {title: boundedText(input.title, 60), desc: boundedText(input.desc, 500), tags};
}

/** Read legacy optional fields without republishing or silently discarding unsafe values. */
export function wallTextForEdit(data: Record<string, unknown>): WallText {
  return {title: typeof data.title === "string" ? data.title : "", desc: typeof data.desc === "string" ? data.desc : "",
    tags: Array.isArray(data.tags) ? data.tags.filter((t): t is string => typeof t === "string") : []};
}
