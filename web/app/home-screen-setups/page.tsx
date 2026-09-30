import { SeoLandingPage } from "@/components/seo/seo-landing-page";
import { seoMetadata, seoRouteContent } from "@/lib/seo-pages";

export const metadata = seoMetadata("home-screen-setups", "/assets/screenshots/screen4.jpg");

export default function HomeScreenSetupsPage() {
  return <SeoLandingPage content={seoRouteContent["home-screen-setups"]} />;
}
