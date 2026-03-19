import type { Metadata } from "next";
import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoRouteContent } from "@/lib/seo-pages";
import { SITE_URL } from "@/lib/site-config";

const content = seoRouteContent["home-screen-setups"];

export const metadata: Metadata = {
  title: content.title,
  description: content.description,
  alternates: {
    canonical: "/home-screen-setups",
  },
  openGraph: {
    url: `${SITE_URL}/home-screen-setups`,
    title: content.title,
    description: content.description,
    images: [{ url: "/assets/screenshots/screen4.jpg", width: 390, height: 844 }],
  },
  twitter: {
    card: "summary_large_image",
    title: content.title,
    description: content.description,
    images: ["/assets/screenshots/screen4.jpg"],
  },
};

export default function HomeScreenSetupsPage() {
  return <SeoLandingPage content={content} />;
}
