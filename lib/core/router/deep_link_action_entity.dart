import 'package:Prism/core/wallpaper/wallpaper_source.dart';

sealed class DeepLinkActionEntity {
  const DeepLinkActionEntity({required this.rawUri});

  final String rawUri;
}

final class ShareLinkIntent extends DeepLinkActionEntity {
  const ShareLinkIntent({
    required this.wallId,
    required this.source,
    required this.wallpaperUrl,
    required this.thumbnailUrl,
    required super.rawUri,
  });

  final String wallId;
  final WallpaperSource source;
  final String wallpaperUrl;
  final String thumbnailUrl;
}

final class UserLinkIntent extends DeepLinkActionEntity {
  const UserLinkIntent({required this.profileIdentifier, required super.rawUri});

  final String profileIdentifier;
}

/// A legacy shared setup link. Setups were removed; the app opens Home instead.
final class SetupLinkIntent extends DeepLinkActionEntity {
  const SetupLinkIntent({required super.rawUri});
}

final class ReferLinkIntent extends DeepLinkActionEntity {
  const ReferLinkIntent({required this.inviterId, required super.rawUri});

  final String inviterId;
}

final class ShortCodeIntent extends DeepLinkActionEntity {
  const ShortCodeIntent({required this.code, required super.rawUri});

  final String code;
}

enum DeepLinkScreen { shop, drops, leaderboard, draw }

final class ScreenLinkIntent extends DeepLinkActionEntity {
  const ScreenLinkIntent({required this.screen, required super.rawUri});

  final DeepLinkScreen screen;
}

/// A canonical app path accepted by [DeepLinkRouteCatalog]. This carries only URL-safe values; route arguments that
/// need local files or fetched entities are resolved by the route catalog, never decoded from arbitrary objects.
final class PageLinkIntent extends DeepLinkActionEntity {
  const PageLinkIntent({required this.path, required super.rawUri, this.source = 'link'});

  /// A validated app path, including only the query keys supported by its route definition.
  final String path;

  final String source;
}

final class UnknownIntent extends DeepLinkActionEntity {
  const UnknownIntent({required super.rawUri});
}
