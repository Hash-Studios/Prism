import type { Metadata } from "next";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { Hero } from "@/components/sections/hero";
import { WebMcp } from "@/components/webmcp";
import { getSiteGraphSchema } from "@/lib/seo";
import { APP_NAME } from "@/lib/site-config";

export const metadata: Metadata = {
  alternates: { canonical: "/", types: { "text/markdown": "/index.md" } },
};

const faqs = [
  { question: "What is Prism Wallpapers?", answer: "Prism is a wallpaper discovery and personalization app for Android and iOS, with curated collections and high-resolution images." },
  { question: "Can I browse wallpapers by style or device?", answer: "Yes. Browse popular wallpapers, categories, phone wallpapers, and desktop wallpapers to find images that suit your screen and style." },
  { question: "Is Prism free to download?", answer: "Prism is free to download. Optional premium features and subscription details are described on the pricing page." },
  { question: "Can developers and AI agents use Prism?", answer: "Yes. Public API documentation, OpenAPI, and an MCP server are available for integrations and agent-assisted discovery." },
];

const faqSchema = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: faqs.map(({ question, answer }) => ({
    "@type": "Question",
    name: question,
    acceptedAnswer: { "@type": "Answer", text: answer },
  })),
};

export default function HomePage() {
  const schema = getSiteGraphSchema();

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
      />

      <Header />
      <WebMcp />
      <Hero />
      <main className="bg-neutral-100 px-4 pb-24 text-black">
        <div className="mx-auto max-w-5xl space-y-16">
          <section className="rounded-3xl bg-white/70 p-8 sm:p-12">
            <h2 className="text-3xl font-bold tracking-tight">A thoughtful way to find your next wallpaper</h2>
            <p className="mt-5 max-w-3xl leading-relaxed text-neutral-600">
              {APP_NAME} is a wallpaper discovery and personalization app for Android and iOS. It brings high-quality
              images and curated collections together so you can find a background that feels right for your screen,
              rather than sorting through an endless stream of unrelated pictures. Explore crisp 4K artwork, dark
              AMOLED-friendly designs, nature, abstract art, minimal styles, and more. Browse on your phone, save the
              images you love, and make your home screen feel more personal. Prism is made for everyday discovery,
              whether you know the exact look you want or are simply looking for a fresh idea.
            </p>
          </section>
          <section>
            <h2 className="text-3xl font-bold tracking-tight">Browse wallpapers</h2>
            <div className="mt-5 flex flex-wrap gap-3">
              {[["Wallpapers", "/wallpapers"], ["Desktop wallpapers", "/desktop-wallpapers"], ["Popular wallpapers", "/wallpapers/popular"], ["AMOLED wallpapers", "/amoled-wallpapers"], ["Collections", "/collections"]].map(([label, href]) => (
                <a key={href} href={href} className="rounded-full bg-white px-5 py-3 font-semibold text-accent shadow-sm">{label}</a>
              ))}
            </div>
            <p className="mt-5 max-w-3xl leading-relaxed text-neutral-600">
              Start with popular picks when you want inspiration, or choose a category to narrow the search by subject
              and mood. Desktop collections are available for larger displays, while phone-friendly wallpapers help
              make lock screens and home screens feel cohesive. Prism focuses on clear previews and curated discovery,
              helping you move from a visual idea to a wallpaper you can use without making the process complicated.
            </p>
          </section>
          <section className="rounded-3xl bg-white/70 p-8 sm:p-12">
            <h2 className="text-3xl font-bold tracking-tight">Made for personal screens</h2>
            <ul className="mt-6 grid gap-4 text-neutral-600 sm:grid-cols-2">
              <li><strong className="text-black">Curated discovery.</strong> Explore collections organized around visual themes and styles.</li>
              <li><strong className="text-black">High-resolution art.</strong> Find detailed wallpapers suited to modern phone displays.</li>
              <li><strong className="text-black">Dark and AMOLED looks.</strong> Browse deep tones and contrast-rich artwork.</li>
              <li><strong className="text-black">A personal library.</strong> Save favorites and revisit images you want to use later.</li>
            </ul>
          </section>
          <section>
            <h2 className="text-3xl font-bold tracking-tight">Frequently asked questions</h2>
            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              {faqs.map(({ question, answer }) => <article key={question} className="rounded-2xl bg-white p-6">
                <h3 className="text-lg font-semibold">{question}</h3><p className="mt-2 leading-relaxed text-neutral-600">{answer}</p>
              </article>)}
            </div>
          </section>
          <nav aria-label="More Prism resources" className="flex flex-wrap gap-x-6 gap-y-3 font-semibold text-accent">
            <a href="/open-source-android-wallpaper-app">Open source</a><a href="/docs">API docs</a><a href="/developers">Developers</a><a href="/mcp">MCP server</a><a href="/pricing.md">Pricing</a>
          </nav>
        </div>
      </main>
      <Footer />
    </>
  );
}
