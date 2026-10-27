import type { Metadata } from "next";
import { ShareButton } from "@/components/changelog/share-button";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { ogImagePath, readChangelog } from "@/lib/changelog";
import { APP_NAME, SITE_URL } from "@/lib/site-config";

const releases = readChangelog();
const latest = releases[0];

const title = `Changelog | ${APP_NAME}`;
const description = "What's new in every Prism release, newest first.";

export const metadata: Metadata = {
  title,
  description,
  alternates: {
    canonical: "/changelog",
    types: {
      "application/rss+xml": "/changelog/rss.xml",
    },
  },
  openGraph: {
    url: `${SITE_URL}/changelog`,
    title,
    description,
    images: [
      {
        url: ogImagePath(latest.slug),
        width: 1200,
        height: 630,
        alt: `Prism ${latest.version}`,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: [ogImagePath(latest.slug)],
  },
};

export default function ChangelogPage() {
  return (
    <>
      <Header />

      <main className="min-h-screen bg-neutral-100 pt-32 pb-24">
        <div className="mx-auto w-full max-w-3xl px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold tracking-tight text-black sm:text-4xl">Changelog</h1>
          <p className="mt-3 text-neutral-500">
            What&apos;s new in Prism, newest first.{" "}
            <a href="/changelog/rss.xml" className="text-accent hover:text-accent-dark transition-colors">
              RSS feed
            </a>
          </p>

          {releases.map((r) => (
            <section
              key={r.slug}
              id={r.slug}
              className="mt-10 scroll-mt-28 border-t border-neutral-200 pt-10 first-of-type:border-t-0 first-of-type:pt-0"
            >
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-semibold text-black">
                  <a href={`#${r.slug}`} className="hover:text-accent transition-colors">
                    {r.version}
                  </a>
                </h2>
                <ShareButton slug={r.slug} version={r.version} />
              </div>
              <ul className="mt-3 list-disc space-y-2 pl-5 text-neutral-600 leading-relaxed">
                {r.bullets.map((bullet, i) => (
                  <li key={i}>{bullet}</li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      </main>

      <Footer />
    </>
  );
}
