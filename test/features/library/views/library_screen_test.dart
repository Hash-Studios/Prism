import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../support/fake_connectivity_service.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

class _LibraryRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('Root', builder: (_) => const SizedBox()),
    ),
    AutoRoute(path: '/library', page: LibraryRoute.page),
    AutoRoute(
      path: '/detail',
      page: PageInfo('Detail', builder: (_) => const SizedBox()),
    ),
  ];
}

const String _channelPrefix = 'dev.flutter.pigeon.Prism.PrismMediaHostApi';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppAnalytics analytics;
  late FakeConnectivityService connectivity;
  late FavouriteWallsBloc bloc;
  late _MockFetchFavouriteWallsUseCase fetch;

  setUpAll(() => registerFallbackValue(const FetchFavouriteWallsParams(userId: '')));

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    connectivity = FakeConnectivityService();
    getIt
      ..registerSingleton<ConnectivityService>(connectivity)
      ..registerSingleton<WallpaperHistoryStore>(WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore())))
      ..registerFactory<WallpaperHistoryBloc>(() => WallpaperHistoryBloc(getIt<WallpaperHistoryStore>()));
    fetch = _MockFetchFavouriteWallsUseCase();
    when(() => fetch(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      '$_channelPrefix.listDownloads',
      (message) async => PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[
        DownloadItemsResult(success: true, items: const <String>[]),
      ]),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      '$_channelPrefix.listDownloads',
      null,
    );
    await bloc.close();
    await connectivity.controller.close();
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  // The Downloads placeholders pulse forever, so pumpAndSettle would never finish.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpLibrary(
    WidgetTester tester, {
    LibraryTab initialTab = LibraryTab.favourites,
    Widget Function(Widget screen)? wrap,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Built inside the test body so the bloc runs on the fake-async clock the tester pumps.
    bloc = FavouriteWallsBloc(
      fetch,
      _MockToggleFavouriteWallUseCase(),
      _MockClearFavouriteWallsUseCase(),
      _MockSetFavouritePinUseCase(),
    );
    Widget home = BlocProvider<FavouriteWallsBloc>.value(
      value: bloc,
      child: LibraryScreen(initialTab: initialTab),
    );
    if (wrap != null) home = wrap(home);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: home,
      ),
    );
    await settle(tester);
  }

  Future<({_LibraryRouter router, DeepLinkDispatcher dispatcher})> pumpDeepLinkHost(WidgetTester tester) async {
    final router = _LibraryRouter();
    final dispatcher = DeepLinkDispatcher(router: router, whenReady: () async => true);
    addTearDown(dispatcher.dispose);
    addTearDown(router.dispose);
    bloc = FavouriteWallsBloc(
      fetch,
      _MockToggleFavouriteWallUseCase(),
      _MockClearFavouriteWallsUseCase(),
      _MockSetFavouritePinUseCase(),
    );
    await tester.pumpWidget(
      BlocProvider<FavouriteWallsBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      ),
    );
    await settle(tester);
    return (router: router, dispatcher: dispatcher);
  }

  Future<void> openLink(WidgetTester tester, DeepLinkDispatcher dispatcher, String link) async {
    final Future<DeepLinkDispatchResult> result = dispatcher.openUri(
      Uri.parse(link),
      source: DeepLinkSourceValue.appLinks,
    );
    await settle(tester);
    expect(await result, DeepLinkDispatchResult.navigated);
  }

  // The tab bar scrolls, so a tab past the right edge is brought into view before the tap.
  Future<void> tapTab(WidgetTester tester, String tab) async {
    await tester.ensureVisible(find.widgetWithText(Tab, tab));
    await tester.tap(find.widgetWithText(Tab, tab));
    await settle(tester);
  }

  int tabBarIndex(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  List<LibraryTabViewedEvent> tabEvents() => analytics.events.whereType<LibraryTabViewedEvent>().toList();

  List<String> tabNames() => tabEvents().map((event) => event.tab).toList();

  testWidgets('Android shows Favourites, Folders, Downloads and History tabs in that order', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('Library'), findsOneWidget);
    expect(tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.text), <String>[
      'Favourites',
      'Folders',
      'Downloads',
      'History',
    ]);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('iOS has no History tab, because it cannot set a wallpaper', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpLibrary(tester);

      expect(tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.text), <String>[
        'Favourites',
        'Folders',
        'Downloads',
      ]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('libraryTabs drops History when the device cannot set a wallpaper', () {
    expect(libraryTabs(canSetWallpaper: false), <LibraryTab>[
      LibraryTab.favourites,
      LibraryTab.folders,
      LibraryTab.downloads,
    ]);
    expect(libraryTabs(canSetWallpaper: true), LibraryTab.values);
  });

  testWidgets('opening tracks the initial tab once, and each later tab change is tracked', (tester) async {
    await pumpLibrary(tester);
    expect(tabNames(), <String>['favourites']);

    await tapTab(tester, 'Downloads');
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);

    await tapTab(tester, 'History');
    await settle(tester);
    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(tabNames(), <String>['favourites', 'downloads', 'history']);
    expect(tabEvents()[1].toWireParameters(), <String, Object?>{'tab': 'downloads'});
  });

  testWidgets('initialTab opens that tab and tracks it as the viewed tab', (tester) async {
    await pumpLibrary(tester, initialTab: LibraryTab.downloads);

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabNames(), <String>['downloads']);
  });

  testWidgets('Android initialTab history with an empty store shows the empty state and no clear button', (
    tester,
  ) async {
    await pumpLibrary(tester, initialTab: LibraryTab.history);

    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('library-clear-history')), findsNothing);
    expect(tabNames(), <String>['history']);
  });

  testWidgets('clearing history after confirming empties the list and tracks the count', (tester) async {
    await getIt<WallpaperHistoryStore>().record(
      AppliedWallpaper(
        id: '1',
        source: 'prism',
        wallpaperId: 'w1',
        thumbnailUrl: '/nope.jpg',
        fullUrl: 'https://example.com/w1.jpg',
        target: 'home',
        appliedAt: DateTime.now(),
      ),
    );
    await pumpLibrary(tester, initialTab: LibraryTab.history);
    expect(find.byType(AppliedWallpaperTile), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('library-clear-history')));
    await settle(tester);
    await tester.tap(find.text('Clear history'));
    await settle(tester);

    expect(find.text('No wallpapers yet'), findsOneWidget);
    final List<LibraryHistoryClearedEvent> cleared = analytics.events.whereType<LibraryHistoryClearedEvent>().toList();
    expect(cleared.map((event) => event.count), <int>[1]);
  });

  testWidgets('closing the clear sheet without confirming keeps the history item', (tester) async {
    await getIt<WallpaperHistoryStore>().record(
      AppliedWallpaper(
        id: '1',
        source: 'prism',
        wallpaperId: 'w1',
        thumbnailUrl: '/nope.jpg',
        fullUrl: 'https://example.com/w1.jpg',
        target: 'home',
        appliedAt: DateTime.now(),
      ),
    );
    await pumpLibrary(tester, initialTab: LibraryTab.history);

    await tester.tap(find.byKey(const ValueKey<String>('library-clear-history')));
    await settle(tester);
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    expect(find.byType(AppliedWallpaperTile), findsOneWidget);
  });

  testWidgets('the Folders tab without a FoldersBloc has no New folder button, and no tab shows an action here', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(find.byKey(const ValueKey<String>('library-new-folder')), findsNothing);

    await tapTab(tester, 'Folders');
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('library-new-folder')), findsNothing);
    expect(find.byKey(const ValueKey<String>('library-clear-history')), findsNothing);

    await tapTab(tester, 'Downloads');
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('library-new-folder')), findsNothing);
    expect(find.byKey(const ValueKey<String>('library-clear-history')), findsNothing);
  });

  // The expected colours come from the same helpers the screen uses, so the test catches a swapped colour.
  for (final String name in <String>['Frost White', 'AMOLED']) {
    testWidgets('$name: the selected tab label is the readable accent, the others the soft ink, both 15 px', (
      tester,
    ) async {
      final PrismThemeOption option = <PrismThemeOption>[
        ...prismLightThemes,
        ...prismDarkThemes,
      ].firstWhere((PrismThemeOption o) => prismThemeDisplayName(o, AppLocalizationsEn()) == name);
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await pumpLibrary(tester, theme: theme);

      TextStyle labelOf(String tab) => tester
          .widget<RichText>(find.descendant(of: find.widgetWithText(Tab, tab), matching: find.byType(RichText)))
          .text
          .style!;
      final TextStyle selected = labelOf('Favourites');
      final TextStyle unselected = labelOf('Downloads');

      expect(selected.color, prismReadableAccent(theme));
      expect(unselected.color, prismSoftInk(theme));
      expect(selected.fontSize, 15);
      expect(unselected.fontSize, 15);
    });
  }

  testWidgets('at 2.0 text scale the tab labels clamp to 1.5x and the tab bar keeps its height', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpLibrary(tester);

    double labelScale(String tab) => tester
        .widget<RichText>(find.descendant(of: find.widgetWithText(Tab, tab), matching: find.byType(RichText)))
        .textScaler
        .scale(15);

    expect(labelScale('Favourites'), 22.5);
    expect(labelScale('Downloads'), 22.5);
    expect(labelScale('History'), 22.5);
    expect(tester.getSize(find.byType(TabBar)).height, 48);
    expect(find.widgetWithText(Tab, 'Folders'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'History'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every icon button on each tab has a tooltip', (tester) async {
    await pumpLibrary(tester);

    for (final String tab in <String>['Favourites', 'Folders', 'Downloads', 'History']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await settle(tester);
      for (final PrismIconButton button in tester.widgetList<PrismIconButton>(find.byType(PrismIconButton))) {
        expect(button.tooltip.isNotEmpty, isTrue, reason: '$tab PrismIconButton');
      }
      for (final IconButton button in tester.widgetList<IconButton>(find.byType(IconButton))) {
        expect(button.tooltip?.isNotEmpty ?? false, isTrue, reason: '$tab IconButton');
      }
    }
  });

  for (final String tab in <String>['favourites', 'folders', 'downloads', 'history']) {
    testWidgets('prism://library?tab=$tab opens that tab on Android', (tester) async {
      final host = await pumpDeepLinkHost(tester);
      addTearDown(host.dispatcher.dispose);

      await openLink(tester, host.dispatcher, 'prism://library?tab=$tab');

      expect(host.router.topRoute.args, LibraryRouteArgs(initialTab: LibraryTab.values.byName(tab)));
      expect(tabBarIndex(tester), <String>['favourites', 'folders', 'downloads', 'history'].indexOf(tab));
    });
  }

  testWidgets('prism://wallpaper-history opens the History tab', (tester) async {
    final host = await pumpDeepLinkHost(tester);

    await openLink(tester, host.dispatcher, 'prism://wallpaper-history');

    expect(host.router.topRoute.args, const LibraryRouteArgs(initialTab: LibraryTab.history));
    expect(tabBarIndex(tester), 3);
  });

  testWidgets('on iOS, prism://library?tab=history falls back to Favourites and tab=downloads is index 2', (
    tester,
  ) async {
    final host = await pumpDeepLinkHost(tester);

    await openLink(tester, host.dispatcher, 'prism://library?tab=history');
    expect(host.router.topRoute.args, const LibraryRouteArgs(initialTab: LibraryTab.history));
    expect(tabBarIndex(tester), 0);

    await openLink(tester, host.dispatcher, 'prism://library?tab=downloads');
    expect(host.router.topRoute.args, const LibraryRouteArgs(initialTab: LibraryTab.downloads));
    expect(tabBarIndex(tester), 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('unchanged route arguments preserve a user tab on widget updates', (tester) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    await pumpLibrary(
      tester,
      wrap: (_) => ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (context, value, child) => BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: LibraryScreen(initialTab: value < 2 ? LibraryTab.favourites : LibraryTab.downloads),
        ),
      ),
    );
    await tapTab(tester, 'Downloads');
    await settle(tester);
    rebuild.value = 1;
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabNames(), <String>['favourites', 'downloads']);

    rebuild.value = 2;
    await settle(tester);
    await tapTab(tester, 'Favourites');
    await settle(tester);
    rebuild.value = 3;
    await settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
    expect(tabNames(), <String>['favourites', 'downloads', 'favourites']);
  });

  testWidgets('the app bar shows an Offline chip only while offline', (tester) async {
    await pumpLibrary(tester);
    expect(find.text('Offline'), findsNothing);

    connectivity.controller.add(false);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);

    connectivity.controller.add(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsNothing);
  });
}
