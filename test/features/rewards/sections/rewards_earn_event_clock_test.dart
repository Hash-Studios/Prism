import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_earn_section.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a notifier rebuild updates the event badge before the next timer tick', (tester) async {
    DateTime now = DateTime.utc(2026, 11, 14, 12);
    final DateTime end = now.add(const Duration(seconds: 1));
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'events': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'launch',
          'startsAtMs': now.millisecondsSinceEpoch,
          'endsAtMs': end.millisecondsSinceEpoch,
          'multiplier': 2,
          'actions': <String>['rewardedAd'],
        },
      ],
    });
    addTearDown(EconomyConfig.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: RewardsEarnSection(clock: () => now)),
        ),
      ),
    );
    expect(find.text('2x'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('coin-event-banner')), findsOneWidget);

    now = end;
    EconomyConfig.current = EconomyConfig(coinEvents: EconomyConfig.current.coinEvents);
    await tester.pump();

    expect(find.text('2x'), findsNothing);
    expect(find.byKey(const ValueKey<String>('coin-event-banner')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
