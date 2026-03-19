import type { Metadata } from "next";
import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoRouteContent } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";

const content = seoRouteContent["4k-wallpapers"];

export const metadata: Metadata = {
  title: content.title,
  description: content.description,
  alternates: {
    canonical: "/4k-wallpapers",
  },
  openGraph: {
    url: `${SITE_URL}/4k-wallpapers`,
    title: content.title,
    description: content.description,
    images: [{ url: "/assets/screenshots/screen1.jpg", width: 390, height: 844 }],
  },
  twitter: {
    card: "summary_large_image",
    title: content.title,
    description: content.description,
    images: ["/assets/screenshots/screen1.jpg"],
  },
};

export default function FourKWallpapersPage() {
  return <SeoLandingPage content={content} />;
}
