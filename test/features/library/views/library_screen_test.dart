import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
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

class _MockStackRouter extends Mock implements StackRouter {}

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
    await tester.pumpWidget(MaterialApp(home: home));
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

  testWidgets('initialTab opens that tab without tracking a change', (tester) async {
    await pumpLibrary(tester, initialTab: LibraryTab.downloads);

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(tabEvents(), isEmpty);
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
