const ASSETLINKS_PAYLOAD = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.hash.prism',
      sha256_cert_fingerprints: ['46:F7:AD:7F:C2:4B:A1:F3:22:53:A8:72:C1:72:C2:67:D4:0E:96:1B:94:14:3F:B0:A1:B8:20:5B:97:83:05:2F'],
    },
  },
];

const APPLE_ASSOCIATION_PAYLOAD = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'X2955Z4CKQ.com.hash.prism',
        paths: ['/share/*', '/user/*', '/setup/*', '/refer/*', '/l/*'],
      },
    ],
  },
};

const ASSOCIATION_HEADERS: HeadersInit = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'public, max-age=300, must-revalidate',
  'x-content-type-options': 'nosniff',
};

function buildAssociationResponse(payload: unknown, method: string): Response {
  if (method === 'HEAD') {
    return new Response(null, { status: 200, headers: ASSOCIATION_HEADERS });
  }
  return new Response(JSON.stringify(payload), { status: 200, headers: ASSOCIATION_HEADERS });
}

export function maybeHandleAssociationRequest(request: Request, pathname: string): Response | null {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return null;
  }

  if (pathname === '/.well-known/assetlinks.json') {
    return buildAssociationResponse(ASSETLINKS_PAYLOAD, request.method);
  }

  if (pathname === '/.well-known/apple-app-site-association' || pathname === '/apple-app-site-association') {
    return buildAssociationResponse(APPLE_ASSOCIATION_PAYLOAD, request.method);
  }

  return null;
}
