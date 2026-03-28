import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { Hero } from "@/components/sections/hero";
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
      <Hero />
      <Footer />
    </>
  );
}
