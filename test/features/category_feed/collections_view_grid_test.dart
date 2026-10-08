import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailingHttpClient();
}

class _FailingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      Future<HttpClientRequest>.error(const SocketException('Network disabled in widget test'));

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw const SocketException('Network disabled in widget test');
}

void main() {
  for (final thumbnail in <String, String>{
    'https://th.wallhaven.cc/small/21/collection.jpg': 'https://th.wallhaven.cc/lg/21/collection.jpg',
    'https://images.pexels.com/photos/1/tiny.jpg?fit=crop&w=200&h=280':
        'https://images.pexels.com/photos/1/tiny.jpg?fit=max&w=200&h=280',
  }.entries) {
    testWidgets('normalizes the collection thumbnail ${thumbnail.key}', (tester) async {
      final originalWalls = anyCollectionWalls;
      final originalHasMore = collectionHasMore;
      anyCollectionWalls = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'wall-1',
          'wallpaper_thumb': thumbnail.key,
          'wallpaper_url': 'https://example.test/wall.jpg',
        },
      ];
      collectionHasMore = false;
      AnalyticsRuntime.instance = FakeAppAnalytics();
      addTearDown(() {
        anyCollectionWalls = originalWalls;
        collectionHasMore = originalHasMore;
        AnalyticsRuntime.reset();
      });

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));

      expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, thumbnail.value);
    });
  }

  testWidgets('a finished empty collection shows an empty state, no tile and no See more button', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[];
    collectionHasMore = false;
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));

    expect(find.byType(GridView), findsNothing);
    expect(find.text('No wallpapers in this collection yet'), findsOneWidget);
    expect(find.text('See more'), findsNothing);
  });

  testWidgets('See more depends on hasMore only, even with fewer than 24 walls', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{'id': '', 'wallpaper_thumb': '', 'wallpaper_url': ''},
    ];
    collectionHasMore = true;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      AnalyticsRuntime.reset();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));

    expect(find.text('See more'), findsOneWidget);
  });

  testWidgets('malformed collection placeholders have square corners', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{'id': '', 'wallpaper_thumb': '', 'wallpaper_url': ''},
    ];
    collectionHasMore = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      AnalyticsRuntime.reset();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));
    await tester.pump(const Duration(milliseconds: 16));

    final tile = tester.widget<Container>(
      find.ancestor(of: find.byIcon(Icons.broken_image_outlined), matching: find.byType(Container)).first,
    );
    expect(tile.decoration, isA<BoxDecoration>());
    expect((tile.decoration! as BoxDecoration).borderRadius, isNull);
  });

  testWidgets('does not replace the 24th collection item with See more', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = List<Map<String, dynamic>>.generate(
      24,
      (index) => <String, dynamic>{'id': 'wall-$index', 'wallpaper_thumb': '', 'wallpaper_url': ''},
    );
    collectionHasMore = true;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      AnalyticsRuntime.reset();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.widget<GridView>(find.byType(GridView)).childrenDelegate.estimatedChildCount, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clips tile ink, and a long press opens the quick actions sheet', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    final originalHttpOverrides = HttpOverrides.current;
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'wall-1',
        'wallpaper_thumb': 'https://example.test/thumb.jpg',
        'wallpaper_url': 'https://example.test/wall.jpg',
        'wallpaper_provider': 'prism',
        'by': 'Artist',
      },
    ];
    collectionHasMore = false;
    HttpOverrides.global = _FailingHttpOverrides();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    messenger.setMockMethodCallHandler(toastChannel, (_) async => null);
    addTearDown(() async {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      HttpOverrides.global = originalHttpOverrides;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
      AnalyticsRuntime.reset();
      await getIt.reset();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));
    await tester.pump(const Duration(milliseconds: 16));

    final inkWellFinder = find.byType(InkWell);
    final tileClipFinder = find.ancestor(of: inkWellFinder, matching: find.byType(ClipRect)).first;
    final tileSemanticsFinder = find.ancestor(of: inkWellFinder, matching: find.byType(Semantics)).first;
    expect(tester.widget<ClipRect>(tileClipFinder).clipBehavior, Clip.hardEdge);
    expect(tester.getSize(tileClipFinder), tester.getSize(inkWellFinder));
    final PrismImageTile image = tester.widget<PrismImageTile>(
      find.descendant(of: tileSemanticsFinder, matching: find.byType(PrismImageTile)),
    );
    expect(image.borderRadius, isNull);
    expect(image.fallbackUrl, 'https://example.test/wall.jpg');

    await tester.longPress(inkWellFinder);
    await tester.pumpAndSettle();

    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Favourite'), findsOneWidget);
  });

  testWidgets('a tap opens the wall from the loaded data, with no second fetch', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'wall-1',
        'wallpaper_thumb': 'https://example.test/thumb.jpg',
        'wallpaper_url': 'https://example.test/wall.jpg',
        'wallpaper_provider': 'prism',
        'by': 'Artist',
        'email': 'artist@example.test',
        'collections': <String>['space'],
      },
    ];
    collectionHasMore = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      AnalyticsRuntime.reset();
    });
    registerFallbackValue(WallpaperDetailRoute());
    final router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const Scaffold(body: CollectionViewGrid()),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.wallId, isNull, reason: 'a wall id would make the detail screen fetch the wall again');
    final PrismFeedItem entity = route.args!.entity! as PrismFeedItem;
    expect(entity.id, 'wall-1');
    expect(entity.wallpaper.core.authorName, 'Artist');
    expect(entity.wallpaper.collections, <String>['space']);
    expect(route.args!.heroTag, contains('wall-1'));
  });

  testWidgets('pull to refresh reloads the open collection', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{'id': '', 'wallpaper_thumb': '', 'wallpaper_url': ''},
    ];
    collectionHasMore = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<FirestoreClient>(_FailingFirestore());
    addTearDown(() async {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      AnalyticsRuntime.reset();
      await getIt.reset();
    });
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    messenger.setMockMethodCallHandler(toastChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(toastChannel, null));

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await getCollectionWithName('space').catchError((Object _) {});
    anyCollectionWalls = <Map<String, dynamic>>[
      <String, dynamic>{'id': '', 'wallpaper_thumb': '', 'wallpaper_url': ''},
    ];
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(GridView), findsOneWidget, reason: 'a failed refresh keeps the walls on screen');
    expect(anyCollectionWalls, hasLength(1));
  });
}

class _MockStackRouter extends Mock implements StackRouter {}

/// Fails every query, like a device that lost its connection.
class _FailingFirestore extends Fake implements FirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) =>
      Future<List<T>>.error(StateError('offline'));
}
