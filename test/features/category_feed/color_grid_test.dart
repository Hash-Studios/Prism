import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
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

  testWidgets('hides See more after empty results', (tester) async {
    final Completer<Result<List<PexelsWallpaper>>> pending = Completer<Result<List<PexelsWallpaper>>>();
    when(() => repository.fetchColorFeed(hex: 'ff0000', refresh: true)).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    expect(find.byType(LoadingCards), findsOneWidget);

    pending.complete(Result.success(const <PexelsWallpaper>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(SeeMoreButton), findsNothing);
    expect(find.widgetWithText(GlintState, 'No wallpapers for this colour'), findsOneWidget);
  });

  testWidgets('shows an error with a retry when the colour feed fails, then recovers', (tester) async {
    var calls = 0;
    when(() => repository.fetchColorFeed(hex: 'ff0000', refresh: true)).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? Result.error<List<PexelsWallpaper>>(const NetworkFailure('offline'))
          : Result.success(<PexelsWallpaper>[_wallpaper('wallpaper-1')]);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ColorGrid(hexColor: 'ff0000')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't load wallpapers"), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GlintState), findsNothing);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    expect(calls, 2);
  });
}
