import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

const Map<String, Object> _spent = <String, Object>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 95,
  'delta': -5,
  'transactionId': 'spend_tx',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  setUp(() async {
    await backend.install();
    service.balanceNotifier.value = 100;
  });
  tearDown(() async {
    await getIt<SettingsLocalDataSource>().delete('pendingAiRefunds');
  });

  test('every spend sends a fresh requestId that fits the server pattern', () async {
    final calls = <Map<String, dynamic>>[];
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') calls.add(parameters);
      return _spent;
    };

    await service.spend(CoinSpendAction.wallpaperDownload);
    await service.spend(CoinSpendAction.wallpaperDownload);

    expect(calls, hasLength(2));
    expect(calls[0]['requestId'], matches(idPattern));
    expect(calls[1]['requestId'], matches(idPattern));
    expect(calls[0]['requestId'], isNot(calls[1]['requestId']));
  });

  test('a lost reply is retried once with the same requestId', () async {
    final requestIds = <String>[];
    backend.onCall = (name, parameters) async {
      requestIds.add(parameters['requestId'] as String);
      if (requestIds.length == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost reply');
      return _spent;
    };

    final result = await service.spend(CoinSpendAction.wallpaperDownload);

    expect(requestIds, hasLength(2));
    expect(requestIds[0], requestIds[1]);
    expect(result.changed, isTrue);
    expect(result.currentBalance, 95);
  });

  test('deadline-exceeded is retried once and then gives up', () async {
    var calls = 0;
    backend.onCall = (name, parameters) {
      calls++;
      return Future<dynamic>.error(FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow'));
    };

    final result = await service.spend(CoinSpendAction.wallpaperDownload);

    expect(calls, 2);
    expect(result.success, isFalse);
    expect(result.reason, 'deadline-exceeded');
  });

  test('other errors are not retried', () async {
    var calls = 0;
    backend.onCall = (name, parameters) {
      calls++;
      return Future<dynamic>.error(FirebaseFunctionsException(code: 'permission-denied', message: 'no'));
    };

    final result = await service.spend(CoinSpendAction.wallpaperDownload);

    expect(calls, 1);
    expect(result.reason, 'permission-denied');
  });

  test('awards and refunds do not carry a requestId', () async {
    final calls = <Map<String, dynamic>>[];
    backend.onCall = (name, parameters) async {
      calls.add(parameters);
      return _spent;
    };

    await service.refundSpend(CoinSpendAction.wallpaperDownload, sourceTag: 'test', transactionId: 'tx-1');

    expect(calls.single.containsKey('requestId'), isFalse);
  });

  test('a refund that cannot reach the server is stored and retried on the next bootstrap', () async {
    backend.onCall = (name, parameters) async =>
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');

    final first = await service.rollbackAiGenerationReservation(
      AiChargeMode.coinSpend,
      reservationTransactionId: 'reservation-1',
    );
    expect(first.changed, isFalse);
    expect(
      getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''),
      contains('reservation-1'),
    );

    final refunds = <Map<String, dynamic>>[];
    backend.onCall = (name, parameters) async {
      if (name == 'awardCoins') refunds.add(parameters);
      return <String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': 90,
        'currentBalance': 100,
        'delta': 10,
      };
    };
    await service.retryPendingAiRefunds();

    expect(refunds, hasLength(1));
    expect(refunds.single['transactionId'], 'reservation-1');
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a refund the server refuses for good is not stored', () async {
    backend.onCall = (name, parameters) async =>
        throw FirebaseFunctionsException(code: 'failed-precondition', message: 'No refundable spend.');

    await service.rollbackAiGenerationReservation(AiChargeMode.coinSpend, reservationTransactionId: 'reservation-2');

    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a spend with no reply after both attempts queues a refund for the deterministic transaction id', () async {
    final requestIds = <String>[];
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') {
        requestIds.add(parameters['requestId'] as String);
        throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow');
      }
      return _spent;
    };

    final reservation = await service.reserveForAiGeneration(qualityTier: AiQualityTier.fast);

    final expectedId = 'spend_${app_state.prismUser.id}_${requestIds.first}';
    expect(reservation.success, isFalse);
    expect(reservation.refundPending, isTrue);
    expect(reservation.mutation.unknownOutcomeTransactionId, expectedId);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), contains(expectedId));
  });

  test('a definite spend failure does not queue a refund', () async {
    backend.onCall = (name, parameters) async =>
        throw FirebaseFunctionsException(code: 'permission-denied', message: 'no');

    final reservation = await service.reserveForAiGeneration(qualityTier: AiQualityTier.fast);

    expect(reservation.refundPending, isFalse);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a queued refund for a debit that never committed is dropped on retry', () async {
    backend.onCall = (name, parameters) {
      final code = name == 'spendCoins' ? 'unavailable' : 'failed-precondition';
      return Future<dynamic>.error(FirebaseFunctionsException(code: code, message: 'refused'));
    };
    await service.reserveForAiGeneration(qualityTier: AiQualityTier.fast);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isNotEmpty);

    await service.retryPendingAiRefunds();

    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a queued refund for a debit that committed is refunded on retry', () async {
    var refundedId = '';
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      refundedId = parameters['transactionId'] as String;
      return <String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': 90,
        'currentBalance': 100,
        'delta': 10,
      };
    };
    await service.reserveForAiGeneration(qualityTier: AiQualityTier.fast);

    await service.retryPendingAiRefunds();

    expect(refundedId, startsWith('spend_${app_state.prismUser.id}_'));
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a successful rollback reports the balance change and stores nothing', () async {
    backend.onCall = (name, parameters) async => <String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 90,
      'currentBalance': 100,
      'delta': 10,
    };

    final refund = await service.rollbackAiGenerationReservation(
      AiChargeMode.coinSpend,
      reservationTransactionId: 'reservation-3',
    );

    expect(refund.changed, isTrue);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('a stored refund older than the 10 minute server window is dropped without a call', () async {
    final settings = getIt<SettingsLocalDataSource>();
    final old = DateTime.now().subtract(const Duration(minutes: 11)).millisecondsSinceEpoch;
    await settings.set(
      'pendingAiRefunds',
      '[{"userId":"${app_state.prismUser.id}","transactionId":"old-tx","atMs":$old}]',
    );
    var calls = 0;
    backend.onCall = (name, parameters) async {
      calls++;
      return _spent;
    };

    await service.retryPendingAiRefunds();

    expect(calls, 0);
    expect(settings.get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
  });

  test('reserveForAiGeneration charges the tier it is given', () async {
    final calls = <Map<String, dynamic>>[];
    backend.onCall = (name, parameters) async {
      calls.add(parameters);
      return _spent;
    };

    await service.reserveForAiGeneration(qualityTier: AiQualityTier.quality);

    expect(calls.single['amount'], AiQualityTier.quality.coinCost);
  });
}
