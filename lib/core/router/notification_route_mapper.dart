import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';

class NotificationRouteMapper {
  const NotificationRouteMapper();

  Future<PageRouteInfo?> fromPayload(Map<String, dynamic> data, {required String sourceTag}) async {
    final String route = data['route']?.toString().trim() ?? '';
    final String wallId = data['wall_id']?.toString().trim() ?? '';
    return _map(route: route, wallId: wallId, sourceTag: sourceTag);
  }

  Future<PageRouteInfo?> fromRoute({required String route, String? wallId, required String sourceTag}) {
    return _map(route: route.trim(), wallId: wallId?.trim() ?? '', sourceTag: sourceTag);
  }

  Future<PageRouteInfo?> _map({required String route, required String wallId, required String sourceTag}) async {
    switch (route) {
      case 'wall':
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
        final String provider = wall['wallpaper_provider']?.toString() ?? 'Prism';
        final String wallpaperUrl = (wall['wallpaper_url'] ?? wall['wallpaper_thumb'] ?? '').toString();
        final String thumbnailUrl = (wall['wallpaper_thumb'] ?? wallpaperUrl).toString();
        if (wallpaperUrl.isEmpty && thumbnailUrl.isEmpty) {
          return null;
        }
        return ShareWallpaperViewRoute(
          wallId: id,
          provider: provider,
          wallpaperUrl: wallpaperUrl,
          thumbnailUrl: thumbnailUrl,
        );
      case 'wall_of_the_day':
        return const HomeTabRoute();
      case 'streak_reminder':
        return const ProfileTabRoute();
      case 'follower':
      case 'announcement':
        return const NotificationRoute();
      default:
        return null;
    }
  }
}
