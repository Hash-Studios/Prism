import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/features/editors_choice/views/pages/editors_choice_screen.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import '../fake_editors_choice_repository.dart';

void _registerRepository(FakeEditorsChoiceRepository repository) {
  getIt.registerFactory<EditorsChoiceCubit>(() => EditorsChoiceCubit(repository));
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      builder: favouriteTestBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorsChoiceScreen(source: 'row'),
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

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('shows the picks grid with the header text and tracks the open', (tester) async {
    _registerRepository(FakeEditorsChoiceRepository(walls: pickWalls(3)));

    await _pumpScreen(tester);

    expect(find.text('Wallpapers our editors love.'), findsOneWidget);
    expect(find.byType(WallIdsGrid), findsOneWidget);
    expect(find.byType(WallpaperTile), findsWidgets);
    expect(recordingAnalytics.events.whereType<EditorsChoiceOpenedEvent>().map((event) => event.source), <String>[
      'row',
    ]);
  });

  testWidgets('shows the empty state when there are no picks', (tester) async {
    _registerRepository(FakeEditorsChoiceRepository());

    await _pumpScreen(tester);

    expect(find.text('No picks yet'), findsOneWidget);
    expect(find.byType(GlintState), findsOneWidget);
  });

  testWidgets('shows the error state when the load fails', (tester) async {
    _registerRepository(FakeEditorsChoiceRepository(fail: true));

    await _pumpScreen(tester);

    expect(find.text("Couldn't load Editors' Choice"), findsOneWidget);
  });
}
