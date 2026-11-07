const botUserAgents = [
  'GPTBot',
  'ChatGPT-User',
  'ClaudeBot',
  'Claude-User',
  'PerplexityBot',
  'Perplexity-User',
];

const htmlLinks = [
  '</sitemap.xml>; rel="sitemap"',
  '</index.md>; rel="alternate"; type="text/markdown"',
  '</openapi.json>; rel="service-desc"',
  '</.well-known/api-catalog>; rel="api-catalog"',
].join(', ');

function acceptsMarkdown(accept) {
  return accept.split(',').some((entry) => {
    const [mediaType, ...parameters] = entry.trim().toLowerCase().split(';');
    const quality = parameters.find((parameter) => parameter.trim().startsWith('q='));
    return mediaType === 'text/markdown' && (quality == null || Number(quality.trim().slice(2)) > 0);
  });
}

function appendVary(headers, value) {
  const existing = headers.get('Vary');
  if (!existing) {
    headers.set('Vary', value);
  } else if (!existing.split(',').some((item) => item.trim().toLowerCase() === value.toLowerCase())) {
    headers.set('Vary', `${existing}, ${value}`);
  }
}

function responseWithHeaders(response, headers, body = response.body) {
  return new Response(body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function agentResponse() {
  return Response.json({
    name: 'Prism Wallpapers',
    description: 'Discover and set beautiful wallpapers with Prism.',
    api: {
      baseUrl: 'https://prismwalls.com/api/v1',
      openapi: 'https://prismwalls.com/openapi.json',
    },
    mcp: {
      server: 'https://prismwalls.com/mcp',
      docs: 'https://prismwalls.com/mcp/docs',
      serverCard: 'https://prismwalls.com/.well-known/mcp/server-card.json',
    },
    auth: 'https://prismwalls.com/auth.md',
    pricing: 'https://prismwalls.com/pricing.md',
    llms: 'https://prismwalls.com/llms.txt',
    capabilities: ['search wallpapers', 'browse collections', 'view wallpaper details'],
  }, { headers: { 'Cache-Control': 'no-store' } });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const isHome = url.pathname === '/';
    const isRead = request.method === 'GET' || request.method === 'HEAD';

    if (isHome && isRead && url.searchParams.get('mode') === 'agent') {
      const response = agentResponse();
      const headers = new Headers(response.headers);
      appendVary(headers, 'Accept');
      return responseWithHeaders(response, headers, request.method === 'HEAD' ? null : response.body);
    }

    if (isHome) {
      const headers = new Headers();
      appendVary(headers, 'Accept');
      const accept = request.headers.get('Accept') ?? '';
      const userAgent = request.headers.get('User-Agent') ?? '';
      const wantsMarkdown = acceptsMarkdown(accept)
        || botUserAgents.some((bot) => userAgent.toLowerCase().includes(bot.toLowerCase()));

      if (isRead && wantsMarkdown) {
        const markdownUrl = new URL('/index.md', url.origin);
        const assetResponse = await env.ASSETS.fetch(new Request(markdownUrl, request));
        if (assetResponse.status !== 404) {
          const markdownHeaders = new Headers(assetResponse.headers);
          markdownHeaders.set('Content-Type', 'text/markdown; charset=utf-8');
          appendVary(markdownHeaders, 'Accept');
          appendVary(markdownHeaders, 'User-Agent');
          return responseWithHeaders(assetResponse, markdownHeaders, request.method === 'HEAD' ? null : assetResponse.body);
        }
      }

      const assetResponse = await env.ASSETS.fetch(request);
      if (assetResponse.status === 404 && acceptsMarkdown(accept)) {
        return new Response(request.method === 'HEAD' ? null : '# Not found\n\nSee [/llms.txt](/llms.txt) and [/sitemap.xml](/sitemap.xml).\n', {
          status: 404,
          headers: {
            'Content-Type': 'text/markdown; charset=utf-8',
            Vary: mergeVary(mergeVary(assetResponse.headers.get('Vary'), 'Accept'), 'User-Agent'),
          },
        });
      }

      const responseHeaders = new Headers(assetResponse.headers);
      appendVary(responseHeaders, 'Accept');
      appendVary(responseHeaders, 'User-Agent');
      const contentType = responseHeaders.get('Content-Type') ?? '';
      if (assetResponse.ok && contentType.toLowerCase().includes('text/html')) {
        const existingLink = responseHeaders.get('Link');
        responseHeaders.set('Link', existingLink ? `${existingLink}, ${htmlLinks}` : htmlLinks);
      }
      return responseWithHeaders(assetResponse, responseHeaders, request.method === 'HEAD' ? null : assetResponse.body);
    }

    const assetResponse = await env.ASSETS.fetch(request);
    if (assetResponse.status === 404 && acceptsMarkdown(request.headers.get('Accept') ?? '')) {
      return new Response(request.method === 'HEAD' ? null : '# Not found\n\nSee [/llms.txt](/llms.txt) and [/sitemap.xml](/sitemap.xml).\n', {
        status: 404,
        headers: {
          'Content-Type': 'text/markdown; charset=utf-8',
          Vary: mergeVary(assetResponse.headers.get('Vary'), 'Accept'),
        },
      });
    }
    return assetResponse;
  },
};

function mergeVary(existing, value) {
  const headers = new Headers();
  if (existing) headers.set('Vary', existing);
  appendVary(headers, value);
  return headers.get('Vary');
}
