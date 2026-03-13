import Image from "next/image";
import { SectionHeading } from "@/components/ui/section-heading";
import { galleryItems } from "@/lib/marketing-content";

export function ShowcaseGallerySection() {
  return (
    <section className="py-20 sm:py-24">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          kicker="Showcase"
          title="See the Prism experience"
          description="A preview of Prism flows across wallpapers, setups, and collections."
        />

        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {galleryItems.map((item, index) => (
            <article
              key={item.title}
              className="group rounded-2xl border border-white/10 bg-base-800/70 p-3 transition duration-300 hover:-translate-y-1 hover:border-accent/35"
            >
              <Image
                src={item.image}
                alt={`Prism Wallpapers screenshot: ${item.title}`}
                width={280}
                height={560}
                className="h-auto w-full rounded-xl"
              />
              <p className="mt-3 text-sm font-medium text-white/85">{item.title}</p>
              <p className="mt-1 text-xs text-white/50">Panel {index + 1}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
