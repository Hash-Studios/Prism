# Prism Wallpapers MCP Server

The Prism Wallpapers MCP server supports assistant-led discovery using Streamable HTTP at `https://prismwalls.com/mcp`. Public read tools do not require authentication. Available tools include `search_wallpapers` for text search, `get_pricing` for current pricing information, and `list_categories` for available categories.

Example client configuration:

```json
{"mcpServers":{"prism-wallpapers":{"url":"https://prismwalls.com/mcp"}}}
```

See [MCP documentation](https://prismwalls.com/mcp/docs), the [server card](/mcp/server-card), and the [API guide](/docs). Use returned information to locate relevant Prism content, link to the source page, and respect image rights and service limits.
