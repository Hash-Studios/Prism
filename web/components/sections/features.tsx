import {
  Compass,
  Grid2x2,
  ImageIcon,
  LayoutTemplate,
  Search,
  Sparkles,
} from "lucide-react";
import { SectionHeading } from "@/components/ui/section-heading";
import { featureItems } from "@/lib/marketing-content";

const icons = [ImageIcon, Grid2x2, LayoutTemplate, Compass, Search, Sparkles] as const;

export function FeaturesSection() {
  return (
    <section id="features" className="py-20 sm:py-24">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          kicker="Features"
          title="Everything you need for a better-looking phone"
          description="Prism is designed for intentional discovery and daily personalization, not endless low-quality wallpaper dumping."
        />

        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {featureItems.map((feature, index) => {
            const Icon = icons[index];

            return (
              <article
                key={feature.title}
                className="rounded-2xl border border-white/10 bg-gradient-to-b from-white/[0.06] to-white/[0.02] p-6 transition duration-300 hover:-translate-y-0.5 hover:border-accent/35"
              >
                <div className="inline-flex rounded-xl border border-accent/25 bg-accent/10 p-2.5">
                  <Icon className="h-5 w-5 text-accent" aria-hidden="true" />
                </div>
                <h3 className="mt-4 text-lg font-semibold text-white">{feature.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-white/70">{feature.body}</p>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
