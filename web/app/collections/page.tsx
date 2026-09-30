import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoMetadata, seoRouteContent } from "@/lib/seo-pages";

export const metadata = seoMetadata("collections", "/assets/screenshots/screen3.jpg");

export default function CollectionsPage() {
  return <SeoLandingPage content={seoRouteContent.collections} />;
}
