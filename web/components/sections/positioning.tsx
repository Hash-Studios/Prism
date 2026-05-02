import { SectionHeading } from "@/components/ui/section-heading";

export function PositioningSection() {
  return (
    <section className="border-y border-white/10 bg-gradient-to-b from-base-850 to-base-900 py-20 sm:py-24">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          kicker="Why Prism feels different"
          title="Made for people who care how their phone feels every day"
          description="Prism is not just an endless feed of random wallpapers. It is a personalization experience that blends discovery, setups, collections, and visual inspiration in one premium flow."
        />

        <div className="mt-10 grid gap-5 md:grid-cols-3">
          <article className="rounded-2xl border border-white/10 bg-base-800/70 p-6">
            <p className="text-sm font-semibold text-white">Intentional discovery</p>
            <p className="mt-2 text-sm leading-relaxed text-white/70">
              Discover based on style and mood, not only by scrolling through endless lists.
            </p>
          </article>
          <article className="rounded-2xl border border-white/10 bg-base-800/70 p-6">
            <p className="text-sm font-semibold text-white">Setups and inspiration</p>
            <p className="mt-2 text-sm leading-relaxed text-white/70">
              Move from single images to complete home screen ideas with curated setup context.
            </p>
          </article>
          <article className="rounded-2xl border border-white/10 bg-base-800/70 p-6">
            <p className="text-sm font-semibold text-white">Premium browsing quality</p>
            <p className="mt-2 text-sm leading-relaxed text-white/70">
              Refined layout, cleaner hierarchy, and smoother interactions for a more polished experience.
            </p>
          </article>
        </div>
      </div>
    </section>
  );
}
