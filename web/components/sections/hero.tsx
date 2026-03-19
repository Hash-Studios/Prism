import Image from "next/image";
import { CheckCircle2, Sparkles } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { GlowOrb } from "@/components/ui/glow-orb";
import { trustPoints } from "@/lib/marketing-content";
import { PLAY_STORE_URL, TESTFLIGHT_COMING_SOON } from "@/lib/site-config";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden border-b border-white/10 py-20 sm:py-24">
      <GlowOrb className="-left-20 top-12 h-56 w-56" />
      <GlowOrb className="right-0 top-2 h-72 w-72 opacity-40" />

      <div className="mx-auto grid w-full max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[1.04fr_0.96fr] lg:items-center lg:px-8">
        <div>
          <Badge>Premium Android Personalization</Badge>
          <Image
            src="/assets/ios.png"
            alt="Prism Wallpapers app icon"
            width={64}
            height={64}
            className="mt-4 rounded-2xl border border-white/10"
            priority
          />
          <h1 className="mt-5 text-balance text-4xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
            Prism Wallpapers - A premium wallpaper app for Android
          </h1>
          <p className="mt-5 max-w-2xl text-pretty text-lg leading-relaxed text-white/75">
            Discover high-quality wallpapers, curated collections, and home screen
            setups designed for people who care about personalization.
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Button href={PLAY_STORE_URL}>Get it on Google Play</Button>
            {TESTFLIGHT_COMING_SOON ? (
              <Button href="#future" variant="secondary">
                iPhone coming soon
              </Button>
            ) : null}
          </div>

          <ul className="mt-6 grid gap-3 text-sm text-white/70 sm:grid-cols-3">
            {trustPoints.map((item) => (
              <li key={item} className="inline-flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-accent" aria-hidden="true" />
                <span>{item}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="relative flex justify-center lg:justify-end">
          <div className="absolute -inset-6 rounded-[2rem] bg-gradient-to-tr from-accent/20 via-transparent to-accent/10 blur-2xl" />
          <div className="relative grid max-w-md grid-cols-2 gap-4">
            <article className="group rounded-3xl border border-white/15 bg-base-800/80 p-3 shadow-2xl">
              <Image
                src="/assets/screenshots/screen1.jpg"
                alt="Prism Wallpapers app wallpaper discovery screen"
                width={320}
                height={640}
                className="h-auto w-full rounded-2xl"
                priority
              />
            </article>
            <article className="mt-10 rounded-3xl border border-white/15 bg-base-800/80 p-3 shadow-2xl">
              <Image
                src="/assets/screenshots/screen2.jpg"
                alt="Prism Wallpapers home screen setup preview"
                width={320}
                height={640}
                className="h-auto w-full rounded-2xl"
                priority
              />
            </article>

            <div className="col-span-2 inline-flex items-center justify-center gap-2 rounded-full border border-accent/30 bg-accent/10 px-4 py-2 text-xs font-medium uppercase tracking-[0.2em] text-accent">
              <Sparkles className="h-3.5 w-3.5" aria-hidden="true" />
              Built for Android personalization lovers
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
