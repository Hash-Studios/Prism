import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CoinsService coins = CoinsService.instance;
  late bool wasLoggedIn;
  late StreakStatus originalStatus;

  setUp(() {
    wasLoggedIn = app_state.prismUser.loggedIn;
    originalStatus = coins.streakNotifier.value;
  });

  tearDown(() {
    app_state.prismUser.loggedIn = wasLoggedIn;
    coins.streakNotifier.value = originalStatus;
  });

  Widget host({required bool compact}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: StreakPill(compact: compact)),
  );

  testWidgets('the streak is hidden while signed out', (tester) async {
    app_state.prismUser.loggedIn = false;
    await tester.pumpWidget(host(compact: false));

    expect(find.byType(StreakPill), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('active streaks announce the capped next day and compact reward', (tester) async {
    app_state.prismUser.loggedIn = true;
    coins.streakNotifier.value = const StreakStatus(
      streakDay: 7,
      count: 14,
      active: true,
      claimedToday: true,
      reminderEnabled: true,
      timezoneOffsetMinutes: 0,
      lastClaimDate: '2026-10-20',
    );
    await tester.pumpWidget(host(compact: true));

    expect(
      tester.widget<StatPill>(find.byType(StatPill)).semanticLabel,
      AppLocalizationsEn().coreStreakSemantics(14, 3),
    );
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('inactive streak uses the full next reward label', (tester) async {
    app_state.prismUser.loggedIn = true;
    coins.streakNotifier.value = const StreakStatus(
      streakDay: 5,
      count: 3,
      active: false,
      claimedToday: false,
      reminderEnabled: true,
      timezoneOffsetMinutes: 0,
      lastClaimDate: '',
    );
    await tester.pumpWidget(host(compact: false));

    expect(
      tester.widget<StatPill>(find.byType(StatPill)).semanticLabel,
      AppLocalizationsEn().coreStreakSemantics(3, 3),
    );
    expect(find.text('Next +3'), findsOneWidget);
  });
}
