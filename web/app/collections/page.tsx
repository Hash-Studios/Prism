import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoMetadata, seoRouteContent } from "@/lib/seo-pages";

export const metadata = seoMetadata("collections");

export default function CollectionsPage() {
  return <SeoLandingPage content={seoRouteContent.collections} />;
}
