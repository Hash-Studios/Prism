import { SectionHeading } from "@/components/ui/section-heading";
import { faqItems } from "@/lib/marketing-content";

export function FaqSection() {
  return (
    <section id="faq" className="border-y border-white/10 bg-base-850/70 py-20 sm:py-24">
      <div className="mx-auto w-full max-w-4xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          centered
          kicker="FAQ"
          title="Frequently asked questions"
          description="Answers for Android users looking for a premium wallpaper and setup app."
        />

        <div className="mt-10 space-y-3">
          {faqItems.map((item) => (
            <details
              key={item.q}
              className="group rounded-2xl border border-white/10 bg-white/[0.03] p-5 open:border-accent/30"
            >
              <summary className="cursor-pointer list-none pr-8 text-sm font-semibold text-white marker:content-none">
                {item.q}
              </summary>
              <p className="mt-3 text-sm leading-relaxed text-white/70">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
