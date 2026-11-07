import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _Tabs extends ChangeNotifier implements TabsRouter {
  int _active = 0;

  @override
  int get activeIndex => _active;

  @override
  void setActiveIndex(int index, {bool notify = true}) {
    _active = index;
    if (notify) notifyListeners();
  }

  @override
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  for (final double bottomInset in <double>[0, 48]) {
    testWidgets('Home navigation clears a $bottomInset point system inset and every tab responds', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1
        ..viewPadding = FakeViewPadding(bottom: bottomInset)
        ..padding = FakeViewPadding(bottom: bottomInset);
      addTearDown(tester.view.reset);
      final _Tabs tabs = _Tabs();
      addTearDown(tabs.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TabsRouterScope(
            controller: tabs,
            stateHash: 0,
            child: const BottomBar(child: Scaffold(body: Text('Home feed'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect pill = tester.getRect(find.byType(PrismBottomNav));
      final Rect create = tester.getRect(find.byType(PrismFab));
      expect(pill.bottom, closeTo(568 - bottomInset - 10, 0.01));
      expect(create.bottom, pill.bottom);
      expect(pill.left, greaterThanOrEqualTo(0));
      expect(create.right, lessThanOrEqualTo(320));
      expect(pill.overlaps(create), isFalse);
      expect(find.bySemanticsLabel('Upload').hitTestable(), findsOneWidget);

      final List<String> labels = <String>['Home', 'Search', 'Rewards', 'Collections'];
      for (int index = 0; index < labels.length; index++) {
        final Finder target = find.byTooltip(labels[index]);
        expect(target.hitTestable(), findsOneWidget);
        final Rect rect = tester.getRect(target);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.bottom, lessThanOrEqualTo(568 - bottomInset));
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tabs.activeIndex, index);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
