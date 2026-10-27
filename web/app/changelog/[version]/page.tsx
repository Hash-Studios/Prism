import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { ogImagePath, readChangelog } from "@/lib/changelog";
import { SITE_URL } from "@/lib/site-config";

export const dynamicParams = false;

export function generateStaticParams() {
  return readChangelog().map((r) => ({ version: r.slug }));
}

function findRelease(slug: string) {
  const release = readChangelog().find((r) => r.slug === slug);
  if (!release) notFound();
  return release;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ version: string }>;
}): Promise<Metadata> {
  const { version } = await params;
  const r = findRelease(version);
  const title = `Prism ${r.version} | Changelog`;
  const description = r.bullets.slice(0, 3).join(". ");

  return {
    title,
    description,
    alternates: {
      canonical: `/changelog/${r.slug}`,
    },
    openGraph: {
      type: "article",
      url: `${SITE_URL}/changelog/${r.slug}`,
      title,
      description,
      images: [
        {
          url: ogImagePath(r.slug),
          width: 1200,
          height: 630,
          alt: `Prism ${r.version}`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImagePath(r.slug)],
    },
  };
}

export default async function ChangelogVersionPage({
  params,
}: {
  params: Promise<{ version: string }>;
}) {
  const { version } = await params;
  const r = findRelease(version);
  const target = `/changelog#${r.slug}`;

  return (
    <>
      <meta httpEquiv="refresh" content={`0; url=${target}`} />
      <Header />

      <main className="min-h-screen bg-neutral-100 pt-32 pb-24">
        <div className="mx-auto w-full max-w-3xl px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold tracking-tight text-black sm:text-4xl">
            Prism {r.version}
          </h1>
          <ul className="mt-6 list-disc space-y-2 pl-5 text-neutral-600 leading-relaxed">
            {r.bullets.map((bullet, i) => (
              <li key={i}>{bullet}</li>
            ))}
          </ul>
          <p className="mt-10">
            <a href={target} className="text-accent hover:text-accent-dark transition-colors">
              See all releases
            </a>
          </p>
        </div>
      </main>

      <Footer />
    </>
  );
}
