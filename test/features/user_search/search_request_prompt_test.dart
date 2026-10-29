import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/widgets/search_request_prompt.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperSearchService service;
  late _MockSearchDiscoveryBloc discoveryBloc;

  setUpAll(() => registerFallbackValue(const SearchFilters()));

  setUp(() {
    service = _MockWallpaperSearchService();
    getIt
      ..registerSingleton<WallpaperSearchService>(service)
      ..registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    discoveryBloc = _MockSearchDiscoveryBloc();
    final SearchDiscoveryState state = SearchDiscoveryState.initial();
    when(() => discoveryBloc.state).thenReturn(state);
    whenListen(discoveryBloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    getIt.registerFactory<SearchDiscoveryBloc>(() => discoveryBloc);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('the prompt shows the question and the request action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SearchRequestPrompt(query: 'zzz')),
      ),
    );

    expect(find.text("Can't find it?"), findsOneWidget);
    expect(find.text('Request it'), findsOneWidget);
  });

  testWidgets('a query with no results offers a request in the empty state', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => service.search('zzz', filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: const <FeedItemEntity>[],
        prismResults: const <FeedItemEntity>[],
        isLocal: false,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Can't find it?"), findsOneWidget);
    expect(find.text('Request it'), findsOneWidget);
  });
}
