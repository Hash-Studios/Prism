import 'dart:io' show SocketException;
import 'dart:io' as io;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
// ignore: depend_on_referenced_packages
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements File {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

void main() {
  late _MockCacheManager cache;
  late BaseCacheManager originalCache;
  late FileInfo image;
  const thumbnail = 'https://example.com/thumb.png';
  const full = 'https://example.com/full.png';

  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _MockCacheManager());

  setUp(() async {
    cache = _MockCacheManager();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    originalCache = CachedNetworkImageProvider.defaultCacheManager;
    CachedNetworkImageProvider.defaultCacheManager = cache;
    PrismImageCache.testOverride = cache;
    when(() => cache.removeFile(any())).thenAnswer((_) async {});
    final file = _MockFile();
    final bytes = await io.File('assets/images/ic_launcher.webp').readAsBytes();
    when(() => file.readAsBytes()).thenAnswer((_) async => bytes);
    image = FileInfo(file, FileSource.Online, DateTime(2100), full);
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    CachedNetworkImageProvider.defaultCacheManager = originalCache;
    PrismImageCache.testOverride = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  void respond(String url, {required bool success}) {
    when(() => cache.getFileStream(url, withProgress: true)).thenAnswer(
      (_) => success ? Stream<FileResponse>.value(image) : Stream<FileResponse>.error(const SocketException('Offline')),
    );
  }

  Future<void> settleImages(WidgetTester tester) async {
    for (var frame = 0; frame < 3; frame++) {
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpTile(WidgetTester tester, {String thumbnailUrl = thumbnail, String fullUrl = full}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 240,
          child: WallpaperTile(
            index: 0,
            item: PrismFeedItem(
              id: 'wall',
              wallpaper: PrismWallpaper(
                core: WallpaperCore(
                  id: 'wall',
                  source: WallpaperSource.prism,
                  thumbnailUrl: thumbnailUrl,
                  fullUrl: fullUrl,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
  }

  testWidgets('a failed thumbnail displays the available full wallpaper instead of grey', (tester) async {
    respond(thumbnail, success: false);
    respond(full, success: true);
    await pumpTile(tester);

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    verify(() => cache.getFileStream(full, withProgress: true)).called(1);
  });

  testWidgets('failed images offer retry and display the wallpaper once the connection recovers', (tester) async {
    respond(thumbnail, success: false);
    respond(full, success: false);
    await pumpTile(tester);

    expect(find.byTooltip('Retry image'), findsOneWidget);
    respond(thumbnail, success: true);
    await tester.tap(find.byTooltip('Retry image'));
    await tester.pump();
    await settleImages(tester);

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    expect(find.byTooltip('Retry image'), findsNothing);
    verify(() => cache.removeFile(thumbnail)).called(1);
    verify(() => cache.removeFile(full)).called(1);
  });

  testWidgets('a healthy thumbnail displays without downloading the full wallpaper', (tester) async {
    respond(thumbnail, success: true);
    await pumpTile(tester);

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    verifyNever(() => cache.getFileStream(full, withProgress: true));
  });

  testWidgets('a missing thumbnail loads the full wallpaper directly', (tester) async {
    respond(full, success: true);
    await pumpTile(tester, thumbnailUrl: '');

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    verifyNever(() => cache.getFileStream('', withProgress: true));
  });

  testWidgets('identical failed URLs are not retried automatically in a loop', (tester) async {
    respond(full, success: false);
    await pumpTile(tester, thumbnailUrl: full);

    expect(find.byTooltip('Retry image'), findsOneWidget);
    verify(() => cache.getFileStream(full, withProgress: true)).called(1);
  });

  testWidgets('carousel images fill their bounds even under loose stack constraints', (tester) async {
    respond(thumbnail, success: true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 160,
            child: Stack(
              children: [PrismImageTile(url: thumbnail, fallbackUrl: full)],
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    expect(tester.getSize(find.byType(RawImage)), const Size(320, 160));
  });

  testWidgets('Wall of the Day retry reloads the image without opening the wallpaper', (tester) async {
    respond(thumbnail, success: false);
    respond(full, success: false);
    final bloc = _MockWotdBloc();
    when(() => bloc.state).thenReturn(
      WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: const WallOfTheDayEntity(wallId: 'retry-wall', url: full, thumbnailUrl: thumbnail, photographer: 'Ana'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WotdBloc>.value(value: bloc, child: const WallOfTheDayCard()),
      ),
    );
    await settleImages(tester);
    expect(find.byTooltip('Retry image'), findsOneWidget);

    respond(thumbnail, success: true);
    await tester.tap(find.byTooltip('Retry image'));
    await settleImages(tester);

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    expect(find.byTooltip('Retry image'), findsNothing);
  });

  testWidgets('a failed image offers retry even when the tile has no fallback URL', (tester) async {
    respond(thumbnail, success: false);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 120, height: 240, child: PrismImageTile(url: thumbnail)),
      ),
    );
    await settleImages(tester);

    expect(find.byTooltip('Retry image'), findsOneWidget);
    respond(thumbnail, success: true);
    await tester.tap(find.byTooltip('Retry image'));
    await settleImages(tester);

    expect(find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null), findsOneWidget);
    expect(find.byTooltip('Retry image'), findsNothing);
  });

  testWidgets('an empty URL with no fallback stays a skeleton and offers no retry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 120, height: 240, child: PrismImageTile(url: '')),
      ),
    );
    await settleImages(tester);

    expect(find.byTooltip('Retry image'), findsNothing);
    expect(find.byType(PulseFill), findsOneWidget);
  });

  testWidgets('the decode sizes reach the image widget', (tester) async {
    respond(thumbnail, success: true);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 240,
          child: PrismImageTile(url: thumbnail, memCacheHeight: 300, memCacheWidth: 150),
        ),
      ),
    );

    final CachedNetworkImage image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.memCacheHeight, 300);
    expect(image.memCacheWidth, 150);
    expect(image.cacheManager, same(PrismImageCache.instance));
  });
}
