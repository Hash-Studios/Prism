import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/views/pages/color_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/color_grid.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockPexelsWallpaperRepository extends Mock implements PexelsWallpaperRepository {}

void main() {
  setUp(() {
    final repository = _MockPexelsWallpaperRepository();
    when(
      () => repository.fetchColorFeed(
        hex: any(named: 'hex'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async => Result.success(const []));
    getIt.registerSingleton<PexelsWallpaperRepository>(repository);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('shows the title, the searched colour and its hex code above the grid', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: ColorScreen(hexColor: 'ff6600')));
    await tester.pump();

    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('#FF6600'), findsOneWidget);
    expect(find.bySemanticsLabel('Colour #FF6600'), findsOneWidget);
    expect(find.byType(ColorGrid), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    semantics.dispose();
  });
}
