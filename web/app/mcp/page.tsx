import type { Metadata } from "next";
import { ContentPage } from "@/components/content-page";
import { SITE_URL } from "@/lib/site-config";

const title = "Prism Wallpapers MCP Server";
const description = "Connect MCP-compatible clients to Prism wallpaper search, categories, and pricing tools.";

export const metadata: Metadata = { title, description, alternates: { canonical: "/mcp", types: { "text/markdown": "/mcp.md" } }, openGraph: { url: `${SITE_URL}/mcp`, title, description } };

export default function McpPage() {
  return <ContentPage title={title}>
    <p>The Prism Wallpapers MCP server lets compatible assistants discover wallpaper content and public product information through structured tools. Connect with Streamable HTTP at <code className="rounded bg-white px-2 py-1 text-black">https://prismwalls.com/mcp</code>. The service is intended for read-only discovery and does not require authentication for its public tools. The protocol endpoint and tool definitions may evolve, so consult the live MCP documentation when configuring a client.</p>
    <p>Available tools include <code>search_wallpapers</code> for text-based wallpaper discovery, <code>get_pricing</code> for current pricing details, and <code>list_categories</code> for browsing available categories. A docs MCP server is at <a className="text-accent underline" href="https://prismwalls.com/mcp/docs">prismwalls.com/mcp/docs</a>, and the server-card metadata is at <a className="text-accent underline" href="/mcp/server-card">/mcp/server-card</a>.</p>
    <h2 className="pt-4 text-2xl font-semibold text-black">Example client configuration</h2>
    <pre className="overflow-x-auto rounded-xl bg-neutral-900 p-5 text-sm text-white"><code>{`{\n  "mcpServers": {\n    "prism-wallpapers": {\n      "url": "https://prismwalls.com/mcp"\n    }\n  }\n}`}</code></pre>
    <p>After adding the server, ask your assistant to search by subject or mood, list categories, or check pricing. Tool results help an agent locate relevant Prism content, but users should review the linked wallpaper page and applicable usage details before downloading or sharing imagery. For API-based integrations outside MCP, see the <a className="text-accent underline" href="/docs">API documentation</a>.</p>
  </ContentPage>;
}
