import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

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
    'https://th.wallhaven.cc/small/21/collection.jpg': 'https://th.wallhaven.cc/orig/21/collection.jpg',
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

  testWidgets('a finished empty collection shows no tile or See more button', (tester) async {
    final originalWalls = anyCollectionWalls;
    final originalHasMore = collectionHasMore;
    anyCollectionWalls = <Map<String, dynamic>>[];
    collectionHasMore = false;
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));

    expect(tester.widget<GridView>(find.byType(GridView)).childrenDelegate.estimatedChildCount, 0);
    expect(find.text('See more'), findsNothing);
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
    await tester.scrollUntilVisible(find.text('See more'), 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clips tile ink and preserves the long-press shrink and reverse animation', (tester) async {
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
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    messenger.setMockMethodCallHandler(toastChannel, (_) async => null);
    addTearDown(() {
      anyCollectionWalls = originalWalls;
      collectionHasMore = originalHasMore;
      HttpOverrides.global = originalHttpOverrides;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
      AnalyticsRuntime.reset();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CollectionViewGrid())));
    await tester.pump(const Duration(milliseconds: 16));

    final inkWellFinder = find.byType(InkWell);
    final tileClipFinder = find.ancestor(of: inkWellFinder, matching: find.byType(ClipRect)).first;
    final tileSemanticsFinder = find.ancestor(of: inkWellFinder, matching: find.byType(Semantics)).first;
    final Size restingSize = tester.getSize(inkWellFinder);
    expect(tester.widget<ClipRect>(tileClipFinder).clipBehavior, Clip.hardEdge);
    expect(tester.getSize(tileClipFinder), restingSize);
    final PrismImageTile image = tester.widget<PrismImageTile>(
      find.descendant(of: tileSemanticsFinder, matching: find.byType(PrismImageTile)),
    );
    expect(image.borderRadius, isNull);

    final gesture = await tester.startGesture(tester.getCenter(inkWellFinder));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.cancel();
    await tester.pump();

    tester.widget<InkWell>(inkWellFinder).onLongPress!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final Size pressedSize = tester.getSize(inkWellFinder);
    expect(pressedSize.width, closeTo(restingSize.width - 16, 0.1));
    expect(pressedSize.height, closeTo(restingSize.height - 8, 0.1));

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(inkWellFinder), restingSize);
  });
}
