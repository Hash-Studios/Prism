import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  final now = DateTime.utc(2026);
  for (final pair in [false, true]) {
    group(pair ? 'pair retry deadline' : 'single retry deadline', () {
      late DateTime clock;
      late SettingsLocalDataSource settings;
      late List<Map<String, dynamic>> calls;
      late OriginalAccessService service;

      OriginalAccessService createService() => OriginalAccessService(
        owner: () => 'alice',
        now: () => clock,
        call: (input) async {
          calls.add(input);
          if (input['mode'] == 'quote') return {'status': 'quoted', 'requiredCoins': 10, 'currentBalance': 40};
          final grant = {
            'url': 'https://signed.example/original',
            'expiresAt': clock.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          };
          return {
            'status': 'granted',
            if (pair)
              'grants': [
                for (final id in ['home', 'lock']) {'assetId': id, ...grant},
              ]
            else
              ...grant,
          };
        },
      );
      Future<OriginalAccessQuote> quote() => pair
          ? service.quotePair(['home', 'lock'])
          : service.quote(wallpaperId: 'wall', action: OriginalAccessAction.set);
      Future<void> acquire() async {
        if (pair) {
          await service.resolvePair(['home', 'lock'], maxCoins: 10);
        } else {
          await service.resolve(
            url: '',
            wallpaperId: 'wall',
            wallpaperSource: WallpaperSource.prism,
            action: OriginalAccessAction.set,
            maxCoins: 10,
          );
        }
      }

      setUp(() {
        clock = now;
        calls = [];
        settings = SettingsLocalDataSource(InMemoryLocalStore());
        getIt.registerSingleton<SettingsLocalDataSource>(settings);
        service = createService();
      });
      tearDown(getIt.reset);

      test('consent delay preserves five minutes of acquisition retries across restart', () async {
        await quote();
        clock = now.add(const Duration(minutes: 3));
        service = createService();
        await acquire();
        clock = now.add(const Duration(minutes: 5, seconds: 30));
        service = createService();
        await quote();
        await acquire();
        expect(calls.map((input) => input['requestId']).toSet(), hasLength(1));

        clock = now.add(const Duration(minutes: 8));
        service = createService();
        await expectLater(acquire(), throwsStateError);
        expect(calls, hasLength(4));
      });

      test('abandoned quote does not expire or start a persisted acquisition deadline', () async {
        await quote();
        final id = pair ? 'pair:home,lock' : 'wall';
        expect(settings.get<int?>('originalAccess.alice.$id.set.until'), isNull);
        clock = now.add(const Duration(minutes: 6));
        service = createService();
        await quote();
        await acquire();
        expect(calls.map((input) => input['requestId']).toSet(), hasLength(1));
        expect(
          settings.get<int?>('originalAccess.alice.$id.set.until'),
          clock.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        );
      });

      test('quoting after an expired acquisition starts a fresh consent operation', () async {
        await acquire();
        final expiredId = calls.single['requestId'];
        clock = now.add(const Duration(minutes: 6));
        service = createService();
        await quote();
        await acquire();
        expect(calls[1]['requestId'], isNot(expiredId));
        expect(calls[2]['requestId'], calls[1]['requestId']);
      });
    });
  }
  for (final source in <WallpaperSource?>[null, WallpaperSource.unknown, WallpaperSource.downloaded]) {
    for (final url in ['https://untrusted.test/original', 'HTTPS://untrusted.test/original']) {
      test('remote $source fails closed for $url', () async {
        var calls = 0;
        final service = OriginalAccessService(
          call: (_) async {
            calls++;
            return {};
          },
        );
        await expectLater(
          service.resolve(url: url, wallpaperId: 'wall', wallpaperSource: source, action: OriginalAccessAction.set),
          throwsStateError,
        );
        expect(calls, 0);
      });
    }
  }
  test('price discovery is quote-only and does not acquire an original', () async {
    final inputs = <Map<String, dynamic>>[];
    final service = OriginalAccessService(
      owner: () => 'alice',
      now: () => now,
      call: (input) async {
        inputs.add(input);
        return {'status': 'quoted', 'requiredCoins': 12, 'currentBalance': 40};
      },
    );
    final quote = await service.quote(wallpaperId: 'wall', action: OriginalAccessAction.set);
    expect(quote.requiredCoins, 12);
    expect(quote.currentBalance, 40);
    expect(inputs.single['mode'], 'quote');
    expect(inputs.single.keys, unorderedEquals(['assetId', 'action', 'requestId', 'mode']));
  });
  for (final action in OriginalAccessAction.values) {
    test('${action.name}: denied access never invokes the original consumer', () async {
      var consumed = false;
      final service = OriginalAccessService(
        owner: () => 'alice',
        call: (_) async => {'status': 'insufficient_balance', 'currentBalance': 0, 'requiredCoins': 10},
      );
      await expectLater(
        service
            .resolve(
              url: 'https://stale.example/original.jpg',
              wallpaperId: 'wall',
              wallpaperSource: WallpaperSource.prism,
              action: action,
            )
            .then((_) => consumed = true),
        throwsA(isA<OriginalAccessInsufficientBalance>()),
      );
      expect(consumed, isFalse);
    });
  }

  test('uses only the server URL and sends identity, not client price or premium', () async {
    Map<String, dynamic>? input;
    final service = OriginalAccessService(
      owner: () => 'alice',
      now: () => now,
      call: (request) async {
        input = request;
        return {
          'status': 'granted',
          'url': 'https://signed.example/original',
          'expiresAt': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        };
      },
    );
    expect(
      await service.resolve(
        url: 'https://stale.example/original',
        wallpaperId: 'canonical-wall',
        wallpaperSource: WallpaperSource.prism,
        action: OriginalAccessAction.download,
        requestId: 'tap',
      ),
      'https://signed.example/original',
    );
    expect(input, {'assetId': 'canonical-wall', 'action': 'download', 'requestId': 'tap'});
  });

  test('account switch discards a granted URL', () async {
    var owner = 'alice';
    final service = OriginalAccessService(
      owner: () => owner,
      now: () => now,
      call: (_) async {
        owner = 'bob';
        return {
          'status': 'granted',
          'url': 'https://signed.example/original',
          'expiresAt': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        };
      },
    );
    await expectLater(
      service.resolve(
        url: 'https://stale.example/original',
        wallpaperId: 'wall',
        wallpaperSource: WallpaperSource.prism,
        action: OriginalAccessAction.set,
      ),
      throwsStateError,
    );
  });

  test('a lost callable reply retries the same owner-scoped operation', () async {
    final ids = <String>[];
    final service = OriginalAccessService(
      owner: () => 'alice',
      now: () => now,
      call: (input) async {
        ids.add(input['requestId'] as String);
        if (ids.length == 1) throw StateError('transport lost after debit');
        return {
          'status': 'granted',
          'url': 'https://signed.example/original',
          'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        };
      },
    );
    Future<String> acquire() => service.resolve(
      url: '',
      wallpaperId: 'wall',
      wallpaperSource: WallpaperSource.prism,
      action: OriginalAccessAction.download,
    );
    await expectLater(acquire(), throwsStateError);
    await acquire();
    expect(ids[0], ids[1]);
  });

  test('an ambiguous acquisition survives service restart without crossing accounts', () async {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    addTearDown(getIt.reset);
    final ids = <String>[];
    var fail = true;
    Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
      ids.add(input['requestId'] as String);
      if (fail) throw StateError('reply lost');
      return {
        'status': 'granted',
        'url': 'https://signed.example/original',
        'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      };
    }

    Future<String> acquire(OriginalAccessService service) => service.resolve(
      url: '',
      wallpaperId: 'wall',
      wallpaperSource: WallpaperSource.prism,
      action: OriginalAccessAction.download,
    );
    await expectLater(
      acquire(OriginalAccessService(owner: () => 'alice', now: () => now, call: call)),
      throwsStateError,
    );
    fail = false;
    await acquire(OriginalAccessService(owner: () => 'alice', now: () => now, call: call));
    await acquire(OriginalAccessService(owner: () => 'bob', now: () => now, call: call));
    expect(ids[0], ids[1]);
    expect(ids[2], isNot(ids[0]));
  });

  test('native save failure keeps the granted operation until explicit success', () async {
    final ids = <String>[];
    final service = OriginalAccessService(
      owner: () => 'alice',
      now: () => now,
      call: (input) async {
        ids.add(input['requestId'] as String);
        return {
          'status': 'granted',
          'url': 'https://signed.example/original',
          'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        };
      },
    );
    Future<String> acquire() => service.resolve(
      url: '',
      wallpaperId: 'wall',
      wallpaperSource: WallpaperSource.prism,
      action: OriginalAccessAction.download,
    );
    await acquire();
    // A downstream save/transform failure does not call complete.
    await acquire();
    expect(ids[0], ids[1]);
    await service.complete(wallpaperId: 'wall', action: OriginalAccessAction.download);
    await acquire();
    expect(ids[2], isNot(ids[1]));
  });

  test('a Prism descriptor with a local-looking URL still requires a grant', () async {
    final service = OriginalAccessService(
      owner: () => 'alice',
      call: (_) async => {'status': 'insufficient_balance', 'requiredCoins': 10, 'currentBalance': 0},
    );
    await expectLater(
      service.resolve(
        url: '/cache/unproven.jpg',
        wallpaperId: 'wall',
        wallpaperSource: WallpaperSource.prism,
        action: OriginalAccessAction.edit,
      ),
      throwsA(isA<OriginalAccessInsufficientBalance>()),
    );
  });

  test('two protected pair assets share one quote, aggregate consent and acquisition request', () async {
    final calls = <Map<String, dynamic>>[];
    final service = OriginalAccessService(
      owner: () => 'alice',
      now: () => now,
      call: (input) async {
        calls.add(input);
        if (input['mode'] == 'quote') return {'status': 'quoted', 'requiredCoins': 5, 'currentBalance': 20};
        return {
          'status': 'granted',
          'grants': [
            for (final id in ['home', 'lock'])
              {
                'assetId': id,
                'url': 'https://signed.example/$id',
                'expiresAt': now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
                'generation': '1',
              },
          ],
        };
      },
    );
    final quote = await service.quotePair(['home', 'lock']);
    expect(quote.requiredCoins, 5);
    final result = await service.resolvePair(['home', 'lock'], maxCoins: quote.requiredCoins);
    expect(result.keys, ['home', 'lock']);
    expect(calls, hasLength(2));
    expect(calls[1]['assets'], [
      {'assetId': 'home', 'action': 'set'},
      {'assetId': 'lock', 'action': 'set'},
    ]);
    expect(calls[1]['maxCoins'], 5);
    expect(calls[1]['requestId'], calls[0]['requestId']);
    expect(calls[1].containsKey('assetId'), isFalse);
  });
}
