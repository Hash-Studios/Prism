import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/features/category_feed/views/pages/color_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/color_grid.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockPexelsWallpaperRepository extends Mock implements PexelsWallpaperRepository {}

PexelsWallpaper _wallpaper(String id) => PexelsWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.pexels, fullUrl: '', thumbnailUrl: '', authorName: id),
);

void main() {
  late _MockPexelsWallpaperRepository repository;

  setUp(() {
    repository = _MockPexelsWallpaperRepository();
    getIt.registerSingleton<PexelsWallpaperRepository>(repository);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('keeps the last wallpaper and appends See more', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]));

    await tester.pumpWidget(
      const MaterialApp(
        home: ColorScreen(hexColor: 'ff0000', name: 'Red'),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('passes the swatch name to the next page request', (tester) async {
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]));
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: false),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-2')]));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ColorGrid(hexColor: 'ff0000', name: 'Red'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('See more'));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-2'), findsOneWidget);
    verify(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: false)).called(1);
  });

  testWidgets('refreshes the same named color feed after paging and replaces old items', (tester) async {
    int firstPageRequests = 0;
    when(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true)).thenAnswer((_) async {
      firstPageRequests++;
      return Result.success(<PexelsWallpaper>[_wallpaper(firstPageRequests == 1 ? 'wallpaper-1' : 'wallpaper-3')]);
    });
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: false),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-2')]));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ColorGrid(hexColor: 'ff0000', name: 'Red'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('See more'));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-2'), findsOneWidget);

    final RefreshIndicatorState indicator = tester.state(find.byType(RefreshIndicator));
    indicator.show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    verify(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true)).called(2);
    verify(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: false)).called(1);
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-3'), findsOneWidget);
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsNothing);
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-2'), findsNothing);
  });

  testWidgets('hides See more after empty results', (tester) async {
    final Completer<Result<List<PexelsWallpaper>>> pending = Completer<Result<List<PexelsWallpaper>>>();
    when(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true)).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ColorGrid(hexColor: 'ff0000', name: 'Red'),
        ),
      ),
    );
    expect(find.byType(LoadingCards), findsOneWidget);

    pending.complete(Result.success(const <PexelsWallpaper>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(SeeMoreButton), findsNothing);
  });

  testWidgets('a failed first page shows an error with Retry, and Retry loads the feed', (tester) async {
    int calls = 0;
    when(() => repository.fetchColorFeed(hex: 'ff0000', name: 'Red', refresh: true)).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? Result.error<List<PexelsWallpaper>>(const NetworkFailure('offline'))
          : Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ColorGrid(hexColor: 'ff0000', name: 'Red'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load wallpapers"), findsOneWidget);
    expect(find.byType(LoadingCards), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load wallpapers"), findsNothing);
    expect(find.byType(SeeMoreButton), findsOneWidget);
  });
}
