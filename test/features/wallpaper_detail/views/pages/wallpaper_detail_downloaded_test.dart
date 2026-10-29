import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/wait_for_real_io.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

FeedItemEntity _wallpaper({String thumbnailUrl = 'https://images.example/thumb.jpg'}) => FeedItemEntity.pexels(
  id: 'pexels-1',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'pexels-1',
      source: WallpaperSource.pexels,
      fullUrl: 'https://images.example/full.jpg',
      thumbnailUrl: thumbnailUrl,
    ),
  ),
);

Future<File> _writePreviewPng(Directory directory) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = Colors.teal);
  final ui.Image image = await recorder.endRecording().toImage(40, 80);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return File('${directory.path}/original.png')..writeAsBytesSync(bytes.buffer.asUint8List());
}

Future<void> _waitForImageDecode(WidgetTester tester, ImageProvider provider) async {
  final Completer<void> decoded = Completer<void>();
  await tester.runAsync(() async {
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!decoded.isCompleted) decoded.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!decoded.isCompleted) decoded.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  });
  for (var i = 0; i < 50 && !decoded.isCompleted; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(decoded.isCompleted, isTrue, reason: 'The retained local file images must finish decoding.');
  await decoded.future;
}

void main() {
  setUpFavouriteCounts();
  setUpAll(() {
    registerFallbackValue(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: File('unused')));
  });

  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpFileError(WidgetTester tester) async {
    for (var i = 0; i < 20 && find.text('Downloaded wallpaper is unavailable').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('local loading shows the file, back control, and passes its path to the bloc', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: const WallpaperDetailLoading());
    final file = File('${Directory.systemTemp.path}/downloaded-wallpaper-missing.jpg');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(unwrapImageProvider(image.image), isA<FileImage>());
    expect(image.errorBuilder, isNotNull);
    expect(find.byTooltip('Back'), findsOneWidget);
    await pumpFileError(tester);
    expect(find.text('Downloaded wallpaper is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    verify(
      () => bloc.add(LoadFromId(wallId: 'wall', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
  });

  testWidgets('a download opens at its own shape and keeps it when the wallpaper loads', (tester) async {
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    const FeedItemEntity wide = FeedItemEntity.pexels(
      id: 'pexels-1',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: 'pexels-1',
          source: WallpaperSource.pexels,
          fullUrl: 'https://images.example/full.jpg',
          thumbnailUrl: 'https://images.example/thumb.jpg',
          width: 1600,
          height: 900,
        ),
      ),
    );
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>();
    addTearDown(states.close);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, states.stream, initialState: const WallpaperDetailLoading());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            wallId: 'pexels-1',
            source: WallpaperSource.pexels,
            localFile: File('assets/images/prism.webp'),
            aspectRatio: 16 / 9,
            heroTag: 'download-1',
          ),
        ),
      ),
    );
    await tester.pump();
    final Size loading = tester.getSize(find.byType(WallpaperDetailHero));

    states.add(const WallpaperDetailLoaded(entity: wide, paletteLoading: false));
    await tester.pump();
    await tester.pump();

    expect(loading.width / loading.height, closeTo(16 / 9, 0.01));
    expect(tester.getSize(find.byType(WallpaperDetailHero)), loading);
  });

  testWidgets('a downloaded catalogue wallpaper asks for recommendations like any other visit', (tester) async {
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      Stream<WallpaperDetailState>.value(WallpaperDetailLoaded(entity: _wallpaper(), paletteLoading: false)),
      initialState: const WallpaperDetailLoading(),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            wallId: 'pexels-1',
            source: WallpaperSource.pexels,
            localFile: File('assets/images/prism.webp'),
          ),
        ),
      ),
    );
    await tester.pump();

    // The same request as a feed visit: the wallpaper's own category or tags decide what is related.
    verify(() => bloc.add(const LoadRecommendations())).called(1);
  });

  testWidgets('downloaded detail uses the local file for set, clock, and color swatches', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallpaper(),
        paletteLoading: false,
        colors: const [Colors.teal],
      ),
    );
    final file = File('assets/images/prism.webp');
    final router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );

    ImageProvider unwrap(ImageProvider provider) => provider is ResizeImage ? provider.imageProvider : provider;
    final localImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => unwrap(image.image))
        .whereType<FileImage>()
        .toList();
    expect(localImages.length, greaterThan(1));
    expect(localImages.every((image) => image.file.path == file.path), isTrue);
    expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).url, file.path);
    final List<SetScreenRequest> requests = <SetScreenRequest>[];
    final Future<SetWallpaperChoice?> Function(BuildContext, SetScreenRequest) originalOpener =
        SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      requests.add(request);
      return null;
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);

    await tester.tap(find.byTooltip('Preview on your screen'));
    await waitForRealIo(tester, () => requests.isNotEmpty, reason: 'the Set screen opens for the local file');
    expect(requests.single.url, file.path);
  });

  testWidgets('a deleted image in loaded detail shows an error without an image-stream exception', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallpaper(),
        paletteLoading: false,
        colors: const [Colors.teal],
      ),
    );
    final file = File('${Directory.systemTemp.path}/deleted-loaded-wallpaper.jpg');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels, localFile: file),
        ),
      ),
    );
    await pumpFileError(tester);

    expect(find.text('Downloaded wallpaper is unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded detail renders a retained original after the temporary image cache is empty', (tester) async {
    const String url = 'https://images.example/full.jpg';
    final _MockCacheManager fullCache = _MockCacheManager();
    final _MockCacheManager thumbnailCache = _MockCacheManager();
    when(() => fullCache.getFileFromCache(url)).thenAnswer((_) async => null);
    when(() => thumbnailCache.getFileFromCache(any())).thenAnswer((_) async => null);
    when(
      () => fullCache.getFileStream(any(), withProgress: any(named: 'withProgress')),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('Offline')));
    when(
      () => thumbnailCache.getFileStream(any(), withProgress: any(named: 'withProgress')),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('Offline')));
    final ({Directory root, OfflineAssetStore assets, File retained}) setup = (await tester.runAsync(() async {
      final Directory root = await Directory.systemTemp.createTemp('detail-retained-preview-');
      final File original = await _writePreviewPng(root);
      final OfflineAssetStore assets = OfflineAssetStore(
        directory: Directory('${root.path}/retained'),
        cacheManager: fullCache,
      );
      final File retained = await assets.retain(url, file: original);
      return (root: root, assets: assets, retained: retained);
    }))!;
    addTearDown(() async {
      OfflineAssetStore.testOverride = null;
      await tester.runAsync(() => setup.root.delete(recursive: true));
    });
    OfflineAssetStore.testOverride = setup.assets;
    PrismFullImageCache.testOverride = fullCache;
    PrismImageCache.testOverride = thumbnailCache;
    addTearDown(() {
      PrismFullImageCache.testOverride = null;
      PrismImageCache.testOverride = null;
    });
    final File resolvedByWallpaperService =
        await tester.runAsync(
              () => WallpaperService.resolveToLocalFile(
                url,
                allowNetwork: false,
                wallpaperId: 'pexels-1',
                wallpaperSource: WallpaperSource.pexels,
              ),
            )
            as File;
    expect(resolvedByWallpaperService.path, setup.retained.path);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallpaper(),
        paletteLoading: false,
        colors: const [Colors.teal, Colors.indigo],
        accent: Colors.teal,
        colorChanged: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels),
        ),
      ),
    );
    await waitForRealIo(
      tester,
      () =>
          find
              .byWidgetPredicate((Widget widget) {
                if (widget is! Image) return false;
                final ImageProvider provider = widget.image is ResizeImage
                    ? (widget.image as ResizeImage).imageProvider
                    : widget.image;
                return provider is FileImage && provider.file.path == setup.retained.path;
              })
              .evaluate()
              .length ==
          4,
      reason: 'the retained original and its three swatch images to appear',
    );
    await waitForRealIo(
      tester,
      () => !networkImageUrls(tester).contains(url),
      reason: 'the decoded retained original to replace the network picture',
    );
    expect(networkImageUrls(tester), isNot(contains(url)));
    final File? resolved = await tester.runAsync<File?>(() => setup.assets.lookup(url));
    expect(resolved?.path, setup.retained.path);
    Finder retainedImageFinder() => find.byWidgetPredicate((Widget widget) {
      if (widget is! Image) return false;
      final ImageProvider provider = widget.image is ResizeImage
          ? (widget.image as ResizeImage).imageProvider
          : widget.image;
      return provider is FileImage && provider.file.path == setup.retained.path;
    });
    for (var i = 0; i < 50 && retainedImageFinder().evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(retainedImageFinder(), findsNWidgets(4));

    final List<FileImage> displayedLocalImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((Image image) => image.image is ResizeImage ? (image.image as ResizeImage).imageProvider : image.image)
        .whereType<FileImage>()
        .toList(growable: false);
    final List<FileImage> retainedImages = displayedLocalImages
        .where((FileImage image) => image.file.path == setup.retained.path)
        .toList(growable: false);
    expect(retainedImages, hasLength(4));
    await _waitForImageDecode(tester, retainedImages.first);
    await tester.pump();
    // The card shows the retained original, not the network picture.
    expect(fileImagePaths(tester, within: find.byType(ShakeOnce)), contains(setup.retained.path));
    final List<Image> retainedImageWidgets = tester.widgetList<Image>(retainedImageFinder()).toList(growable: false);
    expect(retainedImageWidgets.map((Image image) => image.color).toList(), <Color?>[
      null,
      null,
      Colors.teal,
      Colors.indigo,
    ]);
    expect(retainedImageWidgets.map((Image image) => image.colorBlendMode).toList(), <BlendMode?>[
      null,
      null,
      BlendMode.hue,
      BlendMode.hue,
    ]);
    final List<Semantics> accentSwatches = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((Semantics semantics) => semantics.properties.label == 'Accent color')
        .toList(growable: false);
    expect(accentSwatches.map((Semantics semantics) => semantics.properties.selected), <bool?>[true, false]);
    verifyNever(() => fullCache.getSingleFile(any()));
    verifyNever(() => fullCache.getFileFromCache(any()));
    verifyNever(() => thumbnailCache.getSingleFile(any()));
    verifyNever(() => thumbnailCache.getFileFromCache(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted local file keeps metadata failures on detail instead of opening a broken bare screen', (
    tester,
  ) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable)),
      initialState: const WallpaperDetailLoading(),
    );
    final router = _MockStackRouter();
    final file = File('${Directory.systemTemp.path}/already-deleted-wallpaper.jpg');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    await tester.pump();

    verifyNever(() => router.replace(any()));
    expect(find.text('Couldn\'t load this wallpaper'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a valid downloaded file still falls back after metadata fails', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable)),
      initialState: const WallpaperDetailLoading(),
    );
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    await tester.pump();

    verify(() => router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file))).called(1);
  });

  testWidgets('a delayed failure from a covered detail route does not replace the active route', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    final states = StreamController<WallpaperDetailState>.broadcast();
    whenListen(bloc, states.stream, initialState: const WallpaperDetailLoading());
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final navigatorKey = GlobalKey<NavigatorState>();
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        navigatorKey: navigatorKey,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'a', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))));
    await tester.pumpAndSettle();
    states.add(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
    verifyNever(() => router.replace(any()));
    await states.close();
  });

  testWidgets('an error in one detail route does not replace another route', (tester) async {
    final firstBloc = _MockWallpaperDetailBloc();
    final secondBloc = _MockWallpaperDetailBloc();
    whenListen(firstBloc, const Stream<WallpaperDetailState>.empty(), initialState: const WallpaperDetailLoading());
    whenListen(
      secondBloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable)),
      initialState: const WallpaperDetailLoading(),
    );
    final blocs = <WallpaperDetailBloc>[firstBloc, secondBloc];
    getIt.registerFactory<WallpaperDetailBloc>(() => blocs.removeAt(0));
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Stack(
            children: [
              WrappedRoute<WallpaperDetailScreen>(
                child: WallpaperDetailScreen(wallId: 'first', source: WallpaperSource.pexels, localFile: file),
              ),
              WrappedRoute<WallpaperDetailScreen>(
                child: WallpaperDetailScreen(wallId: 'second', source: WallpaperSource.pexels, localFile: file),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    verify(() => router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file))).called(1);
    verify(
      () => firstBloc.add(LoadFromId(wallId: 'first', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
    verify(
      () => secondBloc.add(LoadFromId(wallId: 'second', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
  });
}
