import { ArrowRight } from "lucide-react";
import { PlayStoreLink } from "@/components/download/apk-release-card";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { TopicLinks } from "@/components/seo/topic-links";
import { ORIGINAL_SIZE, PREVIEW_SIZE, STUDIO_CREDIT, amoledWalls, previewPath } from "@/lib/amoled-walls";
import { seoMetadata } from "@/lib/seo-pages";
import { PLAY_STORE_URL } from "@/lib/site-config";

export const metadata = seoMetadata("amoled-wallpapers");

const size = `${ORIGINAL_SIZE.width} × ${ORIGINAL_SIZE.height}`;
const link = "font-semibold text-white underline decoration-white/30 underline-offset-4 hover:decoration-accent";

export default function AmoledWallpapersPage() {
  return (
    <>
      <Header />

      <main className="min-h-screen bg-black pb-24 pt-32 text-white">
        <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold text-accent">{amoledWalls.length} wallpapers by Prism Studio</p>
            <h1 className="mt-3 text-balance text-4xl font-bold tracking-tight sm:text-5xl">
              AMOLED wallpapers with black backgrounds
            </h1>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-white/75">
              On an AMOLED screen, a black pixel is switched off. These wallpapers keep most of the frame black and light
              one subject, with clear space at the top for the clock. The full {size} files are available in Prism.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <PlayStoreLink href={PLAY_STORE_URL} />
              <a
                href="/download"
                className="inline-flex min-h-12 items-center justify-center rounded-2xl border border-white/15 bg-white/5 px-5 py-3 text-base font-semibold transition-colors hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
              >
                Other ways to install
              </a>
            </div>
          </div>

          <section aria-labelledby="walls-heading" className="mt-20">
            <h2 id="walls-heading" className="text-2xl font-bold tracking-tight sm:text-3xl">
              The wallpapers
            </h2>
            <ul className="mt-8 grid gap-x-6 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
              {amoledWalls.map((wall, index) => (
                <li key={wall.id}>
                  <figure className="grid grid-cols-[minmax(0,2fr)_minmax(0,3fr)] items-start gap-4 sm:block">
                    <img
                      src={previewPath(wall.id)}
                      width={PREVIEW_SIZE.width}
                      height={PREVIEW_SIZE.height}
                      alt={`${wall.title}, AMOLED wallpaper by ${STUDIO_CREDIT.name}`}
                      loading={index === 0 ? undefined : "lazy"}
                      decoding="async"
                      className="h-auto w-full rounded-2xl bg-black ring-1 ring-white/15"
                    />
                    <figcaption className="min-w-0 sm:mt-4">
                      <h3 className="text-lg font-semibold">
                        <a href={`/wallpaper/${wall.id}`} className="hover:text-accent focus-visible:text-accent">
                          {wall.title}
                        </a>
                      </h3>
                      <p className="mt-1 text-sm text-white/60">
                        By{" "}
                        <a href={STUDIO_CREDIT.href} className="underline decoration-white/30 underline-offset-4 hover:text-white">
                          {STUDIO_CREDIT.name}
                        </a>
                      </p>
                      <p className="mt-3 text-sm leading-relaxed text-white/75">{wall.description}</p>
                      <dl className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-white/60">
                        <div>
                          <dt className="inline">Original </dt>
                          <dd className="inline tabular-nums text-white/85">{size}</dd>
                        </div>
                      </dl>
                    </figcaption>
                  </figure>
                </li>
              ))}
            </ul>
          </section>

          <section
            aria-labelledby="theme-heading"
            className="mt-20 grid items-center gap-10 border-t border-white/10 pt-16 md:grid-cols-[minmax(0,1fr)_auto]"
          >
            <div className="max-w-xl">
              <h2 id="theme-heading" className="text-2xl font-bold tracking-tight sm:text-3xl">
                Turn the app black too
              </h2>
              <p className="mt-4 leading-relaxed text-white/75">
                Prism has a free AMOLED theme with a black background. Open Themes, set Theme Preference to Dark, then
                pick AMOLED under Dark Themes.
              </p>
            </div>
            <figure className="mx-auto w-full max-w-[220px] md:mx-0">
              <img
                src="/assets/screenshots/themes-iphone.jpg"
                width={440}
                height={956}
                alt="Prism's Themes screen, with AMOLED listed under Dark Themes"
                loading="lazy"
                decoding="async"
                className="h-auto w-full rounded-[28px] ring-1 ring-white/15"
              />
              <figcaption className="mt-3 text-xs leading-relaxed text-white/55">
                Captured on iPhone. Android shows the same Themes screen.
              </figcaption>
            </figure>
          </section>

          <section className="mt-20 grid gap-10 border-t border-white/10 pt-16 md:grid-cols-2">
            <div>
              <h2 className="text-xl font-bold tracking-tight">Why black looks deeper on AMOLED</h2>
              <p className="mt-3 leading-relaxed text-white/75">
                On AMOLED and other OLED screens, each pixel makes its own light. A black pixel gives off none, so black
                areas are as dark as the screen can go, and the lit parts of the picture stand out.
              </p>
            </div>
            <div>
              <h2 className="text-xl font-bold tracking-tight">Who made them</h2>
              <p className="mt-3 leading-relaxed text-white/75">
                All of them are by{" "}
                <a href={STUDIO_CREDIT.href} className={link}>
                  {STUDIO_CREDIT.name}
                </a>
                , the in-house account of Hash Studios, which makes Prism. For more, browse the{" "}
                <a href="/wallpapers/dark" className={link}>
                  Dark category
                </a>
                .
              </p>
            </div>
          </section>

          <section aria-labelledby="more-heading" className="mt-20 border-t border-white/10 pt-16">
            <h2 id="more-heading" className="text-xl font-bold tracking-tight">
              More from Prism
            </h2>
            <TopicLinks current="amoled-wallpapers" />
            <a href="/" className="mt-6 inline-flex items-center gap-2 font-semibold text-accent hover:text-[#ef89a7]">
              Prism home
              <ArrowRight className="size-4" aria-hidden="true" />
            </a>
          </section>
        </div>
      </main>

      <Footer />
    </>
  );
}
