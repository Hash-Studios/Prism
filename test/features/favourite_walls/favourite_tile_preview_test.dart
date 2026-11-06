// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/local.dart' as local;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _thumbnail = 'https://example.test/thumbnail.jpg';
const _original = 'https://example.test/original.jpg';

class _MockCacheManager extends Mock implements BaseCacheManager {}

final _imageStreams = <String, StreamController<FileResponse>>{};

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Center(child: SizedBox(width: 180, height: 360, child: child)),
);

CachedNetworkImage? _network(WidgetTester tester) {
  final Finder finder = find.byType(CachedNetworkImage);
  return finder.evaluate().isEmpty ? null : tester.widget<CachedNetworkImage>(finder.first);
}

/// The picture the tile shows. With [failPrimary], what it shows after its first network image fails.
Future<Widget?> _buildPreview(WidgetTester tester, FavouriteTileImage image, {bool failPrimary = false}) async {
  await tester.pumpWidget(_app(image));
  await tester.pump();
  final CachedNetworkImage? network = _network(tester);
  if (!failPrimary || network == null) return network;
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  _imageStreams[network.imageUrl]!.addError(Exception('Thumbnail failed'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  final Finder images = find.byType(CachedNetworkImage);
  return images.evaluate().length > 1 ? tester.widget<CachedNetworkImage>(images.last) : null;
}

void main() {
  late _MockCacheManager thumbs;
  late _MockCacheManager fulls;

  setUpAll(() => registerFallbackValue(''));

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _imageStreams.clear();
    thumbs = _MockCacheManager();
    fulls = _MockCacheManager();
    CachedNetworkImageProvider.defaultCacheManager = thumbs;
    PrismImageCache.testOverride = thumbs;
    PrismFullImageCache.testOverride = fulls;
    addTearDown(() async {
      for (final stream in _imageStreams.values) {
        await stream.close();
      }
      PrismImageCache.testOverride = null;
      PrismFullImageCache.testOverride = null;
    });
    when(() => thumbs.getFileStream(any(), withProgress: true)).thenAnswer(
      (invocation) => _imageStreams
          .putIfAbsent(invocation.positionalArguments.first as String, () => StreamController<FileResponse>.broadcast())
          .stream,
    );
    when(() => fulls.getFileFromCache(any())).thenAnswer((_) async => null);
  });

  testWidgets('external preview retains original fallback after thumbnail failure', (tester) async {
    final preview = await _buildPreview(
      tester,
      FavouriteTileImage(
        thumbnailUrl: _thumbnail,
        fullUrl: _original,
        allowFullUrlFallback: true,
        onUnavailable: () {},
      ),
      failPrimary: true,
    );

    expect(preview, isA<CachedNetworkImage>());
    expect((preview! as CachedNetworkImage).imageUrl, _original);
  });

  testWidgets('external preview retains original fallback with a missing thumbnail', (tester) async {
    final preview = await _buildPreview(
      tester,
      FavouriteTileImage(thumbnailUrl: '', fullUrl: _original, allowFullUrlFallback: true, onUnavailable: () {}),
    );

    expect(preview, isA<CachedNetworkImage>());
    expect((preview! as CachedNetworkImage).imageUrl, _original);
  });

  testWidgets('Prism preview uses the thumbnail and never falls back to its original on failure', (tester) async {
    var unavailable = 0;
    final image = FavouriteTileImage(thumbnailUrl: _thumbnail, fullUrl: _original, onUnavailable: () => unavailable++);

    final primary = await _buildPreview(tester, image);
    expect(primary, isA<CachedNetworkImage>());
    expect((primary! as CachedNetworkImage).imageUrl, _thumbnail);

    final failed = await _buildPreview(tester, image, failPrimary: true);
    expect(failed, isNot(isA<CachedNetworkImage>()));
    expect(find.text('Unavailable'), findsOneWidget);
    expect(unavailable, greaterThan(0));
  });

  for (final thumbnail in <String>['', '   ']) {
    testWidgets('Prism preview with missing thumbnail "$thumbnail" never loads the original', (tester) async {
      var unavailable = 0;
      final preview = await _buildPreview(
        tester,
        FavouriteTileImage(thumbnailUrl: thumbnail, fullUrl: _original, onUnavailable: () => unavailable++),
      );

      expect(preview, isNull);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(unavailable, greaterThan(0));
    });
  }

  group('full picture already on the device', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fav_tile_full');
      addTearDown(() => dir.deleteSync(recursive: true));
      // A 1x1 PNG.
      file = File('${dir.path}/full.png')
        ..writeAsBytesSync(<int>[
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
          0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
          0x44, 0xAE, 0x42, 0x60, 0x82,
        ]);
    });

    testWidgets('shows the cached full picture, decoded to the tile height, instead of the soft thumbnail', (
      tester,
    ) async {
      when(() => fulls.getFileFromCache(_original)).thenAnswer(
        (_) async => FileInfo(
          const local.LocalFileSystem().file(file.path),
          FileSource.Cache,
          DateTime.now().add(const Duration(days: 1)),
          _original,
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _app(
            FavouriteTileImage(
              thumbnailUrl: _thumbnail,
              fullUrl: _original,
              cachedFullUrl: _original,
              onUnavailable: () {},
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      expect(_network(tester), isNull);
      final Image full = tester.widget<Image>(find.byType(Image));
      expect(full.image, isA<ResizeImage>());
      final ResizeImage resized = full.image as ResizeImage;
      expect(resized.height, (360 * tester.view.devicePixelRatio).round());
      expect((resized.imageProvider as FileImage).file.path, file.path);
    });

    testWidgets('a missing thumbnail is not unavailable while a cached full picture can still load', (tester) async {
      final pending = Completer<FileInfo?>();
      when(() => fulls.getFileFromCache(_original)).thenAnswer((_) => pending.future);
      var unavailable = 0;
      await _buildPreview(
        tester,
        FavouriteTileImage(
          thumbnailUrl: '',
          fullUrl: _original,
          cachedFullUrl: _original,
          onUnavailable: () => unavailable++,
        ),
      );
      expect(unavailable, 0);
      pending.complete(
        FileInfo(
          const local.LocalFileSystem().file(file.path),
          FileSource.Cache,
          DateTime.now().add(const Duration(days: 1)),
          _original,
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
      expect(unavailable, 0);
    });

    for (final bool cacheFails in <bool>[false, true]) {
      testWidgets('reports a missing thumbnail after a cache ${cacheFails ? 'error' : 'miss'}', (tester) async {
        final pending = Completer<FileInfo?>();
        when(() => fulls.getFileFromCache(_original)).thenAnswer((_) => pending.future);
        var unavailable = 0;
        await _buildPreview(
          tester,
          FavouriteTileImage(
            thumbnailUrl: '',
            fullUrl: _original,
            cachedFullUrl: _original,
            onUnavailable: () => unavailable++,
          ),
        );
        expect(unavailable, 0);
        if (cacheFails) {
          pending.completeError(StateError('cache unavailable'));
        } else {
          pending.complete(null);
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        expect(find.text('Unavailable'), findsOneWidget);
        expect(unavailable, greaterThan(0));
        verifyNever(() => fulls.getSingleFile(any()));
      });
    }

    testWidgets('Prism looks up only the detail display derivative and never downloads it', (tester) async {
      final display = WallpaperDisplaySource.forWall(
        id: 'wall',
        source: WallpaperSource.prism,
        thumbnail: _thumbnail,
        fullUrl: _original,
        projectId: 'prism-test',
      );
      await _buildPreview(
        tester,
        FavouriteTileImage(
          thumbnailUrl: display.thumbnail,
          fullUrl: _original,
          cachedFullUrl: display.full,
          onUnavailable: () {},
        ),
      );
      expect(display.full, contains('/wallpaperPreview?'));
      verify(() => fulls.getFileFromCache(display.full)).called(1);
      verifyNever(() => fulls.getFileFromCache(_original));
      verifyNever(() => fulls.getSingleFile(any()));
      verifyNever(() => fulls.getFileStream(any(), withProgress: true));
      expect(_network(tester)?.imageUrl, _thumbnail);
    });

    testWidgets('a withheld wall drops its cached image and ignores an earlier lookup result', (tester) async {
      final pending = Completer<FileInfo?>();
      when(() => fulls.getFileFromCache(_original)).thenAnswer((_) => pending.future);
      await _buildPreview(
        tester,
        FavouriteTileImage(
          thumbnailUrl: _thumbnail,
          fullUrl: _original,
          cachedFullUrl: _original,
          onUnavailable: () {},
        ),
      );
      final withheld = WallpaperDisplaySource.forWall(
        id: 'exclusive',
        source: WallpaperSource.prism,
        thumbnail: _thumbnail,
        fullUrl: _original,
        projectId: 'prism-test',
        withheld: true,
      );
      expect(withheld.full, isEmpty);
      await _buildPreview(
        tester,
        FavouriteTileImage(
          thumbnailUrl: withheld.thumbnail,
          fullUrl: _original,
          cachedFullUrl: withheld.full,
          onUnavailable: () {},
        ),
      );
      pending.complete(
        FileInfo(
          const local.LocalFileSystem().file(file.path),
          FileSource.Cache,
          DateTime.now().add(const Duration(days: 1)),
          _original,
        ),
      );
      await tester.pump();
      expect(_network(tester)?.imageUrl, _thumbnail);
      expect(find.byType(LayoutBuilder), findsNothing);
      verifyNever(() => fulls.getFileFromCache(''));
    });

    testWidgets('never looks up the cache without a link, and keeps the thumbnail on a miss', (tester) async {
      await _buildPreview(
        tester,
        FavouriteTileImage(thumbnailUrl: _thumbnail, fullUrl: _original, onUnavailable: () {}),
      );
      verifyNever(() => fulls.getFileFromCache(any()));
      expect(_network(tester)?.imageUrl, _thumbnail);

      await _buildPreview(
        tester,
        FavouriteTileImage(
          thumbnailUrl: _thumbnail,
          fullUrl: _original,
          cachedFullUrl: _original,
          onUnavailable: () {},
        ),
      );
      verify(() => fulls.getFileFromCache(_original)).called(1);
      expect(_network(tester)?.imageUrl, _thumbnail);
    });
  });
}
