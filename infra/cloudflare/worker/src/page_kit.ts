// HTML and platform helpers shared by the link landings (index.ts) and the web catalogue (catalog.ts).

const ANDROID_PACKAGE = 'com.hash.prism';

export type Platform = 'android' | 'ios' | 'other';

export interface ScreenshotEnv {
  BROWSER_RENDERING_ACCOUNT_ID?: string;
  BROWSER_RENDERING_API_TOKEN?: string;
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function escapeAttribute(value: string): string {
  return escapeHtml(value).replaceAll('`', '&#96;');
}

export function detectPlatform(request: Request): Platform {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  if (userAgent.includes('iphone') || userAgent.includes('ipad') || userAgent.includes('ipod')) {
    return 'ios';
  }
  if (userAgent.includes('android')) {
    return 'android';
  }
  return 'other';
}

export function buildAndroidIntentUrl(canonicalUrl: string, fallbackUrl: string): string {
  const target = new URL(canonicalUrl);
  const path = `${target.host}${target.pathname}${target.search}`.replaceAll(';', '%3B');
  return `intent://${path}#Intent;scheme=https;package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`;
}

/**
 * iOS opens a universal link in Safari when it points at the page's own host, so an "Open in Prism" link on
 * prismwalls.com does nothing. Both hosts are associated with the app, so the link goes to the other one.
 */
export function iosUniversalLinkUrl(canonicalUrl: string, pageHost: string): string {
  const target = new URL(canonicalUrl);
  if (target.host !== pageHost || !['prismwalls.com', 'www.prismwalls.com'].includes(target.host)) return canonicalUrl;
  target.host = target.host.startsWith('www.') ? target.host.slice(4) : `www.${target.host}`;
  return target.toString();
}

/** A 1200x630 JPEG of a card page, or null when Browser Rendering is not configured or fails. */
export async function screenshotCard(htmlTemplate: string, env: ScreenshotEnv): Promise<Uint8Array | null> {
  if (!env.BROWSER_RENDERING_ACCOUNT_ID || !env.BROWSER_RENDERING_API_TOKEN) {
    return null;
  }

  const endpoint = `https://api.cloudflare.com/client/v4/accounts/${env.BROWSER_RENDERING_ACCOUNT_ID}/browser-rendering/screenshot`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.BROWSER_RENDERING_API_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      html: htmlTemplate,
      viewport: {
        width: 1200,
        height: 630,
      },
      // Fonts and images load from the network; wait for them before the screenshot.
      gotoOptions: {
        waitUntil: 'networkidle0',
      },
      screenshotOptions: {
        type: 'jpeg',
        quality: 85,
      },
    }),
  });

  if (!response.ok) {
    console.warn('Browser rendering screenshot failed', response.status, await response.text());
    return null;
  }

  return new Uint8Array(await response.arrayBuffer());
}
