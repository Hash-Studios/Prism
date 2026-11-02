import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/features/editors_choice/views/widgets/editors_choice_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import '../fake_editors_choice_repository.dart';

Future<void> _pumpRow(WidgetTester tester, List<PrismWallpaper> walls, {double textScale = 1}) async {
  final EditorsChoiceCubit cubit = EditorsChoiceCubit(FakeEditorsChoiceRepository(walls: walls));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: favouriteTestBuilder(context, child),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: EditorsChoiceRow(cubit: cubit)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpFavouriteCounts();

  late FakeAppAnalytics recordingAnalytics;

  setUp(() {
    recordingAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = recordingAnalytics;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
  });

  testWidgets('renders nothing with fewer than four picks', (tester) async {
    await _pumpRow(tester, pickWalls(3));

    expect(find.text("Editors' Choice"), findsNothing);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('shows the title, the body and the picks with four picks', (tester) async {
    await _pumpRow(tester, pickWalls(4));

    expect(find.text("Editors' Choice"), findsOneWidget);
    expect(find.text('Wallpapers our editors love.'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    final SliverChildBuilderDelegate strip =
        tester.widget<ListView>(find.byType(ListView)).childrenDelegate as SliverChildBuilderDelegate;
    expect(strip.estimatedChildCount, 7); // 4 tiles and 3 separators
    expect(find.byType(WallpaperTile), findsWidgets);
  });

  testWidgets('lays out at large text without an exception', (tester) async {
    await _pumpRow(tester, pickWalls(4), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text("Editors' Choice"), findsOneWidget);
  });
}
