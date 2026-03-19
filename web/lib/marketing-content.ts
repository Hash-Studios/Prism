import {
  APP_NAME,
  GITHUB_URL,
  PLAY_STORE_URL,
  TESTFLIGHT_COMING_SOON,
} from "@/lib/site-config";

export const trustPoints = [
  "Open source",
  "Android app live now",
  "Built for personalization lovers",
] as const;

export const credibilityItems = [
  { label: "100K+ downloads", detail: "Trusted by Android personalization fans" },
  { label: "Open source", detail: "Built in public with a creator-first mindset" },
  { label: "Community-driven", detail: "Inspired by real setups and real users" },
  {
    label: "Android-focused",
    detail: "Designed for people who care how their home screen feels",
  },
] as const;

export const featureItems = [
  {
    title: "High-quality wallpapers",
    body: "Find polished wallpapers made to look crisp on modern Android displays.",
  },
  {
    title: "Curated collections",
    body: "Explore themed collections so you can discover faster with less scrolling.",
  },
  {
    title: "Home screen setups",
    body: "Browse setups and inspiration, not just standalone images.",
  },
  {
    title: "Preview before you apply",
    body: "Check how a wallpaper fits your screen style before committing.",
  },
  {
    title: "Better discovery and browsing",
    body: "Navigate with intent using categories, styles, and visual cues.",
  },
  {
    title: "Personalization-first experience",
    body: "Every flow is built around making your phone feel more like yours.",
  },
] as const;

export const galleryItems = [
  { title: "Explore Wallpapers", image: "/assets/screenshots/screen1.jpg" },
  { title: "Browse Setups", image: "/assets/screenshots/screen2.jpg" },
  { title: "Curated Collections", image: "/assets/screenshots/screen3.jpg" },
  { title: "Preview on Home Screen", image: "/assets/screenshots/screen4.jpg" },
  { title: "Personalize Your Look", image: "/assets/screenshots/screen5.jpg" },
] as const;

export const faqItems = [
  {
    q: "What is Prism Wallpapers?",
    a: `${APP_NAME} is a premium wallpaper and setup app focused on helping Android users discover better wallpapers, curated collections, and personalization inspiration in one place.`,
  },
  {
    q: "Is Prism Wallpapers available on Android?",
    a: `Yes. ${APP_NAME} is live on Google Play and built specifically for Android users who care about home screen quality and customization.`,
  },
  {
    q: "Is Prism coming to iPhone?",
    a: TESTFLIGHT_COMING_SOON
      ? "An iPhone version is in progress and planned for TestFlight."
      : "Yes, iPhone support is planned.",
  },
  {
    q: "Does Prism include 4K and AMOLED wallpapers?",
    a: "Prism is designed for high-quality visual browsing, including styles popular with 4K and AMOLED wallpaper lovers.",
  },
  {
    q: "Can I browse setups and home screen inspiration?",
    a: "Yes. Prism highlights setups and inspiration flows so you can discover complete looks, not only individual wallpapers.",
  },
  {
    q: "Is Prism open source?",
    a: `Yes. You can explore the project on GitHub: ${GITHUB_URL}`,
  },
  {
    q: "Where can I download Prism Wallpapers?",
    a: `Download ${APP_NAME} directly from Google Play: ${PLAY_STORE_URL}`,
  },
] as const;
