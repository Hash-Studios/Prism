import { CredibilityStrip } from "@/components/sections/credibility-strip";
import { FaqSection } from "@/components/sections/faq";
import { FeaturesSection } from "@/components/sections/features";
import { FinalCtaSection } from "@/components/sections/final-cta";
import { Footer } from "@/components/sections/footer";
import { FutureSection } from "@/components/sections/future-section";
import { Header } from "@/components/sections/header";
import { Hero } from "@/components/sections/hero";
import { CollectionsSetupsSection } from "@/components/sections/collections-setups";
import { PositioningSection } from "@/components/sections/positioning";
import { ShowcaseGallerySection } from "@/components/sections/showcase-gallery";
import { getSoftwareApplicationSchema } from "@/lib/seo";

export default function HomePage() {
  const schema = getSoftwareApplicationSchema();

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
      />

      <Header />

      <main className="relative overflow-hidden bg-hero-noise">
        <Hero />
        <CredibilityStrip />
        <FeaturesSection />
        <PositioningSection />
        <ShowcaseGallerySection />
        <CollectionsSetupsSection />
        <FutureSection />
        <FaqSection />
        <FinalCtaSection />
      </main>

      <Footer />
    </>
  );
}
