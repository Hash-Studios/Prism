import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoMetadata, seoRouteContent } from "@/lib/seo-pages";

export const metadata = seoMetadata("amoled-wallpapers", "/assets/screenshots/screen2.jpg");

export default function AmoledWallpapersPage() {
  return <SeoLandingPage content={seoRouteContent["amoled-wallpapers"]} />;
}
