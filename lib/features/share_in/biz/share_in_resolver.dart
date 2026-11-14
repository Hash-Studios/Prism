import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// Turns a share into where Prism goes. A Prism link opens its page (a wall opens with Save to Folder); an image or
/// another link opens the share sheet. A share Prism cannot read opens the sheet in its failed state.
Future<DeepLinkRouteResolution> resolveShareIn(
  ShareInIntent action,
  DeepLinkNavigation navigation, {
  SharedInbox? inbox,
  void Function(AnalyticsEvent event)? track,
}) async {
  final SharedInbox box = inbox ?? SharedInbox();
  final void Function(AnalyticsEvent event) record = track ?? analytics.track;
  unawaited(box.sweep().catchError((Object _) => 0));
  final SharedItemKind expected = action.inboxId != null ? SharedItemKind.image : SharedItemKind.url;
  final SharedItem? item = await _item(action, box, navigation);
  record(ShareReceivedEvent(kind: (item?.kind ?? expected).analytics, sourceApp: action.sourceApp));
  switch (item) {
    case null:
      return DeepLinkRouteResolution.route(ShareInRoute(key: UniqueKey(), kind: expected));
    case SharedPrismLink(:final DeepLinkActionEntity action):
      final DeepLinkRouteResolution resolution = await navigation.resolveAction(action);
      final PageRouteInfo? route = resolution.route;
      if (route == null) {
        record(const ShareActionEvent(action: ShareActionValue.failed, kind: SharedItemKindValue.prismLink));
        return resolution;
      }
      if (route is! WallpaperDetailRoute) return resolution;
      record(const ShareActionEvent(action: ShareActionValue.save, kind: SharedItemKindValue.prismLink));
      return DeepLinkRouteResolution.route(withFolderSheet(route));
    case SharedImage() || SharedUrl():
      return DeepLinkRouteResolution.route(ShareInRoute(key: UniqueKey(), kind: item.kind, item: item));
  }
}

Future<SharedItem?> _item(ShareInIntent action, SharedInbox inbox, DeepLinkNavigation navigation) async {
  final String? id = action.inboxId;
  if (id == null) return sharedItemFromText(action.text ?? '', parser: navigation.parser);
  try {
    return SharedImage(await inbox.take(id));
  } catch (error) {
    logger.w('[ShareIn] shared image unavailable (${error.runtimeType})');
    return null;
  }
}

/// The same wall page, with the Save to Folder sheet open on arrival.
WallpaperDetailRoute withFolderSheet(WallpaperDetailRoute route) {
  final WallpaperDetailRouteArgs args = route.args!;
  return WallpaperDetailRoute(
    key: UniqueKey(),
    entity: args.entity,
    wallId: args.wallId,
    source: args.source,
    thumbnailUrl: args.thumbnailUrl,
    analyticsSurface: args.analyticsSurface,
    heroTag: args.heroTag,
    localFile: args.localFile,
    aspectRatio: args.aspectRatio,
    requestId: args.requestId,
    entry: args.entry,
    feed: args.feed,
    desktopDownload: args.desktopDownload,
    openFolderSheet: true,
  );
}
