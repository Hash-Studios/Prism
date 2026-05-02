import { APP_NAME } from "@/lib/site-config";

export type SeoRouteContent = {
  slug: "4k-wallpapers" | "amoled-wallpapers" | "home-screen-setups" | "collections";
  navLabel: string;
  title: string;
  description: string;
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
      "Prism Wallpapers helps you discover clean, high-resolution looks built for modern Android screens. Explore visual styles faster with curated paths and setup-friendly context.",
    bullets: [
      "Discover high-resolution wallpapers that stay crisp across devices.",
      "Explore curated 4K collections instead of random low-signal feeds.",
      "Move from wallpaper discovery to full personalization with setups.",
    ],
    sectionTitle: "Why Prism for 4K wallpaper discovery",
    sectionBody:
      "Prism focuses on visual quality and browsing quality together, so finding your next 4K wallpaper feels faster, cleaner, and more intentional.",
  },
  "amoled-wallpapers": {
    slug: "amoled-wallpapers",
    navLabel: "AMOLED Wallpapers",
    title: `AMOLED Wallpapers App for Android | ${APP_NAME}`,
    description:
      "Find AMOLED-friendly wallpapers with Prism Wallpapers. Explore dark, high-contrast styles and curated collections for Android personalization lovers.",
    h1: "AMOLED wallpapers that look clean, bold, and intentional",
    intro:
      "Prism makes it easy to browse dark and contrast-rich wallpapers that pair well with AMOLED displays, while still giving you setup inspiration and curated personalization flows.",
    bullets: [
      "Browse deep-tone wallpapers made for AMOLED visual impact.",
      "Explore curated aesthetics, not only individual images.",
      "Find looks that pair naturally with icon packs and widgets.",
    ],
    sectionTitle: "A better AMOLED browsing experience",
    sectionBody:
      "Prism is designed for people who care about how their phone feels daily. The app combines style discovery, setup context, and premium browsing polish.",
  },
  "home-screen-setups": {
    slug: "home-screen-setups",
    navLabel: "Home Screen Setups",
    title: `Home Screen Setups App for Android | ${APP_NAME}`,
    description:
      "Explore home screen setup inspiration with Prism Wallpapers. Discover wallpapers, setup ideas, and personalization-first Android browsing in one app.",
    h1: "Home screen setup inspiration, not just isolated wallpapers",
    intro:
      "Prism helps Android users move beyond standalone wallpaper browsing by surfacing setup ideas that make complete home screens feel more cohesive and expressive.",
    bullets: [
      "See setup context so wallpapers feel more actionable.",
      "Discover aesthetic directions faster with curated inspiration.",
      "Build a complete phone look with less trial and error.",
    ],
    sectionTitle: "Designed for personalization lovers",
    sectionBody:
      "Prism is built for people who enjoy the craft of personalization. It blends wallpapers, setups, and collections into one premium Android experience.",
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
      "Find wallpapers that align with your overall setup style.",
      "Turn quick inspiration into a polished daily home screen.",
    ],
    sectionTitle: "Collections with editorial quality",
    sectionBody:
      "Prism treats discovery like a premium browsing experience, combining careful curation and personalization context to help Android users choose with confidence.",
  },
};

export const seoRouteOrder: SeoRouteContent["slug"][] = [
  "4k-wallpapers",
  "amoled-wallpapers",
  "home-screen-setups",
  "collections",
];
