import type { Metadata } from "next";
import { APP_NAME, OG_IMAGE, SITE_URL } from "@/lib/site-config";

export type TopicPage = {
  slug: "4k-wallpapers" | "amoled-wallpapers" | "open-source-android-wallpaper-app" | "collections";
  navLabel: string;
  title: string;
  description: string;
};

export type SeoRouteContent = TopicPage & {
  slug: "4k-wallpapers" | "collections";
  h1: string;
  intro: string;
  bullets: [string, string, string];
  sectionTitle: string;
  sectionBody: string;
};

export const seoRouteContent: Record<SeoRouteContent["slug"], SeoRouteContent> = {
  "4k-wallpapers": {
    slug: "4k-wallpapers",
    navLabel: "4K Wallpapers",
    title: `4K Wallpapers for Android | ${APP_NAME}`,
    description:
      "Browse premium 4K wallpapers for Android with Prism Wallpapers. Discover high-resolution styles, curated collections, and personalization-focused browsing.",
    h1: "4K wallpapers for Android, curated with a premium feel",
    intro:
      "Prism Wallpapers helps you discover clean, high-resolution looks built for modern Android screens. Explore visual styles faster with curated paths.",
    bullets: [
      "Discover high-resolution wallpapers that stay crisp across devices.",
      "Explore curated 4K collections instead of random low-signal feeds.",
      "Go from wallpaper discovery to a finished home screen faster.",
    ],
    sectionTitle: "Why Prism for 4K wallpaper discovery",
    sectionBody:
      "Prism focuses on visual quality and browsing quality together, so finding your next 4K wallpaper feels faster, cleaner, and more intentional.",
  },
  collections: {
    slug: "collections",
    navLabel: "Collections",
    title: `Wallpaper Collections App for Android | ${APP_NAME}`,
    description:
      "Browse curated wallpaper collections in Prism Wallpapers. Discover premium Android wallpapers by style, mood, and personalization direction.",
    h1: "Curated wallpaper collections for a better Android look",
    intro:
      "Prism replaces endless random browsing with structured, visual collections so you can discover wallpapers by style, mood, and personalization intent.",
    bullets: [
      "Navigate curated categories designed for faster discovery.",
      "Find wallpapers that match your overall home screen style.",
      "Turn quick inspiration into a polished daily home screen.",
    ],
    sectionTitle: "Collections with editorial quality",
    sectionBody:
      "Prism treats discovery like a premium browsing experience, combining careful curation and personalization context to help Android users choose with confidence.",
  },
};

export const topicPages: Record<TopicPage["slug"], TopicPage> = {
  ...seoRouteContent,
  "amoled-wallpapers": {
    slug: "amoled-wallpapers",
    navLabel: "AMOLED Wallpapers",
    title: `AMOLED Wallpapers with Black Backgrounds | ${APP_NAME}`,
    description:
      "Preview six dark AMOLED wallpapers by Prism Studio, with creator credits and descriptions. Get the full 1440 × 3200 wallpapers in Prism.",
  },
  "open-source-android-wallpaper-app": {
    slug: "open-source-android-wallpaper-app",
    navLabel: "Open-source app",
    title: `Open-Source Wallpaper App for Android | ${APP_NAME}`,
    description:
      "Prism is a wallpaper app for Android with its code on GitHub under the BSD 3-Clause licence. Free on Google Play, with an optional Pro subscription.",
  },
};

export const seoRouteOrder: TopicPage["slug"][] = [
  "4k-wallpapers",
  "amoled-wallpapers",
  "open-source-android-wallpaper-app",
  "collections",
];

export function seoMetadata(slug: TopicPage["slug"]): Metadata {
  const { title, description } = topicPages[slug];

  return {
    title,
    description,
    alternates: { canonical: `/${slug}` },
    openGraph: {
      url: `${SITE_URL}/${slug}`,
      title,
      description,
      images: [OG_IMAGE],
    },
    twitter: { card: "summary_large_image", title, description, images: [OG_IMAGE.url] },
  };
}
