import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

Map<String, Object?> _paid({Map<String, Object?> extra = const <String, Object?>{}}) => <String, Object?>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 50,
  'delta': -50,
  'reason': 'ok',
  ...extra,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  late List<Map<String, dynamic>> spends;

  String pendingRefunds() => getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: '');

  setUp(() async {
    await backend.install();
    spends = <Map<String, dynamic>>[];
    service.balanceNotifier.value = 100;
  });

  tearDown(() async {
    await getIt<SettingsLocalDataSource>().delete('pendingAiRefunds');
    app_state.prismUser = app_constants.createGuestPrismUser();
    service.resetSession();
  });

  void answer(Object? Function(int call, Map<String, dynamic> params) reply) {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      if (name != 'spendCoins') return <String, Object>{};
      spends.add(params);
      return reply(spends.length, params);
    };
  }

  test('a pass spend with a lost reply replays its request id on retry and queues no refund', () async {
    final DateTime until = DateTime.now().add(const Duration(days: 7));
    answer((int call, _) {
      if (call <= 2) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
      return _paid(extra: <String, Object?>{'passUntil': until.millisecondsSinceEpoch});
    });

    final CoinMutationResult lost = await service.spend(CoinSpendAction.autoRotatePass7d);
    expect(lost.success, isFalse);
    expect(pendingRefunds(), isEmpty);

    final CoinMutationResult retried = await service.spend(CoinSpendAction.autoRotatePass7d);
    expect(spends.map((Map<String, dynamic> p) => p['requestId']).toSet(), hasLength(1));
    expect(retried.changed, isTrue);
    expect(service.autoRotateUnlocked, isTrue);

    await service.spend(CoinSpendAction.autoRotatePass7d);
    expect(spends.last['requestId'], isNot(spends.first['requestId']));
  });

  test('each live style keeps its own stored request', () async {
    answer((_, _) => throw FirebaseFunctionsException(code: 'unavailable', message: 'lost'));

    await service.spend(CoinSpendAction.liveWallpaperStyle, styleId: 'plasma');
    await service.spend(CoinSpendAction.liveWallpaperStyle, styleId: 'starfield');

    expect(spends[0]['requestId'], spends[1]['requestId']);
    expect(spends[2]['requestId'], spends[3]['requestId']);
    expect(spends[0]['requestId'], isNot(spends[2]['requestId']));
  });

  test('a download replay that lands drops the refund queued for the lost reply', () async {
    answer((int call, _) {
      if (call <= 2) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
      return _paid();
    });

    await service.spend(CoinSpendAction.wallpaperDownload);
    final String requestId = spends.first['requestId'] as String;
    expect(pendingRefunds(), contains('spend_${backend.userId}_$requestId'));

    final CoinMutationResult replay = await service.spend(CoinSpendAction.wallpaperDownload);
    expect(spends.last['requestId'], requestId);
    expect(replay.changed, isTrue);
    expect(pendingRefunds(), isEmpty);
  });

  test('a replay whose debit was refunded charges again under a fresh request', () async {
    answer((int call, _) {
      if (call <= 2) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
      if (call == 3) {
        return <String, Object?>{
          'success': false,
          'changed': false,
          'previousBalance': 100,
          'currentBalance': 100,
          'delta': 0,
          'reason': 'spend_refunded',
        };
      }
      return _paid();
    });

    await service.spend(CoinSpendAction.premiumFilter);
    final CoinMutationResult result = await service.spend(CoinSpendAction.premiumFilter);

    expect(spends, hasLength(4));
    expect(spends[2]['requestId'], spends[0]['requestId']);
    expect(spends[3]['requestId'], isNot(spends[0]['requestId']));
    expect(result.changed, isTrue);
  });

  test('a zero price is sent to the server, only a negative one is refused locally', () async {
    answer((_, _) => _paid());

    await service.spend(CoinSpendAction.premiumFilter, amountOverride: 0);
    final CoinMutationResult negative = await service.spend(CoinSpendAction.premiumFilter, amountOverride: -1);

    expect(spends.single['amount'], 0);
    expect(negative.reason, 'invalid_amount');
  });

  test('a success with no coin change still applies the pass end and the free downloads left', () async {
    final DateTime until = DateTime.now().add(const Duration(days: 3));
    answer(
      (_, Map<String, dynamic> params) => <String, Object?>{
        'success': true,
        'changed': false,
        'bypassed': true,
        'previousBalance': 100,
        'currentBalance': 100,
        'delta': 0,
        'reason': params['action'] == 'liveWallpaperStyle' ? 'liveWallpaperStyle_already_unlocked' : 'grace_download',
        if (params['action'] == 'liveWallpaperStyle') 'passUntil': until.millisecondsSinceEpoch,
        if (params['action'] == 'wallpaperDownload') 'graceDownloadsLeft': 1,
      },
    );

    await service.spend(CoinSpendAction.liveWallpaperStyle, styleId: 'plasma');
    await service.spend(CoinSpendAction.wallpaperDownload);

    expect(
      service.currentPasses.liveStyles['plasma'],
      DateTime.fromMillisecondsSinceEpoch(until.millisecondsSinceEpoch, isUtc: true),
    );
    expect(service.graceDownloadsLeft, 1);
  });

  test('a pass reply without passUntil invents no end date', () async {
    answer((_, _) => _paid());

    await service.spend(CoinSpendAction.autoRotatePass7d);

    expect(service.currentPasses.autoRotatePassUntil, isNull);
    expect(service.autoRotateUnlocked, isFalse);
  });

  group('identity', () {
    test('passes and free downloads cached for another user are ignored', () async {
      answer(
        (_, _) => <String, Object?>{
          'success': true,
          'changed': false,
          'previousBalance': 100,
          'currentBalance': 100,
          'delta': 0,
          'graceDownloadsLeft': 0,
        },
      );
      await service.spend(CoinSpendAction.wallpaperDownload);
      service.setPassesForTest(Passes(premiumPassUntil: DateTime.now().add(const Duration(hours: 5))));
      expect(service.premiumContentUnlocked, isTrue);
      expect(service.graceDownloadsLeft, 0);

      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'someone-else'
        ..loggedIn = true;

      expect(service.premiumContentUnlocked, isFalse);
      expect(service.currentPasses.premiumPassUntil, isNull);
      expect(service.graceDownloadsLeft, CoinPolicy.graceDownloads);
    });

    test('resetSession empties every per-user value at once', () {
      service.setPassesForTest(Passes(autoRotatePassUntil: DateTime.now().add(const Duration(days: 1))));
      service.questAwardsNotifier.value = const <QuestAward>[QuestAward(id: 'fav_3', coins: 2, xp: 25)];
      app_state.prismUser = app_constants.createGuestPrismUser();

      service.resetSession();

      expect(service.balanceNotifier.value, 0);
      expect(service.passesNotifier.value.autoRotatePassUntil, isNull);
      expect(service.questAwardsNotifier.value, isEmpty);
      expect(service.questsNotifier.value, isNull);
      expect(service.inventoryNotifier.value.owned, isEmpty);
      expect(service.dropsUnlockedNotifier.value, isEmpty);
      expect(service.streakNotifier.value, StreakStatus.empty);
      expect(service.adsRemainingToday, isNull);
    });
  });
}
