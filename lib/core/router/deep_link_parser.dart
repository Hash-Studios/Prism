import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';

class DeepLinkParser {
  const DeepLinkParser();

  static const Set<String> _shareRoots = <String>{'share'};
  static const Set<String> _userRoots = <String>{'user', 'fprofile', 'follower-profile', 'profile'};
  static const Set<String> _setupRoots = <String>{'setup', 'share-setup'};
  static const Set<String> _referRoots = <String>{'refer', 'referral'};
  static const Set<String> _shortCodeRoots = <String>{'l'};

  Uri transform(Uri uri) {
    final List<String> segments = _segments(uri);
    if (segments.isEmpty) {
      return uri.path.isEmpty ? uri.replace(path: '/') : uri;
    }
    return uri.replace(path: '/${segments.join('/')}');
  }

  DeepLinkActionEntity parse(Uri uri) {
    final List<String> segments = _segments(uri);
    if (segments.isEmpty) {
      return UnknownIntent(rawUri: uri.toString());
    }

    final String root = segments.first.toLowerCase();
    if (_shareRoots.contains(root)) {
      final String wallId = _firstNonEmpty(<String?>[segments.safeAt(1), uri.queryParameters['id']]);
      final String provider = _firstNonEmpty(<String?>[uri.queryParameters['provider']]);
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
      if (wallId.isEmpty || provider.isEmpty || (wallpaperUrl.isEmpty && thumbnailUrl.isEmpty)) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return ShareLinkIntent(
        wallId: wallId,
        provider: provider,
        wallpaperUrl: wallpaperUrl,
        thumbnailUrl: thumbnailUrl,
        rawUri: uri.toString(),
      );
    }

    if (_userRoots.contains(root)) {
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
      final String setupName = _firstNonEmpty(<String?>[
        segments.safeAt(1),
        uri.queryParameters['name'],
        uri.queryParameters['setupName'],
        uri.queryParameters['setup_name'],
      ]);
      final String thumbnailUrl = _firstNonEmpty(<String?>[
        uri.queryParameters['thumb'],
        uri.queryParameters['thumbUrl'],
        uri.queryParameters['thumbnail'],
      ]);
      if (setupName.isEmpty) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return SetupLinkIntent(setupName: setupName, thumbnailUrl: thumbnailUrl, rawUri: uri.toString());
    }

    if (_referRoots.contains(root)) {
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
      final String code = _firstNonEmpty(<String?>[segments.safeAt(1), uri.queryParameters['code']]);
      if (code.isEmpty) {
        return UnknownIntent(rawUri: uri.toString());
      }
      return ShortCodeIntent(code: code, rawUri: uri.toString());
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

  bool _isDomainHost(String host) {
    return host.contains('.');
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return Uri.decodeComponent(trimmed);
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
