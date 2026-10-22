import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _RecordingSession extends Fake implements SessionRepository {
  _RecordingSession(this.currentUser);

  @override
  PrismUsersV2 currentUser;
  final List<int> persisted = [];

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    currentUser = user;
    persisted.add(user.coins);
    return Result.success(SessionEntity.guest);
  }

  @override
  Stream<PrismUsersV2> watchCurrentUser() => Stream.value(currentUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;
  late CoinsTestFirestore firestore;
  late _RecordingSession session;

  setUp(() async {
    await getIt.reset();
    await backend.install();
    backend.onCall = (_, _) async => <String, Object?>{};
    firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    session = _RecordingSession(app_state.prismUser);
    getIt.registerSingleton<SessionRepository>(session);
    service.resetSession();
  });

  tearDown(() async {
    service.resetSession();
    await getIt.reset();
  });

  for (final pair in [false, true]) {
    for (final balance in <Object?>[null, -1, 1.5, double.infinity, '90']) {
      test('${pair ? 'pair' : 'single'} rejects malformed grant balance $balance before publishing it', () async {
        final now = DateTime.utc(2026);
        final originals = OriginalAccessService(
          now: () => now,
          call: (_) async {
            final grant = {
              'url': 'https://signed.example/original',
              'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
            };
            return {
              'status': 'granted',
              'currentBalance': balance,
              if (pair)
                'grants': [
                  for (final id in ['home', 'lock']) {'assetId': id, ...grant},
                ]
              else
                ...grant,
            };
          },
        );
        await expectLater(
          pair
              ? originals.resolvePair(['home', 'lock'], maxCoins: 10)
              : originals.resolve(
                  url: '',
                  wallpaperId: 'wall',
                  wallpaperSource: WallpaperSource.prism,
                  action: OriginalAccessAction.set,
                ),
          throwsStateError,
        );
        expect(app_state.prismUser.coins, 100);
        expect(service.balanceNotifier.value, 100);
        expect(session.persisted, isEmpty);
      });
    }

    test('${pair ? 'pair' : 'single'} late grant cannot update the next owner', () async {
      final now = DateTime.utc(2026);
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      final originals = OriginalAccessService(
        now: () => now,
        call: (_) {
          started.complete();
          return response.future;
        },
      );
      final pending = pair
          ? originals.resolvePair(['home', 'lock'], maxCoins: 10)
          : originals.resolve(
              url: '',
              wallpaperId: 'wall',
              wallpaperSource: WallpaperSource.prism,
              action: OriginalAccessAction.set,
            );
      final rejected = expectLater(pending, throwsStateError);
      await started.future;
      session.currentUser.id = 'next-owner';
      session.currentUser.coins = 7;
      service.resetSession();
      final grant = {
        'url': 'https://signed.example/original',
        'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      };
      response.complete({
        'status': 'granted',
        'currentBalance': 90,
        if (pair)
          'grants': [
            for (final id in ['home', 'lock']) {'assetId': id, ...grant},
          ]
        else
          ...grant,
      });
      await rejected;
      expect(app_state.prismUser.coins, 7);
      expect(service.balanceNotifier.value, 7);
      expect(session.persisted, isEmpty);
    });

    test('${pair ? 'pair' : 'single'} grant and replay persist the server balance without double debit', () async {
      final now = DateTime.utc(2026);
      final calls = <Map<String, dynamic>>[];
      final originals = OriginalAccessService(
        now: () => now,
        call: (input) async {
          calls.add(input);
          if (input['mode'] == 'quote') return {'status': 'quoted', 'requiredCoins': 10, 'currentBalance': 100};
          final grant = {
            'url': 'https://signed.example/original',
            'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          };
          return {
            'status': 'granted',
            'currentBalance': 90,
            if (pair)
              'grants': [
                for (final id in ['home', 'lock']) {'assetId': id, ...grant},
              ]
            else
              ...grant,
          };
        },
      );
      final quote = pair
          ? await originals.quotePair(['home', 'lock'])
          : await originals.quote(wallpaperId: 'wall', action: OriginalAccessAction.set);
      expect(quote.currentBalance, 100);
      for (var attempt = 0; attempt < 2; attempt++) {
        if (pair) {
          await originals.resolvePair(['home', 'lock'], maxCoins: quote.requiredCoins);
        } else {
          await originals.resolve(
            url: '',
            wallpaperId: 'wall',
            wallpaperSource: WallpaperSource.prism,
            action: OriginalAccessAction.set,
            maxCoins: quote.requiredCoins,
          );
        }
        expect(app_state.prismUser.coins, 90);
        expect(service.balanceNotifier.value, 90);
        expect(session.persisted, isNotEmpty);
        expect(session.persisted, everyElement(90));
      }
      expect(calls.map((input) => input['requestId']).toSet(), hasLength(1));
    });
  }

  for (final bootstrap in [false, true]) {
    for (final mutation in [
      'spend',
      'award',
      'refund',
      'external',
      'unchanged external',
      'unchanged spend',
      'unchanged award',
      'unchanged refund',
    ]) {
      test('${bootstrap ? 'bootstrap' : 'refresh'} rejects a root balance read older than $mutation', () async {
        final response = Completer<Map<String, dynamic>>();
        firestore.userResponse = response.future;
        // An unchanged authoritative reply must still invalidate the older 100 read.
        final expected = mutation.startsWith('unchanged') ? 100 : (mutation == 'award' ? 108 : 90);
        final pending = bootstrap ? service.bootstrapForCurrentUser().then((_) => null) : service.refreshBalance();
        await pumpEventQueue();
        expect(firestore.userDocReads, 1);
        backend.onCall = (_, _) async => <String, Object>{
          'success': true,
          'changed': !mutation.startsWith('unchanged'),
          'previousBalance': 100,
          'currentBalance': expected,
          'delta': expected - 100,
        };
        switch (mutation) {
          case 'spend':
          case 'unchanged spend':
            await service.spend(CoinSpendAction.wallpaperDownload);
          case 'award':
          case 'unchanged award':
            await service.award(CoinEarnAction.dailyLogin);
          case 'refund':
          case 'unchanged refund':
            await service.refundSpend(
              CoinSpendAction.wallpaperDownload,
              sourceTag: 'test.refund',
              transactionId: 'prior-debit',
            );
          default:
            service.applyServerBalance(expected);
        }
        response.complete({'coins': mutation.startsWith('unchanged') ? 50 : 100});
        final accepted = await pending;
        if (!bootstrap) expect(accepted, expected);
        expect(app_state.prismUser.coins, expected);
        expect(service.balanceNotifier.value, expected);
        expect(session.persisted, everyElement(expected));
        if (expected != 100) expect(session.persisted, isNotEmpty);
      });
    }
  }
}
