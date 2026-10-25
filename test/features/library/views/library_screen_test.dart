import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../support/fake_connectivity_service.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockStackRouter extends Mock implements StackRouter {}

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
      ..registerSingleton<WallpaperHistoryStore>(WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore())));
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
    bloc = FavouriteWallsBloc(fetch, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
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

  List<LibraryTabChangedEvent> tabEvents() => analytics.events.whereType<LibraryTabChangedEvent>().toList();

  testWidgets('Android shows Favourites, Downloads and History tabs on the Favourites tab', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('Library'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Favourites'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Downloads'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'History'), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
    expect(tabEvents(), isEmpty);
  });

  testWidgets('iOS has no History tab, because it cannot set a wallpaper', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpLibrary(tester);

      expect(find.widgetWithText(Tab, 'Favourites'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Downloads'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'History'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('changing tab shows that list and tracks library_tab_changed with the tab name', (tester) async {
    await pumpLibrary(tester);

    await tester.tap(find.widgetWithText(Tab, 'Downloads'));
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads']);

    await tester.tap(find.widgetWithText(Tab, 'History'));
    await settle(tester);
    expect(find.text('Open history'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads', 'history']);
    expect(tabEvents().first.toWireParameters(), <String, Object?>{'tab': 'downloads'});
  });

  // The expected colours are the theme foreground made readable on the page, and the softer ink for the tab you
  // are not on (every theme's ink is dark enough for the soft one to keep 4.5:1).
  const Map<String, ({int selected, int unselected})> tabInk = <String, ({int selected, int unselected})>{
    'Frost White': (selected: 0xFF090909, unselected: 0xCC090909),
    'Rose': (selected: 0xFF19110F, unselected: 0xCC19110F),
    'Cotton Blue': (selected: 0xFF0B0D12, unselected: 0xCC0B0D12),
    'Coffee': (selected: 0xFF1E1709, unselected: 0xCC1E1709),
    'AMOLED': (selected: 0xFFFFFFFF, unselected: 0xCCFFFFFF),
  };

  for (final MapEntry<String, ({int selected, int unselected})> entry in tabInk.entries) {
    testWidgets('${entry.key}: both tab labels are 16 px and read on the page', (tester) async {
      final PrismThemeOption option = <PrismThemeOption>[
        ...prismLightThemes,
        ...prismDarkThemes,
      ].firstWhere((PrismThemeOption o) => prismThemeDisplayName(o, AppLocalizationsEn()) == entry.key);
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await pumpLibrary(tester, theme: theme);

      TextStyle labelOf(String tab) => tester
          .widget<RichText>(find.descendant(of: find.widgetWithText(Tab, tab), matching: find.byType(RichText)))
          .text
          .style!;
      final TextStyle selected = labelOf('Favourites');
      final TextStyle unselected = labelOf('Downloads');

      expect(selected.color!.toARGB32(), entry.value.selected);
      expect(unselected.color!.toARGB32(), entry.value.unselected);
      expect(selected.fontSize, 16);
      expect(unselected.fontSize, 16);
      for (final TextStyle label in <TextStyle>[selected, unselected]) {
        expect(
          contrastRatio(Color.alphaBlend(label.color!, theme.primaryColor), theme.primaryColor),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  }

  group('tab labels and the system text size', () {
    double labelScale(WidgetTester tester, String tab) => tester
        .widget<RichText>(find.descendant(of: find.widgetWithText(Tab, tab), matching: find.byType(RichText)))
        .textScaler
        .scale(16);

    testWidgets('follow it below 1.5x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.25;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLibrary(tester);

      expect(labelScale(tester, 'Favourites'), 20);
      expect(labelScale(tester, 'Downloads'), 20);
    });

    testWidgets('get all of the tab but 4 px each side, so "Downloads" has room at large text', (tester) async {
      await pumpLibrary(tester);

      final double slot = tester.getSize(find.byType(TabBar)).width / 3;
      final double room = tester
          .renderObject<RenderParagraph>(
            find.descendant(of: find.widgetWithText(Tab, 'Downloads'), matching: find.byType(RichText)),
          )
          .constraints
          .maxWidth;

      expect(slot, 130);
      expect(room, 122);
    });

    testWidgets('stop growing at 1.5x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLibrary(tester);

      expect(labelScale(tester, 'Favourites'), 24);
      expect(labelScale(tester, 'Downloads'), 24);
      expect(labelScale(tester, 'History'), 24);
      expect(tester.getSize(find.byType(TabBar)).height, 48);
    });
  });

  testWidgets('initialTab opens that tab without tracking a change', (tester) async {
    await pumpLibrary(tester, initialTab: LibraryTab.downloads);

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents(), isEmpty);
  });

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
    await tester.tap(find.widgetWithText(Tab, 'Downloads'));
    await settle(tester);
    rebuild.value = 1;
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads']);

    rebuild.value = 2;
    await settle(tester);
    await tester.tap(find.widgetWithText(Tab, 'Favourites'));
    await settle(tester);
    rebuild.value = 3;
    await settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads', 'favourites']);
  });

  testWidgets('warm typed Library links update both directions without remounting', (tester) async {
    final router = _LibraryRouter();
    final dispatcher = DeepLinkDispatcher(router: router, whenReady: () async => true);
    addTearDown(dispatcher.dispose);
    addTearDown(router.dispose);
    bloc = FavouriteWallsBloc(fetch, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
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

    Future<void> open(String tab) async {
      final result = dispatcher.openUri(Uri.parse('prism://library?tab=$tab'), source: DeepLinkSourceValue.appLinks);
      await settle(tester);
      expect(await result, DeepLinkDispatchResult.navigated);
      expect(router.topRoute.args, LibraryRouteArgs(initialTab: LibraryTab.values.byName(tab)));
    }

    await open('downloads');
    final state = tester.state(find.byType(LibraryScreen));
    expect(find.text('No downloads yet'), findsOneWidget);
    router.push(const PageRouteInfo<void>('Detail'));
    await settle(tester);
    await router.maybePop();
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);

    await open('favourites');
    expect(tester.state(find.byType(LibraryScreen)), same(state));
    expect(find.text('No favourites yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Downloads'));
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);
    await open('favourites');
    expect(tester.state(find.byType(LibraryScreen)), same(state));
    expect(find.text('No favourites yet'), findsOneWidget);
    await open('downloads');
    expect(tester.state(find.byType(LibraryScreen)), same(state));
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads']);

    await tester.tap(find.widgetWithText(Tab, 'Favourites'));
    await settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
    await open('downloads');
    expect(tester.state(find.byType(LibraryScreen)), same(state));
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads', 'favourites']);

    await tester.tap(find.widgetWithText(Tab, 'Favourites'));
    await settle(tester);
    tester.element(find.byType(LibraryScreen)).markNeedsBuild();
    await settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
    router.push(const PageRouteInfo<void>('Detail'));
    await settle(tester);
    await router.maybePop();
    await settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
    await open('downloads');
    expect(tester.state(find.byType(LibraryScreen)), same(state));
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads', 'favourites', 'favourites']);

    await router.maybePop();
    await settle(tester);
    expect(find.byType(LibraryScreen), findsNothing);
    await open('favourites');
    final remountedState = tester.state(find.byType(LibraryScreen));
    expect(remountedState, isNot(same(state)));
    expect(find.text('No favourites yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Downloads'));
    await settle(tester);
    expect(find.text('No downloads yet'), findsOneWidget);
    await open('favourites');
    expect(tester.state(find.byType(LibraryScreen)), same(remountedState));
    expect(find.text('No favourites yet'), findsOneWidget);
    expect(tabEvents().map((event) => event.tab), <String>['downloads', 'favourites', 'favourites', 'downloads']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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

  testWidgets('the History tab opens the existing history screen', (tester) async {
    registerFallbackValue(const WallpaperHistoryRoute());
    final router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await pumpLibrary(
      tester,
      wrap: (screen) => StackRouterScope(controller: router, stateHash: 0, child: screen),
    );

    await tester.tap(find.widgetWithText(Tab, 'History'));
    await settle(tester);
    await tester.tap(find.text('Open history'));
    await tester.pump();

    verify(() => router.push(any(that: isA<WallpaperHistoryRoute>()))).called(1);
  });
}
