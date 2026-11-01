import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  final now = DateTime.utc(2026);
  late List<Map<String, dynamic>> calls;

  setUp(() {
    calls = [];
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });
  tearDown(getIt.reset);

  test('desktop quote sends variant desktop, phone quote sends none, and the requestIds differ', () async {
    final service = OriginalAccessService(
      owner: () => 'u1',
      now: () => now,
      call: (input) async {
        calls.add(input);
        return {'status': 'quoted', 'requiredCoins': 5, 'currentBalance': 20};
      },
    );

    await service.quote(wallpaperId: 'W1', action: OriginalAccessAction.set, desktop: true);
    await service.quote(wallpaperId: 'W1', action: OriginalAccessAction.set);

    expect(calls, hasLength(2));
    expect(calls[0]['requestId'], isA<String>());
    final Map<String, dynamic> desktopInput = Map<String, dynamic>.from(calls[0])..remove('requestId');
    expect(desktopInput, {'assetId': 'W1', 'action': 'set', 'mode': 'quote', 'variant': 'desktop'});
    expect(calls[1].containsKey('variant'), isFalse);
    expect(calls[0]['requestId'], isNot(calls[1]['requestId']));
  });

  test('desktop resolve returns the granted url and sends variant desktop', () async {
    final service = OriginalAccessService(
      owner: () => 'u1',
      now: () => now,
      call: (input) async {
        calls.add(input);
        return {
          'status': 'granted',
          'url': 'https://r2.example/x',
          'expiresAt': now.millisecondsSinceEpoch + 60000,
          'currentBalance': 5,
        };
      },
    );

    final String url = await service.resolve(
      url: '',
      wallpaperId: 'W1',
      wallpaperSource: WallpaperSource.prism,
      action: OriginalAccessAction.set,
      desktop: true,
    );

    expect(url, 'https://r2.example/x');
    expect(calls.single, containsPair('variant', 'desktop'));
    expect(calls.single, containsPair('assetId', 'W1'));
  });

  test('desktop variants still require a grant for a bundled starter wall', () async {
    final service = OriginalAccessService(
      owner: () => 'u1',
      now: () => now,
      call: (input) async {
        calls.add(input);
        return {
          'status': 'granted',
          'url': 'https://r2.example/desktop',
          'expiresAt': now.millisecondsSinceEpoch + 60000,
          'currentBalance': 5,
        };
      },
    );

    final String url = await service.resolve(
      url: 'https://img.example/starter.jpg',
      wallpaperId: 'starter-prism',
      wallpaperSource: WallpaperSource.prism,
      action: OriginalAccessAction.set,
      desktop: true,
    );

    expect(url, 'https://r2.example/desktop');
    expect(calls.single, containsPair('variant', 'desktop'));
  });

  test('the desktop grant rule does not inherit the phone original exemptions', () {
    expect(
      OriginalAccessService.requiresGrant(
        'https://img.example/starter.jpg',
        'starter-prism',
        WallpaperSource.prism,
        desktop: true,
      ),
      isTrue,
    );
    expect(
      OriginalAccessService.requiresGrant(
        'https://img.example/starter.jpg',
        'starter-prism',
        WallpaperSource.prism,
      ),
      isFalse,
    );
  });

  test('desktop versions use distinct request ids', () async {
    final service = OriginalAccessService(
      owner: () => 'u1',
      now: () => now,
      call: (input) async {
        calls.add(input);
        return {'status': 'quoted', 'requiredCoins': 5, 'currentBalance': 20};
      },
    );

    await service.quote(
      wallpaperId: 'W1',
      action: OriginalAccessAction.set,
      desktop: true,
      desktopVersion: '0123456789abcdef',
    );
    await service.quote(
      wallpaperId: 'W1',
      action: OriginalAccessAction.set,
      desktop: true,
      desktopVersion: 'fedcba9876543210',
    );
    expect(calls.map((call) => call['requestId']).toSet(), hasLength(2));
    expect(calls[0]['requestId'], isNot(calls[1]['requestId']));
  });
}
