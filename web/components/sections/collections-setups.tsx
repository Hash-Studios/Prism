import Image from "next/image";
import { SectionHeading } from "@/components/ui/section-heading";

export function CollectionsSetupsSection() {
  return (
    <section id="collections" className="border-y border-white/10 py-20 sm:py-24">
      <div className="mx-auto grid w-full max-w-6xl gap-10 px-4 sm:px-6 lg:grid-cols-2 lg:items-center lg:px-8">
        <div>
          <SectionHeading
            kicker="Collections + setups"
            title="Move from wallpaper browsing to full personalization"
            description="Prism helps you discover cohesive collections and setup inspiration so your home screen feels intentional, not random."
          />
          <div className="mt-7 space-y-3 text-sm leading-relaxed text-white/75">
            <p>
              Explore aesthetic wallpapers for Android with context around style, tone,
              and compatibility.
            </p>
            <p id="setups">
              Browse setup inspiration to see how wallpapers can pair with icons and
              widgets before you apply.
            </p>
            <p>
              Use curated paths to discover faster and build a look that feels uniquely
              yours.
            </p>
          </div>
        </div>

        <div className="grid gap-4">
          <article className="rounded-2xl border border-white/10 bg-base-800/70 p-4">
            <Image
              src="/assets/screenshots/screen3.jpg"
              alt="Prism Wallpapers curated collections panel"
              width={390}
              height={844}
              className="h-auto w-full rounded-xl"
            />
            <p className="mt-3 text-sm font-medium text-white">Curated collections</p>
          </article>
          <article className="rounded-2xl border border-white/10 bg-base-800/70 p-4">
            <Image
              src="/assets/screenshots/screen4.jpg"
              alt="Prism Wallpapers setup inspiration browsing panel"
              width={390}
              height={844}
              className="h-auto w-full rounded-xl"
            />
            <p className="mt-3 text-sm font-medium text-white">Setup inspiration</p>
          </article>
        </div>
      </div>
    </section>
  );
}
