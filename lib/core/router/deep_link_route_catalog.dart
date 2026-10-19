/// The path-only contract for every app route that can be opened from a URL.
///
/// The catalog intentionally owns matching and validation, while route factories live in
/// `deep_link_catalog_resolver.dart`. A successful match always names a concrete route family; there is no wildcard
/// that turns arbitrary paths into navigation.
enum DeepLinkPageTarget {
  splash,
  onboarding,
  dashboard,
  home,
  searchTab,
  userSearch,
  rewardsTab,
  collectionTab,
  chooseImage,
  ai,
  wallpaperDetail,
  wotdArchive,
  downloadWallpaperInput,
  wallpaperFilterInput,
  editProfile,
  sharePrism,
  settings,
  blockedAccounts,
  about,
  favourites,
  downloads,
  library,
  uploadInput,
  editWallInput,
  review,
  theme,
  notifications,
  collectionView,
  profile,
  followers,
  following,
  adminReview,
  swipeReview,
  adminTelemetry,
  debugPanel,
  quickTileSettings,
  autoRotate,
  iosShortcuts,
  wallpaperHistory,
  photoPreview,
  clockPreview,
  adminImage,
  wallpaperPositionInput,
  liveWallpaperInput,
  rewards,
  coinHistory,
  shop,
  drops,
  dailyChest,
  spinWheel,
  premium,
  dropPreview,
  dropDetail,
  leaderboard,
  draw,
  notFound,
}

final class DeepLinkRouteMatch {
  const DeepLinkRouteMatch({
    required this.target,
    required this.path,
    this.pathParams = const <String, String>{},
    this.queryParams = const <String, String>{},
  });

  final DeepLinkPageTarget target;
  final String path;
  final Map<String, String> pathParams;
  final Map<String, String> queryParams;
}

final class DeepLinkRouteExample {
  const DeepLinkRouteExample(this.uri, this.target);

  final String uri;
  final DeepLinkPageTarget target;
}

/// Exact URL ownership and URL-safe argument validation for app navigation.
final class DeepLinkRouteCatalog {
  const DeepLinkRouteCatalog();

  DeepLinkRouteMatch? resolve(Uri uri) => match(uri);

  static const List<DeepLinkRouteExample> examples = <DeepLinkRouteExample>[
    DeepLinkRouteExample('/', DeepLinkPageTarget.splash),
    DeepLinkRouteExample('/onboarding/v2', DeepLinkPageTarget.onboarding),
    DeepLinkRouteExample('/dashboard', DeepLinkPageTarget.dashboard),
    DeepLinkRouteExample('/dashboard/home', DeepLinkPageTarget.home),
    DeepLinkRouteExample('/dashboard/search', DeepLinkPageTarget.searchTab),
    DeepLinkRouteExample('/dashboard/search/users', DeepLinkPageTarget.userSearch),
    DeepLinkRouteExample('/dashboard/rewards', DeepLinkPageTarget.rewardsTab),
    DeepLinkRouteExample('/dashboard/streak', DeepLinkPageTarget.rewardsTab),
    DeepLinkRouteExample('/dashboard/collection', DeepLinkPageTarget.collectionTab),
    DeepLinkRouteExample('/ai', DeepLinkPageTarget.ai),
    DeepLinkRouteExample('/wallpaper-detail?wallId=wall1&source=prism', DeepLinkPageTarget.wallpaperDetail),
    DeepLinkRouteExample(
      '/wallpaper-detail?wallId=wall1&id=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.wallpaperDetail,
    ),
    DeepLinkRouteExample('/wotd-archive', DeepLinkPageTarget.wotdArchive),
    DeepLinkRouteExample('/download-wallpaper', DeepLinkPageTarget.downloadWallpaperInput),
    DeepLinkRouteExample(
      '/download-wallpaper?wallpaperId=wall1&provider=prism',
      DeepLinkPageTarget.downloadWallpaperInput,
    ),
    DeepLinkRouteExample(
      '/download-wallpaper?wallpaperId=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.downloadWallpaperInput,
    ),
    DeepLinkRouteExample('/wallpaper-filter', DeepLinkPageTarget.wallpaperFilterInput),
    DeepLinkRouteExample('/choose-wallpaper?workflow=uploadWall', DeepLinkPageTarget.chooseImage),
    DeepLinkRouteExample('/edit-profile', DeepLinkPageTarget.editProfile),
    DeepLinkRouteExample('/share-prism', DeepLinkPageTarget.sharePrism),
    DeepLinkRouteExample('/settings', DeepLinkPageTarget.settings),
    DeepLinkRouteExample('/blocked-accounts', DeepLinkPageTarget.blockedAccounts),
    DeepLinkRouteExample('/about', DeepLinkPageTarget.about),
    DeepLinkRouteExample('/fav-walls', DeepLinkPageTarget.favourites),
    DeepLinkRouteExample('/downloads', DeepLinkPageTarget.downloads),
    DeepLinkRouteExample('/library?tab=downloads', DeepLinkPageTarget.library),
    DeepLinkRouteExample('/upload-wall', DeepLinkPageTarget.uploadInput),
    DeepLinkRouteExample('/edit-wall', DeepLinkPageTarget.editWallInput),
    DeepLinkRouteExample('/review', DeepLinkPageTarget.review),
    DeepLinkRouteExample('/coin-transactions', DeepLinkPageTarget.rewards),
    DeepLinkRouteExample('/streak', DeepLinkPageTarget.rewards),
    DeepLinkRouteExample('/theme', DeepLinkPageTarget.theme),
    DeepLinkRouteExample('/notifications', DeepLinkPageTarget.notifications),
    DeepLinkRouteExample('/collection-view?collectionName=featured', DeepLinkPageTarget.collectionView),
    DeepLinkRouteExample('/user/alice', DeepLinkPageTarget.profile),
    DeepLinkRouteExample('/user/alice/followers', DeepLinkPageTarget.followers),
    DeepLinkRouteExample('/user/alice/following', DeepLinkPageTarget.following),
    DeepLinkRouteExample('/followers?user=alice', DeepLinkPageTarget.followers),
    DeepLinkRouteExample('/following?user=alice', DeepLinkPageTarget.following),
    DeepLinkRouteExample('/admin-review', DeepLinkPageTarget.adminReview),
    DeepLinkRouteExample('/admin-review/swipe', DeepLinkPageTarget.swipeReview),
    DeepLinkRouteExample('/admin-firestore-telemetry', DeepLinkPageTarget.adminTelemetry),
    DeepLinkRouteExample('/debug-panel', DeepLinkPageTarget.debugPanel),
    DeepLinkRouteExample('/quick-tile-settings', DeepLinkPageTarget.quickTileSettings),
    DeepLinkRouteExample('/auto-rotate', DeepLinkPageTarget.autoRotate),
    DeepLinkRouteExample('/ios-shortcuts', DeepLinkPageTarget.iosShortcuts),
    DeepLinkRouteExample('/wallpaper-history', DeepLinkPageTarget.wallpaperHistory),
    DeepLinkRouteExample('/photo-preview?wallpaperId=wall1', DeepLinkPageTarget.photoPreview),
    DeepLinkRouteExample(
      '/photo-preview?wallpaperId=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.photoPreview,
    ),
    DeepLinkRouteExample('/clock-preview?wallpaperId=wall1', DeepLinkPageTarget.clockPreview),
    DeepLinkRouteExample(
      '/clock-preview?wallpaperId=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.clockPreview,
    ),
    DeepLinkRouteExample('/admin-review/image?wallpaperId=wall1', DeepLinkPageTarget.adminImage),
    DeepLinkRouteExample('/admin-review/image?wallpaperId=wall1&source=prism', DeepLinkPageTarget.adminImage),
    DeepLinkRouteExample(
      '/admin-review/image?wallpaperId=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.adminImage,
    ),
    DeepLinkRouteExample('/wallpaper-position', DeepLinkPageTarget.wallpaperPositionInput),
    DeepLinkRouteExample(
      '/wallpaper-position?wallpaperId=wall1&source=prism&provider=wallhaven&entryPoint=shared',
      DeepLinkPageTarget.wallpaperPositionInput,
    ),
    DeepLinkRouteExample('/wallpaper/wall1/position?provider=wallhaven', DeepLinkPageTarget.wallpaperPositionInput),
    DeepLinkRouteExample('/wallpaper/wall1/download', DeepLinkPageTarget.downloadWallpaperInput),
    DeepLinkRouteExample('/live-wallpaper', DeepLinkPageTarget.liveWallpaperInput),
    DeepLinkRouteExample('/live-wallpaper?wallpaperId=wall1&provider=prism', DeepLinkPageTarget.liveWallpaperInput),
    DeepLinkRouteExample(
      '/live-wallpaper?wallpaperId=wall1&source=prism&provider=wallhaven',
      DeepLinkPageTarget.liveWallpaperInput,
    ),
    DeepLinkRouteExample('/wallpaper/wall1/live', DeepLinkPageTarget.liveWallpaperInput),
    DeepLinkRouteExample('/rewards', DeepLinkPageTarget.rewards),
    DeepLinkRouteExample('/coin-history', DeepLinkPageTarget.coinHistory),
    DeepLinkRouteExample('/shop', DeepLinkPageTarget.shop),
    DeepLinkRouteExample('/drops', DeepLinkPageTarget.drops),
    DeepLinkRouteExample('/drops/week-2026-10-19', DeepLinkPageTarget.dropDetail),
    DeepLinkRouteExample('/drops/week-2026-10-19/preview/wall1', DeepLinkPageTarget.dropPreview),
    DeepLinkRouteExample('/daily-chest', DeepLinkPageTarget.dailyChest),
    DeepLinkRouteExample('/spin-wheel', DeepLinkPageTarget.spinWheel),
    DeepLinkRouteExample('/premium', DeepLinkPageTarget.premium),
    DeepLinkRouteExample('/paywall', DeepLinkPageTarget.premium),
    DeepLinkRouteExample('/leaderboard', DeepLinkPageTarget.leaderboard),
    DeepLinkRouteExample('/draw', DeepLinkPageTarget.draw),
    DeepLinkRouteExample('/not-found', DeepLinkPageTarget.notFound),
  ];

  static const Set<String> _utmKeys = <String>{'utm_source', 'utm_medium', 'utm_campaign'};
  static const Map<DeepLinkPageTarget, Set<String>> _allowedQuery = <DeepLinkPageTarget, Set<String>>{
    DeepLinkPageTarget.wallpaperDetail: <String>{'wallId', 'id', 'source', 'provider'},
    DeepLinkPageTarget.library: <String>{'tab'},
    DeepLinkPageTarget.collectionView: <String>{'collectionName', 'name'},
    DeepLinkPageTarget.followers: <String>{'user', 'identifier'},
    DeepLinkPageTarget.following: <String>{'user', 'identifier'},
    DeepLinkPageTarget.wallpaperPositionInput: <String>{'wallpaperId', 'source', 'provider', 'entryPoint'},
    DeepLinkPageTarget.downloadWallpaperInput: <String>{'wallpaperId', 'source', 'provider'},
    DeepLinkPageTarget.liveWallpaperInput: <String>{'wallpaperId', 'source', 'provider'},
    DeepLinkPageTarget.chooseImage: <String>{'workflow'},
    DeepLinkPageTarget.photoPreview: <String>{'wallpaperId', 'source', 'provider'},
    DeepLinkPageTarget.clockPreview: <String>{'wallpaperId', 'source', 'provider'},
    DeepLinkPageTarget.adminImage: <String>{'wallpaperId', 'source', 'provider'},
    DeepLinkPageTarget.debugPanel: <String>{'tab'},
  };

  /// Returns null unless the URL matches a catalog route exactly and carries only supported scalar parameters.
  static DeepLinkRouteMatch? match(Uri uri) {
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((String segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }

    final Map<String, String> query = <String, String>{};
    try {
      for (final MapEntry<String, List<String>> entry in uri.queryParametersAll.entries) {
        if (entry.value.length != 1) return null;
        query[entry.key] = entry.value.single;
      }
    } on FormatException {
      return null;
    }

    DeepLinkPageTarget? target;
    final Map<String, String> pathParams = <String, String>{};
    final String path = '/${segments.join('/')}';
    if (segments.isEmpty) {
      target = DeepLinkPageTarget.splash;
    } else if (segments.length == 3 &&
        segments[0].toLowerCase() == 'user' &&
        segments[2].toLowerCase() == 'followers') {
      target = DeepLinkPageTarget.followers;
      pathParams['identifier'] = segments[1];
    } else if (segments.length == 3 &&
        segments[0].toLowerCase() == 'user' &&
        segments[2].toLowerCase() == 'following') {
      target = DeepLinkPageTarget.following;
      pathParams['identifier'] = segments[1];
    } else if (segments.length == 2 && segments[0].toLowerCase() == 'user') {
      target = DeepLinkPageTarget.profile;
      pathParams['identifier'] = segments[1];
    } else if (segments.length == 2 && segments[0].toLowerCase() == 'drops') {
      target = DeepLinkPageTarget.dropDetail;
      pathParams['weekKey'] = segments[1];
    } else if (segments.length == 4 && segments[0].toLowerCase() == 'drops' && segments[2].toLowerCase() == 'preview') {
      target = DeepLinkPageTarget.dropPreview;
      pathParams['weekKey'] = segments[1];
      pathParams['wallId'] = segments[3];
    } else if (segments.length == 2 && segments[0].toLowerCase() == 'collection') {
      target = DeepLinkPageTarget.collectionView;
      pathParams['collectionName'] = segments[1];
    } else if (segments.length == 2 && segments[0].toLowerCase() == 'category') {
      target = DeepLinkPageTarget.collectionView;
      pathParams['collectionName'] = 'category:${segments[1]}';
    } else if (segments.length == 2 && segments[0].toLowerCase() == 'wallpaper') {
      target = DeepLinkPageTarget.wallpaperDetail;
      pathParams['wallId'] = segments[1];
    } else if (segments.length == 3 &&
        segments[0].toLowerCase() == 'wallpaper' &&
        segments[2].toLowerCase() == 'position') {
      target = DeepLinkPageTarget.wallpaperPositionInput;
      pathParams['wallpaperId'] = segments[1];
    } else if (segments.length == 3 &&
        segments[0].toLowerCase() == 'wallpaper' &&
        segments[2].toLowerCase() == 'download') {
      target = DeepLinkPageTarget.downloadWallpaperInput;
      pathParams['wallpaperId'] = segments[1];
    } else if (segments.length == 3 &&
        segments[0].toLowerCase() == 'wallpaper' &&
        segments[2].toLowerCase() == 'live') {
      target = DeepLinkPageTarget.liveWallpaperInput;
      pathParams['wallpaperId'] = segments[1];
    } else {
      target = _staticTargets[path.toLowerCase()];
    }
    if (target == null) return null;

    final Set<String> allowed = _allowedQuery[target] ?? const <String>{};
    if (query.keys.any((String key) => !allowed.contains(key) && !_utmKeys.contains(key))) {
      return null;
    }
    if (query.keys.any((String key) => _utmKeys.contains(key))) {
      query.removeWhere((String key, String _) => _utmKeys.contains(key));
    }

    final String? identifier = pathParams['identifier'] ?? query['identifier'] ?? query['user'];
    if ((target == DeepLinkPageTarget.followers || target == DeepLinkPageTarget.following) &&
        (identifier == null || identifier.trim().isEmpty)) {
      return null;
    }
    final String? wallId = pathParams['wallId'] ?? query['wallId'] ?? query['id'];
    if (target == DeepLinkPageTarget.wallpaperDetail && (wallId == null || wallId.trim().isEmpty)) {
      return null;
    }
    if (target == DeepLinkPageTarget.collectionView &&
        (pathParams['collectionName'] ?? query['collectionName'] ?? query['name'] ?? '').trim().isEmpty) {
      return null;
    }
    if (target == DeepLinkPageTarget.library &&
        query['tab'] != null &&
        !const <String>{'favourites', 'downloads', 'history'}.contains(query['tab']!.toLowerCase())) {
      return null;
    }
    if (target == DeepLinkPageTarget.debugPanel &&
        query['tab'] != null &&
        !const <String>{'logs', 'tools', 'storage', 'app-info', 'mascot'}.contains(query['tab']!.toLowerCase())) {
      return null;
    }
    if (target == DeepLinkPageTarget.chooseImage &&
        !const <String>{
          'uploadWall',
          'editWall',
          'wallpaperFilter',
          'downloadWallpaper',
          'wallpaperPosition',
          'liveWallpaper',
          'clockPreview',
          'photoPreview',
        }.contains(query['workflow'])) {
      return null;
    }
    if ((target == DeepLinkPageTarget.photoPreview ||
            target == DeepLinkPageTarget.clockPreview ||
            target == DeepLinkPageTarget.adminImage) &&
        (query['wallpaperId'] ?? '').trim().isEmpty) {
      return null;
    }
    if (target == DeepLinkPageTarget.wallpaperDetail ||
        target == DeepLinkPageTarget.wallpaperPositionInput ||
        target == DeepLinkPageTarget.downloadWallpaperInput ||
        target == DeepLinkPageTarget.liveWallpaperInput ||
        target == DeepLinkPageTarget.photoPreview ||
        target == DeepLinkPageTarget.clockPreview ||
        target == DeepLinkPageTarget.adminImage) {
      final String? source = query['source'] ?? query['provider'];
      if (source != null && !const <String>{'prism', 'wallhaven', 'pexels'}.contains(source.toLowerCase())) {
        return null;
      }
    }
    if ((target == DeepLinkPageTarget.dropDetail || target == DeepLinkPageTarget.dropPreview) &&
        (pathParams['weekKey'] ?? '').trim().isEmpty) {
      return null;
    }
    if (target == DeepLinkPageTarget.dropPreview && (pathParams['wallId'] ?? '').trim().isEmpty) {
      return null;
    }
    if ((target == DeepLinkPageTarget.profile ||
            target == DeepLinkPageTarget.followers ||
            target == DeepLinkPageTarget.following) &&
        (pathParams['identifier'] ?? '').contains('/')) {
      return null;
    }
    if (pathParams.values.any(
      (String value) => value == '.' || value == '..' || value.contains('/') || value.contains('\\'),
    )) {
      return null;
    }

    final Map<String, String> normalizedQuery = Map<String, String>.of(query);
    final List<String> canonicalSegments = List<String>.of(segments);
    if (canonicalSegments.isNotEmpty) {
      canonicalSegments[0] = canonicalSegments.first.toLowerCase();
    }
    if ((target == DeepLinkPageTarget.followers || target == DeepLinkPageTarget.following) &&
        canonicalSegments.length == 3) {
      canonicalSegments[2] = canonicalSegments[2].toLowerCase();
    } else if (target == DeepLinkPageTarget.wallpaperPositionInput ||
        target == DeepLinkPageTarget.downloadWallpaperInput ||
        target == DeepLinkPageTarget.liveWallpaperInput) {
      if (canonicalSegments.length == 3) {
        canonicalSegments[2] = canonicalSegments[2].toLowerCase();
      }
    } else if (target == DeepLinkPageTarget.dropPreview) {
      canonicalSegments[2] = canonicalSegments[2].toLowerCase();
    } else if (pathParams.isEmpty) {
      for (int i = 1; i < canonicalSegments.length; i += 1) {
        canonicalSegments[i] = canonicalSegments[i].toLowerCase();
      }
    }
    final String canonicalPath = _encodePath(canonicalSegments, normalizedQuery);
    return DeepLinkRouteMatch(
      target: target,
      path: canonicalPath,
      pathParams: Map<String, String>.unmodifiable(pathParams),
      queryParams: Map<String, String>.unmodifiable(normalizedQuery),
    );
  }

  /// True when a path belongs to a catalog route, even if its query or required fields are invalid.
  /// The parser uses this to stop rejected canonical paths falling through to permissive legacy aliases.
  static bool ownsPath(Uri uri) {
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((String segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return false;
    }
    if (segments.isEmpty) return true;
    final String path = '/${segments.join('/')}';
    if (_staticTargets.containsKey(path.toLowerCase())) return true;
    if (segments.length == 2 &&
        const <String>{'user', 'drops', 'collection', 'category', 'wallpaper'}.contains(segments[0].toLowerCase())) {
      return true;
    }
    return segments.length == 3 &&
            ((segments[0].toLowerCase() == 'user' &&
                    const <String>{'followers', 'following'}.contains(segments[2].toLowerCase())) ||
                (segments[0].toLowerCase() == 'wallpaper' &&
                    const <String>{'position', 'download', 'live'}.contains(segments[2].toLowerCase()))) ||
        (segments.length == 4 && segments[0].toLowerCase() == 'drops' && segments[2].toLowerCase() == 'preview');
  }

  static const Map<String, DeepLinkPageTarget> _staticTargets = <String, DeepLinkPageTarget>{
    '/onboarding/v2': DeepLinkPageTarget.onboarding,
    '/dashboard': DeepLinkPageTarget.dashboard,
    '/dashboard/home': DeepLinkPageTarget.home,
    '/dashboard/search': DeepLinkPageTarget.searchTab,
    '/dashboard/search/users': DeepLinkPageTarget.userSearch,
    '/dashboard/rewards': DeepLinkPageTarget.rewardsTab,
    '/dashboard/streak': DeepLinkPageTarget.rewardsTab,
    '/dashboard/collection': DeepLinkPageTarget.collectionTab,
    '/choose-wallpaper': DeepLinkPageTarget.chooseImage,
    '/ai': DeepLinkPageTarget.ai,
    '/wallpaper-detail': DeepLinkPageTarget.wallpaperDetail,
    '/wotd-archive': DeepLinkPageTarget.wotdArchive,
    '/download-wallpaper': DeepLinkPageTarget.downloadWallpaperInput,
    '/wallpaper-filter': DeepLinkPageTarget.wallpaperFilterInput,
    '/edit-profile': DeepLinkPageTarget.editProfile,
    '/share-prism': DeepLinkPageTarget.sharePrism,
    '/settings': DeepLinkPageTarget.settings,
    '/blocked-accounts': DeepLinkPageTarget.blockedAccounts,
    '/about': DeepLinkPageTarget.about,
    '/fav-walls': DeepLinkPageTarget.favourites,
    '/downloads': DeepLinkPageTarget.downloads,
    '/library': DeepLinkPageTarget.library,
    '/upload-wall': DeepLinkPageTarget.uploadInput,
    '/edit-wall': DeepLinkPageTarget.editWallInput,
    '/review': DeepLinkPageTarget.review,
    '/coin-transactions': DeepLinkPageTarget.rewards,
    '/streak': DeepLinkPageTarget.rewards,
    '/theme': DeepLinkPageTarget.theme,
    '/notifications': DeepLinkPageTarget.notifications,
    '/collection-view': DeepLinkPageTarget.collectionView,
    '/followers': DeepLinkPageTarget.followers,
    '/following': DeepLinkPageTarget.following,
    '/admin-review': DeepLinkPageTarget.adminReview,
    '/admin-review/swipe': DeepLinkPageTarget.swipeReview,
    '/admin-firestore-telemetry': DeepLinkPageTarget.adminTelemetry,
    '/debug-panel': DeepLinkPageTarget.debugPanel,
    '/quick-tile-settings': DeepLinkPageTarget.quickTileSettings,
    '/auto-rotate': DeepLinkPageTarget.autoRotate,
    '/ios-shortcuts': DeepLinkPageTarget.iosShortcuts,
    '/wallpaper-history': DeepLinkPageTarget.wallpaperHistory,
    '/photo-preview': DeepLinkPageTarget.photoPreview,
    '/clock-preview': DeepLinkPageTarget.clockPreview,
    '/admin-review/image': DeepLinkPageTarget.adminImage,
    '/wallpaper-position': DeepLinkPageTarget.wallpaperPositionInput,
    '/live-wallpaper': DeepLinkPageTarget.liveWallpaperInput,
    '/rewards': DeepLinkPageTarget.rewards,
    '/coin-history': DeepLinkPageTarget.coinHistory,
    '/shop': DeepLinkPageTarget.shop,
    '/drops': DeepLinkPageTarget.drops,
    '/daily-chest': DeepLinkPageTarget.dailyChest,
    '/spin-wheel': DeepLinkPageTarget.spinWheel,
    '/premium': DeepLinkPageTarget.premium,
    '/paywall': DeepLinkPageTarget.premium,
    '/leaderboard': DeepLinkPageTarget.leaderboard,
    '/draw': DeepLinkPageTarget.draw,
    '/not-found': DeepLinkPageTarget.notFound,
  };

  static String _encodePath(List<String> segments, Map<String, String> query) {
    final String path = segments.isEmpty ? '/' : '/${segments.map(Uri.encodeComponent).join('/')}';
    if (query.isEmpty) return path;
    return '$path?${Uri(queryParameters: query).query}';
  }
}
