import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'support/fav_fixtures.dart';
import '../../support/favourite_test_scope.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  setUpFavouriteCounts();
  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late FavouriteWallsBloc bloc;

  /// Built inside the test body so the bloc runs on the fake-async clock the tester pumps.
  FavouriteWallsBloc createBloc() {
    bloc = FavouriteWallsBloc(fetchUseCase, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
    addTearDown(bloc.close);
    return bloc;
  }

  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = _MockCacheManager();
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
  });

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpGrid(WidgetTester tester, {ThemeData? theme}) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: theme,
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
  }

  Future<void> selectWithHold(WidgetTester tester, Finder target) async {
    await tester.tap(find.byTooltip('More favourites actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0 selected'), findsOneWidget);
    await tester.longPress(target);
  }

  List<String> recordHaptics(WidgetTester tester) {
    const MethodChannel channel = MethodChannel('prism/haptics');
    final bool wasEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    final List<String> haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      PrismHaptics.enabled = wasEnabled;
    });
    return haptics;
  }

  testWidgets('shows loading cards until the favourites arrive, then the empty state', (tester) async {
    final Completer<Result<List<FavouriteWallEntity>>> pending = Completer<Result<List<FavouriteWallEntity>>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => pending.future);
    createBloc();

    await pumpGrid(tester);
    await tester.pump();

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);

    pending.complete(Result.success(const <FavouriteWallEntity>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.widgetWithText(GlintState, 'No favourites yet'), findsOneWidget);
    expect(find.text('Tap the heart on a wallpaper to keep it here.'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
    verify(() => fetchUseCase(any())).called(1);
  });

  testWidgets('shows the grid straight away when the favourites are already loaded', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    createBloc();
    bloc.add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await tester.pump();
    await tester.pump();
    expect(bloc.state.status, LoadStatus.success);

    await pumpGrid(tester);

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GlintState), findsOneWidget);
  });

  testWidgets('shows an error with a retry when the favourites fail to load', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    createBloc();

    await pumpGrid(tester);
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(GlintState, "Couldn't load your favourites"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('with favourites', () {
    late _MockClearFavouriteWallsUseCase clearUseCase;
    late _MockToggleFavouriteWallUseCase toggleUseCase;

    FavouriteWallsBloc createBlocWith(List<FavouriteWallEntity> items) {
      clearUseCase = _MockClearFavouriteWallsUseCase();
      toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      registerFallbackValue(ToggleFavouriteWallParams(userId: 'user_1', wall: items.first, currentlyFavourited: false));
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> pumpLoaded(WidgetTester tester, {ThemeData? theme}) async {
      await pumpGrid(tester, theme: theme);
      await tester.pump();
      await tester.pump();
    }

    // Every theme must keep the chips, the count line and the search field readable on the page.
    const List<String> themeLabels = <String>['Frost White', 'Rose', 'Cotton Blue', 'Coffee', 'AMOLED'];

    ThemeData themeNamed(String label) {
      final PrismThemeOption option = <PrismThemeOption>[
        ...prismLightThemes,
        ...prismDarkThemes,
      ].firstWhere((PrismThemeOption o) => prismThemeDisplayName(o, AppLocalizationsEn()) == label);
      return withPrismAccent(option.theme, option.defaultAccentValue);
    }

    Color colorOf(WidgetTester tester, Finder text) =>
        tester.widget<RichText>(find.descendant(of: text, matching: find.byType(RichText))).text.style!.color!;

    for (final String label in themeLabels) {
      testWidgets('$label: the source chips and the count line read on the page', (tester) async {
        final ThemeData theme = themeNamed(label);
        createBlocWith(<FavouriteWallEntity>[prismFav('a', author: 'Ada'), pexelsFav('b', author: 'Grace')]);
        await pumpLoaded(tester, theme: theme);

        final Color page = theme.colorScheme.surface;
        final Color count = colorOf(tester, find.text('2 favourites'));
        final Color chip = colorOf(tester, find.text('Prism'));
        final Color chipFill = Color.alphaBlend(theme.colorScheme.onSurface.withValues(alpha: 0.06), page);

        expect(contrastRatio(Color.alphaBlend(count, page), page), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(chip, chipFill), greaterThanOrEqualTo(4.5));
        expect(tester.getSize(find.widgetWithText(PrismChip, 'Prism')).height, greaterThanOrEqualTo(44));
      });

      testWidgets('$label: the search field types in text that reads on the page', (tester) async {
        final ThemeData theme = themeNamed(label);
        createBlocWith(<FavouriteWallEntity>[prismFav('a', author: 'Ada'), pexelsFav('b', author: 'Grace')]);
        await pumpLoaded(tester, theme: theme);

        final Color page = theme.colorScheme.surface;
        final TextStyle typed = tester.widget<EditableText>(find.byType(EditableText)).style;
        final TextStyle hint = tester.widget<Text>(find.text('Search by creator or category')).style!;

        expect(typed.fontSize, 16);
        expect(typed.fontFamily, 'Proxima Nova');
        expect(hint.fontSize, greaterThanOrEqualTo(14));
        expect(hint.fontFamily, 'Proxima Nova');
        expect(contrastRatio(Color.alphaBlend(typed.color!, page), page), greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('at 2x text the source chips still fit their 48 px row', (tester) async {
      createBlocWith(<FavouriteWallEntity>[prismFav('a', author: 'Ada'), pexelsFav('b', author: 'Grace')]);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLoaded(tester);

      final RichText label = tester.widget<RichText>(
        find.descendant(of: find.widgetWithText(PrismChip, 'Prism'), matching: find.byType(RichText)),
      );

      expect(label.textScaler.scale(14), 28);
      expect(tester.getSize(find.widgetWithText(PrismChip, 'Prism')).height, lessThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter chips and search narrow the grid and clear filters restores it', (tester) async {
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
      ]);
      await pumpLoaded(tester);
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);

      await tester.tap(find.widgetWithText(PrismChip, 'Prism'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matching favourites'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);
    });

    testWidgets('long press selects, Remove sends one batched delete and Undo restores', (tester) async {
      final List<String> haptics = recordHaptics(tester);
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
        wallhavenFav('c', createdAt: DateTime.utc(2025)),
      ]);
      await pumpLoaded(tester);

      await selectWithHold(tester, find.bySemanticsLabel('Wallpaper by Ada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Wallpaper by Grace'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      haptics.clear();
      await tester.tap(find.bySemanticsLabel('Remove from favourites'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'b']);
      expect(bloc.state.items.map((wall) => wall.id), <String>['c']);
      expect(haptics, <String>['tap']);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed 2 favourites'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b', 'c']);
    });

    testWidgets('an unavailable favourite Remove emits one tap haptic and removes the wall', (tester) async {
      final List<String> haptics = recordHaptics(tester);
      createBlocWith(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]);
      await pumpLoaded(tester);
      tester.widget<FavouriteTileImage>(find.byType(FavouriteTileImage)).onUnavailable();
      await tester.pump();

      await tester.tap(find.widgetWithText(PrismButton, 'Remove'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a']);
      expect(bloc.state.items, isEmpty);
      expect(haptics, <String>['tap']);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed from favourites'), findsOneWidget);
    });

    testWidgets('legacy favourites explain themselves on tap and can be removed after a long press', (tester) async {
      createBlocWith(<FavouriteWallEntity>[legacyFav('old', author: 'Old Timer')]);
      final List<String> shown = <String>[];
      const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast') shown.add((call.arguments as Map)['msg'] as String);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(toastChannel, null));
      await pumpLoaded(tester);

      await tester.tap(find.byType(FavouriteTileImage));
      await tester.pump();
      expect(shown.single, contains('older version'));

      await selectWithHold(tester, find.byType(FavouriteTileImage));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove from favourites'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove from favourites'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items, isEmpty);
      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['old']);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed load with nothing cached shows an error with Retry', (tester) async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load your favourites"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(LoadingCards), findsNothing);
    });
  });

  group('toolbar tools', () {
    late _MockClearFavouriteWallsUseCase clearUseCase;
    late _MockToggleFavouriteWallUseCase toggleUseCase;
    late List<String> toasts;
    late List<MethodCall> shareCalls;
    late Completer<MethodCall> shareRequested;
    late Directory tempDir;
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    const MethodChannel shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      final cache = _MockCacheManager();
      CachedNetworkImageProvider.defaultCacheManager = cache;
      PrismImageCache.testOverride = cache;
      addTearDown(() => PrismImageCache.testOverride = null);
      when(
        () => cache.getFileStream(any(), withProgress: true),
      ).thenAnswer((_) => StreamController<FileResponse>().stream);
      toasts = <String>[];
      shareCalls = <MethodCall>[];
      shareRequested = Completer<MethodCall>();
      tempDir = Directory.systemTemp.createTempSync('fav_export_test');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
        return true;
      });
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        shareCalls.add(call);
        if (!shareRequested.isCompleted) shareRequested.complete(call);
        return 'shared';
      });
      final Directory documentsDir = Directory('${tempDir.path}/documents')..createSync();
      messenger.setMockMethodCallHandler(pathChannel, (call) async {
        return switch (call.method) {
          'getTemporaryDirectory' => tempDir.path,
          'getApplicationDocumentsDirectory' => documentsDir.path,
          _ => throw UnsupportedError('Unexpected path provider method: ${call.method}'),
        };
      });
    });

    tearDown(() {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(toastChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      tempDir.deleteSync(recursive: true);
    });

    FavouriteWallsBloc createToolsBloc(List<FavouriteWallEntity> items) {
      clearUseCase = _MockClearFavouriteWallsUseCase();
      toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      registerFallbackValue(ToggleFavouriteWallParams(userId: 'user_1', wall: items.first, currentlyFavourited: false));
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> pumpLoaded(WidgetTester tester) async {
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> openMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('More favourites actions'));
      await settle(tester);
      await tester.tap(find.text(item));
      await settle(tester);
    }

    testWidgets('selecting one favourite and tapping Set opens the Set screen', (tester) async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      final original = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (context, request) async {
        opened.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = original);
      createToolsBloc(<FavouriteWallEntity>[prismFav('prism')]);
      await pumpLoaded(tester);
      await selectWithHold(tester, find.byType(FavouriteTileImage));
      await tester.pump();

      await tester.tap(find.byType(SetWallpaperButton));
      await tester.pump();
      for (int i = 0; i < 80 && opened.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }

      expect(opened, hasLength(1));
      expect(opened.single.url, 'https://example.com/prism.jpg');
      expect(opened.single.thumbnailUrl, 'https://example.com/prism-thumb.jpg');
      expect(opened.single.onAdjust, isNotNull);
    });

    for (final wall in <FavouriteWallEntity>[
      prismFav('prism'),
      prismFav('starter-sunset'),
      const LegacyFavouriteWall(
        id: 'legacy-prism',
        source: WallpaperSource.prism,
        legacyPayload: <String, Object?>{'url': 'https://example.com/legacy.jpg'},
      ),
      pexelsFav('pexels'),
      wallhavenFav('wallhaven'),
      const LegacyFavouriteWall(
        id: 'unknown-remote',
        source: WallpaperSource.unknown,
        legacyPayload: <String, Object?>{
          'url': 'https://example.com/private.jpg',
          'thumb': 'https://example.com/thumb.jpg',
        },
      ),
      const LegacyFavouriteWall(
        id: 'downloaded-remote',
        source: WallpaperSource.downloaded,
        legacyPayload: <String, Object?>{'url': 'https://example.com/private.jpg'},
      ),
    ]) {
      testWidgets('selected Set keeps ${wall.id} identity', (tester) async {
        createToolsBloc(<FavouriteWallEntity>[wall]);
        await pumpLoaded(tester);
        await selectWithHold(tester, find.byType(FavouriteTileImage));
        await tester.pump();

        final button = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
        expect(button.wallpaperId, wall.id);
        expect(button.wallpaperSource, wall.source);
        expect(button.url, wall.fullUrl);
      });

      testWidgets('${wall.id} tile uses only permitted image fallback', (tester) async {
        createToolsBloc(<FavouriteWallEntity>[wall]);
        await pumpLoaded(tester);

        final image = tester.widget<FavouriteTileImage>(find.byType(FavouriteTileImage));
        expect(image.thumbnailUrl, wall.thumbnailUrl);
        expect(
          image.allowFullUrlFallback,
          wall.source == WallpaperSource.wallhaven ||
              wall.source == WallpaperSource.pexels ||
              wall.id == 'starter-sunset',
        );
      });
    }

    for (final path in <String>['/tmp/acquired.jpg', 'file:///tmp/acquired.jpg']) {
      testWidgets('unknown local copy keeps image fallback for $path', (tester) async {
        createToolsBloc(<FavouriteWallEntity>[
          LegacyFavouriteWall(
            id: 'local-copy',
            source: WallpaperSource.unknown,
            legacyPayload: <String, Object?>{'url': path},
          ),
        ]);
        await pumpLoaded(tester);

        final image = tester.widget<FavouriteTileImage>(find.byType(FavouriteTileImage));
        expect(image.allowFullUrlFallback, isTrue);
        expect(image.fullUrl, path);
      });
    }

    testWidgets('downloaded copy keeps image fallback', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        const LegacyFavouriteWall(
          id: 'downloaded-copy',
          source: WallpaperSource.downloaded,
          legacyPayload: <String, Object?>{'url': '/tmp/downloaded.jpg'},
        ),
      ]);
      await pumpLoaded(tester);

      expect(tester.widget<FavouriteTileImage>(find.byType(FavouriteTileImage)).allowFullUrlFallback, isTrue);
    });

    testWidgets('unknown remote sharing keeps a reference without the original URL', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        const LegacyFavouriteWall(
          id: 'unknown-remote',
          source: WallpaperSource.unknown,
          legacyPayload: <String, Object?>{
            'url': 'https://example.com/private.jpg',
            'thumb': 'https://example.com/thumb.jpg',
          },
        ),
      ]);
      await pumpLoaded(tester);
      await selectWithHold(tester, find.byType(FavouriteTileImage));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share'));
      await settle(tester);

      final Uri link = Uri.parse((shareCalls.single.arguments as Map)['text'] as String);
      expect(link.host, 'prismwalls.com');
      expect(link.queryParameters['id'], 'unknown-remote');
      expect(link.queryParameters['thumb'], isEmpty);
      expect(link.queryParameters, isNot(contains('url')));
    });

    testWidgets('the toolbar shows how many favourites there are', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a'), pexelsFav('b')]);
      await pumpLoaded(tester);

      expect(find.text('2 favourites'), findsOneWidget);
    });

    testWidgets('sharing mixed favourites replaces a starter local path with its public landing link', (tester) async {
      const localPath = '/tmp/prism-bundled-wallpapers/starter-sunset.jpg';
      const starter = PrismFavouriteWall(
        id: 'starter-sunset',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'starter-sunset',
            source: WallpaperSource.prism,
            fullUrl: localPath,
            thumbnailUrl: localPath,
            authorName: 'Prism',
          ),
        ),
      );
      createToolsBloc(<FavouriteWallEntity>[starter, prismFav('a', author: 'Ada')]);
      await pumpLoaded(tester);

      await selectWithHold(tester, find.bySemanticsLabel('Wallpaper by Prism'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Wallpaper by Ada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share'));
      await settle(tester);

      final String sharedText = (shareCalls.single.arguments as Map)['text'] as String;
      expect(sharedText, contains('https://prismwalls.com/'));
      final Uri prismLink = sharedText.split('\n').map(Uri.parse).firstWhere((uri) => uri.path == '/share');
      expect(prismLink.queryParameters['id'], 'a');
      expect(prismLink.queryParameters['source'], 'prism');
      expect(prismLink.queryParameters, isNot(contains('url')));
      expect(sharedText, isNot(contains('https://example.com/a.jpg')));
      expect(sharedText, isNot(contains(localPath)));
    });

    testWidgets('mixed sharing keeps external URLs but replaces legacy Prism originals', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        const LegacyFavouriteWall(
          id: 'legacy-prism',
          source: WallpaperSource.prism,
          legacyPayload: <String, Object?>{'url': 'https://example.com/private-original.jpg', 'photographer': 'Legacy'},
        ),
        pexelsFav('external', author: 'External'),
      ]);
      await pumpLoaded(tester);
      await selectWithHold(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey<String>('legacy-prism')),
          matching: find.byType(FavouriteTileImage),
        ),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Wallpaper by External'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share'));
      await settle(tester);

      final String text = (shareCalls.single.arguments as Map)['text'] as String;
      final Uri prismLink = Uri.parse(text.split('\n').first);
      expect(prismLink.host, 'prismwalls.com');
      expect(prismLink.queryParameters['id'], 'legacy-prism');
      expect(prismLink.queryParameters, isNot(contains('url')));
      expect(text, isNot(contains('private-original.jpg')));
      expect(text, contains('https://example.com/external.jpg'));
    });

    testWidgets('Clear all asks with the count, clears, and Undo restores the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        prismFav('a', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', createdAt: DateTime.utc(2025, 1, 2)),
      ]);
      await pumpLoaded(tester);

      await openMenu(tester, 'Clear all favourites');
      expect(find.text('Clear 2 favourites?'), findsOneWidget);
      expect(find.text('This removes them from your account.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      verifyNever(() => clearUseCase(any()));

      await openMenu(tester, 'Clear all favourites');
      await tester.tap(find.text('Clear all favourites'));
      await settle(tester);
      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'b']);
      expect(bloc.state.items, isEmpty);
      expect(find.text('Cleared 2 favourites'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b']);
    });

    testWidgets('a clear that fails shows an error and keeps the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('nope')));
      await pumpLoaded(tester);

      await openMenu(tester, 'Clear all favourites');
      await tester.tap(find.text('Clear all favourites'));
      await settle(tester);

      expect(toasts, contains("Couldn't clear favourites. Try again."));
      expect(find.text('Cleared 1 favourite'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed refresh with items on screen tells the user and keeps the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      await pumpLoaded(tester);
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      bloc.add(const FavouriteWallsEvent.refreshRequested());
      await tester.pump();
      await tester.pump();

      expect(bloc.state.status, LoadStatus.failure);
      expect(toasts, <String>["Couldn't refresh favourites. Showing your saved list."]);
      expect(find.bySemanticsLabel('Wallpaper by'), findsNothing);
      expect(find.text('1 favourite'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Export writes the JSON file and shares it', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace'),
      ]);
      await pumpLoaded(tester);

      final MethodCall? shared = await tester.runAsync(() async {
        await openMenu(tester, 'Export favourites');
        return shareRequested.future;
      });

      final List<File> written = tempDir.listSync().whereType<File>().toList();
      expect(written, hasLength(1));
      expect(written.single.path, endsWith('.json'));
      final Map<String, Object?> decoded = jsonDecode(written.single.readAsStringSync()) as Map<String, Object?>;
      expect(decoded['count'], 2);
      expect((decoded['favourites']! as List<Object?>).length, 2);
      expect(toasts, isEmpty);
      expect(shareCalls, isNotEmpty);
      expect(shared!.method, 'share');
      expect((shared.arguments as Map)['paths'], <String>[written.single.path]);
    });

    testWidgets('Export with no favourites says so and shares nothing', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      await pumpLoaded(tester);
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc.add(const FavouriteWallsEvent.synced(userId: 'user_1', items: <FavouriteWallEntity>[]));
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('More favourites actions'), findsNothing);
      expect(shareCalls, isEmpty);
    });
  });

  group('guest', () {
    setUp(() {
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    testWidgets('the first frame asks a guest to sign in', (tester) async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
      createBloc();
      await pumpGrid(tester);

      expect(find.byType(SignInPrompt), findsOneWidget);
      expect(find.text('Sign in to use favourites'), findsOneWidget);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('the guest banner Sign in emits one tap haptic', (tester) async {
      final List<String> haptics = recordHaptics(tester);
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(PrismButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(haptics, <String>['tap']);
      expect(find.text('Sign in to Prism'), findsOneWidget);
    });

    testWidgets('a guest with saved favourites sees the list and a banner that can be dismissed', (tester) async {
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.text('Sign in to keep them on every device'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Sign in to keep them on every device'), findsNothing);
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
    });
  });

  group('unavailable tile', () {
    testWidgets('an image that fails for good shows Unavailable and a one-tap remove', (tester) async {
      final cache = _MockCacheManager();
      CachedNetworkImageProvider.defaultCacheManager = cache;
      PrismImageCache.testOverride = cache;
      addTearDown(() => PrismImageCache.testOverride = null);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      when(
        () => cache.getFileStream(any(), withProgress: true),
      ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('Offline')));
      final clearUseCase = _MockClearFavouriteWallsUseCase();
      final toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);

      await pumpGrid(tester);
      for (int i = 0; i < 60 && find.text('Unavailable').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Unavailable'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a']);
      expect(find.byType(FavouriteTileImage), findsNothing);
    });
  });
}
