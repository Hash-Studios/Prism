import { readChangelog } from "@/lib/changelog";
import { APP_NAME, SITE_URL } from "@/lib/site-config";

export const dynamic = "force-static";

function escapeXml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

export function GET() {
  const releases = readChangelog();
  const description = escapeXml("What's new in every Prism release.");

  const items = releases
    .map((release) => {
      const link = `${SITE_URL}/changelog#${release.slug}`;
      const html = `<ul>${release.bullets.map((bullet) => `<li>${escapeXml(bullet)}</li>`).join("")}</ul>`;
      return [
        "<item>",
        `<title>${escapeXml(`Prism ${release.version}`)}</title>`,
        `<link>${escapeXml(link)}</link>`,
        `<guid isPermaLink="true">${escapeXml(link)}</guid>`,
        `<description>${escapeXml(html)}</description>`,
        "</item>",
      ].join("");
    })
    .join("");

  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    "<channel>",
    `<title>${escapeXml(`${APP_NAME} changelog`)}</title>`,
    `<link>${escapeXml(`${SITE_URL}/changelog`)}</link>`,
    `<description>${description}</description>`,
    "<language>en</language>",
    `<atom:link href="${escapeXml(`${SITE_URL}/changelog/rss.xml`)}" rel="self" type="application/rss+xml"/>`,
    items,
    "</channel>",
    "</rss>",
  ].join("");

  return new Response(xml, { headers: { "Content-Type": "application/rss+xml; charset=utf-8" } });
}
