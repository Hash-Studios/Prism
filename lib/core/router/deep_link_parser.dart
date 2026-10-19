import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';

class DeepLinkParser {
  const DeepLinkParser();

  static const Set<String> _shareRoots = <String>{'share'};
  static const Set<String> _userRoots = <String>{'user', 'fprofile', 'follower-profile', 'profile'};
  static const Set<String> _setupRoots = <String>{'setup', 'share-setup'};
  static const Set<String> _referRoots = <String>{'refer', 'referral'};
  static const Map<String, DeepLinkScreen> _screenRoots = <String, DeepLinkScreen>{
    'shop': DeepLinkScreen.shop,
    'drops': DeepLinkScreen.drops,
    'leaderboard': DeepLinkScreen.leaderboard,
    'draw': DeepLinkScreen.draw,
  };
  static const Set<String> _shortCodeRoots = <String>{'l'};

  Uri transform(Uri uri) {
    try {
      // prism://share/abc -> prism:///share/abc. Keep the raw path so escaped characters survive.
      if (_isCustomScheme(uri) && uri.host.trim().isNotEmpty && !_isDomainHost(uri.host)) {
        uri = uri.replace(host: '', path: '/${uri.host}${uri.path}');
      } else if (uri.path.isEmpty) {
        uri = uri.replace(path: '/');
      }

      // auto_route decodes the returned path and query, so validate after moving the custom-scheme host into the path.
      uri.pathSegments;
      uri.queryParameters;
      return uri;
    } on FormatException {
      return Uri(path: '/not-found');
    }
  }

  DeepLinkActionEntity parse(Uri uri) {
    try {
      if (!_isSupportedOrigin(uri)) return UnknownIntent(rawUri: uri.toString());
      // Decode once before transforming custom-scheme hosts. Malformed URLs remain unknown to the parser even though
      // `transform` intentionally sends them to not-found for AutoRoute's platform hook.
      uri.pathSegments;
      uri.queryParameters;
      uri.host;
      return _parse(transform(uri));
    } on FormatException {
      // Malformed percent encoding (for example %FF) in the path or query.
      return UnknownIntent(rawUri: uri.toString());
    }
  }

  DeepLinkActionEntity _parse(Uri uri) {
    final DeepLinkRouteMatch? page = DeepLinkRouteCatalog.match(uri);
    if (page != null) {
      return PageLinkIntent(path: page.path, rawUri: uri.toString());
    }
    if (DeepLinkRouteCatalog.ownsPath(uri)) {
      return UnknownIntent(rawUri: uri.toString());
    }

    final List<String> segments = _segments(uri);
    if (segments.isEmpty) {
      return UnknownIntent(rawUri: uri.toString());
    }

    final String root = segments.first.toLowerCase();
    if (_shareRoots.contains(root)) {
      if (segments.length > 2) return UnknownIntent(rawUri: uri.toString());
      final String wallId = _firstNonEmpty(<String?>[segments.safeAt(1), uri.queryParameters['id']]);
      final WallpaperSource source = WallpaperSourceX.fromWire(
        _firstNonEmpty(<String?>[
          uri.queryParameters['source'],
          uri.queryParameters['provider'],
          uri.queryParameters['wallpaper_provider'],
        ]),
      );
      final String wallpaperUrl = _firstNonEmpty(<String?>[
        uri.queryParameters['url'],
        uri.queryParameters['wallpaperUrl'],
        uri.queryParameters['wallpaper_url'],
      ]);
      final String thumbnailUrl = _firstNonEmpty(<String?>[
        uri.queryParameters['thumb'],
        uri.queryParameters['thumbUrl'],
        uri.queryParameters['thumbnail'],
        uri.queryParameters['thumbnailUrl'],
        uri.queryParameters['wallpaper_thumb'],
        wallpaperUrl,
      ]);
      if (wallId.isEmpty || (wallpaperUrl.isEmpty && thumbnailUrl.isEmpty)) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return ShareLinkIntent(
        wallId: wallId,
        source: source,
        wallpaperUrl: wallpaperUrl,
        thumbnailUrl: thumbnailUrl,
        rawUri: uri.toString(),
      );
    }

    if (_userRoots.contains(root)) {
      if (segments.length > 2 || (root == 'user' && segments.length == 2)) {
        return UnknownIntent(rawUri: uri.toString());
      }
      final String profileIdentifier = _firstNonEmpty(<String?>[
        segments.safeAt(1),
        uri.queryParameters['identifier'],
        uri.queryParameters['username'],
        uri.queryParameters['user'],
        uri.queryParameters['email'],
      ]);
      if (profileIdentifier.isEmpty) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return UserLinkIntent(profileIdentifier: profileIdentifier, rawUri: uri.toString());
    }

    if (_setupRoots.contains(root)) {
      return SetupLinkIntent(rawUri: uri.toString());
    }

    if (_referRoots.contains(root)) {
      if (segments.length > 2) return UnknownIntent(rawUri: uri.toString());
      final String inviterId = _firstNonEmpty(<String?>[
        segments.safeAt(1),
        uri.queryParameters['inviterId'],
        uri.queryParameters['userID'],
        uri.queryParameters['userId'],
        uri.queryParameters['userid'],
        uri.queryParameters['id'],
      ]);
      if (inviterId.isEmpty) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return ReferLinkIntent(inviterId: inviterId, rawUri: uri.toString());
    }

    if (_shortCodeRoots.contains(root)) {
      if (segments.length > 2) return UnknownIntent(rawUri: uri.toString());
      final String code = _firstNonEmpty(<String?>[segments.safeAt(1), uri.queryParameters['code']]);
      if (code.isEmpty) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return ShortCodeIntent(code: code, rawUri: uri.toString());
    }

    final DeepLinkScreen? screen = _screenRoots[root];
    if (screen != null) {
      return ScreenLinkIntent(screen: screen, rawUri: uri.toString());
    }

    return UnknownIntent(rawUri: uri.toString());
  }

  List<String> _segments(Uri uri) {
    final List<String> pathSegments = uri.pathSegments.where((String it) => it.trim().isNotEmpty).toList();
    if (pathSegments.isNotEmpty) {
      if (_isCustomScheme(uri) && uri.host.trim().isNotEmpty && !_isDomainHost(uri.host)) {
        return <String>[uri.host, ...pathSegments];
      }
      return pathSegments;
    }

    if (_isCustomScheme(uri) && uri.host.trim().isNotEmpty && !_isDomainHost(uri.host)) {
      return <String>[uri.host];
    }
    return const <String>[];
  }

  bool _isCustomScheme(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    return scheme.isNotEmpty && scheme != 'http' && scheme != 'https';
  }

  bool _isSupportedOrigin(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return true;
    if (scheme == 'prism') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    final String host = uri.host.toLowerCase();
    if (uri.userInfo.isNotEmpty || (host != 'prismwalls.com' && host != 'www.prismwalls.com')) return false;
    return (scheme == 'https' && (!uri.hasPort || uri.port == 443)) ||
        (scheme == 'http' && (!uri.hasPort || uri.port == 80));
  }

  bool _isDomainHost(String host) {
    return host.contains('.');
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}

extension on List<String> {
  String? safeAt(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return this[index];
  }
}
