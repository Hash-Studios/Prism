import type { ReactNode } from "react";

export function Section({ heading, children }: { heading: string; children: ReactNode }) {
  return (
    <section className="mt-10">
      <h2 className="text-xl font-semibold text-black">{heading}</h2>
      <div className="mt-2 space-y-3 text-neutral-600 leading-relaxed">{children}</div>
    </section>
  );
}
