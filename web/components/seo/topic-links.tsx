import { seoRouteOrder, topicPages, type TopicPage } from "@/lib/seo-pages";

export function TopicLinks({ current }: { current: TopicPage["slug"] }) {
  return (
    <ul className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {seoRouteOrder
        .filter((slug) => slug !== current)
        .map((slug) => topicPages[slug])
        .map((page) => (
          <li key={page.slug}>
            <a
              href={`/${page.slug}`}
              className="block h-full rounded-2xl border border-current/15 p-4 transition-colors hover:border-accent/50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              <span className="text-sm font-semibold">{page.navLabel}</span>
              <span className="mt-1 block text-xs leading-relaxed opacity-70">{page.description}</span>
            </a>
          </li>
        ))}
    </ul>
  );
}
