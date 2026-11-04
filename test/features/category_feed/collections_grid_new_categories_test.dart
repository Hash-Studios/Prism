import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as collections_data;
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

/// Cover photos that are not bundled would hit the network. Fail every request so the tiles fall back to placeholders.
class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineHttpClient();
}

class _OfflineHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Future<HttpClientRequest>.error(const SocketException('Network disabled in widget test'));

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      Future<HttpClientRequest>.error(const SocketException('Network disabled in widget test'));

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw const SocketException('Network disabled in widget test');
}

/// The built-in list as the feed state holds it. [includeDesktop] false matches a list where Desktop has fewer than
/// [minimumCategoryWalls] walls and is hidden.
List<CategoryEntity> _categories({required bool includeDesktop}) => <CategoryEntity>[
  for (final CategoryDefinition definition in categoryDefinitions)
    if (includeDesktop || definition.name != 'Desktop')
      CategoryEntity(
        name: definition.name,
        source: definition.source,
        searchType: definition.searchType,
        image: definition.imageUrl,
        image2: definition.secondaryImageUrl,
        hasPrismWalls: definition.hasPrismWalls,
        query: definition.query,
      ),
];

final Finder _scrollable = find.byType(Scrollable).first;

void main() {
  late HttpOverrides? originalHttpOverrides;

  setUp(() {
    originalHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _OfflineHttpOverrides();
    collections_data.collections = <Map<String, dynamic>>[];
  });

  tearDown(() {
    HttpOverrides.global = originalHttpOverrides;
    collections_data.collections = <Map<String, dynamic>>[];
  });

  final Map<String, ThemeData> themes = <String, ThemeData>{'light': ThemeData.light(), 'dark': ThemeData.dark()};

  Future<void> pumpGrid(
    WidgetTester tester, {
    required List<CategoryEntity> categories,
    required ThemeData theme,
    TextScaler textScaler = TextScaler.noScaling,
    StackRouter? router,
  }) async {
    final _MockCategoryFeedBloc bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial().copyWith(categories: categories));

    final Widget grid = BlocProvider<CategoryFeedBloc>.value(
      value: bloc,
      child: const Scaffold(body: CollectionsGrid()),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: router == null ? grid : StackRouterScope(controller: router, stateHash: 0, child: grid),
      ),
    );
    await tester.pump();
  }

  for (final MapEntry<String, ThemeData> variant in themes.entries) {
    testWidgets('shows the Pastel and Gaming tiles with their names (${variant.key})', (tester) async {
      await pumpGrid(tester, categories: _categories(includeDesktop: false), theme: variant.value);

      await tester.scrollUntilVisible(find.text('Gaming'), 300, scrollable: _scrollable);
      expect(find.text('Pastel'), findsOneWidget);
      expect(find.text('Gaming'), findsOneWidget);
      expect(find.text('3D Render'), findsOneWidget);
      expect(find.text('Desktop'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text keeps the new tile names readable (${variant.key})', (tester) async {
      await pumpGrid(
        tester,
        categories: _categories(includeDesktop: true),
        theme: variant.value,
        textScaler: const TextScaler.linear(2.0),
      );

      for (final String name in <String>['Pastel', 'Gaming', 'Desktop']) {
        await tester.scrollUntilVisible(find.text(name), 300, scrollable: _scrollable);
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Pastel'), findsOneWidget);
      expect(find.text('Gaming'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
    });
  }

  testWidgets('shows the Desktop tile when the list has it', (tester) async {
    await pumpGrid(tester, categories: _categories(includeDesktop: true), theme: ThemeData.light());

    await tester.scrollUntilVisible(find.text('Desktop'), 300, scrollable: _scrollable);
    expect(find.text('Desktop'), findsOneWidget);
  });

  testWidgets('tapping Pastel opens the Pastel category', (tester) async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    registerFallbackValue(CollectionViewRoute(collectionName: 'category:Space'));
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await pumpGrid(tester, categories: _categories(includeDesktop: false), theme: ThemeData.light(), router: router);

    await tester.tap(find.text('Pastel'));
    await tester.pump();

    final CollectionViewRoute route = verify(() => router.push(captureAny())).captured.single as CollectionViewRoute;
    expect(route.args!.collectionName, 'category:Pastel');
  });
}
