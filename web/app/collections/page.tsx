import type { Metadata } from "next";
import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoRouteContent } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";

const content = seoRouteContent.collections;

export const metadata: Metadata = {
  title: content.title,
  description: content.description,
  alternates: {
    canonical: "/collections",
  },
  openGraph: {
    url: `${SITE_URL}/collections`,
    title: content.title,
    description: content.description,
    images: [{ url: "/assets/screenshots/screen3.jpg", width: 390, height: 844 }],
  },
  twitter: {
    card: "summary_large_image",
    title: content.title,
    description: content.description,
    images: ["/assets/screenshots/screen3.jpg"],
  },
};

export default function CollectionsPage() {
  return <SeoLandingPage content={content} />;
}
