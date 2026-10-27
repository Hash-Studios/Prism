import { readFileSync } from "node:fs";
import { join } from "node:path";

export type Release = {
  version: string;
  slug: string;
  bullets: string[];
};

// Same rules as _parseChangelogMarkdown in lib/core/widgets/popup/changelog_pop_up.dart,
// so the site and the app's What's new sheet show the same releases.
export function parseChangelog(markdown: string): Release[] {
  const releases: Release[] = [];
  let current: Release | null = null;
  for (const raw of markdown.split("\n")) {
    const line = raw.trim();
    if (line.startsWith("### ")) {
      if (current && current.bullets.length > 0) releases.push(current);
      const version = line.slice(4).trim();
      current = { version, slug: versionSlug(version), bullets: [] };
    } else if (line.startsWith("- ") && current) {
      const text = line.slice(2).trim();
      if (text) current.bullets.push(text);
    }
  }
  if (current && current.bullets.length > 0) releases.push(current);
  return releases;
}

export function versionSlug(version: string): string {
  return version
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export function ogImagePath(slug: string): string {
  return `/changelog/og/${slug}.png`;
}

// The site builds from a full repo checkout (`npm run deploy` in web/, and CI checks out the whole repo).
export function readChangelog(): Release[] {
  return parseChangelog(readFileSync(join(process.cwd(), "..", "CHANGELOG.md"), "utf8"));
}
