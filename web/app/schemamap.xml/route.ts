export const dynamic = "force-static";

export function GET() {
  return new Response(
    '<?xml version="1.0" encoding="UTF-8"?><schemamap><feed>https://prismwalls.com/openapi.json</feed><feed>https://prismwalls.com/sitemap.xml</feed></schemamap>',
    { headers: { "Content-Type": "application/xml; charset=utf-8" } },
  );
}
