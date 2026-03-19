import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:auto_route/auto_route.dart';

class NotificationRouteMapper {
  const NotificationRouteMapper();

  Future<PageRouteInfo?> fromPayload(Map<String, dynamic> data, {required String sourceTag}) {
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
    return _map(route: route, wallId: wallId, profileIdentifier: profileIdentifier, sourceTag: sourceTag);
  }

  Future<PageRouteInfo?> fromRoute({
    required String route,
    String? wallId,
    String? profileIdentifier,
    required String sourceTag,
  }) {
    return _map(
      route: route.trim(),
      wallId: wallId?.trim() ?? '',
      profileIdentifier: profileIdentifier?.trim() ?? '',
      sourceTag: sourceTag,
    );
  }

  Future<PageRouteInfo?> _map({
    required String route,
    required String wallId,
    required String profileIdentifier,
    required String sourceTag,
  }) async {
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
        return const ProfileTabRoute();
      case 'follower':
        if (profileIdentifier.isNotEmpty) {
          return ProfileRoute(profileIdentifier: profileIdentifier);
        }
        return const NotificationRoute();
      case 'announcement':
        return const NotificationRoute();
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
    if (wall == null) {
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
      wallpaperUrl: wallpaperUrl,
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
