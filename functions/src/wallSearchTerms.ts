import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {REGION} from "./common";

const STOPWORDS = new Set(["a", "an", "and", "at", "by", "for", "from", "in", "is", "of", "on", "the", "to", "with"]);
const MAX_SEARCH_TERMS = 64;

function singular(word: string): string {
  if (word.length <= 3) return word;
  if (word.endsWith("ies")) return `${word.slice(0, -3)}y`;
  if (["ches", "shes", "sses", "xes", "zes"].some((end) => word.endsWith(end))) return word.slice(0, -2);
  if (word.endsWith("s") && !["ss", "us", "is"].some((end) => word.endsWith(end))) return word.slice(0, -1);
  return word;
}

export function searchTermsOf(text: string): string[] {
  const terms: string[] = [];
  for (const word of text.toLowerCase().split(/[^\p{L}\p{M}\p{N}]+/u)) {
    if (word.length < 2 || STOPWORDS.has(word)) continue;
    const term = singular(word);
    if (!terms.includes(term)) terms.push(term);
  }
  return terms;
}

const textOf = (value: unknown): string[] => typeof value === "string" ? [value] : [];
const textsOf = (value: unknown): string[] => Array.isArray(value) ? value.flatMap(textOf) : [];

export function wallSearchTermsFor(data: Record<string, unknown>): string[] {
  const texts = [
    ...textOf(data.title),
    ...textsOf(data.tags),
    ...textOf(data.category),
    ...textOf(data.desc),
    ...textOf(data.by),
    ...textsOf(data.visionLabels),
  ];
  const terms = new Set(texts.flatMap(searchTermsOf));
  return [...terms].slice(0, MAX_SEARCH_TERMS);
}

export function sameTerms(stored: unknown, terms: string[]): boolean {
  return Array.isArray(stored) && stored.length === terms.length && stored.every((term, i) => term === terms[i]);
}

export const onWallSearchTerms = onDocumentWritten(
  {document: "walls/{wallId}", region: REGION},
  async (event) => {
    const after = event.data?.after;
    const data = after?.data();
    if (!after || !data) return;
    const searchTerms = wallSearchTermsFor(data);
    if (sameTerms(data.searchTerms, searchTerms)) return;
    await after.ref.update({searchTerms});
  },
);
