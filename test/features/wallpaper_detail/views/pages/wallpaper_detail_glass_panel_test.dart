import 'dart:ui' as ui;

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
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
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
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';

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

bool _isWallpaperLayer(Widget widget) => widget is CachedNetworkImage && widget.imageUrl.endsWith('thumb.jpg');

Finder _wallpaper() => find.descendant(of: find.byType(ShakeOnce), matching: find.byWidgetPredicate(_isWallpaperLayer));

void main() {
  String? copied;

  setUp(() {
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
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  void useDeviceWithHomeIndicator(WidgetTester tester) {
    tester.view.physicalSize = const Size(_screenWidth * 3, _screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: _safeBottom * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: _safeBottom * 3);
    addTearDown(tester.view.reset);
  }

  Future<void> pumpDetail(WidgetTester tester, WallpaperDetailLoaded state, {GlobalKey? boundary}) async {
    useDeviceWithHomeIndicator(tester);
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: state.entity),
          ),
        ),
      ),
    );
    await tester.pump();
  }

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

  group('layout', () {
    testWidgets('the wallpaper fills the whole screen behind the panel and stays put when the panel opens', (
      tester,
    ) async {
      await pumpDetail(tester, loaded());

      expect(tester.getRect(_wallpaper().first), const Rect.fromLTWH(0, 0, _screenWidth, _screenHeight));

      await openPanel(tester);

      expect(tester.getRect(_wallpaper().first), const Rect.fromLTWH(0, 0, _screenWidth, _screenHeight));
    });

    testWidgets('the glass floats 10 px in from the sides and 10 px above the safe area when collapsed', (
      tester,
    ) async {
      await pumpDetail(tester, loaded());

      final Rect glass = tester.getRect(find.byType(PrismGlass));
      expect(glass.left, 10);
      expect(glass.right, _screenWidth - 10);
      expect(glass.bottom, _screenHeight - _safeBottom - 10);
      expect(glass.height, 36 + WallpaperActionBar.height);
    });

    testWidgets('the glass keeps its bottom edge and grows to the panel height while the panel slides open', (
      tester,
    ) async {
      await pumpDetail(tester, loaded());
      final Rect collapsed = tester.getRect(find.byType(PrismGlass));

      await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final Rect sliding = tester.getRect(find.byType(PrismGlass));
      await tester.pumpAndSettle();
      final Rect open = tester.getRect(find.byType(PrismGlass));

      expect(sliding.bottom, collapsed.bottom);
      expect(sliding.height, greaterThan(collapsed.height));
      expect(sliding.height, lessThan(open.height));
      expect(open.bottom, collapsed.bottom);
      expect(open.left, 10);
      expect(open.right, _screenWidth - 10);
      expect(open.height, closeTo(_screenHeight * 0.55, 0.01));
    });

    testWidgets('the glass is painted with four round corners, whether the dock is closed or open', (tester) async {
      final GlobalKey boundary = GlobalKey();
      await pumpDetail(tester, loaded(), boundary: boundary);

      Future<void> expectRoundCorners(Rect glass) async {
        final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image image = (await tester.runAsync(() => render.toImage()))!;
        final ByteData? pixels = await tester.runAsync<ByteData?>(() => image.toByteData());
        int pixelAt(double x, double y) => pixels!.getUint32(((y.toInt() * image.width) + x.toInt()) * 4);

        final int screen = pixelAt(2, glass.center.dy);
        expect(pixelAt(glass.left + 2, glass.top + 2), screen, reason: 'top left corner is cut round');
        expect(pixelAt(glass.right - 3, glass.top + 2), screen, reason: 'top right corner is cut round');
        expect(pixelAt(glass.left + 2, glass.bottom - 2), screen, reason: 'bottom left corner is cut round');
        expect(pixelAt(glass.right - 3, glass.bottom - 2), screen, reason: 'bottom right corner is cut round');
        expect(pixelAt(glass.center.dx, glass.bottom - 3), isNot(screen), reason: 'the glass reaches its bottom edge');
        expect(pixelAt(glass.center.dx, glass.top + 3), isNot(screen), reason: 'the glass reaches its top edge');
      }

      await expectRoundCorners(tester.getRect(find.byType(PrismGlass)));
      await openPanel(tester);
      await expectRoundCorners(tester.getRect(find.byType(PrismGlass)));
    });

    testWidgets('the action bar sits on the glass and can be tapped while the panel is collapsed', (tester) async {
      await pumpDetail(tester, loaded());

      final Rect glass = tester.getRect(find.byType(PrismGlass));
      final Rect actionBar = tester.getRect(find.byType(WallpaperActionBar));
      expect(actionBar.bottom, glass.bottom);
      expect(actionBar.left, greaterThanOrEqualTo(glass.left));
      expect(actionBar.right, lessThanOrEqualTo(glass.right));
      expect(glass.top, lessThan(actionBar.top));
      expect(find.byType(SetWallpaperButton).hitTestable(), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('swiping up on the wallpaper opens the panel', (tester) async {
      await pumpDetail(tester, loaded());

      await tester.drag(_wallpaper().first, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PrismGlass)).height, closeTo(_screenHeight * 0.55, 0.01));
    });

    testWidgets('the glass tint grows stronger as the panel opens, so the text on it stays readable', (tester) async {
      await pumpDetail(tester, loaded());
      final double collapsed = tester.widget<PrismGlass>(find.byType(PrismGlass)).glassColor!.a;

      await openPanel(tester);
      final double open = tester.widget<PrismGlass>(find.byType(PrismGlass)).glassColor!.a;

      expect(open, greaterThan(collapsed));
    });
  });

  group('colour variations', () {
    late FakeAppAnalytics analytics;
    final Result<PaletteEntity> twoColours = Result.success(
      const PaletteEntity(
        imageUrl: 'https://img.test/thumb.jpg',
        dominantColorValue: 0xFF008080,
        paletteColorValues: <int>[0xFF008080, 0xFFFF0000],
      ),
    );

    Future<void> pumpWithRealBloc(WidgetTester tester, Result<PaletteEntity> paletteResult) async {
      useDeviceWithHomeIndicator(tester);
      final palette = _MockPaletteRepository();
      final views = _MockRecordViews();
      final setCount = _MockSetCount();
      when(() => setCount(any())).thenAnswer((_) async => Result.success<int?>(null));
      when(() => views(any())).thenAnswer((_) async => Result.success('7'));
      when(() => palette.generatePalette(any())).thenAnswer((_) async => paletteResult);
      analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      final bloc = WallpaperDetailBloc(
        _MockPrismRepository(),
        _MockWallhavenRepository(),
        _MockPexelsRepository(),
        views,
        palette,
        setCount,
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: _prism()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    ColorFilter? tintOnWallpaper(WidgetTester tester) {
      final Finder tinted = find.ancestor(of: _wallpaper(), matching: find.byType(ColorFiltered));
      return tinted.evaluate().isEmpty ? null : tester.widget<ColorFiltered>(tinted).colorFilter;
    }

    List<AnalyticsActionValue> trackedActions() =>
        analytics.events.whereType<SurfaceActionTappedEvent>().map((event) => event.action).toList();

    testWidgets('a tap tints the wallpaper with the next palette colour and a long press brings the original back', (
      tester,
    ) async {
      await pumpWithRealBloc(tester, twoColours);
      expect(tintOnWallpaper(tester), isNull);

      await tester.tapAt(const Offset(195, 300));
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

    testWidgets('each swatch shows the wallpaper thumbnail tinted with its colour, the first one untouched', (
      tester,
    ) async {
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal, Colors.red], accent: Colors.teal));
      await openPanel(tester);

      final List<CachedNetworkImage> swatches = tester
          .widgetList<CachedNetworkImage>(
            find.byWidgetPredicate((w) => w is CachedNetworkImage && w.memCacheWidth == 240),
          )
          .toList();

      expect(swatches.map((swatch) => (swatch.imageUrl, swatch.color, swatch.colorBlendMode)), <Object>[
        ('https://img.test/thumb.jpg', null, null),
        ('https://img.test/thumb.jpg', Colors.teal, BlendMode.hue),
        ('https://img.test/thumb.jpg', Colors.red, BlendMode.hue),
      ]);
    });

    testWidgets('a long press on a swatch copies its hex colour', (tester) async {
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
      await openPanel(tester);

      await tester.longPress(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Accent color'),
      );
      await tester.pump();

      expect(copied, '#009688');
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('with no palette a tap leaves the original wallpaper', (tester) async {
      await pumpWithRealBloc(tester, Result.error(const NetworkFailure('x')));

      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tintOnWallpaper(tester), isNull);
      expect(trackedActions(), isNot(contains(AnalyticsActionValue.paletteCycleTapped)));
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
