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
import 'package:Prism/theme/jam_icons_icons.dart';
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

    testWidgets('light themes tint the glass more than dark ones, closed and open, so dark icons stay readable', (
      tester,
    ) async {
      double alpha(WidgetTester tester) => tester.widget<PrismGlass>(find.byType(PrismGlass)).glassColor!.a;
      final List<(Brightness, double, double)> expected = <(Brightness, double, double)>[
        (Brightness.dark, 0.5, 0.6),
        (Brightness.light, 0.55, 0.7),
      ];
      for (final (Brightness brightness, double dock, double open) in expected) {
        await pumpDetail(tester, loaded(), theme: ThemeData(brightness: brightness));

        expect(alpha(tester), closeTo(dock, 0.001), reason: '$brightness closed');
        await openPanel(tester);
        expect(alpha(tester), closeTo(open, 0.001), reason: '$brightness open');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the glass and the action bar keep clear of a side safe area, the wallpaper does not', (tester) async {
      await pumpDetail(tester, loaded(), side: 44);

      final Rect glass = tester.getRect(find.byType(PrismGlass));
      expect(glass.left, 54);
      expect(glass.right, _screenWidth - 54);
      expect(tester.getRect(find.byType(WallpaperActionBar)).left, 54);
      expect(tester.getRect(find.byType(WallpaperActionBar)).right, _screenWidth - 54);
      expect(tester.getRect(_wallpaper().first), const Rect.fromLTWH(0, 0, _screenWidth, _screenHeight));

      await openPanel(tester);
      expect(tester.getRect(find.byType(PrismGlass)).left, 54);
      expect(tester.getRect(find.byType(PrismGlass)).right, _screenWidth - 54);
    });

    testWidgets('the Set pill and the swatches start on the same line as the panel text, 24 px inside the glass', (
      tester,
    ) async {
      await pumpDetail(tester, loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
      await openPanel(tester);

      final Rect glass = tester.getRect(find.byType(PrismGlass));
      final Rect swatch = tester.getRect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Original wallpaper colors'),
      );
      expect(tester.getRect(find.byType(SetWallpaperButton)).left, glass.left + 24);
      expect(swatch.left, glass.left + 24);
      expect(tester.getRect(find.text('Wallpaper by Akshay')).left, glass.left + 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    group('handle', () {
      testWidgets('one chevron turns over as the panel opens, and fades to 70 percent of the text colour', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          loaded(),
          theme: ThemeData(colorScheme: const ColorScheme.light(secondary: Colors.black)),
        );
        final Finder chevron = find.byIcon(JamIcons.chevron_up);
        double turn() => tester
            .widget<Transform>(find.ancestor(of: chevron, matching: find.byType(Transform)).first)
            .transform
            .storage[0];

        expect(chevron, findsOneWidget);
        expect(turn(), closeTo(1, 0.001));
        expect(tester.widget<Icon>(chevron).color!.a, closeTo(0.7, 0.001));

        await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final double midway = turn();
        await tester.pumpAndSettle();

        expect(midway, inExclusiveRange(-1, 1));
        expect(chevron, findsOneWidget);
        expect(turn(), closeTo(-1, 0.001));
      });

      testWidgets('its touch target is 96 by 48 and the dock stays 102 tall', (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await pumpDetail(tester, loaded());

        final Rect target = tester.getSemantics(find.bySemanticsLabel('Expand wallpaper details')).rect;
        expect(target.size, const Size(96, 48));
        expect(tester.getSize(find.byType(PrismGlass)).height, 36 + WallpaperActionBar.height);

        final Offset chevron = tester.getCenter(find.byIcon(JamIcons.chevron_up));
        await tester.tapAt(chevron + const Offset(40, 0));
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(PrismGlass)).height, closeTo(_screenHeight * 0.55, 0.01));
        semantics.dispose();
      });
    });

    testWidgets('panel content fades out over the 24 px above the action bar instead of ending in a hard edge', (
      tester,
    ) async {
      await pumpDetail(tester, loaded());
      await openPanel(tester);
      final Finder maskFinder = find.byWidgetPredicate((w) => w is ShaderMask && w.blendMode == BlendMode.dstIn);
      final Size size = tester.getSize(maskFinder);
      final Shader shader = tester.widget<ShaderMask>(maskFinder).shaderCallback(Offset.zero & size);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(Offset.zero & size, Paint()..shader = shader);
      final ui.Image image = (await tester.runAsync(
        () => recorder.endRecording().toImage(size.width.ceil(), size.height.ceil()),
      ))!;
      final ByteData pixels = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
      int alphaAt(double y) => pixels.getUint8((y.toInt() * image.width + 10) * 4 + 3);
      final double barTop = size.height - WallpaperActionBar.height;

      expect(alphaAt(barTop - 30), 255);
      expect(alphaAt(barTop - 12), inInclusiveRange(110, 145));
      expect(alphaAt(barTop - 1), lessThan(15));
      expect(alphaAt(barTop + 2), 0);
    });

    group('shadow', () {
      testWidgets('lifts the glass off the wallpaper below it and fades out before it reaches the area above', (
        tester,
      ) async {
        final GlobalKey boundary = GlobalKey();
        await pumpDetail(
          tester,
          loaded(),
          boundary: boundary,
          theme: ThemeData(brightness: Brightness.dark, primaryColor: const Color(0xFF808080)),
        );
        final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image image = (await tester.runAsync(() => render.toImage()))!;
        final ByteData pixels = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
        int redAt(double x, double y) => pixels.getUint8(((y.toInt() * image.width) + x.toInt()) * 4);
        final Rect glass = tester.getRect(find.byType(PrismGlass));
        final int wallpaper = redAt(2, 300);

        expect(redAt(glass.center.dx, glass.bottom + 4), lessThan(wallpaper - 20), reason: 'below the glass');
        expect(redAt(glass.center.dx, glass.top - 40), wallpaper, reason: 'well above it');
      });

      testWidgets('is painted around the glass only, so it never darkens what the glass blurs', (tester) async {
        await pumpDetail(tester, loaded());
        final ClipPath clip = tester.widget<ClipPath>(
          find.byWidgetPredicate((w) => w is ClipPath && w.child is DecoratedBox),
        );
        final Path outside = clip.clipper!.getClip(const Size(340, 102));

        expect(outside.contains(const Offset(170, 51)), isFalse, reason: 'inside the glass');
        expect(outside.contains(const Offset(170, 120)), isTrue, reason: 'below the glass');
        expect(outside.contains(const Offset(-20, 51)), isTrue, reason: 'beside the glass');
        expect(outside.contains(const Offset(4, 4)), isTrue, reason: 'in the rounded corner');
      });
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

      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent color'));
      await tester.tap(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Original wallpaper colors'),
      );

      expect(played, <String>['selection', 'selection']);
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
