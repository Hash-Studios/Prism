// eslint-disable-next-line spaced-comment
/// <reference lib="es2022.intl" />
export const HIDDEN_CHARACTERS = /[\p{Cc}\p{Cf}\p{Co}\p{Cn}]/u;
export const TEXT_SEGMENTER = new Intl.Segmenter(undefined, {granularity: "grapheme"});
const BLOCKED_WORDS = new Set([
  "nigger", "nigga", "faggot", "fag", "retard", "kike", "chink", "spic", "tranny", "porn", "porno", "nude", "nudes",
  "naked", "nsfw", "hentai", "sex", "sexy", "xxx", "boobs", "tits", "dick", "cock", "pussy", "cum", "rape", "milf",
]);
const PATTERNS = [...BLOCKED_WORDS].map((word) => new RegExp(`^${[...word].map((c) => `${c}+`).join("")}$`));
const PUNCTUATED_PATTERNS = [...BLOCKED_WORDS].map((word) => new RegExp(
  `(?:^|[^\\p{L}\\p{N}])${[...word].map((c) => `${c}+[\\p{P}\\p{S}\\p{Z}]*`).join("")}(?=$|[^\\p{L}\\p{N}])`, "u",
));
const LEET: Record<string, string> = {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"};
export function textWords(text: string): string[] {
  return text.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}
export function hasBlockedWord(text: string): boolean {
  const normalized = text.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase();
  const words = textWords(normalized);
  const unleet = textWords(normalized.replace(/[013457@$]/g, (c) => LEET[c]));
  return [...words, ...unleet].some((w) => BLOCKED_WORDS.has(w) || PATTERNS.some((p) => p.test(w))) ||
    PUNCTUATED_PATTERNS.some((pattern) => pattern.test(normalized) || pattern.test(
      normalized.replace(/[013457@$]/g, (c) => LEET[c]),
    ));
}
