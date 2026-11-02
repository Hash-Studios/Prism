import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_photo/views/open_live_photo.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';
import 'fake_live_photo_repository.dart';

typedef _Resolve = ({String url, String? wallpaperId, WallpaperSource? source, OriginalAccessAction action});

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  late FakeLivePhotoRepository repository;
  late List<_Resolve> resolves;
  late int paywalls;
  late String? grant;
  Completer<String?>? pendingGrant;

  setUp(() {
    PrismDeviceCornerRadius.setValueForTesting(48);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    repository = FakeLivePhotoRepository();
    getIt.registerSingleton<LivePhotoRepository>(repository);
    resolves = <_Resolve>[];
    paywalls = 0;
    grant = 'file:///tmp/original.jpg';
    pendingGrant = null;
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
          return pendingGrant == null ? grant : await pendingGrant!.future;
        };
    livePhotoPaywall = (context) async => paywalls++;
  });

  tearDown(() async {
    await getIt.unregister<LivePhotoRepository>();
    if (getIt.isRegistered<SessionRepository>()) await getIt.unregister<SessionRepository>();
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

  testWidgets('a Pro wall cannot export after Pro access ends with the sheet open', (tester) async {
    await open(tester, premiumWall: true, premiumUser: true);
    app_state.prismUser = profileUser();

    await save(tester);

    expect(resolves, isEmpty);
    expect(repository.exports, isEmpty);
    expect(find.text('Save Live Photo'), findsOneWidget);
  });

  testWidgets('a sheet opened by another account cannot resolve or export the original', (tester) async {
    await open(tester, premiumWall: false, premiumUser: true);
    app_state.prismUser = profileUser(id: 'other', premium: true);

    await save(tester);

    expect(resolves, isEmpty);
    expect(repository.exports, isEmpty);
  });

  testWidgets('sign-out during original consent discards the grant', (tester) async {
    pendingGrant = Completer<String?>();
    await open(tester, premiumWall: false, premiumUser: false);
    await save(tester);
    expect(resolves, hasLength(1));

    app_state.prismUser = profileUser(loggedIn: false);
    pendingGrant!.complete('file:///tmp/original.jpg');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.exports, isEmpty);
    expect(find.text('Save Live Photo'), findsOneWidget);
  });

  testWidgets('a paid style cannot export using the Pro snapshot after access ends', (tester) async {
    await open(tester, premiumWall: false, premiumUser: true);
    await tester.tap(find.text('Breathe'));
    await tester.pump();
    app_state.prismUser = profileUser();

    await save(tester);

    expect(repository.exports, isEmpty);
    expect(resolves, isEmpty);
  });

  testWidgets('an account change while rendering cancels the current export', (tester) async {
    final _MockSessionRepository session = _MockSessionRepository();
    final StreamController<PrismUsersV2> users = StreamController<PrismUsersV2>.broadcast();
    PrismUsersV2 current = profileUser(premium: true);
    when(() => session.currentUser).thenAnswer((_) => current);
    when(() => session.watchCurrentUser()).thenAnswer((_) => users.stream);
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(users.close);

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
                premiumWall: false,
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
    await save(tester);
    expect(repository.exports, hasLength(1));

    current = profileUser(id: 'other', premium: true);
    users.add(current);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.cancelCount, 1);
    expect(find.text('Save Live Photo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
