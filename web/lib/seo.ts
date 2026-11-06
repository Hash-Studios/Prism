import {
  APP_NAME,
  APP_STORE_URL,
  CONTACT_EMAIL,
  GITHUB_URL,
  PLAY_STORE_URL,
  SITE_URL,
  TELEGRAM_URL,
  X_URL,
} from "@/lib/site-config";

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

export function getSiteGraphSchema() {
  const organizationId = `${SITE_URL}/#organization`;

  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": organizationId,
        name: APP_NAME,
        url: SITE_URL,
        logo: `${SITE_URL}/assets/ios.png`,
        sameAs: [GITHUB_URL, TELEGRAM_URL, X_URL, PLAY_STORE_URL, APP_STORE_URL],
        contactPoint: [{ "@type": "ContactPoint", email: CONTACT_EMAIL, contactType: "customer support" }],
      },
      {
        "@type": "WebSite",
        "@id": `${SITE_URL}/#website`,
        name: APP_NAME,
        url: SITE_URL,
        publisher: { "@id": organizationId },
      },
      { ...getSoftwareApplicationSchema(), "@id": `${SITE_URL}/#application` },
    ],
  };
}
