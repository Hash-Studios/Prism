import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_photo/views/open_live_photo.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';
import 'fake_live_photo_repository.dart';

typedef _Resolve = ({String url, String? wallpaperId, WallpaperSource? source, OriginalAccessAction action});

void main() {
  late FakeLivePhotoRepository repository;
  late List<_Resolve> resolves;
  late int paywalls;
  late String? grant;

  setUp(() {
    PrismDeviceCornerRadius.setValueForTesting(48);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    repository = FakeLivePhotoRepository();
    getIt.registerSingleton<LivePhotoRepository>(repository);
    resolves = <_Resolve>[];
    paywalls = 0;
    grant = 'file:///tmp/original.jpg';
    livePhotoResolveOriginal =
        (
          context, {
          required url,
          required wallpaperId,
          required wallpaperSource,
          required action,
          required label,
        }) async {
          resolves.add((url: url, wallpaperId: wallpaperId, source: wallpaperSource, action: action));
          return grant;
        };
    livePhotoPaywall = (context) async => paywalls++;
  });

  tearDown(() async {
    await getIt.unregister<LivePhotoRepository>();
    AnalyticsRuntime.reset();
  });

  Future<void> open(WidgetTester tester, {required bool premiumWall, required bool premiumUser}) async {
    app_state.prismUser = profileUser(premium: premiumUser);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openLivePhoto(
                context,
                url: 'https://cdn.example.com/protected.jpg',
                wallId: 'wall-7',
                wallpaperSource: WallpaperSource.prism,
                premiumWall: premiumWall,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save Live Photo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a protected wall takes the Download grant on Save, not on open', (tester) async {
    await open(tester, premiumWall: false, premiumUser: false);
    expect(resolves, isEmpty);

    await save(tester);

    expect(resolves, hasLength(1));
    expect(resolves.single.action, OriginalAccessAction.download);
    expect(resolves.single.url, 'https://cdn.example.com/protected.jpg');
    expect(resolves.single.wallpaperId, 'wall-7');
    expect(resolves.single.source, WallpaperSource.prism);
    expect(repository.imageUrls, <String>['file:///tmp/original.jpg']);
    repository.complete(const LiveExportCancelled());
    await tester.pump();
  });

  testWidgets('a declined consent exports nothing and keeps the picker', (tester) async {
    grant = null;
    await open(tester, premiumWall: false, premiumUser: false);

    await save(tester);

    expect(resolves, hasLength(1));
    expect(repository.exports, isEmpty);
    expect(find.text('Save Live Photo'), findsOneWidget);
  });

  testWidgets('a Pro wall opens the paywall for a user without Pro and shows no sheet', (tester) async {
    await open(tester, premiumWall: true, premiumUser: false);

    expect(paywalls, 1);
    expect(find.text('Save Live Photo'), findsNothing);
    expect(resolves, isEmpty);
  });

  testWidgets('a Pro wall opens the sheet for a Pro user', (tester) async {
    await open(tester, premiumWall: true, premiumUser: true);

    expect(paywalls, 0);
    expect(find.text('Save Live Photo'), findsOneWidget);
  });
}
