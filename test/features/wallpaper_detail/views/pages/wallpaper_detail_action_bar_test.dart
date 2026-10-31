import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remix_credit_cubit.dart';
import 'package:Prism/features/wall_remix/biz/remixes_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/views/widgets/remix_action_button.dart';
import 'package:Prism/features/wall_remix/views/widgets/remix_credit_row.dart';
import 'package:Prism/features/wall_remix/views/widgets/remixes_section.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/coins_test_backend.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wait_for_real_io.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _DetailTestAssetStore extends OfflineAssetStore {
  _DetailTestAssetStore({required super.directory, required this.sourceFile});

  final File sourceFile;
  final Map<String, File> _retainedFiles = <String, File>{};

  @override
  Future<File?> lookup(String source) async => _retainedFiles[source];

  @override
  Future<File> retain(String source, {File? file}) async {
    final File retained = await super.retain(source, file: file);
    _retainedFiles[source] = retained;
    return retained;
  }

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    if (source == 'https://img.test/full.jpg' ||
        source == 'https://signed.test/prism-1' ||
        source == 'https://signed.test/preview-wall') {
      return sourceFile;
    }
    // A rendered colour variation is a local file that the set flow hands back to the store.
    if (source.startsWith('/') && File(source).existsSync()) return File(source);
    throw OfflineAssetUnavailableException(source);
  }
}

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockImageCacheManager extends Mock implements BaseCacheManager {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

class _RemixScreenRepository implements WallRemixRepository {
  _RemixScreenRepository(this.userBlockRepository, this.original, this.remixes);

  final UserBlockRepository userBlockRepository;
  final PrismWallpaper original;
  final List<PrismWallpaper> remixes;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => original;

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) async =>
      startAfterDocId == null ? remixes : const <PrismWallpaper>[];

  @override
  Future<BlockedCreators> loadBlockedCreators() => userBlockRepository.loadBlockedCreators();

  @override
  BlockedCreators get blockedCreators => userBlockRepository.blockedCreators;

  @override
  Stream<BlockedCreators> watchBlockedCreators() => userBlockRepository.watchBlockedCreators();
}

Future<void> _installEmptyOfflineAssetStore() async {
  final Directory directory = Directory.systemTemp.createTempSync('detail_empty_offline_assets');
  final _MockImageCacheManager cacheManager = _MockImageCacheManager();
  when(() => cacheManager.getFileFromCache(any())).thenAnswer((_) async => null);
  when(
    () => cacheManager.getFileStream(any(), withProgress: true),
  ).thenAnswer((_) => const Stream<FileResponse>.empty());
  final OfflineAssetStore store = OfflineAssetStore(
    directory: Directory('${directory.path}/retained'),
    cacheManager: cacheManager,
  );
  OfflineAssetStore.testOverride = store;
  PrismImageCache.testOverride = cacheManager;
  PrismFullImageCache.testOverride = cacheManager;
  addTearDown(() async {
    OfflineAssetStore.testOverride = null;
    PrismImageCache.testOverride = null;
    PrismFullImageCache.testOverride = null;
    if (directory.existsSync()) await directory.delete(recursive: true);
  });
}

bool _isNetworkThumbnail(Widget widget) {
  if (widget is! Image) return false;
  final ImageProvider provider = unwrapImageProvider(widget.image);
  return provider is CachedNetworkImageProvider && provider.url.endsWith('thumb.jpg');
}

Future<Finder> _waitForThumbnailFallback(WidgetTester tester) async {
  final Finder thumbnail = find.descendant(
    of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Wallpaper'),
    matching: find.byWidgetPredicate(_isNetworkThumbnail),
  );
  for (int attempt = 0; attempt < 40 && thumbnail.evaluate().isEmpty; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(thumbnail, findsOneWidget, reason: 'the empty offline lookup completes and mounts the network thumbnail');
  return thumbnail;
}

FeedItemEntity _prism({List<String> collections = const <String>[], int? width, int? height, List<String>? colors}) =>
    FeedItemEntity.prism(
      id: 'prism-1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'prism-1',
          source: WallpaperSource.prism,
          fullUrl: 'https://img.test/full.jpg',
          thumbnailUrl: 'https://img.test/thumb.jpg',
          authorName: 'Akshay',
          width: width,
          height: height,
        ),
        collections: collections,
        tags: const <String>['space', 'stars'],
        colors: colors,
      ),
    );

Future<List<double>> _hues(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData())!;
  return <double>[
    for (int x = 0; x < image.width; x++)
      HSVColor.fromColor(
        Color.fromARGB(255, data.getUint8(x * 4), data.getUint8(x * 4 + 1), data.getUint8(x * 4 + 2)),
      ).hue,
  ];
}

Future<Uint8List> _redAndBluePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(1, 0, 1, 1), Paint()..color = const Color(0xFF0000FF));
  final ui.Image image = await recorder.endRecording().toImage(2, 1);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  setUpFavouriteCounts();
  setUpAll(() {
    registerFallbackValue(const SelectAccentColor(color: Colors.black));
    registerFallbackValue(WallpaperAction.set);
  });

  late DownloadedWallIndex downloaded;
  late SettingsLocalDataSource settings;
  late OfflineAssetFixture offlineAssets;

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    downloaded = DownloadedWallIndex(settings);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<DownloadedWallIndex>(downloaded);
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<_MockWallpaperDetailBloc> pumpDetail(WidgetTester tester, WallpaperDetailLoaded state) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state.copyWith(panelCollapsed: false));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('Android shows a labelled Set action and icon actions with tooltips, on the details panel', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );

    expect(find.text('Set'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsOneWidget);
    expect(find.byType(DownloadButton), findsOneWidget);
    expect(find.byType(FavouriteWallpaperButton), findsOneWidget);
    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.byType(EditButton), findsOneWidget);
    for (final String tooltip in <String>['Set as wallpaper', 'Download', 'Favourite', 'Share', 'Edit']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    expect(
      tester.getRect(find.byType(SetWallpaperButton)).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Remix action hides when the live block snapshot adds the creator', (tester) async {
    final StreamController<BlockedCreators> blockedUids = StreamController<BlockedCreators>.broadcast(sync: true);
    addTearDown(blockedUids.close);
    BlockedCreators current = KnownBlockedCreators(const <String>{});
    final _MockUserBlockRepository blocks = _MockUserBlockRepository();
    when(() => blocks.watchBlockedCreators()).thenAnswer((_) => blockedUids.stream);
    when(() => blocks.loadBlockedCreators()).thenAnswer((_) async => KnownBlockedCreators(const <String>{}));
    when(() => blocks.blockedCreators).thenAnswer((_) => current);
    const PrismWallpaper original = PrismWallpaper(
      core: WallpaperCore(
        id: 'ai-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/full.jpg',
        thumbnailUrl: 'https://img.test/thumb.jpg',
        authorUid: 'creator-uid',
      ),
      review: true,
      firestoreDocumentId: 'ai-wall-doc',
      aiSource: WallAiSource(prompt: 'a koi pond'),
      remixCount: 1,
    );
    const FeedItemEntity entity = FeedItemEntity.prism(id: 'ai-wall', wallpaper: original);
    const PrismWallpaper remix = PrismWallpaper(
      core: WallpaperCore(
        id: 'remix-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/remix.jpg',
        thumbnailUrl: 'https://img.test/remix-thumb.jpg',
        authorName: 'Remixer',
        authorUid: 'remixer-uid',
      ),
      review: true,
      firestoreDocumentId: 'remix-wall-doc',
    );
    getIt.registerSingleton<WallRemixRepository>(_RemixScreenRepository(blocks, original, <PrismWallpaper>[remix]));
    getIt.registerFactory<RemixesCubit>(() => RemixesCubit(getIt<WallRemixRepository>()));
    getIt.registerFactory<RemixCreditCubit>(() => RemixCreditCubit(getIt<WallRemixRepository>()));
    await pumpDetail(
      tester,
      const WallpaperDetailLoaded(
        recommendations: RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(RemixActionButton), findsOneWidget);
    expect(find.text('Remixes'), findsOneWidget);

    current = KnownBlockedCreators(const <String>{'creator-uid'});
    blockedUids.add(current);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(RemixActionButton), findsNothing);
    expect(find.text('Remixes'), findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('the Remix action waits until the block list is known', (tester) async {
    final StreamController<BlockedCreators> blockedUids = StreamController<BlockedCreators>.broadcast(sync: true);
    addTearDown(blockedUids.close);
    BlockedCreators current = const UnknownBlockedCreators();
    final _MockUserBlockRepository blocks = _MockUserBlockRepository();
    when(() => blocks.watchBlockedCreators()).thenAnswer((_) => blockedUids.stream);
    when(() => blocks.loadBlockedCreators()).thenAnswer((_) async => const UnknownBlockedCreators());
    when(() => blocks.blockedCreators).thenAnswer((_) => current);
    const PrismWallpaper original = PrismWallpaper(
      core: WallpaperCore(
        id: 'ai-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/full.jpg',
        thumbnailUrl: 'https://img.test/thumb.jpg',
        authorUid: 'creator-uid',
      ),
      review: true,
      firestoreDocumentId: 'ai-wall-doc',
      aiSource: WallAiSource(prompt: 'a koi pond'),
      remixCount: 1,
    );
    const FeedItemEntity entity = FeedItemEntity.prism(id: 'ai-wall', wallpaper: original);
    const PrismWallpaper remix = PrismWallpaper(
      core: WallpaperCore(
        id: 'remix-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/remix.jpg',
        thumbnailUrl: 'https://img.test/remix-thumb.jpg',
        authorName: 'Remixer',
        authorUid: 'remixer-uid',
      ),
      review: true,
      firestoreDocumentId: 'remix-wall-doc',
    );
    getIt.registerSingleton<WallRemixRepository>(_RemixScreenRepository(blocks, original, <PrismWallpaper>[remix]));
    getIt.registerFactory<RemixesCubit>(() => RemixesCubit(getIt<WallRemixRepository>()));
    getIt.registerFactory<RemixCreditCubit>(() => RemixCreditCubit(getIt<WallRemixRepository>()));
    await pumpDetail(
      tester,
      const WallpaperDetailLoaded(
        recommendations: RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
      ),
    );
    blockedUids.add(const UnknownBlockedCreators());
    await tester.pump();
    await tester.pump();
    expect(find.byType(RemixActionButton), findsNothing);
    expect(find.text('Remixes'), findsNothing);

    current = KnownBlockedCreators(const <String>{});
    blockedUids.add(current);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(RemixActionButton), findsOneWidget);
    expect(find.text('Remixes'), findsOneWidget);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('remix rows stay hidden when the block list is unknown and the repository is missing', (tester) async {
    const PrismWallpaper wallpaper = PrismWallpaper(
      core: WallpaperCore(
        id: 'ai-remix-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/full.jpg',
        thumbnailUrl: 'https://img.test/thumb.jpg',
      ),
      review: true,
      firestoreDocumentId: 'ai-remix-wall-doc',
      aiSource: WallAiSource(prompt: 'a koi pond'),
      remixOf: 'source-wall-doc',
      remixCount: 1,
    );

    await pumpDetail(
      tester,
      const WallpaperDetailLoaded(
        recommendations: RecommendationState.exhausted(),
        entity: FeedItemEntity.prism(id: 'ai-remix-wall', wallpaper: wallpaper),
        paletteLoading: false,
      ),
    );
    await tester.pump();

    expect(find.byType(RemixCreditRow), findsNothing);
    expect(find.byType(RemixesSection), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('credit appears only for an AI child with a different original document', (tester) async {
    final StreamController<BlockedCreators> blockedUids = StreamController<BlockedCreators>.broadcast(sync: true);
    addTearDown(blockedUids.close);
    final BlockedCreators current = KnownBlockedCreators(const <String>{});
    final _MockUserBlockRepository blocks = _MockUserBlockRepository();
    when(() => blocks.watchBlockedCreators()).thenAnswer((_) => blockedUids.stream);
    when(() => blocks.loadBlockedCreators()).thenAnswer((_) async => KnownBlockedCreators(const <String>{}));
    when(() => blocks.blockedCreators).thenAnswer((_) => current);
    const PrismWallpaper original = PrismWallpaper(
      core: WallpaperCore(
        id: 'source-wall',
        source: WallpaperSource.prism,
        fullUrl: 'https://img.test/source.jpg',
        thumbnailUrl: 'https://img.test/source-thumb.jpg',
        authorName: 'Artist',
        authorUid: 'source-uid',
      ),
      title: 'Original',
      review: true,
      firestoreDocumentId: 'source-doc',
      aiSource: WallAiSource(prompt: 'a koi pond'),
    );
    getIt.registerSingleton<WallRemixRepository>(_RemixScreenRepository(blocks, original, const <PrismWallpaper>[]));
    getIt.registerFactory<RemixesCubit>(() => RemixesCubit(getIt<WallRemixRepository>()));
    getIt.registerFactory<RemixCreditCubit>(() => RemixCreditCubit(getIt<WallRemixRepository>()));

    Future<void> pumpChild({
      required String id,
      required String docId,
      required bool isAi,
      required String? remixOf,
    }) async {
      final PrismWallpaper child = PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://img.test/$id.jpg',
          thumbnailUrl: 'https://img.test/$id-thumb.jpg',
          authorUid: 'child-uid',
        ),
        review: true,
        firestoreDocumentId: docId,
        aiSource: isAi ? const WallAiSource(prompt: 'a koi pond') : null,
        remixOf: remixOf,
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: FeedItemEntity.prism(id: id, wallpaper: child),
          paletteLoading: false,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pumpChild(id: 'non-ai', docId: 'non-ai-doc', isAi: false, remixOf: 'source-doc');
    expect(find.textContaining('Remix of'), findsNothing);

    await pumpChild(id: 'self-remix', docId: 'self-doc', isAi: true, remixOf: 'self-doc');
    expect(find.textContaining('Remix of'), findsNothing);

    await pumpChild(id: 'valid-remix', docId: 'valid-doc', isAi: true, remixOf: 'source-doc');
    expect(find.text('Remix of Original by Artist'), findsOneWidget);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('the action icons are bare 24 point glyphs beside the 30 point heart', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );

    for (final Type button in <Type>[EditButton, ShareButton, DownloadButton]) {
      final IconThemeData icon = IconTheme.of(
        tester.element(find.descendant(of: find.byType(button), matching: find.byType(Icon)).first),
      );
      expect(icon.size, 24, reason: '$button');
      expect(
        tester.getSize(find.descendant(of: find.byType(button), matching: find.byType(CircularMenuButton))),
        const Size.square(50),
      );
    }
    final FavoriteIcon heart = tester.widget<FavoriteIcon>(find.byType(FavoriteIcon));
    expect(heart.iconSize, 30);
    expect(heart.tapTargetExtent, 53);
    expect(heart.iconColor, Theme.of(tester.element(find.byType(FavoriteIcon))).colorScheme.onSurface);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('inline actions precede details and the palette stays interactive', (tester) async {
    final bloc = await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
        colors: const [Colors.teal],
      ),
    );
    expect(
      tester.getRect(find.byType(WallpaperActionBar)).bottom,
      lessThan(tester.getRect(find.widgetWithText(ActionChip, 'space')).top),
    );
    final swatch = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Accent color');
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    verify(() => bloc.add(const SelectAccentColor(color: Colors.teal))).called(1);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('every button in the bar shrinks to 0.96 under the finger, not twice over', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    Finder glyph(Type button) => find.descendant(of: find.byType(button), matching: find.byType(Icon)).first;
    final Map<String, Finder> buttons = <String, Finder>{
      'Set': find.byType(SetWallpaperButton),
      'Download': glyph(DownloadButton),
      'Favourite': glyph(FavouriteWallpaperButton),
      'Share': glyph(ShareButton),
      'Edit': glyph(EditButton),
    };

    for (final MapEntry<String, Finder> button in buttons.entries) {
      final double width = tester.getSize(button.value).width;
      final TestGesture finger = await tester.startGesture(tester.getCenter(button.value));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final double shown = tester.getBottomRight(button.value).dx - tester.getTopLeft(button.value).dx;
      await finger.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(shown / width, closeTo(0.96, 0.002), reason: button.key);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS shows Save as the primary action and no Set action', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.byType(DownloadButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the preview action stays bound to its displayed wall when detail state changes underneath it', (
    tester,
  ) async {
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast(sync: true);
    addTearDown(states.close);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'test-user'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final WallpaperDetailLoaded first = WallpaperDetailLoaded(
      recommendations: const RecommendationState.exhausted(),
      entity: _prism(),
      paletteLoading: false,
      accent: Colors.teal,
      colorChanged: true,
    );
    whenListen(bloc, states.stream, initialState: first);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: first.entity),
        ),
      ),
    );

    final Future<SetWallpaperChoice?> Function(BuildContext, SetScreenRequest) originalOpener =
        SetWallpaperFlow.screenOpener;
    final List<SetScreenRequest> requests = <SetScreenRequest>[];
    final Completer<SetWallpaperChoice?> closed = Completer<SetWallpaperChoice?>();
    SetWallpaperFlow.screenOpener = (context, request) {
      requests.add(request);
      return closed.future;
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
    addTearDown(() {
      if (!closed.isCompleted) closed.complete(null);
    });

    await tester.tap(find.byTooltip(AppLocalizationsEn().wallpaperPreviewOnScreen));
    await waitForRealIo(tester, () => requests.isNotEmpty, reason: 'the Set screen opens for the displayed wall');

    final FeedItemEntity replacement = _prism().copyWith(id: 'prism-2');
    states.add(first.copyWith(entity: replacement, accent: Colors.blue));
    await tester.pump();

    expect(requests, hasLength(1));
    expect(requests.single.wallpaperId, 'prism-1');
    expect(requests.single.url, 'https://img.test/full.jpg');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('actions sit under the card: icons first, then the labelled primary at the end', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    final bool android = defaultTargetPlatform == TargetPlatform.android;
    final Finder primary = find.byType(android ? SetWallpaperButton : DownloadButton);
    final List<Finder> order = <Finder>[
      find.byType(FavouriteWallpaperButton),
      find.byType(ShareButton),
      find.byType(EditButton),
      if (android) find.byType(DownloadButton),
      primary,
    ];
    double left(Finder finder) => tester.getRect(finder).left;
    for (int i = 1; i < order.length; i++) {
      expect(left(order[i]), greaterThan(left(order[i - 1])), reason: '${order[i]}');
    }
    final Rect card = tester.getRect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Wallpaper'),
    );
    final Rect bar = tester.getRect(find.byType(WallpaperActionBar));
    expect(bar.top, card.bottom);
    expect(left(find.byType(FavouriteWallpaperButton)), card.left);
    expect(tester.getRect(primary).right, bar.right - 8);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('the share button gets the creator and the stored palette colours of a Prism wall', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(colors: const <String>['blue', 'pink']),
        paletteLoading: false,
      ),
    );

    final ShareButton share = tester.widget<ShareButton>(find.byType(ShareButton));
    expect(share.palette, const <Color>[Color(0xFF0066CC), Color(0xFFEA4C88)]);
    expect(share.creator, 'Akshay');
  });

  testWidgets('a wall in a premium collection is a premium download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(collections: <String>['space']),
        paletteLoading: false,
      ),
    );
    final DownloadButton premium = tester.widget<DownloadButton>(find.byType(DownloadButton));

    expect(premium.isPremiumContent, isTrue);
    expect(premium.contentId, 'prism-1');
  });

  testWidgets('a wall in a free collection is a normal download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(collections: <String>['Nature']),
        paletteLoading: false,
      ),
    );

    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).isPremiumContent, isFalse);
  });

  testWidgets('a colour picked on the colour bar tints the wallpaper with its hue', (tester) async {
    await _installEmptyOfflineAssetStore();
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
        colorChanged: true,
      ),
    );
    final Finder thumbnail = await _waitForThumbnailFallback(tester);
    final Finder tinted = find.ancestor(of: thumbnail, matching: find.byType(ColorFiltered));
    expect(tinted, findsOneWidget);
    expect(tester.widget<ColorFiltered>(tinted).colorFilter, const ColorFilter.mode(Colors.teal, BlendMode.hue));
  });

  testWidgets('the original wallpaper has no colour filter, even with an accent on the chrome', (tester) async {
    await _installEmptyOfflineAssetStore();
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
      ),
    );
    await _waitForThumbnailFallback(tester);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  group('colour variation as the source of Set, Download and Edit', () {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('detail_tint');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => directory.path,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null);
      directory.deleteSync(recursive: true);
    });

    List<Future<String> Function()?> preparers(WidgetTester tester) => <Future<String> Function()?>[
      tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).prepareSource,
      tester.widget<DownloadButton>(find.byType(DownloadButton)).variant?.prepare,
      tester.widget<EditButton>(find.byType(EditButton)).prepareSource,
    ];

    testWidgets('with a colour picked, each action renders this wallpaper in that hue', (tester) async {
      final File source = File('${directory.path}/wall.png');
      await tester.runAsync(() async => source.writeAsBytes(await _redAndBluePng()));
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'prism-1',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'prism-1',
            source: WallpaperSource.prism,
            fullUrl: source.path,
            thumbnailUrl: 'https://img.test/thumb.jpg',
          ),
        ),
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: entity,
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );

      for (final Future<String> Function()? prepare in preparers(tester)) {
        final List<double> hues = (await tester.runAsync(() async {
          final String path = await prepare!();
          return _hues(await File(path).readAsBytes());
        }))!;

        expect(hues, hasLength(2));
        expect(hues, everyElement(closeTo(120, 10)));
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS preview exposes Save to Photos with its current tinted variant', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'ios-preview-user'
        ..loggedIn = true;
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      final File source = File('${directory.path}/ios-preview-wall.png');
      await tester.runAsync(() async => source.writeAsBytes(await _redAndBluePng()));
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'ios-preview-wall',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'ios-preview-wall',
            source: WallpaperSource.prism,
            fullUrl: source.path,
            thumbnailUrl: '',
          ),
        ),
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: entity,
          paletteLoading: false,
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );

      await tester.tap(find.byTooltip(AppLocalizationsEn().wallpaperPreviewOnScreen));
      await tester.pumpAndSettle();

      final Finder preview = find.byType(ClockOverlay);
      final DownloadButton action = tester.widget<DownloadButton>(
        find.descendant(of: preview, matching: find.byType(DownloadButton)),
      );
      expect(action.label, AppLocalizationsEn().wallpaperSaveToPhotos);
      expect(action.link, source.path);
      expect(action.contentId, 'ios-preview-wall');
      expect(action.variant?.key, 'tint-00ff00');
      expect(action.variant?.prepareAuthorized, isNotNull);

      final List<double> hues = (await tester.runAsync(() async {
        final String path = await action.variant!.prepareAuthorized!(source.path);
        return _hues(await File(path).readAsBytes());
      }))!;
      expect(hues, hasLength(2));
      expect(hues, everyElement(closeTo(120, 10)));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an iOS guest opens the passive preview; its Save asks for sign-in', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );

      await tester.tap(find.byTooltip(AppLocalizationsEn().wallpaperPreviewOnScreen));
      await tester.pumpAndSettle();

      final Finder preview = find.byType(ClockOverlay);
      expect(preview, findsOneWidget);
      expect(find.text('Sign in to Prism'), findsNothing);
      for (final Type action in <Type>[FavouriteWallpaperButton, ShareButton, EditButton, SetWallpaperButton]) {
        expect(
          find.descendant(of: preview, matching: find.byType(action)),
          findsNothing,
          reason: '$action is absent',
        );
      }

      final Finder lockChoice = find.descendant(
        of: preview,
        matching: find.text(AppLocalizationsEn().wallpaperPreviewLock),
      );
      final Finder homeChoice = find.descendant(
        of: preview,
        matching: find.text(AppLocalizationsEn().wallpaperPreviewHome),
      );
      expect(lockChoice, findsOneWidget);
      expect(homeChoice, findsOneWidget);
      await tester.tap(homeChoice);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.descendant(of: preview, matching: find.byType(HomePreviewLayer)), findsOneWidget);
      await tester.tap(lockChoice);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.descendant(of: preview, matching: find.byType(LockPreviewLayer)), findsOneWidget);

      await tester.tap(find.descendant(of: preview, matching: find.byType(DownloadButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Sign in to Prism'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('with the original showing, each action uses the wallpaper as it is', (tester) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );

      expect(preparers(tester), everyElement(isNull));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('a detail download is acquired only after native save succeeds', () {
    const BasicMessageChannel<Object?> enqueueChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const BasicMessageChannel<Object?> listChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final CoinsTestBackend backend = CoinsTestBackend();
    late Directory directory;
    late File sourceFile;
    late List<DownloadRequest> requests;
    late List<Map<String, dynamic>> spendCalls;
    late Completer<void> nativeRequestStarted;
    late Completer<void> releaseNativeResponse;
    late Completer<void> saveFeedback;
    late Completer<void> failureToast;
    late bool nativeSaveSucceeds;
    late String failureMessage;

    setUp(() async {
      await backend.install();
      directory = Directory.systemTemp.createTempSync('detail_action_download');
      sourceFile = File('${directory.path}/source.png')..writeAsBytesSync(await _redAndBluePng());
      requests = <DownloadRequest>[];
      spendCalls = <Map<String, dynamic>>[];
      nativeRequestStarted = Completer<void>();
      releaseNativeResponse = Completer<void>();
      saveFeedback = Completer<void>();
      failureToast = Completer<void>();
      nativeSaveSucceeds = true;
      failureMessage = AppLocalizationsEn().economyAiDownloadFailed;
      CoinsService.instance.balanceNotifier.value = 100;
      backend.onCall = (String name, Map<String, dynamic> parameters) async {
        if (name == 'resolveOriginalAccess') {
          backend.originalCalls.add(parameters);
          if (parameters['mode'] == 'quote') {
            return <String, Object>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
          }
          return <String, Object>{
            'status': 'granted',
            'currentBalance': 100,
            'url': 'https://signed.test/prism-1',
            'expiresAt': DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          };
        }
        if (name == 'spendCoins') spendCalls.add(parameters);
        return <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 100,
          'currentBalance': 95,
          'delta': -5,
          'transactionId': 'detail_download_tx',
        };
      };
      OfflineAssetStore.testOverride = _DetailTestAssetStore(
        directory: Directory('${directory.path}/retained'),
        sourceFile: sourceFile,
      );
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pathChannel, (_) async => directory.path);
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        final Map<Object?, Object?> arguments = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>? ?? {},
        );
        final String expectedMessage = nativeSaveSucceeds
            ? wallpaperSavedMessage(AppLocalizationsEn())
            : failureMessage;
        if (call.method == 'showToast' && arguments['msg'] == expectedMessage) {
          if (!saveFeedback.isCompleted) saveFeedback.complete();
          if (!nativeSaveSucceeds && !failureToast.isCompleted) failureToast.complete();
        }
        return true;
      });
      messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, (message) async {
        final DownloadRequest request = (message! as List<Object?>).single! as DownloadRequest;
        requests.add(request);
        if (!nativeRequestStarted.isCompleted) nativeRequestStarted.complete();
        await releaseNativeResponse.future;
        if (!nativeSaveSucceeds) {
          return <Object?>[OperationResult(success: false, message: 'No space')];
        }
        final File savedFile = File('${directory.path}/${request.filenameWithoutExtension}.png');
        return <Object?>[OperationResult(success: true, message: savedFile.path)];
      });
      messenger.setMockDecodedMessageHandler<Object?>(
        listChannel,
        (_) async => <Object?>[DownloadItemsResult(success: true, items: <String>[])],
      );
      await settings.set('notificationPermissionPromptedV2', true);
    });

    tearDown(() async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, null);
      messenger.setMockDecodedMessageHandler<Object?>(listChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
      OfflineAssetStore.testOverride = null;
      app_state.prismUser = app_constants.createGuestPrismUser();
      await settings.delete('notificationPermissionPromptedV2');
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    Future<void> tapAndWait(WidgetTester tester, String identity, {required bool expectAcquired}) async {
      await tester.tap(find.byType(DownloadButton));
      await tester.pump();
      await waitForRealIo(
        tester,
        () => nativeRequestStarted.isCompleted,
        reason: 'the granted original to render its requested variation and enqueue native save',
        pumpDuration: const Duration(milliseconds: 16),
      );
      expect(nativeRequestStarted.isCompleted, isTrue, reason: 'the native download request starts');
      expect(requests, hasLength(1));
      final DownloadRequest request = requests.single;
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), hasLength(1));
      expect(backend.originalCalls.last['assetId'], 'prism-1');
      expect(backend.originalCalls.last['action'], 'download');
      if (nativeSaveSucceeds) {
        final List<int> bytes = (await tester.runAsync(
          () => request.isLocalFile ? File(request.link).readAsBytes() : sourceFile.readAsBytes(),
        ))!;
        await tester.runAsync(
          () => File('${directory.path}/${request.filenameWithoutExtension}.png').writeAsBytes(bytes),
        );
      }
      releaseNativeResponse.complete();
      await waitForRealIo(
        tester,
        () => saveFeedback.isCompleted,
        reason: 'native save to finish retaining and indexing the original before its localized feedback',
        pumpDuration: const Duration(milliseconds: 16),
      );
      expect(saveFeedback.isCompleted, isTrue, reason: 'the download flow reaches its success or failure feedback');
      if (!expectAcquired) expect(failureToast.isCompleted, isTrue);
      expect(downloaded.hasAcquired(link: identity, id: 'prism-1', source: WallpaperSource.prism), expectAcquired);
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('a tinted download saves valid prepared bytes and remembers only its variation identity', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );
      await tapAndWait(tester, 'full_tint-00ff00.png', expectAcquired: true);

      expect(requests, hasLength(1));
      expect(requests.single.filenameWithoutExtension, 'full_tint-00ff00');
      expect(requests.single.link, isNot('https://img.test/full.jpg'));
      expect(requests.single.isLocalFile, isTrue);
      final List<int> savedBytes = (await tester.runAsync(() => File(requests.single.link).readAsBytes()))!;
      final List<double> hues = (await tester.runAsync(() => _hues(Uint8List.fromList(savedBytes))))!;
      expect(hues, hasLength(2));
      expect(hues, everyElement(closeTo(120, 10)));
      expect(spendCalls, isEmpty, reason: 'Prism originals use the server original-access grant, not spendCoins');
      expect(
        downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
        isTrue,
      );
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      final String ownerId = app_state.prismUser.id;
      expect(ownerId, backend.userId);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'different-owner'
        ..loggedIn = true;
      expect(
        downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = ownerId
        ..loggedIn = true;
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'an original download saves only the granted URL and remembers the stable identity after native success',
      (tester) async {
        await pumpDetail(
          tester,
          WallpaperDetailLoaded(
            recommendations: const RecommendationState.exhausted(),
            entity: _prism(),
            paletteLoading: false,
          ),
        );
        await tapAndWait(tester, 'https://img.test/full.jpg', expectAcquired: true);

        expect(requests, hasLength(1));
        expect(requests.single.link, 'https://signed.test/prism-1');
        expect(requests.single.isLocalFile, isFalse);
        expect(spendCalls, isEmpty, reason: 'the original-access grant owns charging');
        expect(
          downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
          isTrue,
        );
        expect(
          downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
          isFalse,
        );
        final File? retained = await tester.runAsync<File?>(
          () => OfflineAssetStore.instance.lookup('https://img.test/full.jpg'),
        );
        expect(retained, isNotNull);
        final List<List<int>> retainedAndSourceBytes = (await tester.runAsync(() async {
          return <List<int>>[await retained!.readAsBytes(), await sourceFile.readAsBytes()];
        }))!;
        expect(retainedAndSourceBytes.first, retainedAndSourceBytes.last);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a failed native save never records an acquisition', (tester) async {
      nativeSaveSucceeds = false;
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
        ),
      );
      await tapAndWait(tester, 'https://img.test/full.jpg', expectAcquired: false);

      expect(requests, hasLength(1));
      expect(spendCalls, isEmpty, reason: 'the original-access grant owns charging');
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      expect(
        await tester.runAsync<File?>(() => OfflineAssetStore.instance.lookup('https://img.test/full.jpg')),
        isNull,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a missing original grant never enqueues the preview URL or records an acquisition', (tester) async {
      nativeSaveSucceeds = false;
      failureMessage = AppLocalizationsEn().economyCoinSpendFailed;
      backend.onCall = (name, parameters) async {
        backend.originalCalls.add(parameters);
        if (parameters['mode'] == 'quote') {
          return <String, Object>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
        }
        return <String, Object>{'status': 'unavailable'};
      };
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
        ),
      );
      await tester.tap(find.byType(DownloadButton));
      for (int i = 0; i < 100 && !failureToast.isCompleted; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(failureToast.isCompleted, isTrue);
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), hasLength(1));
      expect(requests, isEmpty);
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('a wall smaller than the screen shows the low resolution note', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(width: 100, height: 100),
        paletteLoading: false,
      ),
    );

    expect(find.text('Low resolution for your screen'), findsOneWidget);
  });

  testWidgets('a large wall shows no low resolution note', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(width: 9000, height: 9000),
        paletteLoading: false,
      ),
    );

    expect(find.text('Low resolution for your screen'), findsNothing);
  });

  testWidgets('the tags show as chips', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );

    expect(find.widgetWithText(ActionChip, 'space'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'stars'), findsOneWidget);
  });

  testWidgets('an exhausted discovery feed does not invent similar results', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('More like this'), findsNothing);
  });

  group('a preview opened with a picked colour sets the tinted source', () {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('detail_tint_preview');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => directory.path,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        (_) async => true,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      directory.deleteSync(recursive: true);
    });

    testWidgets('a preview opened with a picked colour opens the Set screen for this wall in that colour', (
      tester,
    ) async {
      final File source = File('${directory.path}/preview-wall.png');
      await tester.runAsync(() async => source.writeAsBytes(await _redAndBluePng()));
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'preview-wall',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'preview-wall',
            source: WallpaperSource.prism,
            fullUrl: source.path,
            thumbnailUrl: '',
          ),
        ),
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: entity,
          paletteLoading: false,
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );
      final Future<SetWallpaperChoice?> Function(BuildContext, SetScreenRequest) originalOpener =
          SetWallpaperFlow.screenOpener;
      final List<SetScreenRequest> requests = <SetScreenRequest>[];
      SetWallpaperFlow.screenOpener = (context, request) async {
        requests.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);

      await tester.tap(find.byTooltip(AppLocalizationsEn().wallpaperPreviewOnScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(requests, hasLength(1));
      expect(requests.single.wallpaperId, 'preview-wall');
      expect(requests.single.wallpaperSource, WallpaperSource.prism);
      expect(requests.single.url, source.path);
      expect(requests.single.tint, const Color(0xFF00FF00));
      expect(requests.single.onAdjust, isNotNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
