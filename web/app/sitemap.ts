import type { MetadataRoute } from "next";
import { seoRouteOrder } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";
import { duoIsIndexable, duoRoute, duoWalls } from "@/lib/duo-wallpapers";

export const dynamic = "force-static";

const routes = ["/", ...seoRouteOrder.map((slug) => `/${slug}`), "/changelog",
  ...(duoIsIndexable(duoWalls) ? [duoRoute] : [])];

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return routes.map((route) => ({
    url: `${SITE_URL}${route}`,
    lastModified: now,
    changeFrequency: route === "/" ? "weekly" : "monthly",
    priority: route === "/" ? 1 : 0.7,
  }));
}
