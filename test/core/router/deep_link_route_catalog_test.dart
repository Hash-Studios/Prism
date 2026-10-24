import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DeepLinkParser parser = DeepLinkParser();

  test('every catalog example resolves to its declared AutoRoute page', () async {
    final Directory tempDirectory = await Directory.systemTemp.createTemp('deep-link-catalog-');
    final File localImage = File('${tempDirectory.path}/wallpaper.jpg');
    await localImage.writeAsBytes(<int>[1]);
    addTearDown(() => tempDirectory.delete(recursive: true));

    const PublicProfileEntity profile = PublicProfileEntity(
      id: 'alice-id',
      name: 'Alice',
      email: 'alice@example.com',
      username: 'alice',
      profilePhoto: '',
      bio: '',
      links: <String, String>{},
      coverPhoto: '',
    );
    const FeedItemEntity wallpaper = PrismFeedItem(
      id: 'wall1',
      wallpaper: PrismWallpaper(
        review: true,
        core: WallpaperCore(
          id: 'wall1',
          source: WallpaperSource.prism,
          fullUrl: 'https://raw.githubusercontent.com/hash-studios/walls/main/wall.jpg',
          thumbnailUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg',
        ),
      ),
    );

    for (final DeepLinkRouteExample example in DeepLinkRouteCatalog.examples) {
      final DeepLinkActionEntity action = parser.parse(Uri.parse(example.uri));
      expect(action, isA<PageLinkIntent>(), reason: example.uri);
      final PageRouteInfo? route = await routeForPageLink(
        action as PageLinkIntent,
        profileLookup: (String _) async => profile,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => wallpaper,
        localFileResolver:
            ({required String imageUrl, required String wallId, required WallpaperSource source}) async => localImage,
      );
      expect(route, isNotNull, reason: example.uri);
      expect(_routeNames(route!).contains(_expectedPageName(example.target, example.uri)), isTrue, reason: example.uri);
    }
  });

  test('route examples cover every page target', () {
    expect(
      DeepLinkRouteCatalog.examples.map((DeepLinkRouteExample example) => example.target).toSet(),
      DeepLinkPageTarget.values.toSet(),
    );
  });

  test('catalog rejects query parameters that have no app route meaning', () {
    for (final String uri in <String>[
      '/dashboard/search?q=sunset',
      '/download-wallpaper?wallpaperId=wall1&provider=downloaded',
      '/admin-review/image?wallpaperId=wall1&source=unsupported',
    ]) {
      expect(DeepLinkRouteCatalog.match(Uri.parse(uri)), isNull, reason: uri);
    }
  });

  test('catalog examples and picker destinations cover every app page', () async {
    final Set<String> reachablePages = <String>{};
    const PublicProfileEntity profile = PublicProfileEntity(
      id: 'alice-id',
      name: 'Alice',
      email: 'alice@example.com',
      username: 'alice',
      profilePhoto: '',
      bio: '',
      links: <String, String>{},
      coverPhoto: '',
    );
    for (final DeepLinkRouteExample example in DeepLinkRouteCatalog.examples) {
      final PageLinkIntent intent = parser.parse(Uri.parse(example.uri)) as PageLinkIntent;
      final PageRouteInfo? route = await routeForPageLink(
        intent,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
            _wallpaper('https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg'),
        profileLookup: (String _) async => profile,
        localFileResolver:
            ({required String imageUrl, required String wallId, required WallpaperSource source}) async =>
                File('/tmp/catalog-wallpaper.jpg'),
      );
      if (route != null) reachablePages.addAll(_routeNames(route));
    }

    reachablePages.addAll(<String>{
      'UploadWallRoute',
      'EditWallRoute',
      'WallpaperFilterRoute',
      'DownloadWallpaperRoute',
      'WallpaperPositionRoute',
      'LiveWallpaperRoute',
      'ClockPreviewRoute',
      'ReviewPhotoPreviewRoute',
    });

    final Set<String> appPages = _appRouteNames(AppRouter().routes)..remove('SplashWidgetRoute');
    expect(appPages, hasLength(56));
    expect(
      appPages.difference(reachablePages),
      isEmpty,
      reason: 'Every app page should have a catalog URL or an explicit picker continuation.',
    );
  });

  test('resolver preserves identifiers, encoded collection names, wallpaper source, and profile relations', () async {
    const PublicProfileEntity profile = PublicProfileEntity(
      id: 'alice-id',
      name: 'Alice',
      email: 'alice@example.com',
      username: 'alice',
      profilePhoto: '',
      bio: '',
      links: <String, String>{},
      coverPhoto: '',
    );

    final PageRouteInfo detail = (await routeForPageLink(
      parser.parse(Uri.parse('/wallpaper-detail?wallId=wall1&source=wallhaven')) as PageLinkIntent,
    ))!;
    expect((detail.args! as WallpaperDetailRouteArgs).source, WallpaperSource.wallhaven);

    final PageRouteInfo collection = (await routeForPageLink(
      parser.parse(Uri.parse('/collection/My%20walls%20%26%20more')) as PageLinkIntent,
    ))!;
    expect((collection.args! as CollectionViewRouteArgs).collectionName, 'My walls & more');

    final PageRouteInfo drop = (await routeForPageLink(
      parser.parse(Uri.parse('/drops/week-2026-10-19')) as PageLinkIntent,
    ))!;
    expect((drop.args! as DropDetailRouteArgs).weekKey, 'week-2026-10-19');

    final PageRouteInfo dropPreview = (await routeForPageLink(
      parser.parse(Uri.parse('/drops/week-2026-10-19/preview/wall1')) as PageLinkIntent,
    ))!;
    expect((dropPreview.args! as DropPreviewRouteArgs).weekKey, 'week-2026-10-19');
    expect((dropPreview.args! as DropPreviewRouteArgs).wallId, 'wall1');

    final PageRouteInfo relation = (await routeForPageLink(
      parser.parse(Uri.parse('/user/alice/followers')) as PageLinkIntent,
      profileLookup: (String _) async => profile,
    ))!;
    expect((relation.args! as FollowersRouteArgs).userId, profile.id);
  });

  test('read-only wallpaper lookup maps provider repositories to source entities', () async {
    final _FakeWallhavenRepository wallhaven = _FakeWallhavenRepository(
      Result.success<WallhavenWallpaper?>(
        const WallhavenWallpaper(
          core: WallpaperCore(
            id: 'wh-wall',
            source: WallpaperSource.wallhaven,
            fullUrl: 'https://w.wallhaven.cc/full/ab/wall.jpg',
            thumbnailUrl: 'https://th.wallhaven.cc/small/ab/thumb.jpg',
          ),
        ),
      ),
    );
    final DeepLinkWallpaperLookup lookup = DeepLinkWallpaperLookup(
      prismRepository: _FakePrismRepository(Result.success<PrismWallpaper?>(null)),
      wallhavenRepository: wallhaven,
      pexelsRepository: _FakePexelsRepository(Result.success<PexelsWallpaper?>(null)),
    );

    final FeedItemEntity? entity = await lookup.call(wallId: 'wh-wall', source: WallpaperSource.wallhaven);
    expect(entity, isA<WallhavenFeedItem>());
    expect(entity?.source, WallpaperSource.wallhaven);
    expect(entity?.id, 'wh-wall');
    expect(wallhaven.lastFetchedId, 'wh-wall');
  });

  test('external local paths and arbitrary image URLs never become route arguments', () {
    for (final String uri in <String>[
      '/upload-wall?filePath=%2Ftmp%2Fwall.jpg',
      '/edit-wall?image=%2Ftmp%2Fwall.jpg',
      '/wallpaper-filter?filePath=%2Ftmp%2Fwall.jpg',
      '/wallpaper-position?imageUrl=https%3A%2F%2F127.0.0.1%2Fsecret',
      '/download-wallpaper?url=http%3A%2F%2F169.254.169.254%2Fmetadata',
      '/live-wallpaper?imageUrl=https%3A%2F%2Fevil.example%2Fwall.jpg',
    ]) {
      expect(DeepLinkRouteCatalog.match(Uri.parse(uri)), isNull, reason: uri);
    }
  });

  test('a wallpaper id resolves through trusted provider data before image actions', () async {
    final PageRouteInfo? position = await routeForPageLink(
      const PageLinkIntent(path: '/wallpaper/wall1/position', rawUri: '/wallpaper/wall1/position'),
      wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
          _wallpaper('https://evil.example/wall.jpg'),
    );
    expect(position, isA<WallpaperDetailRoute>());

    for (final String path in <String>[
      '/photo-preview?wallpaperId=wall1',
      '/clock-preview?wallpaperId=wall1',
      '/admin-review/image?wallpaperId=wall1',
    ]) {
      final DeepLinkActionEntity action = parser.parse(Uri.parse(path));
      expect(action, isA<PageLinkIntent>(), reason: path);
      expect(
        await routeForPageLink(
          action as PageLinkIntent,
          wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
              _wallpaper('https://evil.example/wall.jpg'),
        ),
        isNull,
        reason: path,
      );
    }
  });

  test('protected original actions route through detail without native acquisition', () async {
    for (final path in [
      '/wallpaper/wall1/position',
      '/wallpaper/wall1/live',
      '/download-wallpaper?wallpaperId=wall1',
    ]) {
      final intent = parser.parse(Uri.parse(path));
      expect(intent, isA<PageLinkIntent>());
      final route = await routeForPageLink(
        intent as PageLinkIntent,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
            throw StateError('must not acquire an original'),
        localFileResolver:
            ({required String imageUrl, required String wallId, required WallpaperSource source}) async =>
                throw StateError('must not download an original'),
      );
      expect(route, isA<WallpaperDetailRoute>(), reason: path);
    }
  });

  test('relation links fail closed when profile data is missing or unavailable', () async {
    final PageLinkIntent followers = parser.parse(Uri.parse('/user/alice/followers')) as PageLinkIntent;
    final PageLinkIntent following = parser.parse(Uri.parse('/user/alice/following')) as PageLinkIntent;

    expect(await routeForPageLink(followers, profileLookup: (_) async => null), isNull);
    expect(await routeForPageLink(followers, profileLookup: (_) async => throw StateError('offline')), isNull);
    expect(await routeForPageLink(following, profileLookup: (_) async => throw StateError('offline')), isNull);
  });

  test('external download links fail closed when acquisition fails or returns no file', () async {
    const FeedItemEntity wallpaper = WallhavenFeedItem(
      id: 'wh-wall',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'wh-wall',
          source: WallpaperSource.wallhaven,
          fullUrl: 'https://w.wallhaven.cc/full/ab/wall.jpg',
          thumbnailUrl: 'https://th.wallhaven.cc/small/ab/thumb.jpg',
        ),
      ),
    );
    final PageLinkIntent intent =
        parser.parse(Uri.parse('/download-wallpaper?wallpaperId=wh-wall&provider=wallhaven')) as PageLinkIntent;

    expect(
      await routeForPageLink(
        intent,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => wallpaper,
        localFileResolver:
            ({required String imageUrl, required String wallId, required WallpaperSource source}) async =>
                throw StateError('download failed'),
      ),
      isNull,
    );

    final Directory directory = await Directory.systemTemp.createTemp('deep-link-download-');
    addTearDown(() => directory.delete(recursive: true));
    final File image = File('${directory.path}/wall.jpg')..writeAsBytesSync(<int>[1]);
    final PageRouteInfo? downloaded = await routeForPageLink(
      intent,
      wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => wallpaper,
      localFileResolver: ({required String imageUrl, required String wallId, required WallpaperSource source}) async =>
          image,
    );
    expect(downloaded, isA<DownloadWallpaperRoute>());
    expect((downloaded!.args! as DownloadWallpaperRouteArgs).source, WallpaperSource.wallhaven);
    expect(
      await routeForPageLink(
        intent,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => wallpaper,
        localFileResolver:
            ({required String imageUrl, required String wallId, required WallpaperSource source}) async =>
                File('/path/that/does/not/exist'),
      ),
      isNull,
    );
  });

  test('provider-backed image actions reject missing lookups and untrusted provider URLs', () async {
    final PageLinkIntent position =
        parser.parse(Uri.parse('/wallpaper-position?wallpaperId=wall1&provider=wallhaven')) as PageLinkIntent;
    final PageLinkIntent preview =
        parser.parse(Uri.parse('/photo-preview?wallpaperId=wall1&provider=wallhaven')) as PageLinkIntent;

    expect(
      await routeForPageLink(
        position,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => null,
      ),
      isNull,
    );
    expect(
      await routeForPageLink(
        preview,
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
            _wallhavenWallpaper('https://evil.example/wall.jpg'),
      ),
      isNull,
    );
    final PageRouteInfo? trustedPosition = await routeForPageLink(
      position,
      wallpaperLookup: ({required String wallId, required WallpaperSource source}) async =>
          _wallhavenWallpaper('https://w.wallhaven.cc/full/ab/wall.jpg'),
    );
    expect(trustedPosition, isA<WallpaperPositionRoute>());
    expect((trustedPosition!.args! as WallpaperPositionRouteArgs).entryPoint, 'deep_link');
  });

  test('non-canonical Prism thumbnails are not trusted', () async {
    const endpoint = 'https://images.example.com/private/wall1';
    for (final url in [
      endpoint,
      '$endpoint?url=secret',
      '$endpoint#fragment',
      '$endpoint/extra',
      endpoint.replaceFirst('.net/', '.net:443/'),
      endpoint.replaceFirst('https://', 'https://user@'),
    ]) {
      final route = await routeForPageLink(
        const PageLinkIntent(path: '/photo-preview?wallpaperId=wall1', rawUri: '/photo-preview?wallpaperId=wall1'),
        wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => _wallpaper(url),
      );
      expect(route, isNull, reason: url);
    }
  });

  test('input workflows and debug tabs are allowlisted', () async {
    expect(DeepLinkRouteCatalog.match(Uri.parse('/choose-wallpaper?workflow=photoPreview')), isNotNull);
    expect(DeepLinkRouteCatalog.match(Uri.parse('/choose-wallpaper?workflow=clockPreview')), isNotNull);
    expect(DeepLinkRouteCatalog.match(Uri.parse('/choose-wallpaper?workflow=unknown')), isNull);
    expect(DeepLinkRouteCatalog.match(Uri.parse('/debug-panel?tab=mascot')), isNotNull);
    expect(DeepLinkRouteCatalog.match(Uri.parse('/debug-panel?tab=arbitrary')), isNull);
    for (final String tab in <String>['logs', 'tools', 'storage', 'app-info', 'mascot']) {
      expect(DeepLinkRouteCatalog.match(Uri.parse('/debug-panel?tab=$tab')), isNotNull, reason: tab);
    }
    expect(
      DeepLinkRouteCatalog.match(Uri.parse('/DROPS/week-2026-10-19/PREVIEW/wall1'))!.path,
      '/drops/week-2026-10-19/preview/wall1',
    );
    final PageLinkIntent debugIntent = parser.parse(Uri.parse('/debug-panel?tab=mascot')) as PageLinkIntent;
    final PageRouteInfo? debugRoute = await routeForPageLink(debugIntent);
    expect(debugRoute?.rawQueryParams['tab'], 'mascot');
  });
}

FeedItemEntity _wallpaper(String url) => PrismFeedItem(
  id: 'wall1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: 'wall1', source: WallpaperSource.prism, fullUrl: url, thumbnailUrl: url),
  ),
);

FeedItemEntity _wallhavenWallpaper(String url) => WallhavenFeedItem(
  id: 'wall1',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wall1',
      source: WallpaperSource.wallhaven,
      fullUrl: url,
      thumbnailUrl: 'https://th.wallhaven.cc/small/ab/thumb.jpg',
    ),
  ),
);

Set<String> _routeNames(PageRouteInfo route) => <String>{
  route.routeName,
  ...?route.initialChildren?.expand(_routeNames),
};

Set<String> _appRouteNames(List<AutoRoute> routes) => <String>{
  for (final AutoRoute route in routes)
    if (!route.page.name.startsWith('#')) ...<String>{
      route.page.name,
      ..._appRouteNames(route.children ?? const <AutoRoute>[]),
    },
};

String _expectedPageName(DeepLinkPageTarget target, String uri) => switch (target) {
  DeepLinkPageTarget.splash || DeepLinkPageTarget.dashboard => 'DashboardRoute',
  DeepLinkPageTarget.onboarding => 'OnboardingV2ShellRoute',
  DeepLinkPageTarget.home => 'HomeTabRoute',
  DeepLinkPageTarget.searchTab => 'SearchRoute',
  DeepLinkPageTarget.userSearch => 'UserSearchRoute',
  DeepLinkPageTarget.rewardsTab => 'RewardsTabRoute',
  DeepLinkPageTarget.collectionTab => 'CollectionTabRoute',
  DeepLinkPageTarget.downloadWallpaperInput =>
    uri.contains('wallpaperId=') || uri.contains('/wallpaper/') ? 'WallpaperDetailRoute' : 'DeepLinkInputRoute',
  DeepLinkPageTarget.wallpaperPositionInput =>
    uri.contains('/wallpaper/') || uri.contains('wallpaperId=') ? 'WallpaperDetailRoute' : 'DeepLinkInputRoute',
  DeepLinkPageTarget.liveWallpaperInput =>
    uri.contains('/wallpaper/') || uri.contains('wallpaperId=') ? 'WallpaperDetailRoute' : 'DeepLinkInputRoute',
  DeepLinkPageTarget.chooseImage ||
  DeepLinkPageTarget.wallpaperFilterInput ||
  DeepLinkPageTarget.uploadInput ||
  DeepLinkPageTarget.editWallInput => 'DeepLinkInputRoute',
  DeepLinkPageTarget.ai => 'AiTabRoute',
  DeepLinkPageTarget.wallpaperDetail => 'WallpaperDetailRoute',
  DeepLinkPageTarget.wotdArchive => 'WotdArchiveRoute',
  DeepLinkPageTarget.editProfile => 'EditProfilePanelRoute',
  DeepLinkPageTarget.sharePrism => 'SharePrismRoute',
  DeepLinkPageTarget.settings => 'SettingsRoute',
  DeepLinkPageTarget.blockedAccounts => 'BlockedAccountsRoute',
  DeepLinkPageTarget.about => 'AboutRoute',
  DeepLinkPageTarget.favourites => 'FavouriteWallpaperRoute',
  DeepLinkPageTarget.downloads => 'DownloadRoute',
  DeepLinkPageTarget.library => 'LibraryRoute',
  DeepLinkPageTarget.review => 'ReviewRoute',
  DeepLinkPageTarget.theme => 'ThemeViewRoute',
  DeepLinkPageTarget.notifications => 'NotificationRoute',
  DeepLinkPageTarget.collectionView => 'CollectionViewRoute',
  DeepLinkPageTarget.profile => 'ProfileRoute',
  DeepLinkPageTarget.followers => 'FollowersRoute',
  DeepLinkPageTarget.following => 'FollowingListRoute',
  DeepLinkPageTarget.adminReview => 'AdminReviewRoute',
  DeepLinkPageTarget.swipeReview => 'SwipeReviewRoute',
  DeepLinkPageTarget.adminTelemetry => 'FirestoreTelemetryRoute',
  DeepLinkPageTarget.debugPanel => 'DebugPanelRoute',
  DeepLinkPageTarget.quickTileSettings => 'QuickTileSettingsRoute',
  DeepLinkPageTarget.autoRotate => 'AutoRotateRoute',
  DeepLinkPageTarget.iosShortcuts => 'IosShortcutsGuideRoute',
  DeepLinkPageTarget.wallpaperHistory => 'WallpaperHistoryRoute',
  DeepLinkPageTarget.photoPreview => 'ReviewPhotoPreviewRoute',
  DeepLinkPageTarget.clockPreview => 'ClockPreviewRoute',
  DeepLinkPageTarget.adminImage => 'FullScreenImageRoute',
  DeepLinkPageTarget.rewards => 'RewardsRoute',
  DeepLinkPageTarget.coinHistory => 'CoinHistoryRoute',
  DeepLinkPageTarget.shop => 'ShopRoute',
  DeepLinkPageTarget.drops => 'DropsRoute',
  DeepLinkPageTarget.dropDetail => 'DropDetailRoute',
  DeepLinkPageTarget.dropPreview => 'DropPreviewRoute',
  DeepLinkPageTarget.dailyChest => 'DailyChestRoute',
  DeepLinkPageTarget.spinWheel => 'SpinWheelRoute',
  DeepLinkPageTarget.premium => 'PremiumRoute',
  DeepLinkPageTarget.leaderboard => 'LeaderboardRoute',
  DeepLinkPageTarget.draw => 'DrawRoute',
  DeepLinkPageTarget.notFound => 'NotFoundRoute',
};

final class _FakePrismRepository implements PrismWallpaperRepository {
  _FakePrismRepository(this.result);

  final Result<PrismWallpaper?> result;

  @override
  Future<Result<PrismWallpaper?>> fetchById(String id) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeWallhavenRepository implements WallhavenWallpaperRepository {
  _FakeWallhavenRepository(this.result);

  final Result<WallhavenWallpaper?> result;
  String? lastFetchedId;

  @override
  Future<Result<WallhavenWallpaper?>> fetchById(String id) async {
    lastFetchedId = id;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakePexelsRepository implements PexelsWallpaperRepository {
  _FakePexelsRepository(this.result);

  final Result<PexelsWallpaper?> result;

  @override
  Future<Result<PexelsWallpaper?>> fetchById(String id) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
