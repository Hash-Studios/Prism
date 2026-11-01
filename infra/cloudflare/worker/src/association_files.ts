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

const APP_LINK_PATHS = [
  '/share', '/share/*', '/user', '/user/*', '/fprofile', '/fprofile/*', '/follower-profile', '/follower-profile/*',
  '/profile', '/profile/*', '/setup', '/setup/*', '/share-setup', '/share-setup/*', '/refer', '/refer/*',
  '/referral', '/referral/*', '/collection', '/collection/*', '/category', '/category/*', '/wallpaper', '/wallpaper/*',
  '/folder/*', '/mood/*', '/challenges/*',
  '/l', '/l/*', '/onboarding/v2', '/dashboard', '/dashboard/home', '/dashboard/search', '/dashboard/search/users',
  '/dashboard/rewards', '/dashboard/streak', '/dashboard/collection', '/ai',
  '/wallpaper-detail', '/wotd-archive', '/download-wallpaper', '/wallpaper-filter', '/choose-wallpaper', '/premium', '/paywall',
  '/edit-profile', '/share-prism',
  '/settings', '/blocked-accounts', '/about', '/fav-walls', '/downloads', '/library', '/upload-wall', '/edit-wall',
  '/review', '/coin-transactions', '/theme', '/notifications', '/collection-view', '/gallery', '/requests', '/creators', '/followers', '/following',
  '/admin-review', '/admin-review/swipe', '/admin-review/image', '/admin-firestore-telemetry', '/debug-panel',
  '/daily-moment', '/daily-chest', '/spin-wheel',
  '/photo-preview', '/clock-preview', '/quick-tile-settings',
  '/auto-rotate', '/ios-shortcuts', '/wallpaper-history', '/wallpaper-position', '/live-wallpaper', '/rewards',
  '/coin-history', '/shop', '/drops', '/drops/*', '/leaderboard', '/draw', '/streak', '/creator-stats', '/not-found',
];

const APPLE_ASSOCIATION_PAYLOAD = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'X2955Z4CKQ.com.hash.prism',
        paths: APP_LINK_PATHS,
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
