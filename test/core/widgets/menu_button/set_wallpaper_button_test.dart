import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/offline_asset_fixture.dart';
import '../../../support/profile_user_fixture.dart';

final AppLocalizationsEn l10n = AppLocalizationsEn();

/// The Set screen that [SetWallpaperFlow] opens over the page.
Finder get setScreen => find.byType(ClockOverlay);

class _MockStackRouter extends Mock implements StackRouter {}

class _DownloadedWallIndex extends Mock implements DownloadedWallIndex {}

/// Lets real file IO finish inside an Undo. Each step of the undo chain waits on the real event loop, so one pump is not
/// enough.
Future<void> settleUndoIo(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

class _Client implements WallpaperClient {
  _Client({this.capabilities = const aw.WallpaperCapabilities(), this.status = aw.WallpaperOperationStatus.applied});

  final aw.WallpaperCapabilities capabilities;
  aw.WallpaperOperationStatus status;

  /// Per target overrides, for a half that fails.
  Object? capabilitiesError;
  final Map<aw.WallpaperTarget, aw.WallpaperOperationStatus> statusFor =
      <aw.WallpaperTarget, aw.WallpaperOperationStatus>{};
  String? errorCode;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];
  final List<aw.WallpaperOperationResult> scriptedResults = <aw.WallpaperOperationResult>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async {
    final Object? error = capabilitiesError;
    if (error != null) throw error;
    return capabilities;
  }

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    if (scriptedResults.isNotEmpty) return scriptedResults.removeAt(0);
    final aw.WallpaperOperationStatus result = statusFor[request.target] ?? status;
    return aw.WallpaperOperationResult(
      status: result,
      requestedTarget: request.target,
      errorCode: result == aw.WallpaperOperationStatus.applied ? null : errorCode,
    );
  }

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

void main() {
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late OfflineAssetFixture assets;
  late String wallFilePath;
  late String lockFilePath;
  late String thumbnailFilePath;
  final studioOpener = SetWallpaperFlow.studioOpener;
  final pairPicker = SetWallpaperFlow.pairPicker;
  final screenOpener = SetWallpaperFlow.screenOpener;
  final signIn = signedInActionSignIn;

  setUp(() async {
    app_state.prismUser = profileUser();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    assets = await OfflineAssetFixture.create();
    assets.install(immediateResolver: true);
    wallFilePath = assets.createImageSync('wall.png').path;
    lockFilePath = assets.createImageSync('lock.png').path;
    thumbnailFilePath = assets.createImageSync('thumbnail.png').path;
    assets.mapSource('/tmp/wall.png', File(wallFilePath));
    assets.mapSource('/tmp/lock.png', File(lockFilePath));
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    SetWallpaperFlow.studioOpener = studioOpener;
    SetWallpaperFlow.pairPicker = pairPicker;
    SetWallpaperFlow.screenOpener = screenOpener;
    signedInActionSignIn = signIn;
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
    await assets.dispose();
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    VoidCallback? onSet,
    String? label,
    String? thumbnailUrl,
    String? entryPoint,
    List<String> notes = const <String>[],
    VoidCallback? onMatchAccent,
    Future<String> Function()? prepareSource,
    Future<String> Function(String)? prepareAuthorized,
    bool primary = false,
    WallpaperSource? source,
    String? wallpaperId,
    WallpaperTarget? target,
    String url = '/tmp/wall.png',
  }) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: Center(
            child: SetWallpaperButton(
              url: url,
              wallpaperSource: source,
              wallpaperId: wallpaperId,
              thumbnailUrl: thumbnailUrl,
              onSet: onSet,
              label: label,
              entryPoint: entryPoint,
              notes: notes,
              onMatchAccent: onMatchAccent,
              prepareSource: prepareSource,
              prepareAuthorized: prepareAuthorized,
              primary: primary,
              target: target,
            ),
          ),
        ),
      ),
    );
  }

  /// Taps Set on the button, which opens the Set screen.
  Future<void> openSetScreen(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
  }

  /// On the open Set screen, picks [target] (Home is the default) and taps Set.
  Future<void> setOn(WidgetTester tester, WallpaperTarget target) async {
    if (target != WallpaperTarget.home) {
      final String label = switch (target) {
        WallpaperTarget.lock => l10n.setScreenTargetLock,
        WallpaperTarget.both => l10n.setScreenTargetBoth,
        WallpaperTarget.home => l10n.setScreenTargetHome,
      };
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-set')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// A PNG in a folder of its own, as the studio hands it back. The flow deletes that folder after a set.
  String placedWallFile() {
    final Directory dir = Directory.systemTemp.createTempSync('set-screen-placed');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final File file = File('${dir.path}/placed.png')..writeAsBytesSync(File(wallFilePath).readAsBytesSync());
    assets.mapSource(file.path, file);
    return file.path;
  }

  testWidgets('closing the Set screen never quotes, grants, charges, or applies a protected original', (tester) async {
    final backend = CoinsTestBackend();
    await backend.install();
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    var callableCount = 0;
    backend.onCall = (_, _) async {
      callableCount++;
      throw StateError('No acquire expected');
    };
    final client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');
    await openSetScreen(tester);
    expect(setScreen, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip(l10n.setScreenClose));
    await tester.pumpAndSettle();
    expect(callableCount, 0);
    expect(client.requests, isEmpty);
  });

  group('signed-out user', () {
    late CoinsTestBackend backend;
    late List<Map<String, dynamic>> calls;
    late int signIns;

    Future<CoinsTestBackend> asGuest(WidgetTester tester, {required bool signsIn}) async {
      backend = CoinsTestBackend();
      await backend.install();
      final signedInUser = app_state.prismUser;
      app_state.prismUser = app_constants.createGuestPrismUser();
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '${assets.directory.path}/scratch',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      calls = <Map<String, dynamic>>[];
      backend.onCall = (name, input) async {
        expect(name, 'resolveOriginalAccess');
        if (!app_state.prismUser.loggedIn) {
          throw FirebaseFunctionsException(code: 'unauthenticated', message: 'Sign in to access originals.');
        }
        calls.add(input);
        if (input['mode'] == 'quote') {
          return <String, dynamic>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
        }
        return <String, dynamic>{
          'status': 'granted',
          'url': 'https://signed.test/${input['assetId']}',
          'expiresAt': DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          'currentBalance': 100,
        };
      };
      signIns = 0;
      signedInActionSignIn = (_) async {
        signIns++;
        if (signsIn) app_state.prismUser = signedInUser;
        return signsIn;
      };
      return backend;
    }

    testWidgets('Set on a protected wall asks a guest to sign in and calls nothing when they leave', (tester) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();

      expect(signIns, 1);
      expect(setScreen, findsNothing);
      expect(calls, isEmpty);
      expect(client.requests, isEmpty);
    });

    testWidgets('opening the Set screen requires sign-in first', (tester) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');

      await openSetScreen(tester);
      expect(signIns, 1);
      expect(setScreen, findsNothing);
      expect(calls, isEmpty);
      expect(client.requests, isEmpty);
    });

    testWidgets('a cancelled sign-in never opens Adjust or prepares the image', (tester) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      var preparations = 0;
      await pumpButton(
        tester,
        source: WallpaperSource.prism,
        wallpaperId: 'protected-wall',
        url: '',
        prepareSource: () async {
          preparations++;
          return wallFilePath;
        },
      );

      await openSetScreen(tester);
      expect(signIns, 1);
      expect(setScreen, findsNothing);
      expect(preparations, 0);
      expect(calls, isEmpty);
      expect(client.requests, isEmpty);
    });

    testWidgets('after a guest signs in, Set goes on and sets the original', (tester) async {
      await asGuest(tester, signsIn: true);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      assets.mapSource('https://signed.test/protected-wall', File(wallFilePath));
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(signIns, 1);
      expect(calls.map((call) => (call['assetId'], call['action'], call['mode'])), [
        ('protected-wall', 'set', 'quote'),
        ('protected-wall', 'set', null),
      ]);
      expect(client.requests.map((r) => (r.target, r.source.filePath)), [(aw.WallpaperTarget.home, wallFilePath)]);
    });

    testWidgets('Set stops if the owner changes while original access is being quoted', (tester) async {
      final backend = await asGuest(tester, signsIn: true);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      var quotes = 0;
      backend.onCall = (name, input) async {
        quotes++;
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = 'different-owner'
          ..loggedIn = true;
        return <String, dynamic>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
      };
      await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');

      await openSetScreen(tester);
      await setOn(tester, WallpaperTarget.home);

      expect(signIns, 1);
      expect(quotes, 1);
      expect(client.requests, isEmpty);
    });

    testWidgets('a fixed target prepares the consented original and retries on that target', (tester) async {
      await asGuest(tester, signsIn: true);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      assets.mapSource('https://signed.test/protected-wall', File(wallFilePath));
      final String preparedPath = assets.createImageSync('tinted-protected-wall.png').path;
      final client = _Client()..statusFor[aw.WallpaperTarget.lock] = aw.WallpaperOperationStatus.failed;
      aw.AsyncWallpaper.debugSetClient(client);
      final List<String> preparedSources = <String>[];
      await pumpButton(
        tester,
        source: WallpaperSource.prism,
        wallpaperId: 'protected-wall',
        url: '',
        target: WallpaperTarget.lock,
        prepareAuthorized: (source) async {
          preparedSources.add(source);
          return preparedPath;
        },
      );

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
      await tester.pumpAndSettle();

      expect(preparedSources, <String>['https://signed.test/protected-wall']);
      final int initialRequestCount = client.requests.length;
      expect(initialRequestCount, greaterThanOrEqualTo(2));
      expect(client.requests, everyElement(isA<aw.StaticWallpaperRequest>()));
      expect(client.requests.map((request) => request.target), everyElement(aw.WallpaperTarget.lock));
      expect(client.requests.map((request) => request.source.filePath), everyElement(preparedPath));
      expect(find.text(l10n.coreTryAgain), findsOneWidget);

      client.statusFor[aw.WallpaperTarget.lock] = aw.WallpaperOperationStatus.applied;
      await tester.tap(find.text(l10n.coreTryAgain));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests, hasLength(initialRequestCount + 1));
      expect(client.requests.last.target, aw.WallpaperTarget.lock);
      expect(client.requests.last.source.filePath, preparedPath);
      expect(preparedSources, hasLength(1));
      expect(settings.get<String>(PersistenceKeys.defaultApplyTarget), 'home');
      expect(calls.map((call) => (call['assetId'], call['action'], call['mode'])), [
        ('protected-wall', 'set', 'quote'),
        ('protected-wall', 'set', null),
      ]);
    });

    testWidgets('Set on a local wall still requires sign-in', (tester) async {
      await asGuest(tester, signsIn: false);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(signIns, 1);
      expect(client.requests, isEmpty);
    });

    testWidgets('a prepared Wallhaven Set keeps its canonical history URL and can be undone', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => assets.directory.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      final String previousPath = assets.createImageSync('prepared-previous.png').path;
      final String preparedPath = '${assets.directory.path}/scratch/prepared-tint.png';
      const String sourceUrl = 'https://wallhaven.cc/w/prepared-history';
      assets.mapSource(sourceUrl, File(wallFilePath));
      File(preparedPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File(wallFilePath).readAsBytesSync());
      assets.mapSource(preparedPath, File(preparedPath));
      final store = WallpaperHistoryStore(settings);
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      await store.record(
        AppliedWallpaper(
          id: 'previous-prepared-wall',
          source: 'local',
          thumbnailUrl: previousPath,
          fullUrl: previousPath,
          target: WallpaperTarget.home.name,
          appliedAt: DateTime(2025),
        ),
      );
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(
        tester,
        source: WallpaperSource.wallhaven,
        url: sourceUrl,
        prepareAuthorized: (_) async => preparedPath,
      );

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.single.source.filePath, preparedPath);
      final AppliedWallpaper set = store.items().singleWhere((item) => item.id != 'previous-prepared-wall');
      expect(set.fullUrl, sourceUrl);
      expect(set.source, 'wallhaven');
      expect(set.originalIdentity, isNull);
      expect(find.text(l10n.coreUndo), findsOneWidget);
      await tester.tap(find.text(l10n.coreUndo));
      await settleUndoIo(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.last.source.filePath, previousPath);
      expect(store.items().map((item) => item.id), <String>['previous-prepared-wall']);
    });

    testWidgets('a prepared protected Prism Set keeps its original identity and can be undone', (tester) async {
      await asGuest(tester, signsIn: true);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      const String sourceUrl = 'https://signed.test/prepared-protected';
      assets.mapSource(sourceUrl, File(wallFilePath));
      final String previousPath = assets.createImageSync('protected-prepared-previous.png').path;
      final String preparedPath = '${assets.directory.path}/scratch/prepared-protected.png';
      File(preparedPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File(wallFilePath).readAsBytesSync());
      assets.mapSource(preparedPath, File(preparedPath));
      final store = WallpaperHistoryStore(settings);
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      await store.record(
        AppliedWallpaper(
          id: 'previous-protected-prepared',
          source: 'local',
          thumbnailUrl: previousPath,
          fullUrl: previousPath,
          target: WallpaperTarget.home.name,
          appliedAt: DateTime(2025),
        ),
      );
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(
        tester,
        source: WallpaperSource.prism,
        wallpaperId: 'prepared-protected',
        url: '',
        prepareAuthorized: (_) async => preparedPath,
      );

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(signIns, 1);
      expect(calls.map((call) => (call['assetId'], call['mode'])), <(Object?, Object?)>[
        ('prepared-protected', 'quote'),
        ('prepared-protected', null),
      ]);
      expect(client.requests.single.source.filePath, preparedPath);
      final AppliedWallpaper set = store.items().singleWhere((item) => item.id != 'previous-protected-prepared');
      expect(set.fullUrl, wallFilePath);
      expect(set.originalIdentity, 'prism:prepared-protected');
      expect(File(set.fullUrl).readAsBytesSync(), File(wallFilePath).readAsBytesSync());
      expect(find.text(l10n.coreUndo), findsOneWidget);
      await tester.tap(find.text(l10n.coreUndo));
      await settleUndoIo(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.last.source.filePath, previousPath);
      expect(store.items().map((item) => item.id), <String>['previous-protected-prepared']);
    });

    testWidgets('Adjust then Set on a protected wall asks for consent once and sets the placed file', (tester) async {
      await asGuest(tester, signsIn: true);
      assets.mapSource('https://signed.test/protected-wall', File(wallFilePath));
      final String placedPath = placedWallFile();
      final String previousWallPath = assets.createImageSync('previous-wallpaper.png').path;
      final store = WallpaperHistoryStore(settings);
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      await store.record(
        AppliedWallpaper(
          id: 'previous-wallpaper',
          source: 'local',
          thumbnailUrl: previousWallPath,
          fullUrl: previousWallPath,
          target: WallpaperTarget.home.name,
          appliedAt: DateTime(2025),
        ),
      );
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final List<String> studioUrls = <String>[];
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
        studioUrls.add(url);
        return PlacedWallpaper(path: placedPath, placement: const WallpaperPlacement());
      };
      await pumpButton(
        tester,
        source: WallpaperSource.prism,
        wallpaperId: 'protected-wall',
        url: '',
        thumbnailUrl: thumbnailFilePath,
      );

      await openSetScreen(tester);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await setOn(tester, WallpaperTarget.home);

      expect(signIns, 1);
      expect(studioUrls, <String>['https://signed.test/protected-wall']);
      expect(calls.map((call) => (call['assetId'], call['action'], call['mode'])), [
        ('protected-wall', 'set', 'quote'),
        ('protected-wall', 'set', null),
      ]);
      expect(client.requests.first.source.filePath, placedPath);
      final AppliedWallpaper placedHistory = store.items().singleWhere((item) => item.id != 'previous-wallpaper');
      expect(placedHistory.wallpaperId, 'protected-wall');
      expect(placedHistory.source, 'prism');
      expect(placedHistory.originalIdentity, 'prism:protected-wall');
      expect(placedHistory.fullUrl, isNot(startsWith('https:')));
      expect(placedHistory.fullUrl, wallFilePath);
      expect(File(placedHistory.fullUrl).readAsBytesSync(), File(wallFilePath).readAsBytesSync());
      expect(find.text(l10n.coreUndo), findsOneWidget);
      await tester.tap(find.text(l10n.coreUndo));
      await settleUndoIo(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(client.requests.map((request) => request.source.filePath), <String>[placedPath, previousWallPath]);
      expect(store.items().map((item) => item.id), <String>['previous-wallpaper']);
    });

    PairPick protectedPick() => PairPick(
      source: PairSource.favourites,
      candidate: PairCandidate(
        fullUrl: '',
        thumbnailUrl: lockFilePath,
        wallpaperId: 'protected-lock',
        wallpaperSource: WallpaperSource.prism,
      ),
    );

    Future<void> openPair(WidgetTester tester) async {
      await openSetScreen(tester);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setScreenPairLock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('Adjust then Pair reuses the home original grant and charges only for the lock pick', (tester) async {
      await asGuest(tester, signsIn: true);
      assets.mapSource('https://signed.test/protected-wall', File(wallFilePath));
      assets.mapSource('https://signed.test/protected-lock', File(lockFilePath));
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      var prepares = 0;
      SetWallpaperFlow.studioOpener = (_, {required url, thumbnailUrl, entryPoint}) async => null;
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => protectedPick();
      await pumpButton(
        tester,
        source: WallpaperSource.prism,
        wallpaperId: 'protected-wall',
        url: '',
        prepareAuthorized: (_) async {
          prepares++;
          return wallFilePath;
        },
      );

      await openSetScreen(tester);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setScreenPairLock));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(prepares, 1);
      expect(calls.map((call) => call['assetId']), <String>[
        'protected-wall',
        'protected-wall',
        'protected-lock',
        'protected-lock',
      ]);
      expect(
        client.requests.map((request) => (request.target, request.source.filePath)),
        <(aw.WallpaperTarget, String)>[
          (aw.WallpaperTarget.home, wallFilePath),
          (aw.WallpaperTarget.lock, lockFilePath),
        ],
      );
    });

    testWidgets('a protected lock screen pick asks a guest to sign in and sets nothing when they leave', (
      tester,
    ) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => protectedPick();
      await pumpButton(tester);

      await openSetScreen(tester);

      expect(signIns, 1);
      expect(setScreen, findsNothing);
      expect(calls, isEmpty);
      expect(client.requests, isEmpty);
    });

    testWidgets('after a guest signs in, a protected lock screen pick goes on and sets both screens', (tester) async {
      await asGuest(tester, signsIn: true);
      assets.mapSource('https://signed.test/protected-lock', File(lockFilePath));
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => protectedPick();
      await pumpButton(tester);

      await openPair(tester);

      expect(signIns, 1);
      expect(calls.map((call) => (call['assetId'], call['action'], call['mode'])), [
        ('protected-lock', 'set', 'quote'),
        ('protected-lock', 'set', null),
      ]);
      expect(client.requests.map((r) => (r.target, r.source.filePath)), [
        (aw.WallpaperTarget.home, wallFilePath),
        (aw.WallpaperTarget.lock, lockFilePath),
      ]);
    });
  });

  testWidgets('catalogue Set deduplicates a retained original and a later downloaded copy', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'history-original-owner'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '${assets.directory.path}/scratch',
    );
    final client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    final store = WallpaperHistoryStore(settings);
    getIt.registerSingleton<WallpaperHistoryStore>(store);
    const url = 'https://example.com/original.jpg';
    assets.mapSource(url, File(wallFilePath));
    await WallpaperService.setWallpaper(
      url,
      WallpaperTarget.home,
      wallpaperId: 'same-original',
      wallpaperSource: WallpaperSource.prism,
    );
    expect(store.items().single.originalIdentity, 'prism:same-original');
    final downloaded = assets.createImageSync('downloaded-original.png');
    final index = _DownloadedWallIndex();
    when(
      () => index.localFileForIdentity(id: 'same-original', source: WallpaperSource.prism),
    ).thenAnswer((_) async => downloaded);
    when(
      () => index.localFileFor(link: downloaded.path, id: 'same-original', source: WallpaperSource.prism),
    ).thenAnswer((_) async => null);
    getIt.registerSingleton<DownloadedWallIndex>(index);
    await pumpButton(tester, url: url, source: WallpaperSource.prism, wallpaperId: 'same-original');
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.last.source.filePath, downloaded.path);
    expect(store.items(), hasLength(1));
    expect(store.items().single.fullUrl, downloaded.path);
    expect(store.items().single.originalIdentity, 'prism:same-original');
  });

  testWidgets('with the default ask, tapping Set opens the Set screen and applies the chosen target', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await openSetScreen(tester);
    expect(setScreen, findsOneWidget);
    expect(client.requests, isEmpty);

    await setOn(tester, WallpaperTarget.lock);
    expect(client.requests.single.target, aw.WallpaperTarget.lock);
    expect(client.requests.single.scaleMode, aw.WallpaperScaleMode.centerCrop);
    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.success);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  const List<(WallpaperTarget, aw.WallpaperTarget)> targetCases = <(WallpaperTarget, aw.WallpaperTarget)>[
    (WallpaperTarget.home, aw.WallpaperTarget.home),
    (WallpaperTarget.lock, aw.WallpaperTarget.lock),
    (WallpaperTarget.both, aw.WallpaperTarget.both),
  ];
  for (final (WallpaperTarget target, aw.WallpaperTarget requested) in targetCases) {
    testWidgets('Set on the Set screen for ${target.name} applies exactly one ${requested.name} request', (
      tester,
    ) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester);

      await openSetScreen(tester);
      await setOn(tester, target);

      expect(client.requests.map((r) => r.target), <aw.WallpaperTarget>[requested]);
      expect(setScreen, findsNothing);
    });
  }

  testWidgets('tapping the label beside the circle triggers the same action', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    int onSetCalls = 0;
    await pumpButton(tester, onSet: () => onSetCalls++, label: 'Set');

    await tester.tap(find.text(l10n.coreSet));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(onSetCalls, 1);
  });

  testWidgets('with a saved default target, tapping Set applies straight away', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    int onSetCalls = 0;
    await pumpButton(tester, onSet: () => onSetCalls++);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(setScreen, findsNothing);
    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(onSetCalls, 1);
  });

  testWidgets('a fixed target applies that screen without the Set screen, even with another saved default', (
    tester,
  ) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    const String wallpaperUrl = 'https://example.test/fixed-target-wallpaper.jpg';
    assets.mapSource(wallpaperUrl, File(wallFilePath));
    final WallpaperHistoryStore history = WallpaperHistoryStore(settings);
    getIt.registerSingleton<WallpaperHistoryStore>(history);
    await history.record(
      AppliedWallpaper(
        id: 'before-lock',
        source: 'local',
        thumbnailUrl: lockFilePath,
        fullUrl: lockFilePath,
        target: 'lock',
        appliedAt: DateTime(2026),
      ),
    );
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(
      tester,
      url: wallpaperUrl,
      source: WallpaperSource.pexels,
      target: WallpaperTarget.lock,
      primary: true,
      label: 'Set on lock',
    );

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(setScreen, findsNothing);
    expect(client.requests.single.target, aw.WallpaperTarget.lock);
    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget), 'home');
    expect(history.items().first.target, 'lock');
    expect(history.items(), hasLength(2));
    expect(analytics.events.whereType<SetWallEvent>().single.toWireParameters(), containsPair('used_default', 0));

    expect(find.byType(SnackBarAction), findsOneWidget);
    await tester.tap(find.byType(SnackBarAction));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(client.requests, hasLength(2));
    expect(client.requests.last.target, aw.WallpaperTarget.lock);
    expect(client.requests.last.source.filePath, lockFilePath);
    expect(history.items().map((item) => item.id), <String>['before-lock']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a fixed target shows no tune badge', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, target: WallpaperTarget.lock, label: 'Set');

    expect(find.byKey(const ValueKey<String>('set-tune-badge')), findsNothing);
  });

  testWidgets('long press on a fixed target still opens the Set screen', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, target: WallpaperTarget.lock);

    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(setScreen, findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('a fixed target the device cannot set falls back to the Set screen', (tester) async {
    final _Client client = _Client(
      capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
    );
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, target: WallpaperTarget.lock);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(setScreen, findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('long press opens the Set screen even with a saved default', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'both');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreBothScreens)));
    await tester.pumpAndSettle();

    expect(setScreen, findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('the primary button plays one tap haptic for pointer and semantics activation', (tester) async {
    final List<Object?> played = <Object?>[];
    const MethodChannel haptics = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (call) async {
      played.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, null));

    await pumpButton(tester, primary: true);
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    expect(played, <Object?>['tap'], reason: 'the PrismButton owns the pointer tap haptic');
    expect(setScreen, findsOneWidget, reason: 'pointer activation still opens the set flow');

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpButton(tester, primary: true);
    played.clear();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final SemanticsNode button = tester.getSemantics(find.bySemanticsLabel(l10n.coreSetWallpaper));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: button.id),
    );
    await tester.pumpAndSettle();
    expect(played, <Object?>['tap'], reason: 'the outer semantic action bypasses PrismButton.onPressed');
    expect(setScreen, findsOneWidget, reason: 'semantics activation still opens the set flow');
    semantics.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('long-pressing the primary button plays one tap haptic', (tester) async {
    final List<Object?> played = <Object?>[];
    const MethodChannel haptics = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (call) async {
      played.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, null));

    await pumpButton(tester, primary: true);
    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();

    expect(played, <Object?>['tap']);
    expect(setScreen, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the circular button plays one tap haptic', (tester) async {
    final List<Object?> played = <Object?>[];
    const MethodChannel haptics = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (call) async {
      played.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, null));

    await pumpButton(tester);
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();

    expect(played, <Object?>['tap']);
    expect(setScreen, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a saved default the device cannot set falls back to the Set screen', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
    final _Client client = _Client(
      capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
    );
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(setScreen, findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('Both is absent when the device cannot set both screens', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(
        capabilities: const aw.WallpaperCapabilities(
          supportsStaticWallpaper: true,
          supportsHomeWallpaper: true,
          supportsLockWallpaper: true,
        ),
      ),
    );
    await pumpButton(tester);

    await openSetScreen(tester);

    expect(find.text(l10n.setScreenTargetHome), findsOneWidget);
    expect(find.text(l10n.setScreenTargetLock), findsOneWidget);
    expect(find.text(l10n.setScreenTargetBoth), findsNothing);
  });

  testWidgets('Lock and Both are absent when the device cannot set the lock screen', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpButton(tester);

    await openSetScreen(tester);

    expect(find.text(l10n.setScreenTargetHome), findsNothing);
    expect(find.text(l10n.setScreenTargetLock), findsNothing);
    expect(find.text(l10n.setScreenTargetBoth), findsNothing);
    expect(find.bySemanticsLabel(l10n.setScreenTargetGroup), findsNothing);
  });

  testWidgets('Adjust then the system editor sets one wall through the system cropper', (tester) async {
    final _Client client = _Client(status: aw.WallpaperOperationStatus.awaitingUserConfirmation);
    aw.AsyncWallpaper.debugSetClient(client);
    SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async =>
        const SystemEditorRequested();
    // The system cropper reads a content URI, which MainActivity makes through this channel.
    const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      cropChannel,
      (MethodCall call) async => 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/wallpaper.jpg',
    );
    addTearDown(
      () =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, null),
    );
    await pumpButton(tester);

    await openSetScreen(tester);
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(setScreen, findsNothing);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.strategy, aw.WallpaperApplyStrategy.systemCropper);
    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(client.requests.single.source.contentUri, startsWith('content://'));
  });

  testWidgets('a failed set shows Try again and tracks a failure', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed);
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle();

    expect(find.text(l10n.coreTryAgain), findsOneWidget);
    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.failure);
    final int before = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text(l10n.coreTryAgain));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(client.requests.length, greaterThan(before));
  });

  testWidgets('a cancelled set stays silent', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client(status: aw.WallpaperOperationStatus.cancelled));
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
  });

  testWidgets('the Set screen shows the low resolution note and the landscape note as chips', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(
      tester,
      thumbnailUrl: thumbnailFilePath,
      notes: const <String>['Low resolution for your screen', 'Landscape wallpaper: the sides will be cropped'],
    );

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();

    expect(find.text('Low resolution for your screen'), findsOneWidget);
    expect(find.text('Landscape wallpaper: the sides will be cropped'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('without Remember the default stays on ask', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);

    await openSetScreen(tester);
    await setOn(tester, WallpaperTarget.lock);

    expect(SetWallpaperFlow.defaultTarget(), isNull);
    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask'), 'ask');
  });

  testWidgets('Remember this choice saves Lock as the default, and the next Set applies it without the Set screen', (
    tester,
  ) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await openSetScreen(tester);
    await tester.tap(find.text(l10n.setScreenRemember));
    await tester.pump();
    await setOn(tester, WallpaperTarget.lock);

    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget), 'lock');
    expect(client.requests.map((r) => r.target), <aw.WallpaperTarget>[aw.WallpaperTarget.lock]);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(setScreen, findsNothing);
    expect(client.requests.map((r) => r.target), <aw.WallpaperTarget>[
      aw.WallpaperTarget.lock,
      aw.WallpaperTarget.lock,
    ]);
  });

  testWidgets('a saved default Both opens the Set screen on long press with Both and Remember checked', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'both');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreBothScreens)));
    await tester.pumpAndSettle();

    expect(setScreen, findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel(l10n.setScreenTargetBoth)), isSemantics(isSelected: true));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.text(l10n.setScreenRemember));
    await tester.pump();
    await tester.tap(find.text(l10n.setScreenTargetHome));
    await tester.pump();
    await setOn(tester, WallpaperTarget.home);

    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget), 'ask');
    expect(client.requests.map((r) => r.target), <aw.WallpaperTarget>[aw.WallpaperTarget.home]);
  });

  testWidgets('closing the Set screen saves nothing and applies nothing', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await openSetScreen(tester);
    await tester.tap(find.text(l10n.setScreenRemember));
    await tester.pump();
    await tester.tap(find.text(l10n.setScreenTargetLock));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.setScreenClose));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(setScreen, findsNothing);
    expect(SetWallpaperFlow.defaultTarget(), isNull);
    expect(client.requests, isEmpty);
    expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
  });

  testWidgets(
    'set_wall says the default was used and the target did not change when a saved default skips the screen',
    (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      aw.AsyncWallpaper.debugSetClient(_Client());
      await pumpButton(tester, entryPoint: 'favourites');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final SetWallEvent event = analytics.events.whereType<SetWallEvent>().single;
      expect(event.entryPoint, 'favourites');
      expect(event.usedDefault, isTrue);
      expect(event.targetChanged, isNull);
    },
  );

  testWidgets('set_wall records target_changed true when the user moves from Home to Lock on the Set screen', (
    tester,
  ) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, entryPoint: 'wallpaper_detail');

    await openSetScreen(tester);
    await setOn(tester, WallpaperTarget.lock);

    final SetWallEvent event = analytics.events.whereType<SetWallEvent>().single;
    expect(event.entryPoint, 'wallpaper_detail');
    expect(event.usedDefault, isFalse);
    expect(event.targetChanged, isTrue);
  });

  testWidgets('set_wall records target_changed false when the user sets the initial Home target on the Set screen', (
    tester,
  ) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, entryPoint: 'wallpaper_detail');

    await openSetScreen(tester);
    await setOn(tester, WallpaperTarget.home);

    final SetWallEvent event = analytics.events.whereType<SetWallEvent>().single;
    expect(event.entryPoint, 'wallpaper_detail');
    expect(event.usedDefault, isFalse);
    expect(event.targetChanged, isFalse);
  });

  testWidgets('the set_wall event records the fit, the entry point and that the default was used', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, entryPoint: 'wallpaper_detail');

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final Map<String, Object?> wire = analytics.events.whereType<SetWallEvent>().single.toWireParameters();
    expect(wire, containsPair('entry_point', 'wallpaper_detail'));
    expect(wire, containsPair('fit', 'fill'));
    expect(wire, containsPair('used_default', 1));
  });

  testWidgets('a permanent error shows its message and no retry', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed)..errorCode = 'image-too-large';
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(client.requests, hasLength(1));
    expect(
      analytics.events.whereType<SetWallEvent>().single.toWireParameters(),
      containsPair('error_code', 'image-too-large'),
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Try again still works after the user leaves the screen', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed);
    aw.AsyncWallpaper.debugSetClient(client);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: SetWallpaperButton(url: '/tmp/wall.png')),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coreTryAgain), findsOneWidget);

    Navigator.of(tester.element(find.byType(SetWallpaperButton))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.text(l10n.coreTryAgain), findsOneWidget);

    final int before = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text(l10n.coreTryAgain));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.length, greaterThan(before));
    expect(tester.takeException(), isNull);
    expect(analytics.events.whereType<SetWallEvent>().last.result, BinaryResultValue.success);
  });

  testWidgets('a placed wall can retry after its detail screen is gone', (tester) async {
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed);
    aw.AsyncWallpaper.debugSetClient(client);
    final String placedPath = placedWallFile();
    const String sourceUrl = 'https://wallhaven.cc/w/placed-retry';
    assets.mapSource(sourceUrl, File(wallFilePath));
    SetWallpaperFlow.screenOpener = (_, _) async => SetWallpaperChoice(
      WallpaperTarget.home,
      placed: PlacedWallpaper(path: placedPath, placement: const WallpaperPlacement()),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(
                      child: SetWallpaperButton(url: sourceUrl, wallpaperSource: WallpaperSource.wallhaven),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coreTryAgain), findsOneWidget);

    Navigator.of(tester.element(find.byType(SetWallpaperButton))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SetWallpaperButton), findsNothing);
    final int attemptsBeforeRetry = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text(l10n.coreTryAgain));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.length, attemptsBeforeRetry + 1);
    expect(client.requests.map((request) => request.source.filePath), everyElement(placedPath));
    await tester.runAsync(() async {
      for (int attempt = 0; attempt < 20 && await File(placedPath).exists(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await File(placedPath).exists(), isFalse);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('a set that finishes after the user left still shows its result', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed);
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.failure);
  });

  group('tune badge', () {
    testWidgets('has a 48 by 48 hit area', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      aw.AsyncWallpaper.debugSetClient(_Client());
      await pumpButton(tester, label: 'Set');

      expect(tester.getSize(find.byKey(const ValueKey<String>('set-tune-badge'))), const Size(48, 48));
    });

    testWidgets('opens the Set screen and does not apply', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, label: 'Set');

      await tester.tap(find.byKey(const ValueKey<String>('set-tune-badge')));
      await tester.pumpAndSettle();

      expect(setScreen, findsOneWidget);
      expect(client.requests, isEmpty);
    });

    testWidgets('does not steal the tap from the pill', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, label: 'Set');

      await tester.tap(find.text(l10n.coreSet));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(setScreen, findsNothing);
      expect(client.requests.single.target, aw.WallpaperTarget.home);
    });

    testWidgets('is absent while the default is ask', (tester) async {
      aw.AsyncWallpaper.debugSetClient(_Client());
      await pumpButton(tester, label: 'Set');

      expect(find.byKey(const ValueKey<String>('set-tune-badge')), findsNothing);
    });
  });

  group('position studio entry', () {
    testWidgets('keeps the original source identity while the position studio opens', (tester) async {
      final Completer<StudioResult?> studio = Completer<StudioResult?>();
      final List<String> opened = <String>[];
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) {
        opened.add(url);
        return studio.future;
      };
      await pumpButton(tester, thumbnailUrl: thumbnailFilePath);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(opened, <String>['/tmp/wall.png']);
      studio.complete(null);
      await tester.pumpAndSettle();

      expect(opened, <String>['/tmp/wall.png']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Adjust opens the studio with the wall and its entry point', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final List<(String, String?, String?)> opened = <(String, String?, String?)>[];
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
        opened.add((url, thumbnailUrl, entryPoint));
        return null;
      };
      await pumpButton(tester, thumbnailUrl: thumbnailFilePath, entryPoint: 'wallpaper_detail');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle();

      expect(opened, [('/tmp/wall.png', thumbnailFilePath, 'wallpaper_detail')]);
      expect(client.requests, isEmpty);
    });

    testWidgets('by default the studio opens as the WallpaperPositionRoute with the wall, thumbnail and entry point', (
      tester,
    ) async {
      registerFallbackValue(WallpaperPositionRoute(imageUrl: 'unused'));
      final _MockStackRouter router = _MockStackRouter();
      PageRouteInfo<dynamic>? pushed;
      when(() => router.push<StudioResult>(any())).thenAnswer((invocation) async {
        pushed = invocation.positionalArguments.first as PageRouteInfo<dynamic>;
        return null;
      });
      aw.AsyncWallpaper.debugSetClient(_Client());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          builder: (context, child) => StackRouterScope(controller: router, stateHash: 0, child: child!),
          home: Scaffold(
            body: SetWallpaperButton(
              url: '/tmp/wall.png',
              thumbnailUrl: thumbnailFilePath,
              entryPoint: 'download_screen',
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle();

      expect(pushed?.routeName, WallpaperPositionRoute.name);
      final WallpaperPositionRouteArgs args = pushed!.args! as WallpaperPositionRouteArgs;
      expect(
        (args.imageUrl, args.thumbnailUrl, args.entryPoint),
        ('/tmp/wall.png', thumbnailFilePath, 'download_screen'),
      );
    });

    testWidgets('Adjust places the wall, and Set applies the placed file with the studio fit and entry point', (
      tester,
    ) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final String placedPath = placedWallFile();
      final List<(String, String?)> opened = <(String, String?)>[];
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
        opened.add((url, entryPoint));
        return PlacedWallpaper(
          path: placedPath,
          placement: const WallpaperPlacement(fit: PlacementFit.fitBlur),
        );
      };
      await pumpButton(tester, thumbnailUrl: thumbnailFilePath, entryPoint: 'wallpaper_detail');

      await openSetScreen(tester);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle();
      expect(opened, <(String, String?)>[('/tmp/wall.png', 'wallpaper_detail')]);
      expect(client.requests, isEmpty);

      await setOn(tester, WallpaperTarget.home);

      expect(client.requests.map((r) => (r.target, r.source.filePath)), <(aw.WallpaperTarget, String)>[
        (aw.WallpaperTarget.home, placedPath),
      ]);
      final Map<String, Object?> wire = analytics.events.whereType<SetWallEvent>().single.toWireParameters();
      expect(wire, containsPair('fit', 'studio_fitBlur'));
      expect(wire, containsPair('entry_point', 'wallpaper_detail'));
    });
  });

  group('different wallpaper for lock screen', () {
    PairPick pick() => PairPick(
      source: PairSource.favourites,
      candidate: PairCandidate(fullUrl: '/tmp/lock.png', thumbnailUrl: lockFilePath),
    );

    Future<void> openPair(WidgetTester tester) async {
      await openSetScreen(tester);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setScreenPairLock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('sets this wall on the home screen and the pick on the lock screen', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      String? excluded;
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async {
        excluded = excludeUrl;
        return pick();
      };
      await pumpButton(tester, entryPoint: 'wallpaper_detail');

      await openPair(tester);

      expect(excluded, '/tmp/wall.png');
      expect(client.requests.map((r) => (r.target, r.source.filePath)), [
        (aw.WallpaperTarget.home, wallFilePath),
        (aw.WallpaperTarget.lock, lockFilePath),
      ]);
      final SetWallPairEvent event = analytics.events.whereType<SetWallPairEvent>().single;
      expect(event.toWireParameters(), {
        'home_source': 'wallpaper_detail',
        'lock_source': 'favourites',
        'result': 'success',
      });
      expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
    });

    testWidgets('a rendered pair keeps the acquired original in history', (tester) async {
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final store = WallpaperHistoryStore(settings);
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '${assets.directory.path}/scratch',
      );
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => pick();
      final renderedPath = assets.createImageSync('pair-rendered.png').path;
      await pumpButton(tester, prepareAuthorized: (_) async => renderedPath);
      await openPair(tester);
      expect(client.requests.first.source.filePath, renderedPath);
      expect(store.items().where((item) => item.target == 'home').single.fullUrl, wallFilePath);
      expect(store.items().where((item) => item.target == 'lock').single.fullUrl, '/tmp/lock.png');
    });

    testWidgets('More is hidden when the device cannot set the lock screen', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await pumpButton(tester);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('set-screen-more')), findsNothing);
    });

    testWidgets('closing the picker sets nothing', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => null;
      await pumpButton(tester);

      await openPair(tester);

      expect(client.requests, isEmpty);
    });

    testWidgets('a lock screen failure says the home screen was set and retries only the lock screen', (tester) async {
      final _Client client = _Client()
        ..statusFor[aw.WallpaperTarget.lock] = aw.WallpaperOperationStatus.failed
        ..errorCode = 'timeout';
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => pick();
      await pumpButton(tester);

      await openPair(tester);

      expect(find.text('Home screen set. Lock screen failed.'), findsOneWidget);
      expect(analytics.events.whereType<SetWallPairEvent>().single.result, 'partial');
      final int before = client.requests.length;
      client.statusFor.clear();
      await tester.tap(find.text('Retry lock screen'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.skip(before).map((r) => (r.target, r.source.filePath)), [
        (aw.WallpaperTarget.lock, lockFilePath),
      ]);
      expect(analytics.events.whereType<SetWallPairEvent>().last.result, 'success');
    });

    testWidgets('a home screen failure sets nothing on the lock screen and retries the whole pair', (tester) async {
      final _Client client = _Client()
        ..statusFor[aw.WallpaperTarget.home] = aw.WallpaperOperationStatus.failed
        ..errorCode = 'timeout';
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => pick();
      var prepares = 0;
      await pumpButton(
        tester,
        prepareAuthorized: (_) async {
          prepares++;
          return wallFilePath;
        },
      );

      await openPair(tester);

      expect(prepares, 1);
      expect(client.requests.where((r) => r.target == aw.WallpaperTarget.lock), isEmpty);
      expect(analytics.events.whereType<SetWallPairEvent>().single.result, 'failure');
      client.statusFor.clear();
      await tester.tap(find.text(l10n.coreTryAgain));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(prepares, 1);
      expect(client.requests.last.target, aw.WallpaperTarget.lock);
    });
  });

  for (final bool placed in <bool>[false, true]) {
    testWidgets('retrying a partial Both set keeps both restore entries for Undo (placed: $placed)', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '${assets.directory.path}/scratch',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      final store = WallpaperHistoryStore(settings);
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      await store.record(
        AppliedWallpaper(
          id: 'previous-home',
          source: 'local',
          thumbnailUrl: wallFilePath,
          fullUrl: wallFilePath,
          target: WallpaperTarget.home.name,
          appliedAt: DateTime(2025),
        ),
      );
      await store.record(
        AppliedWallpaper(
          id: 'previous-lock',
          source: 'local',
          thumbnailUrl: lockFilePath,
          fullUrl: lockFilePath,
          target: WallpaperTarget.lock.name,
          appliedAt: DateTime(2025, 1, 2),
        ),
      );
      final String sourcePath = assets.createImageSync('partial-both-source-$placed.png').path;
      final String? placedPath = placed ? placedWallFile() : null;
      final client = _Client()
        ..scriptedResults.addAll(<aw.WallpaperOperationResult>[
          for (int i = 0; i < 2; i++)
            const aw.WallpaperOperationResult(
              status: aw.WallpaperOperationStatus.failed,
              requestedTarget: aw.WallpaperTarget.both,
              errorCode: 'partial-apply',
              home: aw.WallpaperTargetResult(status: aw.WallpaperTargetStatus.applied),
              lock: aw.WallpaperTargetResult(status: aw.WallpaperTargetStatus.failed),
            ),
        ]);
      aw.AsyncWallpaper.debugSetClient(client);
      if (placedPath != null) {
        SetWallpaperFlow.screenOpener = (_, _) async => SetWallpaperChoice(
          WallpaperTarget.both,
          placed: PlacedWallpaper(path: placedPath, placement: const WallpaperPlacement()),
        );
      }
      await pumpButton(tester, target: placed ? null : WallpaperTarget.both, url: sourcePath);

      await tester.tap(
        find.bySemanticsLabel(placed ? l10n.coreSetWallpaper : l10n.coreSetWallpaperOn(l10n.coreBothScreens)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text(l10n.coreRetryOnScreen(l10n.coreLockScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text(l10n.coreUndo), findsOneWidget);
      await tester.tap(find.text(l10n.coreUndo));
      await settleUndoIo(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.skip(3).map((request) => request.target), <aw.WallpaperTarget>[
        aw.WallpaperTarget.home,
        aw.WallpaperTarget.lock,
      ]);
      expect(client.requests.skip(3).map((request) => request.source.filePath), <String>[wallFilePath, lockFilePath]);
      expect(store.items().map((item) => item.id).toSet(), <String>{'previous-home', 'previous-lock'});
    });
  }

  testWidgets('Match accent shows on the success snackbar when the screen offers it', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    int matched = 0;
    await pumpButton(tester, onMatchAccent: () => matched++);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    expect(matched, 1);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a plugin error while reading capabilities does not stop a saved default from applying', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client()..capabilitiesError = StateError('channel down');
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.single.target, aw.WallpaperTarget.home);
  });

  testWidgets('an unexpected error while opening Adjust tells the user instead of failing silently', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async =>
        throw StateError('router gone');
    final List<MethodCall> toasts = <MethodCall>[];
    await pumpButton(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (
      call,
    ) async {
      toasts.add(call);
      return true;
    });

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
    await tester.pumpAndSettle();

    expect(
      toasts.any(
        (call) =>
            call.method == 'showToast' && (call.arguments as Map)['msg'] == "Couldn't set the wallpaper. Try again.",
      ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  group('prepareSource', () {
    final List<MethodCall> toasts = <MethodCall>[];

    Future<void> pumpPrepared(WidgetTester tester, Future<String> Function() prepareSource) async {
      await pumpButton(tester, prepareSource: prepareSource);
      toasts.clear();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        (call) async {
          toasts.add(call);
          return true;
        },
      );
    }

    bool toasted(String message) =>
        toasts.any((call) => call.method == 'showToast' && (call.arguments as Map)['msg'] == message);

    testWidgets('authorized rendering stays busy and reports edit errors without applying', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final ready = Completer<String>();
      var preparations = 0;
      await pumpButton(
        tester,
        prepareAuthorized: (source) {
          preparations++;
          return ready.future;
        },
      );
      toasts.clear();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        (call) async {
          toasts.add(call);
          return true;
        },
      );
      final button = find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isTrue);
      await tester.tap(button);
      await tester.pump();
      expect(preparations, 1);
      ready.completeError(StateError('render failed'));
      await tester.pumpAndSettle();
      expect(client.requests, isEmpty);
      expect(toasted(l10n.coreWallpaperEditApplyColorFailed), isTrue);
      expect(toasted(l10n.coreWallpaperSaveFailed), isFalse);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a saved default target sets the prepared file, not the url', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final String preparedPath = assets.createImageSync('tinted.png').path;
      int prepared = 0;
      await pumpPrepared(tester, () async {
        prepared++;
        return preparedPath;
      });

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(prepared, 1);
      expect(client.requests.single.source.filePath, preparedPath);
    });

    testWidgets('prepares before the Set screen opens and opens the studio on the prepared file', (tester) async {
      aw.AsyncWallpaper.debugSetClient(_Client());
      String? studioUrl;
      final String preparedPath = assets.createImageSync('tinted.png').path;
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
        studioUrl = url;
        return null;
      };
      int prepared = 0;
      await pumpPrepared(tester, () async {
        prepared++;
        return preparedPath;
      });

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(setScreen, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
      await tester.pumpAndSettle();

      expect(studioUrl, preparedPath);
    });

    testWidgets('shows the busy state while preparing and ignores a second tap', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final String preparedPath = assets.createImageSync('tinted.png').path;
      final Completer<String> ready = Completer<String>();
      int prepared = 0;
      await pumpPrepared(tester, () {
        prepared++;
        return ready.future;
      });

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pump();
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isTrue);
      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pump();
      expect(prepared, 1);

      ready.complete(preparedPath);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(client.requests.single.source.filePath, preparedPath);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);
    });

    testWidgets('a failed prepare tells the user, sets nothing and can be tried again', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      int prepared = 0;
      await pumpPrepared(tester, () {
        prepared++;
        return Future<String>.error(StateError('render failed'));
      });

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle();

      expect(toasted("Couldn't apply the colour. Try again."), isTrue);
      expect(client.requests, isEmpty);
      expect(setScreen, findsNothing);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle();
      expect(prepared, 2);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  for (final status in <aw.WallpaperOperationStatus>[
    aw.WallpaperOperationStatus.cancelled,
    aw.WallpaperOperationStatus.unsupported,
  ]) {
    testWidgets('a placed wall releases its temporary file after ${status.name}', (tester) async {
      final client = _Client(status: status);
      aw.AsyncWallpaper.debugSetClient(client);
      final path = placedWallFile();
      SetWallpaperFlow.screenOpener = (_, _) async => SetWallpaperChoice(
        WallpaperTarget.home,
        placed: PlacedWallpaper(path: path, placement: const WallpaperPlacement()),
      );
      await pumpButton(tester);

      await openSetScreen(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await File(path).exists(), isFalse);
      });
      expect(client.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('a placed wall stays available while the system wallpaper preview is pending', (tester) async {
    final client = _Client(status: aw.WallpaperOperationStatus.previewOpened);
    aw.AsyncWallpaper.debugSetClient(client);
    final path = placedWallFile();
    SetWallpaperFlow.screenOpener = (_, _) async => SetWallpaperChoice(
      WallpaperTarget.home,
      placed: PlacedWallpaper(path: path, placement: const WallpaperPlacement()),
    );
    await pumpButton(tester);

    await openSetScreen(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await File(path).exists(), isTrue);
      await File(path).parent.delete(recursive: true);
    });
  });

  testWidgets('Adjust then pair reuses the prepared source even when the home screen is retried', (tester) async {
    final client = _Client()..statusFor[aw.WallpaperTarget.home] = aw.WallpaperOperationStatus.failed;
    aw.AsyncWallpaper.debugSetClient(client);
    final preparedPath = assets.createImageSync('prepared-once.png').path;
    var prepares = 0;
    SetWallpaperFlow.studioOpener = (_, {required url, thumbnailUrl, entryPoint}) async => null;
    SetWallpaperFlow.pairPicker = (_, {excludeUrl}) async => PairPick(
      source: PairSource.favourites,
      candidate: PairCandidate(fullUrl: '/tmp/lock.png', thumbnailUrl: lockFilePath),
    );
    await pumpButton(
      tester,
      prepareAuthorized: (_) async {
        prepares++;
        return preparedPath;
      },
    );
    await openSetScreen(tester);
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-adjust')));
    await tester.pumpAndSettle();
    expect(prepares, 1);
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.setScreenPairLock));
    await tester.pumpAndSettle();
    expect(prepares, 1);
    expect(client.requests.first.source.filePath, preparedPath);

    client.statusFor.clear();
    await tester.tap(find.text(l10n.coreTryAgain));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(prepares, 1);
    expect(client.requests.last.target, aw.WallpaperTarget.lock);
  });

  test('defaultTarget reads the saved value and treats ask or junk as ask', () async {
    expect(SetWallpaperFlow.defaultTarget(), isNull);
    await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
    expect(SetWallpaperFlow.defaultTarget(), WallpaperTarget.lock);
    await settings.set(PersistenceKeys.defaultApplyTarget, 'ask');
    expect(SetWallpaperFlow.defaultTarget(), isNull);
    await settings.set(PersistenceKeys.defaultApplyTarget, 'sideways');
    expect(SetWallpaperFlow.defaultTarget(), isNull);
  });
}
