import { credibilityItems } from "@/lib/marketing-content";

export function CredibilityStrip() {
  return (
    <section className="border-b border-white/10 py-10">
      <div className="mx-auto grid w-full max-w-6xl gap-4 px-4 sm:grid-cols-2 sm:px-6 lg:grid-cols-4 lg:px-8">
        {credibilityItems.map((item) => (
          <article
            key={item.label}
            className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 transition hover:border-accent/35 hover:bg-white/[0.05]"
          >
            <p className="text-sm font-semibold text-white">{item.label}</p>
            <p className="mt-2 text-xs leading-relaxed text-white/65">{item.detail}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
