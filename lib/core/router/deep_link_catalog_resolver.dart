import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart' show LibraryTab;
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:auto_route/auto_route.dart';

/// Resolves a catalog-validated URL to a real page route. Object arguments are fetched from repositories or replaced
/// with an explicit input workflow; they are never reconstructed from file paths or arbitrary URL payloads.
Future<PageRouteInfo?> routeForPageLink(
  PageLinkIntent intent, {
  Future<PublicProfileEntity?> Function(String identifier)? profileLookup,
  Future<FeedItemEntity?> Function({required String wallId, required WallpaperSource source})? wallpaperLookup,
  Future<File> Function({required String imageUrl, required String wallId, required WallpaperSource source})?
  localFileResolver,
}) async {
  final DeepLinkRouteMatch? match = const DeepLinkRouteCatalog().resolve(Uri.parse(intent.path));
  if (match == null) return null;

  final Map<String, String> path = match.pathParams;
  final Map<String, String> query = match.queryParams;
  final String identifier = path['identifier'] ?? query['identifier'] ?? query['user'] ?? '';
  final String wallId = path['wallId'] ?? query['wallId'] ?? query['id'] ?? '';
  final String sourceWire = query['source'] ?? query['provider'] ?? '';
  final WallpaperSource? source = sourceWire.isEmpty ? null : WallpaperSourceX.fromWire(sourceWire);

  return switch (match.target) {
    // Splash is internal startup UI. A direct root link resumes in the browsable app after the startup gate.
    DeepLinkPageTarget.splash => const DashboardRoute(),
    DeepLinkPageTarget.onboarding => OnboardingV2ShellRoute(),
    DeepLinkPageTarget.dashboard => const DashboardRoute(),
    DeepLinkPageTarget.home => const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()]),
    DeepLinkPageTarget.searchTab => const DashboardRoute(
      children: <PageRouteInfo>[
        SearchTabRoute(children: <PageRouteInfo>[SearchRoute()]),
      ],
    ),
    DeepLinkPageTarget.chooseImage => _inputRoute(_workflow(query['workflow']!)),
    DeepLinkPageTarget.userSearch => const DashboardRoute(
      children: <PageRouteInfo>[
        SearchTabRoute(children: <PageRouteInfo>[UserSearchRoute()]),
      ],
    ),
    DeepLinkPageTarget.rewardsTab => const DashboardRoute(children: <PageRouteInfo>[RewardsTabRoute()]),
    DeepLinkPageTarget.collectionTab => const DashboardRoute(children: <PageRouteInfo>[CollectionTabRoute()]),
    DeepLinkPageTarget.ai => AiTabRoute(),
    DeepLinkPageTarget.wallpaperDetail => WallpaperDetailRoute(wallId: wallId, source: source ?? WallpaperSource.prism),
    DeepLinkPageTarget.wotdArchive => const WotdArchiveRoute(),
    DeepLinkPageTarget.downloadWallpaperInput =>
      wallId.isEmpty && (path['wallpaperId'] ?? query['wallpaperId'] ?? '').isEmpty
          ? _inputRoute(DeepLinkInputWorkflow.downloadWallpaper)
          : _downloadRoute(
              wallId: path['wallpaperId'] ?? query['wallpaperId'] ?? wallId,
              source: source ?? WallpaperSource.prism,
              wallpaperLookup: wallpaperLookup,
              localFileResolver: localFileResolver,
            ),
    DeepLinkPageTarget.wallpaperFilterInput => _inputRoute(DeepLinkInputWorkflow.wallpaperFilter),
    DeepLinkPageTarget.editProfile => const EditProfilePanelRoute(),
    DeepLinkPageTarget.sharePrism => const SharePrismRoute(),
    DeepLinkPageTarget.settings => const SettingsRoute(),
    DeepLinkPageTarget.blockedAccounts => const BlockedAccountsRoute(),
    DeepLinkPageTarget.about => AboutRoute(),
    DeepLinkPageTarget.favourites => const FavouriteWallpaperRoute(),
    DeepLinkPageTarget.downloads => const DownloadRoute(),
    DeepLinkPageTarget.library => LibraryRoute(initialTab: _libraryTab(query['tab'])),
    DeepLinkPageTarget.uploadInput => _inputRoute(DeepLinkInputWorkflow.uploadWall),
    DeepLinkPageTarget.editWallInput => _inputRoute(DeepLinkInputWorkflow.editWall),
    DeepLinkPageTarget.review => const ReviewRoute(),
    DeepLinkPageTarget.theme => const ThemeViewRoute(),
    DeepLinkPageTarget.notifications => const NotificationRoute(),
    DeepLinkPageTarget.collectionView => CollectionViewRoute(
      collectionName: path['collectionName'] ?? query['collectionName'] ?? query['name']!,
    ),
    DeepLinkPageTarget.profile => ProfileRoute(profileIdentifier: identifier),
    DeepLinkPageTarget.followers => _relationRoute(identifier, followers: true, profileLookup: profileLookup),
    DeepLinkPageTarget.following => _relationRoute(identifier, followers: false, profileLookup: profileLookup),
    DeepLinkPageTarget.adminReview => AdminReviewRoute(),
    DeepLinkPageTarget.swipeReview => const SwipeReviewRoute(),
    DeepLinkPageTarget.adminTelemetry => const FirestoreTelemetryRoute(),
    DeepLinkPageTarget.debugPanel => DebugPanelRoute(tab: query['tab'] ?? 'logs'),
    DeepLinkPageTarget.quickTileSettings => const QuickTileSettingsRoute(),
    DeepLinkPageTarget.autoRotate => const AutoRotateRoute(),
    DeepLinkPageTarget.iosShortcuts => const IosShortcutsGuideRoute(),
    DeepLinkPageTarget.wallpaperHistory => const WallpaperHistoryRoute(),
    DeepLinkPageTarget.photoPreview => _previewRoute(
      wallId: query['wallpaperId']!,
      source: source,
      wallpaperLookup: wallpaperLookup,
      clock: false,
    ),
    DeepLinkPageTarget.clockPreview => _previewRoute(
      wallId: query['wallpaperId']!,
      source: source,
      wallpaperLookup: wallpaperLookup,
      clock: true,
    ),
    DeepLinkPageTarget.adminImage => _adminImageRoute(
      wallId: query['wallpaperId']!,
      source: source,
      wallpaperLookup: wallpaperLookup,
    ),
    DeepLinkPageTarget.wallpaperPositionInput => _wallpaperActionRoute(
      workflow: DeepLinkInputWorkflow.wallpaperPosition,
      wallId: path['wallpaperId'] ?? query['wallpaperId'] ?? '',
      source: source,
      entryPoint: query['entryPoint'],
      wallpaperLookup: wallpaperLookup,
    ),
    DeepLinkPageTarget.liveWallpaperInput => _wallpaperActionRoute(
      workflow: DeepLinkInputWorkflow.liveWallpaper,
      wallId: path['wallpaperId'] ?? query['wallpaperId'] ?? '',
      source: source,
      wallpaperLookup: wallpaperLookup,
    ),
    DeepLinkPageTarget.rewards => RewardsRoute(),
    DeepLinkPageTarget.coinHistory => const CoinHistoryRoute(),
    DeepLinkPageTarget.shop => const ShopRoute(),
    DeepLinkPageTarget.drops => const DropsRoute(),
    DeepLinkPageTarget.dropDetail => DropDetailRoute(weekKey: path['weekKey']!),
    DeepLinkPageTarget.dropPreview => DropPreviewRoute(weekKey: path['weekKey']!, wallId: path['wallId']!),
    DeepLinkPageTarget.dailyChest => DailyChestRoute(),
    DeepLinkPageTarget.spinWheel => SpinWheelRoute(),
    DeepLinkPageTarget.premium => const PremiumRoute(),
    DeepLinkPageTarget.leaderboard => const LeaderboardRoute(),
    DeepLinkPageTarget.draw => const DrawRoute(),
    DeepLinkPageTarget.notFound => const NotFoundRoute(),
  };
}

/// Fetches the provider entity without opening the detail bloc or triggering view and palette work.
final class DeepLinkWallpaperLookup {
  const DeepLinkWallpaperLookup({
    required PrismWallpaperRepository prismRepository,
    required WallhavenWallpaperRepository wallhavenRepository,
    required PexelsWallpaperRepository pexelsRepository,
  }) : _prismRepository = prismRepository,
       _wallhavenRepository = wallhavenRepository,
       _pexelsRepository = pexelsRepository;

  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;

  factory DeepLinkWallpaperLookup.fromGetIt() => DeepLinkWallpaperLookup(
    prismRepository: getIt<PrismWallpaperRepository>(),
    wallhavenRepository: getIt<WallhavenWallpaperRepository>(),
    pexelsRepository: getIt<PexelsWallpaperRepository>(),
  );

  Future<FeedItemEntity?> call({required String wallId, required WallpaperSource source}) async {
    try {
      final FeedItemEntity? entity = switch (source) {
        WallpaperSource.prism => (await _prismRepository.fetchById(wallId)).fold(
          onFailure: (_) => null,
          onSuccess: (PrismWallpaper? wallpaper) =>
              wallpaper == null ? null : PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
        ),
        WallpaperSource.wallhaven => (await _wallhavenRepository.fetchById(wallId)).fold(
          onFailure: (_) => null,
          onSuccess: (WallhavenWallpaper? wallpaper) =>
              wallpaper == null ? null : WallhavenFeedItem(id: wallpaper.id, wallpaper: wallpaper),
        ),
        WallpaperSource.pexels => (await _pexelsRepository.fetchById(wallId)).fold(
          onFailure: (_) => null,
          onSuccess: (PexelsWallpaper? wallpaper) =>
              wallpaper == null ? null : PexelsFeedItem(id: wallpaper.id, wallpaper: wallpaper),
        ),
        _ => null,
      };
      return entity;
    } catch (_) {
      return null;
    }
  }
}

DeepLinkInputRoute _inputRoute(DeepLinkInputWorkflow workflow) => DeepLinkInputRoute(workflow: workflow);

LibraryTab _libraryTab(String? tab) => switch (tab?.toLowerCase()) {
  'downloads' => LibraryTab.downloads,
  'history' => LibraryTab.history,
  _ => LibraryTab.favourites,
};

DeepLinkInputWorkflow _workflow(String value) => switch (value) {
  'uploadWall' => DeepLinkInputWorkflow.uploadWall,
  'editWall' => DeepLinkInputWorkflow.editWall,
  'wallpaperFilter' => DeepLinkInputWorkflow.wallpaperFilter,
  'downloadWallpaper' => DeepLinkInputWorkflow.downloadWallpaper,
  'wallpaperPosition' => DeepLinkInputWorkflow.wallpaperPosition,
  'liveWallpaper' => DeepLinkInputWorkflow.liveWallpaper,
  'clockPreview' => DeepLinkInputWorkflow.clockPreview,
  'photoPreview' => DeepLinkInputWorkflow.photoPreview,
  _ => throw ArgumentError.value(value, 'workflow', 'Unsupported deep-link input workflow'),
};

Future<PageRouteInfo?> _previewRoute({
  required String wallId,
  required WallpaperSource? source,
  required bool clock,
  Future<FeedItemEntity?> Function({required String wallId, required WallpaperSource source})? wallpaperLookup,
}) async {
  if (wallId.trim().isEmpty) return null;
  final FeedItemEntity? entity = await (wallpaperLookup ?? _lookupWallpaper)(
    wallId: wallId,
    source: source ?? WallpaperSource.prism,
  );
  if (entity == null || !_isTrustedImageUrl(entity.thumbnailUrl, entity.source)) {
    return null;
  }
  final previewUrl = entity.source == WallpaperSource.prism ? entity.thumbnailUrl : entity.fullUrl;
  if (!_isTrustedImageUrl(previewUrl, entity.source)) return null;
  if (clock) {
    return ClockPreviewRoute(
      link: previewUrl,
      file: false,
      wallpaperId: entity.id,
      wallpaperSource: entity.source,
      thumbnailUrl: entity.thumbnailUrl,
    );
  }
  return ReviewPhotoPreviewRoute(url: previewUrl, thumbUrl: entity.thumbnailUrl);
}

Future<PageRouteInfo?> _adminImageRoute({
  required String wallId,
  required WallpaperSource? source,
  Future<FeedItemEntity?> Function({required String wallId, required WallpaperSource source})? wallpaperLookup,
}) async {
  if (wallId.trim().isEmpty) return null;
  final FeedItemEntity? entity = await (wallpaperLookup ?? _lookupWallpaper)(
    wallId: wallId,
    source: source ?? WallpaperSource.prism,
  );
  if (entity == null) {
    return null;
  }
  final previewUrl = entity.source == WallpaperSource.prism ? entity.thumbnailUrl : entity.fullUrl;
  if (!_isTrustedImageUrl(previewUrl, entity.source)) return null;
  return FullScreenImageRoute(imageUrl: previewUrl);
}

Future<PageRouteInfo?> _relationRoute(
  String identifier, {
  required bool followers,
  Future<PublicProfileEntity?> Function(String identifier)? profileLookup,
}) async {
  if (identifier.trim().isEmpty) return null;
  try {
    final PublicProfileEntity? profile = await (profileLookup ?? _lookupProfile)(identifier);
    if (profile == null) return null;
    final PageRouteInfo route = followers
        ? FollowersRoute(followers: List<String>.unmodifiable(profile.followers))
        : FollowingListRoute(following: List<String>.unmodifiable(profile.following));
    return route;
  } catch (_) {
    return null;
  }
}

Future<PublicProfileEntity?> _lookupProfile(String identifier) =>
    getIt<PublicProfileRepository>().watchProfile(identifier).first.timeout(const Duration(seconds: 15));

Future<FeedItemEntity?> _lookupWallpaper({required String wallId, required WallpaperSource source}) async {
  try {
    return await DeepLinkWallpaperLookup.fromGetIt()
        .call(wallId: wallId, source: source)
        .timeout(const Duration(seconds: 30));
  } catch (_) {
    return null;
  }
}

Future<PageRouteInfo?> _wallpaperActionRoute({
  required DeepLinkInputWorkflow workflow,
  required String wallId,
  required WallpaperSource? source,
  String? entryPoint,
  Future<FeedItemEntity?> Function({required String wallId, required WallpaperSource source})? wallpaperLookup,
}) async {
  if (wallId.isEmpty) return _inputRoute(workflow);
  final WallpaperSource selectedSource = source ?? WallpaperSource.prism;
  if (selectedSource == WallpaperSource.prism) {
    return WallpaperDetailRoute(wallId: wallId, source: selectedSource);
  }
  final FeedItemEntity? entity = await (wallpaperLookup ?? _lookupWallpaper)(wallId: wallId, source: selectedSource);
  if (entity?.source == WallpaperSource.prism) {
    return WallpaperDetailRoute(wallId: entity!.id, source: WallpaperSource.prism);
  }
  if (entity == null || !_isTrustedImageUrl(entity.fullUrl, entity.source)) {
    return null;
  }
  return switch (workflow) {
    DeepLinkInputWorkflow.wallpaperPosition => WallpaperPositionRoute(
      imageUrl: entity.fullUrl,
      thumbnailUrl: entity.thumbnailUrl,
      entryPoint: entryPoint ?? 'deep_link',
      wallpaperId: entity.id,
      wallpaperSource: entity.source,
    ),
    DeepLinkInputWorkflow.liveWallpaper => LiveWallpaperRoute(imageUrl: entity.fullUrl),
    _ => null,
  };
}

Future<PageRouteInfo?> _downloadRoute({
  required String wallId,
  required WallpaperSource source,
  Future<FeedItemEntity?> Function({required String wallId, required WallpaperSource source})? wallpaperLookup,
  Future<File> Function({required String imageUrl, required String wallId, required WallpaperSource source})?
  localFileResolver,
}) async {
  if (source == WallpaperSource.prism) return WallpaperDetailRoute(wallId: wallId, source: source);
  final FeedItemEntity? entity = await (wallpaperLookup ?? _lookupWallpaper)(wallId: wallId, source: source);
  if (entity?.source == WallpaperSource.prism) {
    return WallpaperDetailRoute(wallId: entity!.id, source: WallpaperSource.prism);
  }
  if (entity == null || !_isTrustedImageUrl(entity.fullUrl, entity.source)) {
    return null;
  }
  try {
    final File file = await (localFileResolver ?? _resolveLocalFile)(
      imageUrl: entity.fullUrl,
      wallId: entity.id,
      source: entity.source,
    );
    if (!await file.exists()) return null;
    return DownloadWallpaperRoute(source: entity.source, file: file);
  } catch (_) {
    return null;
  }
}

Future<File> _resolveLocalFile({required String imageUrl, required String wallId, required WallpaperSource source}) =>
    WallpaperService.resolveToLocalFile(imageUrl, wallpaperId: wallId, wallpaperSource: source);

bool _isTrustedImageUrl(String imageUrl, WallpaperSource source) {
  final Uri? uri = Uri.tryParse(imageUrl);
  if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }
  if (source == WallpaperSource.prism) return isSafePrismThumbnailUrl(imageUrl);
  final Set<String> allowedHosts = switch (source) {
    WallpaperSource.prism => const <String>{},
    WallpaperSource.wallhaven => <String>{'w.wallhaven.cc', 'th.wallhaven.cc'},
    WallpaperSource.pexels => <String>{'images.pexels.com'},
    _ => const <String>{},
  };
  return (uri.port == 443 || uri.hasPort == false) && allowedHosts.contains(uri.host.toLowerCase());
}
