import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/palette_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wait_for_real_io.dart';
import '../../../../support/favourite_test_scope.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPaletteRepository extends Mock implements PaletteRepository {}

class _MockSetCount extends Mock implements GetWallpaperSetCountUseCase {}

const double _screenWidth = 390;
const double _screenHeight = 844;
const double _safeBottom = 34;

FeedItemEntity _prism() => const FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
    ),
    tags: <String>['space', 'stars'],
  ),
);

bool _isWallpaperLayer(Widget widget) =>
    (widget is CachedNetworkImage && widget.imageUrl.endsWith('thumb.jpg')) ||
    (widget is Image && (widget.image is FileImage || widget.image is ResizeImage));

Finder _wallpaper() => find.descendant(of: find.byType(ShakeOnce), matching: find.byWidgetPredicate(_isWallpaperLayer));

void main() {
  setUpFavouriteCounts();
  String? copied;
  late OfflineAssetFixture offlineAssets;

  setUp(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    offlineAssets = await OfflineAssetFixture.create();
    offlineAssets.install();
    copied = null;
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      return null;
    });
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await offlineAssets.dispose();
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  void useDeviceWithHomeIndicator(WidgetTester tester, {double side = 0}) {
    tester.view.physicalSize = const Size(_screenWidth * 3, _screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    final FakeViewPadding padding = FakeViewPadding(
      left: side * 3,
      top: 47 * 3,
      right: side * 3,
      bottom: _safeBottom * 3,
    );
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    WallpaperDetailLoaded state, {
    GlobalKey? boundary,
    ThemeData? theme,
    double side = 0,
  }) async {
    useDeviceWithHomeIndicator(tester, side: side);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: state.entity),
          ),
        ),
      ),
    );
    await tester.pump();
    for (int attempt = 0; attempt < 10 && find.byType(CachedNetworkImage).evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  final Finder accentSwatch = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent color');

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pumpAndSettle();
  }

  WallpaperDetailLoaded loaded({List<Color>? colors, Color? accent, bool colorChanged = false}) =>
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: colors,
        accent: accent,
        colorChanged: colorChanged,
      );

  group('colour variations', () {
    late FakeAppAnalytics analytics;
    final Result<PaletteEntity> twoColours = Result.success(
      const PaletteEntity(
        imageUrl: 'https://img.test/thumb.jpg',
        dominantColorValue: 0xFF008080,
        paletteColorValues: <int>[0xFF008080, 0xFFFF0000],
      ),
    );

    Future<WallpaperDetailBloc> pumpWithRealBloc(
      WidgetTester tester,
      Result<PaletteEntity> paletteResult, {
      bool requirePalette = true,
    }) async {
      useDeviceWithHomeIndicator(tester);
      final palette = _MockPaletteRepository();
      final views = _MockRecordViews();
      final setCount = _MockSetCount();
      when(() => setCount(any())).thenAnswer((_) async => Result.success<int?>(null));
      when(() => views(any())).thenAnswer((_) async => Result.success('7'));
      when(() => palette.generatePalette(any())).thenAnswer((_) async => paletteResult);
      analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      final prism = _MockPrismRepository();
      when(
        () => prism.fetchCanonicalById('prism-1'),
      ).thenAnswer((_) async => Result.success((_prism() as PrismFeedItem).wallpaper));
      final bloc = WallpaperDetailBloc(
        prism,
        _MockWallhavenRepository(),
        _MockPexelsRepository(),
        views,
        palette,
        setCount,
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: _prism()),
          ),
        ),
      );
      await tester.pump();
      await waitForRealIo(
        tester,
        () =>
            bloc.state is WallpaperDetailLoaded &&
            (!requirePalette || (bloc.state as WallpaperDetailLoaded).colors?.isNotEmpty == true),
        reason: 'the canonical wallpaper and requested palette to load',
        pumpDuration: const Duration(milliseconds: 16),
      );
      await waitForRealIo(
        tester,
        () => find
            .descendant(
              of: _wallpaper(),
              matching: find.byWidgetPredicate((widget) => widget is RawImage && widget.image != null),
            )
            .evaluate()
            .isNotEmpty,
        reason: 'the cached public thumbnail to decode into a real image',
        pumpDuration: const Duration(milliseconds: 16),
      );
      expect(
        bloc.state,
        isA<WallpaperDetailLoaded>().having(
          (state) => requirePalette ? state.colors : state.entity.id,
          'loaded wallpaper',
          requirePalette ? isNotEmpty : 'prism-1',
        ),
      );
      expect(
        find.descendant(of: _wallpaper(), matching: find.byType(RawImage)),
        findsAtLeastNWidgets(1),
        reason: 'the cached wallpaper image has decoded before color interactions',
      );
      return bloc;
    }

    ColorFilter? tintOnWallpaper(WidgetTester tester) {
      final List<ColorFiltered> filters = tester
          .widgetList<ColorFiltered>(find.descendant(of: find.byType(ShakeOnce), matching: find.byType(ColorFiltered)))
          .toList(growable: false);
      expect(filters, hasLength(lessThanOrEqualTo(1)), reason: 'the wallpaper has at most one hue tint');
      return filters.isEmpty ? null : filters.single.colorFilter;
    }

    List<AnalyticsActionValue> trackedActions() =>
        analytics.events.whereType<SurfaceActionTappedEvent>().map((event) => event.action).toList();

    testWidgets('a tap tints the wallpaper with the next palette colour and a long press brings the original back', (
      tester,
    ) async {
      final WallpaperDetailBloc bloc = await pumpWithRealBloc(tester, twoColours);
      expect(tintOnWallpaper(tester), isNull);

      await tester.tapAt(const Offset(195, 300));
      await tester.pump();
      await waitForRealIo(
        tester,
        () => bloc.state is WallpaperDetailLoaded && (bloc.state as WallpaperDetailLoaded).colorChanged,
        reason: 'the wallpaper accent selection to update',
      );
      expect((bloc.state as WallpaperDetailLoaded).accent, const Color(0xFFFF0000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tintOnWallpaper(tester), const ColorFilter.mode(Color(0xFFFF0000), BlendMode.hue));
      expect(trackedActions(), contains(AnalyticsActionValue.paletteCycleTapped));

      await tester.longPressAt(const Offset(195, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tintOnWallpaper(tester), isNull);
      expect(trackedActions(), contains(AnalyticsActionValue.paletteResetLongPressed));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('the first swatch shows the untouched thumbnail and each other swatch its colour', (tester) async {
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal, Colors.red], accent: Colors.teal));
      await openPanel(tester);
      final Finder originalSwatch = find.bySemanticsLabel('Original wallpaper colors');
      final Finder swatchRow = find.ancestor(of: originalSwatch, matching: find.byType(Row));
      Finder fixtureSwatches() => find.descendant(of: swatchRow, matching: find.byType(CachedNetworkImage));
      await waitForRealIo(
        tester,
        () => fixtureSwatches().evaluate().length == 3,
        reason: 'the three public thumbnail palette swatches to mount',
        pumpDuration: const Duration(milliseconds: 16),
      );

      final List<CachedNetworkImage> swatches = tester.widgetList<CachedNetworkImage>(fixtureSwatches()).toList();
      expect(swatches.map((swatch) => swatch.imageUrl), everyElement('https://img.test/thumb.jpg'));
      expect(swatches.map((swatch) => (swatch.color, swatch.colorBlendMode)), <Object>[
        (null, null),
        (Colors.teal, BlendMode.hue),
        (Colors.red, BlendMode.hue),
      ]);
    });

    testWidgets('a long press on a swatch copies its hex colour', (tester) async {
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
      await openPanel(tester);

      await tester.longPress(accentSwatch);
      await tester.pump();

      expect(copied, '#009688');
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('tapping a swatch plays a selection haptic, like a tap on the wallpaper', (tester) async {
      final List<Object?> played = <Object?>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) async {
        played.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), null));
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
      await openPanel(tester);

      await tester.tap(accentSwatch);
      await tester.tap(find.bySemanticsLabel('Original wallpaper colors'));

      expect(played, <String>['selection', 'selection']);
    });

    testWidgets('with no palette a tap leaves the original wallpaper', (tester) async {
      await pumpWithRealBloc(tester, Result.error(const NetworkFailure('x')), requirePalette: false);

      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tintOnWallpaper(tester), isNull);
      expect(trackedActions(), isNot(contains(AnalyticsActionValue.paletteCycleTapped)));
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
