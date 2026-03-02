import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:http/http.dart' as http;

class DeepLinkNavigation {
  const DeepLinkNavigation({this.parser = const DeepLinkParser(), this.httpClient});

  static const String _shortLinkResolveApiBase = 'https://prismwalls.com/api/links';

  final DeepLinkParser parser;
  final http.Client? httpClient;

  bool isPrismDeepLink(Uri uri) {
    final String host = uri.host.toLowerCase();
    final String scheme = uri.scheme.toLowerCase();
    if (host == 'prismwalls.com' || host == 'www.prismwalls.com') {
      return true;
    }
    return scheme == 'prism';
  }

  Future<PageRouteInfo?> mapUriToRoute(Uri uri) {
    final DeepLinkActionEntity action = parser.parse(parser.transform(uri));
    return _mapActionToRoute(action);
  }

  Future<PageRouteInfo?> _mapActionToRoute(DeepLinkActionEntity action) async {
    switch (action) {
      case ShareLinkIntent():
        return ShareWallpaperViewRoute(
          wallId: action.wallId,
          provider: action.provider,
          wallpaperUrl: action.wallpaperUrl,
          thumbnailUrl: action.thumbnailUrl,
        );
      case UserLinkIntent():
        return ProfileRoute(profileIdentifier: action.profileIdentifier);
      case SetupLinkIntent():
        return ShareSetupViewRoute(setupName: action.setupName, thumbnailUrl: action.thumbnailUrl);
      case ReferLinkIntent():
        return null;
      case ShortCodeIntent():
        final DeepLinkActionEntity? resolved = await _resolveShortCode(action.code);
        if (resolved == null) {
          return null;
        }
        return _mapActionToRoute(resolved);
      case UnknownIntent():
        return null;
    }
  }

  Future<DeepLinkActionEntity?> _resolveShortCode(String code) async {
    final String shortCode = code.trim();
    if (shortCode.isEmpty) {
      return null;
    }

    final Uri endpoint = Uri.parse('$_shortLinkResolveApiBase/$shortCode');
    try {
      final Future<http.Response> responseFuture = httpClient != null
          ? httpClient!.get(endpoint, headers: const <String, String>{'Accept': 'application/json'})
          : http.get(endpoint, headers: const <String, String>{'Accept': 'application/json'});
      final http.Response response = await responseFuture.timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final String canonicalUrl = decoded['canonical_url']?.toString() ?? '';
      if (canonicalUrl.isEmpty) {
        return null;
      }
      final Uri? canonicalUri = Uri.tryParse(canonicalUrl);
      if (canonicalUri == null) {
        return null;
      }
      final DeepLinkActionEntity canonicalAction = parser.parse(parser.transform(canonicalUri));
      if (canonicalAction is UnknownIntent || canonicalAction is ShortCodeIntent) {
        return null;
      }
      return canonicalAction;
    } catch (_) {
      return null;
    }
  }
}
