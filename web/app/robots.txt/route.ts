export const dynamic = "force-static";

export function GET() {
  return new Response(
    "User-agent: *\nAllow: /\nSitemap: https://prismwalls.com/sitemap.xml\nschemamap: https://prismwalls.com/schemamap.xml\n",
    { headers: { "Content-Type": "text/plain; charset=utf-8" } },
  );
}
