import type { Metadata } from "next";
import { ContentPage } from "@/components/content-page";
import { SITE_URL } from "@/lib/site-config";

const title = "Prism Wallpapers API Documentation";
const description = "Public API guide for wallpaper search, wallpaper details, categories, pricing, and the sandbox.";

export const metadata: Metadata = { title, description, alternates: { canonical: "/docs", types: { "text/markdown": "/docs.md" } }, openGraph: { url: `${SITE_URL}/docs`, title, description } };

export default function DocsPage() {
  return <ContentPage title={title}>
    <p>The Prism Wallpapers API exposes public catalog information for apps, websites, and agent workflows. The base URL is <code className="rounded bg-white px-2 py-1 text-black">https://prismwalls.com/api/v1</code>. Public read requests do not require authentication. Responses use JSON; clients should handle pagination and service errors rather than assuming a fixed catalog size.</p>
    <h2 className="pt-4 text-2xl font-semibold text-black">Endpoints</h2>
    <div className="overflow-x-auto rounded-xl bg-white p-4"><table className="w-full text-left"><thead><tr><th className="p-2">Method and path</th><th className="p-2">Purpose</th></tr></thead><tbody>
      <tr><td className="p-2"><code>GET /api/v1/wallpapers</code></td><td className="p-2">Browse wallpapers. <code>q</code> filters only the first page of the latest list (or of a <code>category</code>); it is not a full-text search.</td></tr>
      <tr><td className="p-2"><code>GET /api/v1/wallpapers/&#123;id&#125;</code></td><td className="p-2">Retrieve one wallpaper by identifier.</td></tr>
      <tr><td className="p-2"><code>GET /api/v1/categories</code></td><td className="p-2">List available wallpaper categories.</td></tr>
      <tr><td className="p-2"><code>GET /api/v1/pricing</code></td><td className="p-2">List the plan tiers. Prices are set per store; check the app.</td></tr>
      <tr><td className="p-2"><code>GET /api/v1/sandbox/wallpapers</code></td><td className="p-2">Try the catalog response with sandbox data.</td></tr>
    </tbody></table></div>
    <h2 className="pt-4 text-2xl font-semibold text-black">Quick requests</h2>
    <pre className="overflow-x-auto rounded-xl bg-neutral-900 p-5 text-sm text-white"><code>{`curl 'https://prismwalls.com/api/v1/wallpapers?q=mountains'\ncurl 'https://prismwalls.com/api/v1/wallpapers/example-id'\ncurl 'https://prismwalls.com/api/v1/categories'\ncurl 'https://prismwalls.com/api/v1/sandbox/wallpapers'`}</code></pre>
    <p>Errors use a compact JSON object such as <code className="rounded bg-white px-2 py-1 text-black">&#123;&quot;error&quot;: &#123;&quot;code&quot;: &quot;not_found&quot;, &quot;message&quot;: &quot;Resource not found&quot; &#125;&#125;</code>. Check the HTTP status as well as the error code. Apply reasonable request pacing; sandbox responses are intended for integration testing and may have stricter rate limits or sample data, so do not treat them as production catalog results.</p>
    <p>See the machine-readable <a className="text-accent underline" href="/openapi.json">OpenAPI description</a> and the concise <a className="text-accent underline" href="/api.md">API summary</a>. For agent integrations, see the <a className="text-accent underline" href="/mcp">MCP server guide</a>.</p>
  </ContentPage>;
}
