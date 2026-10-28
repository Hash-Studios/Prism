import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const String _previewUrl =
    'https://us-central1-prism-test.cloudfunctions.net/wallpaperPreview?id=p1&thumb=https%3A%2F%2Fimg%2Fthumb.jpg';

FeedItemEntity _prism({
  String id = 'p1',
  String fullUrl = 'https://img/full.jpg',
  String thumbnailUrl = 'https://img/thumb.jpg',
  List<String>? collections,
  bool isStreakExclusive = false,
  int? width,
  int? height,
}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      width: width,
      height: height,
    ),
    collections: collections,
    isStreakExclusive: isStreakExclusive,
  ),
);

class _MockDownloadedWallIndex extends Mock implements DownloadedWallIndex {}

class _OfflineAssetStoreWithKnownOriginal extends OfflineAssetStore {
  _OfflineAssetStoreWithKnownOriginal() : super(directory: Directory.systemTemp);

  @override
  Future<File?> lookup(String source) async =>
      source == '/tmp/guest-original.jpg' || source == '/tmp/owner-original.jpg' ? File(source) : null;

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async =>
      throw OfflineAssetUnavailableException(source);
}

class _SwitchingOfflineAssetStore extends OfflineAssetStore {
  _SwitchingOfflineAssetStore(this.onLookup) : super(directory: Directory.systemTemp);

  final void Function(String source) onLookup;

  @override
  Future<File?> lookup(String source) async {
    onLookup(source);
    return File(source);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    OfflineAssetStore.testOverride = null;
  });

  test('locked Prism wall shows the server preview, never the original', () {
    final display = WallpaperDisplaySource.of(_prism(), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot(contains('full.jpg')));
    expect(display.thumbnail, 'https://img/thumb.jpg');
  });

  test('unlocked Prism wall still gets the preview URL from the picker', () {
    final display = WallpaperDisplaySource.of(_prism(collections: <String>['Nature']), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot('https://img/full.jpg'));
  });

  test('premium Prism wall gets the preview URL, not the original', () {
    final display = WallpaperDisplaySource.of(_prism(collections: <String>['premium']), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot('https://img/full.jpg'));
  });

  test('streak-exclusive Prism wall is withheld: no full image, thumbnail is the best link', () {
    final display = WallpaperDisplaySource.of(_prism(isStreakExclusive: true), projectId: 'prism-test');
    expect(display.full, '');
    expect(display.bestLink, 'https://img/thumb.jpg');
  });

  test('drop wall withheld: no full image', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'd1',
      source: WallpaperSource.prism,
      thumbnail: 'https://img/d.jpg',
      withheld: true,
      projectId: 'prism-test',
    );
    expect(display.full, '');
  });

  test('Prism wall without a project id gets no preview and falls back to the thumbnail', () {
    final display = WallpaperDisplaySource.of(_prism(), projectId: '');
    expect(display.full, '');
    expect(display.bestLink, display.thumbnail);
    expect(display.bestLink, 'https://img/thumb.jpg');
  });

  test('Prism wall without Firebase initialization gets no preview URL', () {
    final display = WallpaperDisplaySource.of(_prism());

    expect(display.full, '');
    expect(display.bestLink, display.thumbnail);
  });

  test('Wallhaven wall keeps its public original', () {
    const entity = FeedItemEntity.wallhaven(
      id: 'w1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'w1',
          source: WallpaperSource.wallhaven,
          fullUrl: 'https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg',
          thumbnailUrl: 'https://th.wallhaven.cc/small/ab/ab1234.jpg',
        ),
      ),
    );
    final display = WallpaperDisplaySource.of(entity, projectId: 'prism-test');
    expect(display.full, 'https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg');
  });

  test('Pexels wall keeps its public original', () {
    const entity = FeedItemEntity.pexels(
      id: 'x1',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: 'x1',
          source: WallpaperSource.pexels,
          fullUrl: 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg',
          thumbnailUrl: 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg?w=400',
        ),
      ),
    );
    final display = WallpaperDisplaySource.of(entity, projectId: 'prism-test');
    expect(display.full, 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg');
  });

  test('bundled starter uses the exact local path returned by the trusted catalog', () async {
    final starters = await BundledWallpapers.load();
    final String trustedPath = starters.singleWhere((item) => item.id == 'starter-prism').fullUrl;
    final display = WallpaperDisplaySource.of(
      _prism(id: 'starter-prism', fullUrl: '/data/starter.jpg', thumbnailUrl: '/data/starter.jpg'),
      projectId: 'prism-test',
    );
    expect(display.full, trustedPath);
    expect(display.full, isNot('/data/starter.jpg'));
  });

  test('feed-supplied local paths are ignored even for a starter identity', () {
    final display = WallpaperDisplaySource.of(
      _prism(id: 'starter-prism', fullUrl: '/etc/passwd', thumbnailUrl: '/etc/passwd'),
      projectId: 'prism-test',
    );

    expect(display.full, endsWith('/prism-bundled-wallpapers/starter-prism.jpg'));
    expect(display.full, isNot('/etc/passwd'));
    expect(display.thumbnail, '');
  });

  test('a non-starter feed field never opens a local file', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'w2',
      source: WallpaperSource.wallhaven,
      thumbnail: 'https://th.wallhaven.cc/small/ab/ab1234.jpg',
      fullUrl: '/etc/passwd',
      projectId: 'prism-test',
    );
    expect(display.full, '');
  });

  test('a guest cannot use an original from the downloaded-wall index offline', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final index = _MockDownloadedWallIndex();
    when(
      () => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism),
    ).thenAnswer((_) async => File('/tmp/guest-original.jpg'));
    when(
      () => index.localFileFor(
        link: any(named: 'link'),
        id: any(named: 'id'),
        source: WallpaperSource.prism,
      ),
    ).thenAnswer((_) async => null);
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _OfflineAssetStoreWithKnownOriginal();

    final File? offline = await wallpaperOfflineCopy(
      const WallpaperDisplaySource(
        thumbnail: 'https://img/thumb.jpg',
        full: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );

    expect(offline, isNull);
    verifyNever(() => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism));
  });

  test('a signed-in owner may use its original from the downloaded-wall index offline', () async {
    final owner = app_constants.createGuestPrismUser()
      ..id = 'owner-1'
      ..loggedIn = true;
    app_state.prismUser = owner;
    final index = _MockDownloadedWallIndex();
    when(
      () => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism),
    ).thenAnswer((_) async => File('/tmp/owner-original.jpg'));
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _OfflineAssetStoreWithKnownOriginal();

    final File? offline = await wallpaperOfflineCopy(
      const WallpaperDisplaySource(
        thumbnail: 'https://img/thumb.jpg',
        full: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );

    expect(offline?.path, '/tmp/owner-original.jpg');
    verify(() => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism)).called(1);
  });

  test('Prism offline fallback never asks the index for a preview-linked original', () async {
    final owner = app_constants.createGuestPrismUser()
      ..id = 'owner-1'
      ..loggedIn = true;
    app_state.prismUser = owner;
    final index = _MockDownloadedWallIndex();
    when(() => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism)).thenAnswer((_) async => null);
    when(
      () => index.localFileFor(
        link: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    ).thenAnswer((_) async => File('/tmp/owner-original.jpg'));
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _OfflineAssetStoreWithKnownOriginal();

    final File? offline = await wallpaperOfflineCopy(
      const WallpaperDisplaySource(
        thumbnail: 'https://img/thumb.jpg',
        full: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );

    expect(offline, isNull);
    verifyNever(
      () => index.localFileFor(
        link: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );
  });

  test('a withheld Prism wall cannot use a previously downloaded original', () async {
    final owner = app_constants.createGuestPrismUser()
      ..id = 'owner-1'
      ..loggedIn = true;
    app_state.prismUser = owner;
    final index = _MockDownloadedWallIndex();
    when(
      () => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism),
    ).thenAnswer((_) async => File('/tmp/owner-original.jpg'));
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _OfflineAssetStoreWithKnownOriginal();

    final File? offline = await wallpaperOfflineCopy(
      WallpaperDisplaySource.forWall(
        id: 'p1',
        source: WallpaperSource.prism,
        thumbnail: 'https://img/thumb.jpg',
        fullUrl: 'https://img/original.jpg',
        withheld: true,
        projectId: 'prism-test',
      ),
    );

    expect(offline, isNull);
    verifyNever(() => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism));
  });

  test('a downloaded original is discarded if the signed-in owner changes during verification', () async {
    final owner = app_constants.createGuestPrismUser()
      ..id = 'owner-1'
      ..loggedIn = true;
    app_state.prismUser = owner;
    final index = _MockDownloadedWallIndex();
    when(
      () => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism),
    ).thenAnswer((_) async => File('/tmp/owner-original.jpg'));
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _SwitchingOfflineAssetStore((_) {
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    final File? offline = await wallpaperOfflineCopy(
      const WallpaperDisplaySource(
        thumbnail: 'https://img/thumb.jpg',
        full: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );

    expect(offline, isNull);
  });

  test('a downloaded original is discarded if the signed-in owner changes while the index resolves', () async {
    final owner = app_constants.createGuestPrismUser()
      ..id = 'owner-1'
      ..loggedIn = true;
    app_state.prismUser = owner;
    final index = _MockDownloadedWallIndex();
    when(() => index.localFileForIdentity(id: 'p1', source: WallpaperSource.prism)).thenAnswer((_) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      return File('/tmp/owner-original.jpg');
    });
    getIt.registerSingleton<DownloadedWallIndex>(index);
    OfflineAssetStore.testOverride = _OfflineAssetStoreWithKnownOriginal();

    final File? offline = await wallpaperOfflineCopy(
      const WallpaperDisplaySource(
        thumbnail: 'https://img/thumb.jpg',
        full: 'https://preview.test/wallpaperPreview?id=p1',
        id: 'p1',
        source: WallpaperSource.prism,
      ),
    );

    expect(offline, isNull);
  });

  test('Prism wall with no thumbnail has no preview and no best link', () {
    final display = WallpaperDisplaySource.of(_prism(thumbnailUrl: ''), projectId: 'prism-test');
    expect(display.thumbnail, '');
    expect(display.full, '');
    expect(display.bestLink, '');
  });

  test('Prism wall with its original repeated as thumbnail does not expose either URL', () {
    const String original = 'https://img/original.jpg';
    final display = WallpaperDisplaySource.of(
      _prism(fullUrl: original, thumbnailUrl: original),
      projectId: 'prism-test',
    );

    expect(display.thumbnail, '');
    expect(display.full, '');
    expect(display.bestLink, '');
  });

  test('a Prism preview URL is not built from a local thumbnail path', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'p1',
      source: WallpaperSource.prism,
      thumbnail: '/etc/passwd',
      fullUrl: 'https://img/original.jpg',
      projectId: 'prism-test',
    );

    expect(display.thumbnail, '');
    expect(display.full, '');
  });

  test('pixel size comes from the wall width and height', () {
    final display = WallpaperDisplaySource.of(_prism(width: 1440, height: 3200), projectId: 'prism-test');
    expect(display.pixelSize, const Size(1440, 3200));
  });

  group('sizedWallpaperImage', () {
    const ImageProvider image = AssetImage('assets/wall.jpg');
    ResizeImage sized(Size box, Size? wall) => sizedWallpaperImage(image, box, 3, wall) as ResizeImage;

    test('an unknown size decodes the wall whole, within 4096 on each side', () {
      final ResizeImage resized = sized(const Size(390, 844), null);
      expect((resized.width, resized.height, resized.policy), (4096, 4096, ResizeImagePolicy.fit));
      expect(resized.imageProvider, image);
    });

    test('a portrait wall in a portrait box follows the box width', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(1440, 3200));
      expect((resized.width, resized.height, resized.policy), (1170, 2600, ResizeImagePolicy.fit));
    });

    test('a landscape 4K wall in a portrait box follows the box height and is never enlarged', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(3840, 2160));
      expect((resized.width, resized.height, resized.policy), (3840, 2160, ResizeImagePolicy.fit));
    });

    test('an 8K wall is capped at 4096 on its long side', () {
      final ResizeImage resized = sized(const Size(2000, 1000), const Size(7680, 4320));
      expect((resized.width, resized.height, resized.policy), (4096, 2304, ResizeImagePolicy.fit));
    });

    test('an extreme aspect ratio keeps both decoded sides within the cap', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(1, 100000));
      expect((resized.width, resized.height, resized.policy), (1, 4096, ResizeImagePolicy.fit));
    });

    test('a non-finite source size falls back to the bounded decode', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(double.infinity, 3200));
      expect((resized.width, resized.height, resized.policy), (4096, 4096, ResizeImagePolicy.fit));
    });
  });
}
