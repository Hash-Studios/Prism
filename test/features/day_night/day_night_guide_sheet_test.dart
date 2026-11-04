import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_guide_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

DayNightWall _wall(String id) =>
    DayNightWall(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: '');

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpHost(WidgetTester tester, DayNightPair pair, {double textScale = 1}) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showDayNightGuideSheet(context, pair: pair),
            child: const Text('Open guide'),
          ),
        ),
      ),
    );
  }

  testWidgets('lists the steps for the pair in order with the times and the screen', (tester) async {
    final DayNightPair pair = DayNightPair(day: _wall('day'), night: _wall('night'), target: WallpaperTarget.lock);
    await pumpHost(tester, pair);

    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();

    expect(find.text('Switch walls with Shortcuts'), findsOneWidget);
    expect(find.text('Tap Time of Day. Choose 7:00 AM, then Daily.'), findsOneWidget);
    expect(find.text('Make a second automation the same way for 7:00 PM.'), findsOneWidget);
    expect(find.textContaining('choose Lock Screen'), findsOneWidget);
    expect(find.text('Sunrise and sunset'), findsOneWidget);
  });

  testWidgets('large text opens the guide without overflow', (tester) async {
    final DayNightPair pair = DayNightPair(day: _wall('day'), night: _wall('night'));
    await pumpHost(tester, pair, textScale: 2);

    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
