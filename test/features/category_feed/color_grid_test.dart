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
      () => repository.fetchColorFeed(hex: 'ff0000', refresh: true),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('uses square loading cards and hides See more after empty results', (tester) async {
    final Completer<Result<List<PexelsWallpaper>>> pending = Completer<Result<List<PexelsWallpaper>>>();
    when(() => repository.fetchColorFeed(hex: 'ff0000', refresh: true)).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    expect(find.byType(LoadingCards), findsOneWidget);
    expect(tester.widget<LoadingCards>(find.byType(LoadingCards)).borderRadius, BorderRadius.zero);

    pending.complete(Result.success(const <PexelsWallpaper>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(SeeMoreButton), findsNothing);
  });

  testWidgets('clears stale results after an empty successful refresh', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var refreshCount = 0;
    when(() => repository.fetchColorFeed(hex: 'ff0000', refresh: true)).thenAnswer((_) async {
      refreshCount++;
      return Result.success(refreshCount == 1 ? <PexelsWallpaper>[_wallpaper('wallpaper-1')] : <PexelsWallpaper>[]);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);

    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await refresh;

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsNothing);
    expect(find.byType(SeeMoreButton), findsNothing);
    semantics.dispose();
  });

  testWidgets('preserves existing wallpapers after a failed refresh', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var refreshCount = 0;
    when(() => repository.fetchColorFeed(hex: 'ff0000', refresh: true)).thenAnswer((_) async {
      refreshCount++;
      return refreshCount == 1
          ? Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')])
          : Result.error<List<PexelsWallpaper>>(const ServerFailure('offline'));
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);

    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await refresh;

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('does not paginate after an initial fetch failure', (tester) async {
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', refresh: true),
    ).thenAnswer((_) async => Result.error<List<PexelsWallpaper>>(const ServerFailure('offline')));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(GridView), const Offset(0, -5000));
    await tester.pump();

    verifyNever(() => repository.fetchColorFeed(hex: 'ff0000', refresh: false));
  });

  testWidgets('keeps pagination available after a failed next-page request', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', refresh: true),
    ).thenAnswer((_) async => Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]));
    when(
      () => repository.fetchColorFeed(hex: 'ff0000', refresh: false),
    ).thenAnswer((_) async => Result.error<List<PexelsWallpaper>>(const ServerFailure('offline')));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(SeeMoreButton));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Wallpaper by wallpaper-1'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    verify(() => repository.fetchColorFeed(hex: 'ff0000', refresh: false)).called(1);
    semantics.dispose();
  });
}
