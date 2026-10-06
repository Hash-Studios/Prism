import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';

class NotificationRouteMapper {
  const NotificationRouteMapper();

  /// Maps a push or inbox payload to a route.
  ///
  /// With [fallbackToInbox] (the default) the result is never null: a missing or unknown target opens the inbox and
  /// shows a toast. Pass `false` to get null instead.
  Future<PageRouteInfo?> fromPayload(
    Map<String, dynamic> data, {
    required String sourceTag,
    bool fallbackToInbox = true,
  }) {
    final String route = data['route']?.toString().trim() ?? '';
    final String wallId = data['wall_id']?.toString().trim() ?? '';
    final String profileIdentifier = _firstPresent(data, const <String>[
      'profile_identifier',
      'profileIdentifier',
      'follower_email',
      'followerEmail',
      'username',
      'user',
    ]);
    return _map(
      route: route,
      wallId: wallId,
      profileIdentifier: profileIdentifier,
      sourceTag: sourceTag,
      fallbackToInbox: fallbackToInbox,
    );
  }

  Future<PageRouteInfo?> fromRoute({
    required String route,
    String? wallId,
    String? profileIdentifier,
    required String sourceTag,
    bool fallbackToInbox = true,
  }) {
    return _map(
      route: route.trim(),
      wallId: wallId?.trim() ?? '',
      profileIdentifier: profileIdentifier?.trim() ?? '',
      sourceTag: sourceTag,
      fallbackToInbox: fallbackToInbox,
    );
  }

  Future<PageRouteInfo?> _map({
    required String route,
    required String wallId,
    required String profileIdentifier,
    required String sourceTag,
    required bool fallbackToInbox,
  }) async {
    PageRouteInfo? mapped;
    try {
      mapped = await _resolve(route: route, wallId: wallId, profileIdentifier: profileIdentifier, sourceTag: sourceTag);
    } catch (_) {
      mapped = null;
    }
    if (mapped != null || !fallbackToInbox) {
      return mapped;
    }
    if (route.isNotEmpty) {
      toasts.error('That item is no longer available');
    }
    return const NotificationRoute();
  }

  Future<PageRouteInfo?> _resolve({
    required String route,
    required String wallId,
    required String profileIdentifier,
    required String sourceTag,
  }) async {
    final Uri? routeUri = Uri.tryParse(route);
    if (routeUri != null && const DeepLinkParser().parse(routeUri) is SetupLinkIntent) {
      toasts.error('Home screen setups are no longer available.');
      return const HomeTabRoute();
    }

    switch (route) {
      case 'wall':
        return _mapWallRoute(wallId: wallId, sourceTag: sourceTag);
      case 'wall_of_the_day':
        if (wallId.isNotEmpty) {
          final PageRouteInfo? wallRoute = await _mapWallRoute(wallId: wallId, sourceTag: '$sourceTag.wotd');
          if (wallRoute != null) {
            return wallRoute;
          }
        }
        return const HomeTabRoute();
      case 'streak_reminder':
        return const RewardsTabRoute();
      case 'follower':
        if (profileIdentifier.isNotEmpty) {
          return ProfileRoute(profileIdentifier: profileIdentifier);
        }
        return const NotificationRoute();
      case 'announcement':
        return const NotificationRoute();
      case 'content_report':
        return app_state.isAdminUser() ? AdminReviewRoute() : null;
      default:
        return null;
    }
  }

  Future<PageRouteInfo?> _mapWallRoute({required String wallId, required String sourceTag}) async {
    if (wallId.isEmpty) {
      return null;
    }
    final Map<String, dynamic>? wall = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.walls,
      wallId,
      (Map<String, dynamic> data, String _) => data,
      sourceTag: sourceTag,
    );
    if (wall == null || (wall['review'] != true && !app_state.isAdminUser())) {
      return null;
    }
    final String id = wall['id']?.toString() ?? wallId;
    final WallpaperSource source = WallpaperSourceX.fromWire(
      _firstPresent(wall, const <String>['source', 'wallpaper_provider', 'provider']),
    );
    final String wallpaperUrl = (wall['wallpaper_url'] ?? wall['wallpaper_thumb'] ?? '').toString();
    final String thumbnailUrl = (wall['wallpaper_thumb'] ?? wallpaperUrl).toString();
    if (wallpaperUrl.isEmpty && thumbnailUrl.isEmpty) {
      return null;
    }
    return WallpaperDetailRoute(
      wallId: id,
      source: source,
      thumbnailUrl: thumbnailUrl,
      analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
    );
  }
}

String _firstPresent(Map<String, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    final String? v = map[key]?.toString().trim();
    if (v != null && v.isNotEmpty) {
      return v;
    }
  }
  return '';
}
