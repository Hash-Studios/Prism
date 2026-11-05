import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_guide_sheet.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

DayNightWall _wall(String id) =>
    DayNightWall(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: '');

void main() {
  final Future<int?> Function() originalIosVersion = iosMajorVersion;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    iosMajorVersion = () async => 17;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    iosMajorVersion = originalIosVersion;
  });

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

  testWidgets('iOS 16 uses its automation instruction instead of iOS 17 labels', (tester) async {
    iosMajorVersion = () async => 16;
    final DayNightPair pair = DayNightPair(day: _wall('day'), night: _wall('night'));
    await pumpHost(tester, pair);

    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();

    expect(find.text('On iOS 16 there is no Run Immediately. Turn off Ask Before Running instead.'), findsOneWidget);
    expect(find.text('Choose Run Immediately, then tap Next.'), findsNothing);
    expect(find.text('Tap New Blank Automation.'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
