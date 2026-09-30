import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoMetadata, seoRouteContent } from "@/lib/seo-pages";

export const metadata = seoMetadata("4k-wallpapers", "/assets/screenshots/screen1.jpg");

export default function FourKWallpapersPage() {
  return <SeoLandingPage content={seoRouteContent["4k-wallpapers"]} />;
}
