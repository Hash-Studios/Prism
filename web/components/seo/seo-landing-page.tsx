import { ArrowRight, Sparkles } from "lucide-react";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { seoRouteContent, seoRouteOrder, type SeoRouteContent } from "@/lib/seo-pages";
import { APP_NAME, PLAY_STORE_URL, TESTFLIGHT_COMING_SOON } from "@/lib/site-config";

type SeoLandingPageProps = {
  content: SeoRouteContent;
};

export function SeoLandingPage({ content }: SeoLandingPageProps) {
  const relatedPages = seoRouteOrder
    .filter((slug) => slug !== content.slug)
    .map((slug) => seoRouteContent[slug]);

  return (
    <>
      <Header />

      <main className="min-h-screen bg-hero-noise">
        <section className="border-b border-white/10 py-20 sm:py-24">
          <div className="mx-auto w-full max-w-5xl px-4 sm:px-6 lg:px-8">
            <Badge>Android personalization</Badge>
            <h1 className="mt-5 text-balance text-4xl font-bold tracking-tight text-white sm:text-5xl">
              {content.h1}
            </h1>
            <p className="mt-5 max-w-3xl text-pretty text-lg leading-relaxed text-white/75">
              {content.intro}
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Button href={PLAY_STORE_URL}>Get it on Google Play</Button>
              {TESTFLIGHT_COMING_SOON ? (
                <Button href="/#future" variant="secondary">
                  iPhone coming soon
                </Button>
              ) : null}
            </div>
          </div>
        </section>

        <section className="py-16 sm:py-20">
          <div className="mx-auto grid w-full max-w-5xl gap-4 px-4 sm:px-6 lg:px-8 md:grid-cols-3">
            {content.bullets.map((item) => (
              <article
                key={item}
                className="rounded-2xl border border-white/10 bg-white/[0.03] p-5"
              >
                <Sparkles className="h-4 w-4 text-accent" aria-hidden="true" />
                <p className="mt-3 text-sm leading-relaxed text-white/80">{item}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="border-y border-white/10 bg-base-850/70 py-16 sm:py-20">
          <div className="mx-auto w-full max-w-5xl px-4 sm:px-6 lg:px-8">
            <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
              {content.sectionTitle}
            </h2>
            <p className="mt-4 max-w-3xl text-base leading-relaxed text-white/75">
              {content.sectionBody}
            </p>

            <div className="mt-8 rounded-2xl border border-accent/30 bg-accent/10 p-5 text-sm text-white/85">
              <p>
                Looking for the full product overview? Visit the main {APP_NAME} landing
                page for features, collections, setups, and FAQs.
              </p>
              <a
                href="/"
                className="mt-3 inline-flex items-center gap-2 font-semibold text-accent transition hover:text-[#ef89a7]"
              >
                Explore homepage
                <ArrowRight className="h-4 w-4" aria-hidden="true" />
              </a>
            </div>
          </div>
        </section>

        <section className="py-16 sm:py-20">
          <div className="mx-auto w-full max-w-5xl px-4 sm:px-6 lg:px-8">
            <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
              Related personalization pages
            </h2>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-white/70">
              Explore more Android wallpaper and setup topics to find styles that match
              your taste.
            </p>

            <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {relatedPages.map((page) => (
                <a
                  key={page.slug}
                  href={`/${page.slug}`}
                  className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 transition hover:border-accent/35 hover:bg-white/[0.05]"
                >
                  <p className="text-sm font-semibold text-white">{page.navLabel}</p>
                  <p className="mt-1 text-xs leading-relaxed text-white/60">
                    {page.description}
                  </p>
                </a>
              ))}
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </>
  );
}
