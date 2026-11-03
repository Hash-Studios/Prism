import { seoRouteOrder } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";
import { duoIsIndexable, duoRoute, duoWalls } from "@/lib/duo-wallpapers";

export const dynamic = "force-static";

const routes = ["/", ...seoRouteOrder.map((slug) => `/${slug}`), "/changelog", "/download",
  ...(duoIsIndexable(duoWalls) ? [duoRoute] : [])];

function escapeXml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export function GET(): Response {
  const now = new Date().toISOString();

  const entries = routes
    .map((route) => {
      const loc = escapeXml(`${SITE_URL}${route}`);
      const changefreq = route === "/" ? "weekly" : "monthly";
      const priority = route === "/" ? 1 : 0.7;
      return `  <url>\n    <loc>${loc}</loc>\n    <lastmod>${now}</lastmod>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`;
    })
    .join("\n");

  const body = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`;

  return new Response(body, {
    headers: { "content-type": "application/xml; charset=utf-8" },
  });
}
