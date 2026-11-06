import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/core/widgets/prism_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<String> haptics = <String>[];

  setUp(() {
    haptics.clear();
    PrismHaptics.enabled = true;
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) async {
      haptics.add(call.arguments as String);
      return null;
    });
  });

  Widget app(RefreshCallback onRefresh, {double edgeOffset = 0}) => MaterialApp(
    home: Scaffold(
      body: PrismRefresh(
        onRefresh: onRefresh,
        edgeOffset: edgeOffset,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[for (int i = 0; i < 20; i++) SizedBox(height: 100, child: Text('row $i'))],
        ),
      ),
    ),
  );

  // The bounce runs on a ticker, so it needs frames, not one long pump.
  Future<void> frames(WidgetTester tester, Duration total) async {
    for (Duration d = Duration.zero; d < total; d += const Duration(milliseconds: 16)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<TestGesture> pull(WidgetTester tester, double distance) async {
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('row 0')));
    for (double moved = 0; moved < distance; moved += 10) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    return gesture;
  }

  testWidgets('iOS: the mark steps with the pull, refreshes past the trigger, holds, then closes', (tester) async {
    final Completer<void> done = Completer<void>();
    int refreshes = 0;
    await tester.pumpWidget(
      app(() {
        refreshes++;
        return done.future;
      }),
    );

    final TestGesture gesture = await pull(tester, 400);
    expect(haptics, <String>[
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
    expect(tester.widget<PrismLoader>(find.byType(PrismLoader)).progress, 1);
    expect(refreshes, 0);

    await gesture.up();
    await frames(tester, const Duration(milliseconds: 32)); // starts on the first bounce frame
    expect(refreshes, 1);
    expect(tester.widget<PrismLoader>(find.byType(PrismLoader)).progress, isNull, reason: 'loops while refreshing');

    // The bounce back stops at the hold gap.
    await frames(tester, const Duration(seconds: 1));
    expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(PrismRefresh.holdExtent, 0.5));
    expect(find.byType(PrismLoader), findsOneWidget);

    done.complete();
    await tester.pump();
    await frames(tester, const Duration(milliseconds: 300));
    expect(find.byType(PrismLoader), findsNothing);
    expect(tester.getTopLeft(find.text('row 0')).dy, 0);
    expect(haptics.length, 3, reason: 'no second impact on release');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: a short pull does not refresh', (tester) async {
    int refreshes = 0;
    await tester.pumpWidget(app(() async => refreshes++));

    final TestGesture gesture = await pull(tester, 30);
    await gesture.up();
    await frames(tester, const Duration(seconds: 1));

    expect(refreshes, 0);
    expect(haptics, isNot(contains('HapticFeedbackType.mediumImpact')));
    expect(find.byType(PrismLoader), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: the mark sits below the edge offset', (tester) async {
    await tester.pumpWidget(app(() async {}, edgeOffset: 96));

    await pull(tester, 400);

    expect(tester.getTopLeft(find.byType(PrismLoader)).dy, greaterThanOrEqualTo(96));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: a RefreshIndicator in the page colours that plays an impact', (tester) async {
    int refreshes = 0;
    await tester.pumpWidget(app(() async => refreshes++, edgeOffset: 40));

    final RefreshIndicator indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final ColorScheme cs = Theme.of(tester.element(find.byType(ListView))).colorScheme;
    expect(indicator.edgeOffset, 40);
    expect(indicator.color, cs.primary);
    expect(indicator.backgroundColor, cs.surface);

    await indicator.onRefresh();
    expect(refreshes, 1);
    expect(haptics, <String>['impact']);
  });
}
