# Prism Wallpapers API Documentation

The public Prism API base URL is `https://prismwalls.com/api/v1`. Public read requests do not require authentication and return JSON. Use `GET /api/v1/wallpapers` to browse or search with `q`, `GET /api/v1/wallpapers/{id}` for a wallpaper, `GET /api/v1/categories` for categories, `GET /api/v1/pricing` for pricing, and `GET /api/v1/sandbox/wallpapers` for sandbox data.

Example: `curl 'https://prismwalls.com/api/v1/wallpapers?q=mountains'`. Errors use a JSON `error` object with a stable `code` and readable `message`; check the HTTP status too. Apply reasonable pacing, since sandbox access may use sample responses or stricter limits. See [OpenAPI](/openapi.json), [the live docs](/docs), and the [MCP guide](/mcp). A listing does not grant image redistribution rights.
