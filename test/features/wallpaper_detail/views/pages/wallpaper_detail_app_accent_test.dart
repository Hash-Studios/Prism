import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

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
    tags: <String>['space'],
  ),
);

WallpaperDetailLoaded _loaded({required List<Color> colors, required Color accent, bool colorChanged = false}) =>
    WallpaperDetailLoaded(
      recommendations: const RecommendationState.exhausted(),
      entity: _prism(),
      paletteLoading: false,
      colors: colors,
      accent: accent,
      colorChanged: colorChanged,
    );

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  late SettingsLocalDataSource settings;
  late _MockWallpaperDetailBloc detailBloc;
  late _MockThemeBloc themeBloc;
  late StreamController<WallpaperDetailState> detailStates;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(const ThemeEvent.started());
    registerFallbackValue(const SelectAccentColor(color: Colors.black));
  });

  setUp(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    offlineAssets = await OfflineAssetFixture.create();
    offlineAssets.install();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    detailBloc = _MockWallpaperDetailBloc();
    detailStates = StreamController<WallpaperDetailState>.broadcast();
    themeBloc = _MockThemeBloc();
    when(() => themeBloc.state).thenReturn(ThemeState.initial());
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await detailStates.close();
    await offlineAssets.dispose();
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, WallpaperDetailLoaded initial) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    whenListen(detailBloc, detailStates.stream, initialState: initial);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(colorScheme: const ColorScheme.light()),
        themeAnimationDuration: Duration.zero,
        home: BlocProvider<ThemeBloc>.value(
          value: themeBloc,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: detailBloc,
            child: WallpaperDetailScreen(entity: initial.entity),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final Finder useAsAppAccent = find.text('Use as app accent');
  final Finder paletteSwatch = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent color');

  Future<void> showPalette(WidgetTester tester) async {
    await tester.ensureVisible(find.bySemanticsLabel('Original wallpaper colors'));
    await tester.pump();
  }

  testWidgets('the app accent action is absent before a palette colour is selected', (tester) async {
    await pumpDetail(tester, _loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
    await showPalette(tester);

    expect(useAsAppAccent, findsNothing);
  });

  testWidgets('a palette colour with good contrast becomes the light app accent and turns match-system off', (
    tester,
  ) async {
    await pumpDetail(tester, _loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
    await showPalette(tester);

    await tester.tap(paletteSwatch);
    await tester.pump();
    verify(() => detailBloc.add(const SelectAccentColor(color: Colors.teal))).called(1);
    detailStates.add(_loaded(colors: const <Color>[Colors.teal], accent: Colors.teal, colorChanged: true));
    // The palette row resolves its offline preview before the action appears.
    await tester.pump(const Duration(milliseconds: 300));

    expect(useAsAppAccent, findsOneWidget);
    await tester.ensureVisible(useAsAppAccent);
    await tester.tap(useAsAppAccent);
    await tester.pump();

    verify(() => themeBloc.add(ThemeEvent.lightAccentChanged(accentColorValue: Colors.teal.toARGB32()))).called(1);
    expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isFalse);
    expect(analytics.events.whereType<AccentChangedEvent>().map((event) => event.color), <String>[Colors.teal.rgbHex]);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('the app accent action is absent while the light theme is Material You', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(
        light: const ThemeSelection(themeId: prismMaterialYouLightThemeId, accentColorValue: prismDefaultAccentValue),
        system: SystemColorSchemes(
          light: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
          dark: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC), brightness: Brightness.dark),
        ),
      ),
    );
    await pumpDetail(tester, _loaded(colors: const <Color>[Colors.teal], accent: Colors.teal));
    await showPalette(tester);

    await tester.tap(paletteSwatch);
    await tester.pump();
    detailStates.add(_loaded(colors: const <Color>[Colors.teal], accent: Colors.teal, colorChanged: true));
    await tester.pump(const Duration(milliseconds: 300));

    expect(useAsAppAccent, findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a palette colour that fails contrast on the surface does not change the accent', (tester) async {
    await pumpDetail(tester, _loaded(colors: const <Color>[Colors.white], accent: Colors.white));
    await showPalette(tester);

    await tester.tap(paletteSwatch);
    await tester.pump();
    detailStates.add(_loaded(colors: const <Color>[Colors.white], accent: Colors.white, colorChanged: true));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(useAsAppAccent);
    await tester.tap(useAsAppAccent);
    await tester.pump();

    verifyNever(() => themeBloc.add(any()));
    expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isTrue);
    expect(analytics.events.whereType<AccentChangedEvent>(), isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });
}
