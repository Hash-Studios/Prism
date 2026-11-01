import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/promo_codes/data/promo_code_repository.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/features/promo_codes/views/redeem_code_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

void main() {
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService coins = CoinsService.instance;
  late CoinsTestFirestore firestore;
  late Map<String, Object?> reply;
  final DateTime currentUntil = DateTime(2030, 12);
  final DateTime oldUntil = DateTime(2030, 11);

  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    await backend.install();
    firestore = CoinsTestFirestore()
      ..userData = <String, dynamic>{'coins': 320}
      ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
        'rev': 1,
        'passes': <String, dynamic>{'premiumPassUntil': currentUntil.millisecondsSinceEpoch},
      };
    getIt.registerSingleton<FirestoreClient>(firestore);
    await coins.refreshBalance();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> redeem(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRedeemCodeSheet(
                context,
                source: RedeemSheetSource.link,
                initialCode: 'ABCDEFGH23',
                repository: PromoCodeRepository(call: (_, _) async => reply),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Redeem'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  Map<String, Object?> premiumReply({required bool replayed, required DateTime until}) => <String, Object?>{
    'ok': true,
    'reward': <String, Object?>{'type': 'premiumDays', 'days': 3},
    'premiumUntil': until.millisecondsSinceEpoch,
    'replayed': replayed,
  };

  testWidgets('a replayed coin receipt preserves current balance then refreshes server state', (tester) async {
    final Completer<Map<String, dynamic>> refreshed = Completer<Map<String, dynamic>>();
    firestore.userResponse = refreshed.future;
    final int readsBefore = firestore.userDocReads;
    reply = <String, Object?>{
      'ok': true,
      'reward': <String, Object?>{'type': 'coins', 'coins': 100},
      'coinBalance': 150,
      'replayed': true,
    };

    await redeem(tester);

    expect(app_state.prismUser.coins, 320);
    expect(coins.balanceNotifier.value, 320);
    expect(firestore.userDocReads, greaterThan(readsBefore));
    await tester.runAsync(() async {
      refreshed.complete(<String, dynamic>{'coins': 410});
      await pumpEventQueue();
    });
    await tester.pump();
    expect(app_state.prismUser.coins, 410);
    expect(coins.balanceNotifier.value, 410);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a replayed premium receipt does not recreate a pass absent from current state', (tester) async {
    final Completer<Map<String, dynamic>> refreshed = Completer<Map<String, dynamic>>();
    firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{'rev': 2};
    await tester.runAsync(coins.refreshBalance);
    firestore.userResponse = refreshed.future;
    reply = premiumReply(replayed: true, until: oldUntil);

    await redeem(tester);

    expect(coins.passesNotifier.value.premiumPassUntil, isNull);
    refreshed.complete(<String, dynamic>{'coins': 320});
    await tester.pump();
    expect(coins.passesNotifier.value.premiumPassUntil, isNull);
  });

  testWidgets('a replay refresh failure does not turn a successful redemption into an uncaught error', (tester) async {
    final Completer<Map<String, dynamic>> refreshed = Completer<Map<String, dynamic>>();
    firestore.userResponse = refreshed.future;
    reply = premiumReply(replayed: true, until: oldUntil);
    final int readsBefore = firestore.userDocReads;
    await redeem(tester);

    expect(firestore.userDocReads, greaterThan(readsBefore));
    refreshed.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('You got 3 days of Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(coins.passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch, currentUntil.millisecondsSinceEpoch);
  });

  testWidgets('a fresh premium receipt preserves a later pass already received locally', (tester) async {
    reply = premiumReply(replayed: false, until: oldUntil);

    await redeem(tester);

    expect(coins.passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch, currentUntil.millisecondsSinceEpoch);
  });

  testWidgets('an economy refresh that started before the grant does not shorten the new pass', (tester) async {
    final DateTime grantedUntil = DateTime(2031);
    final Completer<Map<String, dynamic>?> staleRead = Completer<Map<String, dynamic>?>();
    firestore.privateEconomyResponse = staleRead.future;
    final Future<int> refresh = coins.refreshBalance();
    reply = premiumReply(replayed: false, until: grantedUntil);

    await redeem(tester);
    expect(coins.passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch, grantedUntil.millisecondsSinceEpoch);

    await tester.runAsync(() async {
      staleRead.complete(<String, dynamic>{
        'rev': 1,
        'passes': <String, dynamic>{'premiumPassUntil': currentUntil.millisecondsSinceEpoch},
      });
      await refresh;
    });
    await tester.pump();

    expect(coins.passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch, grantedUntil.millisecondsSinceEpoch);
  });

  testWidgets('a fresh premium receipt extends an earlier local pass', (tester) async {
    coins.passesNotifier.value = Passes(premiumPassUntil: oldUntil);
    reply = premiumReply(replayed: false, until: currentUntil);

    await redeem(tester);

    expect(coins.passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch, currentUntil.millisecondsSinceEpoch);
  });
}
