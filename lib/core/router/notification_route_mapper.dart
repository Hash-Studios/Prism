import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class NotificationRouteMapper {
  const NotificationRouteMapper();

  /// Set from app startup. Push taps record a scoreboard signal through this hook.
  static Future<void> Function(String kindWire, {bool gallery})? onMeasuredTap;

  /// The gallery link of a push that carries at least two wall ids, or null.
  static Uri? galleryLinkFor(Map<String, dynamic> data) {
    final String ids = data['wall_ids']?.toString().trim() ?? '';
    if (ids.split(',').where((id) => id.trim().isNotEmpty).length < 2) return null;
    return Uri(path: '/gallery', queryParameters: <String, String>{'ids': ids, 'source': 'push'});
  }

  /// Classifies metadata before asynchronous lookups, without claiming that resolution succeeded.
  static TargetTypeValue targetTypeForRoute(String route) {
    final String target = route.trim();
    if (target.isEmpty) return TargetTypeValue.unknown;
    final Uri? uri = Uri.tryParse(target);
    return switch (target) {
      'wall' || 'wall_of_the_day' => TargetTypeValue.share,
      'follower' => TargetTypeValue.user,
      'home' ||
      'ai' ||
      'streak_reminder' ||
      'creator_stats' ||
      'rewards' ||
      'drops' ||
      'announcement' ||
      'content_report' => TargetTypeValue.screen,
      _ => uri == null ? TargetTypeValue.unknown : DeepLinkNavigation.targetType(const DeepLinkParser().parse(uri)),
    };
  }

  /// The kind of a push payload, or null for pushes that the app does not measure.
  static PushKindValue? pushKindFor(Map<String, dynamic> data) {
    final String explicit = data['push_kind']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) {
      for (final PushKindValue kind in PushKindValue.values) {
        if (kind.wireValue == explicit) return kind;
      }
    }
    final String route = data['route']?.toString().trim() ?? '';
    final bool isReport = (data['report_id']?.toString().trim() ?? '').isNotEmpty;
    return switch (route) {
      'streak_reminder' => PushKindValue.streakReminder,
      'follower' => PushKindValue.follower,
      'wall' => isReport ? PushKindValue.moderation : PushKindValue.post,
      'wall_of_the_day' => PushKindValue.wotd,
      'drops' => PushKindValue.drop,
      'content_report' => PushKindValue.moderation,
      _ => null,
    };
  }

  /// Records that the user opened a push. Call it once per tap.
  void trackPushOpened(Map<String, dynamic> data) {
    if (data['notification_kind'] == 'wall_request_filled') {
      unawaited(analytics.track(WallRequestPushOpenedEvent(requestId: data['request_id']?.toString() ?? '')));
    }
    final PushKindValue? kind = pushKindFor(data);
    if (kind == null) return;
    unawaited(analytics.track(PushOpenedEvent(kind: kind)));
    final Future<void> Function(String kindWire, {bool gallery})? onTap = onMeasuredTap;
    if (onTap != null) unawaited(onTap(kind.wireValue, gallery: data['gallery']?.toString() == '1'));
  }

  /// Adapts legacy push metadata to the same typed destinations used by URLs.
  Future<DeepLinkActionEntity?> actionFromPayload(
    Map<String, dynamic> data, {
    required String sourceTag,
    bool fallbackToInbox = true,
  }) {
    if (data['route'] == 'creator_stats') {
      return actionFromRoute(route: 'creator_stats', sourceTag: sourceTag, fallbackToInbox: fallbackToInbox);
    }
    final String rawUrl = data['url']?.toString().trim() ?? '';
    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri != null && const DeepLinkNavigation().isPrismDeepLink(uri)) {
      const DeepLinkParser parser = DeepLinkParser();
      final DeepLinkActionEntity action = parser.parse(uri);
      if (action is! UnknownIntent) return Future<DeepLinkActionEntity?>.value(action);
    }
    final String route = data['route']?.toString().trim() ?? '';
    final String wallId = data['wall_id']?.toString().trim() ?? '';
    final String profileIdentifier = _firstPresent(data, const <String>[
      'profile_identifier',
      'profileIdentifier',
      'follower_uid',
      'profile_uid',
      'username',
      'user',
    ]);
    return _mapAction(
      route: route,
      wallId: wallId,
      profileIdentifier: profileIdentifier,
      sourceTag: sourceTag,
      fallbackToInbox: fallbackToInbox,
    );
  }

  Future<DeepLinkActionEntity?> actionFromRoute({
    required String route,
    String? wallId,
    String? profileIdentifier,
    required String sourceTag,
    bool fallbackToInbox = true,
  }) {
    return _mapAction(
      route: route.trim(),
      wallId: wallId?.trim() ?? '',
      profileIdentifier: profileIdentifier?.trim() ?? '',
      sourceTag: sourceTag,
      fallbackToInbox: fallbackToInbox,
    );
  }

  Future<DeepLinkActionEntity?> _mapAction({
    required String route,
    required String wallId,
    required String profileIdentifier,
    required String sourceTag,
    required bool fallbackToInbox,
  }) async {
    DeepLinkActionEntity? mapped;
    try {
      mapped = await _resolveAction(
        route: route,
        wallId: wallId,
        profileIdentifier: profileIdentifier,
        sourceTag: sourceTag,
      );
    } catch (_) {
      mapped = null;
    }
    if (mapped != null || !fallbackToInbox) {
      return mapped;
    }
    if (route.isNotEmpty) {
      final l10n = await loadDeviceAppLocalizations();
      toasts.error(l10n.coreContentNotAvailable);
    }
    return const PageLinkIntent(path: '/notifications', rawUri: '/notifications');
  }

  Future<DeepLinkActionEntity?> _resolveAction({
    required String route,
    required String wallId,
    required String profileIdentifier,
    required String sourceTag,
  }) async {
    if (route.isEmpty) return null;
    final Uri? routeUri = Uri.tryParse(route);
    final DeepLinkActionEntity? parsedAction = routeUri == null ? null : const DeepLinkParser().parse(routeUri);
    if (parsedAction is SetupLinkIntent) return parsedAction;

    switch (route) {
      case 'wall':
        return _mapWallAction(wallId: wallId, sourceTag: sourceTag);
      case 'wall_of_the_day':
        if (wallId.isNotEmpty) {
          final DeepLinkActionEntity? wallAction = await _mapWallAction(wallId: wallId, sourceTag: '$sourceTag.wotd');
          if (wallAction != null) {
            return wallAction;
          }
        }
        return const PageLinkIntent(path: '/dashboard/home', rawUri: '/dashboard/home');
      case 'home':
        return const PageLinkIntent(path: '/dashboard/home', rawUri: '/dashboard/home');
      case 'ai':
        return const PageLinkIntent(path: '/ai', rawUri: '/ai');
      case 'creator_stats':
        return const PageLinkIntent(path: '/creator-stats', rawUri: '/creator-stats', source: 'inbox');
      case 'streak_reminder':
      case 'rewards':
        return const PageLinkIntent(path: '/dashboard/rewards', rawUri: '/dashboard/rewards');
      case 'drops':
        return const ScreenLinkIntent(screen: DeepLinkScreen.drops, rawUri: '/drops');
      case 'follower':
        if (profileIdentifier.isNotEmpty) {
          return UserLinkIntent(profileIdentifier: profileIdentifier, rawUri: route);
        }
        return null;
      case 'announcement':
        return const PageLinkIntent(path: '/notifications', rawUri: '/notifications');
      case 'content_report':
        return app_state.isAdminUser() ? const PageLinkIntent(path: '/admin-review', rawUri: '/admin-review') : null;
      default:
        return parsedAction is UnknownIntent ? null : parsedAction;
    }
  }

  Future<DeepLinkActionEntity?> _mapWallAction({required String wallId, required String sourceTag}) async {
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
    return ShareLinkIntent(
      wallId: id,
      source: source,
      thumbnailUrl: thumbnailUrl,
      wallpaperUrl: wallpaperUrl,
      rawUri: '/share/$id',
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
