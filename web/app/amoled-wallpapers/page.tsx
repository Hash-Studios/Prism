import type { Metadata } from "next";
import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoRouteContent } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";

const content = seoRouteContent["amoled-wallpapers"];

export const metadata: Metadata = {
  title: content.title,
  description: content.description,
  alternates: {
    canonical: "/amoled-wallpapers",
  },
  openGraph: {
    url: `${SITE_URL}/amoled-wallpapers`,
    title: content.title,
    description: content.description,
    images: [{ url: "/assets/screenshots/screen2.jpg", width: 390, height: 844 }],
  },
  twitter: {
    card: "summary_large_image",
    title: content.title,
    description: content.description,
    images: ["/assets/screenshots/screen2.jpg"],
  },
};

export default function AmoledWallpapersPage() {
  return <SeoLandingPage content={content} />;
}
