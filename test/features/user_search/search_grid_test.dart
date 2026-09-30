import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

FeedItemEntity _wallpaper(int index) {
  final id = 'wallpaper-$index';
  return PexelsFeedItem(
    id: id,
    wallpaper: PexelsWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.pexels,
        fullUrl: '',
        thumbnailUrl: '',
        authorName: 'Author $index',
      ),
    ),
  );
}

void main() {
  late _MockWallpaperSearchService search;

  setUp(() {
    search = _MockWallpaperSearchService();
    getIt.registerSingleton<WallpaperSearchService>(search);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('keeps the last wallpaper and appends See more after 24 results', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Wallpaper by Author 23'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('does not show See more for an empty first page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchGrid(query: 'nothing', provider: SearchProviderValue.pexels, initialResults: <FeedItemEntity>[]),
        ),
      ),
    );

    expect(find.byType(SeeMoreButton), findsNothing);
  });

  testWidgets('clears stale results after an empty successful refresh', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: true),
    ).thenAnswer((_) async => <FeedItemEntity>[]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: <FeedItemEntity>[_wallpaper(0)],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Wallpaper by Author 0'), findsOneWidget);

    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await refresh;

    expect(find.bySemanticsLabel('Wallpaper by Author 0'), findsNothing);
    semantics.dispose();
  });
}
