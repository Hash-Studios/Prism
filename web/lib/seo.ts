import { APP_NAME, APP_STORE_URL, PLAY_STORE_URL, SITE_URL } from "@/lib/site-config";

export function getSoftwareApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: APP_NAME,
    applicationCategory: "MultimediaApplication",
    operatingSystem: "Android, iOS",
    description:
      "Discover high-quality wallpapers and curated collections with Prism Wallpapers, a premium wallpaper app for Android and iOS.",
    downloadUrl: [PLAY_STORE_URL, APP_STORE_URL],
    installUrl: PLAY_STORE_URL,
    url: SITE_URL,
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
  };
}
