import type { Metadata } from "next";
import { ContentPage } from "@/components/content-page";
import { GITHUB_URL, SITE_URL } from "@/lib/site-config";

const title = `Developers | Prism Wallpapers`;
const description = "Developer resources for Prism Wallpapers, including API docs, OpenAPI, MCP, and the source repository.";

export const metadata: Metadata = { title, description, alternates: { canonical: "/developers", types: { "text/markdown": "/developers.md" } }, openGraph: { url: `${SITE_URL}/developers`, title, description } };

export default function DevelopersPage() {
  return <ContentPage title="Prism Wallpapers for developers">
    <p>Build tools and experiences around Prism Wallpapers with the public developer resources. The API is designed for read-only catalog discovery, so applications can search wallpaper listings, request an individual item, browse categories, or check pricing information without a user sign-in. Start with the API guide to understand available endpoints, request patterns, and error handling before connecting a client.</p>
    <h2 className="pt-4 text-2xl font-semibold text-black">Integration resources</h2>
    <ul className="list-disc space-y-3 pl-6">
      <li><a className="text-accent underline" href="/docs">API documentation</a> explains the base URL, public read endpoints, examples, and sandbox behavior.</li>
      <li><a className="text-accent underline" href="/openapi.json">OpenAPI specification</a> can be used by API clients and code-generation tools.</li>
      <li><a className="text-accent underline" href="/mcp">MCP server</a> gives compatible assistants tools for wallpaper search, categories, and pricing.</li>
      <li><a className="text-accent underline" href={GITHUB_URL}>GitHub repository</a> contains the open-source application and contribution history.</li>
      <li><a className="text-accent underline" href="/llms.txt">llms.txt</a> is a compact index for language models and other automated readers.</li>
    </ul>
    <p>Use the sandbox to test request handling, keep clients resilient to updates, and link back to Prism when your experience presents wallpaper information. Public read access does not imply permission to bypass rate limits or redistribute images without respecting applicable content rights. If a resource or integration detail is unclear, contact the team using the information on the contact page.</p>
  </ContentPage>;
}
