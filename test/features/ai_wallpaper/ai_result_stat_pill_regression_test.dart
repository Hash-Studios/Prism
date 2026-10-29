import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

StatPill _pill({VoidCallback? onTap, Widget child = const SizedBox(width: 24, height: 18)}) =>
    StatPill(key: const ValueKey<String>('stat-pill'), semanticLabel: 'Test stat pill', onTap: onTap, child: child);

void main() {
  testWidgets('loose bounded header constraints keep a tappable pill at the 44 point minimum', (tester) async {
    int taps = 0;
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_host(Center(child: _pill(onTap: () => taps++))));

      final Finder pill = find.byKey(const ValueKey<String>('stat-pill'));
      expect(tester.getSize(pill).height, 44);
      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Test stat pill'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      final Rect rect = tester.getRect(pill);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a fixed-height stage header keeps its caller height', (tester) async {
    await tester.pumpWidget(_host(SizedBox(height: 56, child: _pill(onTap: () {}))));

    expect(tester.getSize(find.byKey(const ValueKey<String>('stat-pill'))).height, 56);
  });

  for (final bool showStreak in <bool>[false, true]) {
    testWidgets('PrismHeader keeps its minimum height with 44 point stats, showStreak=$showStreak', (tester) async {
      final bool wasLoggedIn = app_state.prismUser.loggedIn;
      final int previousBalance = CoinsService.instance.balanceNotifier.value;
      final int previousDelta = CoinsService.instance.deltaNotifier.value;
      addTearDown(() {
        app_state.prismUser.loggedIn = wasLoggedIn;
        CoinsService.instance.balanceNotifier.value = previousBalance;
        CoinsService.instance.deltaNotifier.value = previousDelta;
      });
      app_state.prismUser.loggedIn = true;
      CoinsService.instance.balanceNotifier.value = 120;
      CoinsService.instance.deltaNotifier.value = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                PrismHeader(
                  title: 'AI wallpaper',
                  showBack: false,
                  actions: <Widget>[CoinBalanceChip(sourceTag: 'ai_gen_page', showStreak: showStreak)],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PrismHeader)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byType(CoinBalancePill)).height, 44);
      if (showStreak) {
        expect(tester.widget<StreakPill>(find.byType(StreakPill)).compact, isTrue);
        expect(tester.getSize(find.byType(StreakPill)).height, 44);
      } else {
        expect(find.byType(StreakPill), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unbounded vertical constraints still produce a finite 44 point target', (tester) async {
    await tester.pumpWidget(
      _host(
        UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          child: _pill(onTap: () {}),
        ),
      ),
    );

    final double height = tester.getSize(find.byKey(const ValueKey<String>('stat-pill'))).height;
    expect(height, 44);
    expect(height.isFinite, isTrue);
  });

  testWidgets('content taller than the minimum keeps its full height', (tester) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: _pill(onTap: () {}, child: const SizedBox(width: 24, height: 72)),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey<String>('stat-pill'))).height, 86);
  });
}
