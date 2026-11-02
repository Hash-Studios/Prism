import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/pick_up_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

HistoryWall _viewed(String id) => HistoryWall.tryCreate(
  id: id,
  source: WallpaperSource.prism,
  thumbnailUrl: 'https://example.com/$id-thumb.jpg',
  action: HistoryAction.view,
  at: DateTime(2026, 10, 28, 9),
)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpRow(WidgetTester tester, List<HistoryWall> walls) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PickUpRow(walls: walls)),
    ),
  );

  testWidgets('shows the title and one tile per wall', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpRow(tester, <HistoryWall>[_viewed('a'), _viewed('b'), _viewed('c'), _viewed('d')]);

    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && '${widget.key}'.contains('pick-up-')),
      findsNWidgets(4),
    );
    expect(find.bySemanticsLabel('Open wallpaper 1 of 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders nothing when there are no walls', (tester) async {
    await pumpRow(tester, const <HistoryWall>[]);

    expect(find.text('Pick up where you left off'), findsNothing);
    expect(find.byType(PickUpRow), findsOneWidget);
  });
}
