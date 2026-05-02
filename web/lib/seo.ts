import { APP_NAME, PLAY_STORE_URL, SITE_URL } from "@/lib/site-config";

export function getSoftwareApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: APP_NAME,
    applicationCategory: "MultimediaApplication",
    operatingSystem: "Android",
    description:
      "Discover high-quality wallpapers, curated collections, and home screen setups with Prism Wallpapers, a premium wallpaper app for Android.",
    downloadUrl: PLAY_STORE_URL,
    installUrl: PLAY_STORE_URL,
    url: SITE_URL,
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
  };
}
