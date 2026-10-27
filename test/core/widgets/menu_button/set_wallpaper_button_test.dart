import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/coins_test_backend.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/offline_asset_fixture.dart';

final AppLocalizationsEn l10n = AppLocalizationsEn();

class _MockStackRouter extends Mock implements StackRouter {}

class _DownloadedWallIndex extends Mock implements DownloadedWallIndex {}

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

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async {
    final Object? error = capabilitiesError;
    if (error != null) throw error;
    return capabilities;
  }

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
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
  final signIn = originalSignIn;

  setUp(() async {
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
    SetWallpaperFlow.studioOpener = studioOpener;
    SetWallpaperFlow.pairPicker = pairPicker;
    originalSignIn = signIn;
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

  testWidgets('cancelling the target sheet never quotes, grants, charges, or applies a protected original', (
    tester,
  ) async {
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
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(callableCount, 0);
    expect(client.requests, isEmpty);
  });

  group('signed-out user', () {
    late CoinsTestBackend backend;
    late List<Map<String, dynamic>> calls;
    late int signIns;

    Future<void> asGuest(WidgetTester tester, {required bool signsIn}) async {
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
      originalSignIn = (_) async {
        signIns++;
        if (signsIn) app_state.prismUser = signedInUser;
        return signsIn;
      };
    }

    testWidgets('Set on a protected wall asks a guest to sign in and calls nothing when they leave', (tester) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, source: WallpaperSource.prism, wallpaperId: 'protected-wall', url: '');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();

      expect(signIns, 1);
      expect(find.byType(SetOptionsPanel), findsNothing);
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

    testWidgets('Set on a wall that needs no grant does not ask a guest to sign in', (tester) async {
      await asGuest(tester, signsIn: false);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(signIns, 0);
      expect(client.requests.map((r) => r.source.filePath), [wallFilePath]);
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
      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.coreDifferentLockWallpaper));
      await tester.tap(find.text(l10n.coreDifferentLockWallpaper));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('a protected lock screen pick asks a guest to sign in and sets nothing when they leave', (
      tester,
    ) async {
      await asGuest(tester, signsIn: false);
      final client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => protectedPick();
      await pumpButton(tester);

      await openPair(tester);

      expect(signIns, 1);
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

  testWidgets('with the default ask, tapping Set opens the sheet and applies the chosen target', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);

    await tester.tap(find.text(l10n.coreLockScreen));
    await tester.pumpAndSettle();
    expect(client.requests.single.target, aw.WallpaperTarget.lock);
    expect(client.requests.single.scaleMode, aw.WallpaperScaleMode.centerCrop);
    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.success);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

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

    expect(find.byType(SetOptionsPanel), findsNothing);
    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(onSetCalls, 1);
  });

  testWidgets('a fixed target applies that screen without the sheet, even with another saved default', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, target: WallpaperTarget.lock, primary: true, label: 'Set on lock');

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(SetOptionsPanel), findsNothing);
    expect(client.requests.single.target, aw.WallpaperTarget.lock);
  });

  testWidgets('a fixed target shows no tune badge', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, target: WallpaperTarget.lock, label: 'Set');

    expect(find.byKey(const ValueKey<String>('set-tune-badge')), findsNothing);
  });

  testWidgets('long press on a fixed target still opens the sheet', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, target: WallpaperTarget.lock);

    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('a fixed target the device cannot set falls back to the sheet', (tester) async {
    final _Client client = _Client(
      capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
    );
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester, target: WallpaperTarget.lock);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('long press opens the sheet even with a saved default', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'both');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.longPress(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreBothScreens)));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
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
    expect(find.byType(SetOptionsPanel), findsOneWidget, reason: 'pointer activation still opens the set flow');

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
    expect(find.byType(SetOptionsPanel), findsOneWidget, reason: 'semantics activation still opens the set flow');
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
    expect(find.byType(SetOptionsPanel), findsOneWidget);
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
    expect(find.byType(SetOptionsPanel), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a saved default the device cannot set falls back to the sheet', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
    final _Client client = _Client(
      capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
    );
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreLockScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('the sheet hides Lock and Both when the device does not support them', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();

    expect(find.text(l10n.coreHomeScreen), findsOneWidget);
    expect(find.text(l10n.coreLockScreen), findsNothing);
    expect(find.text(l10n.coreBoth), findsNothing);
  });

  testWidgets('Fit whole image changes the request, and Crop and position opens the system cropper', (tester) async {
    final _Client client = _Client(status: aw.WallpaperOperationStatus.awaitingUserConfirmation);
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.coreFitWholeImage));
    await tester.pump();
    await tester.tap(find.text(l10n.coreHomeScreen));
    await tester.pumpAndSettle();
    expect(client.requests.last.scaleMode, aw.WallpaperScaleMode.fitCenter);
    expect(client.requests.last.strategy, aw.WallpaperApplyStrategy.direct);
    expect(find.text(l10n.coreConfirmWallpaperPreview), findsOneWidget);

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
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.coreCropAndPosition));
    await tester.pump();
    await tester.tap(find.text(l10n.coreBoth));
    await tester.pumpAndSettle();
    expect(client.requests.last.strategy, aw.WallpaperApplyStrategy.systemCropper);
    expect(client.requests.last.target, aw.WallpaperTarget.both);
    expect(client.requests.last.source.contentUri, startsWith('content://'));
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

  testWidgets('the sheet shows the wall, the low resolution note and the landscape note as chips', (tester) async {
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

  testWidgets('Always use this saves the target the user picks as the default', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l10n.coreAlwaysUseThis));
    await tester.tap(find.text(l10n.coreAlwaysUseThis));
    await tester.pump();
    await tester.tap(find.text(l10n.coreLockScreen));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(SetWallpaperFlow.defaultTarget(), WallpaperTarget.lock);
  });

  testWidgets('without Always use this the default stays on ask', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.coreLockScreen));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(SetWallpaperFlow.defaultTarget(), isNull);
  });

  testWidgets('the Both line shows only when Both is offered', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coreBothSetsScreens), findsOneWidget);
  });

  testWidgets('the Both line is hidden when the device cannot set both screens', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpButton(tester);
    await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
    await tester.pumpAndSettle();

    expect(find.text(l10n.coreBoth), findsNothing);
    expect(find.text(l10n.coreBothSetsScreens), findsNothing);
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

    testWidgets('opens the sheet and does not apply', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, label: 'Set');

      await tester.tap(find.byKey(const ValueKey<String>('set-tune-badge')));
      await tester.pumpAndSettle();

      expect(find.byType(SetOptionsPanel), findsOneWidget);
      expect(client.requests, isEmpty);
    });

    testWidgets('does not steal the tap from the pill', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      await pumpButton(tester, label: 'Set');

      await tester.tap(find.text(l10n.coreSet));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(SetOptionsPanel), findsNothing);
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
      final Completer<WallpaperSetResult?> studio = Completer<WallpaperSetResult?>();
      final List<String> opened = <String>[];
      SetWallpaperFlow.studioOpener =
          (context, {required url, thumbnailUrl, entryPoint, requestId, wallpaperId, wallpaperSource}) async {
            opened.add(url);
            return studio.future;
          };
      await pumpButton(tester, thumbnailUrl: thumbnailFilePath);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.coreAdjustPositionPreview));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(opened, <String>['/tmp/wall.png']);
      studio.complete(null);
      await tester.pumpAndSettle();

      expect(opened, <String>['/tmp/wall.png']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Adjust position and preview opens the studio with the wall and its entry point', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final List<(String, String?, String?)> opened = <(String, String?, String?)>[];
      SetWallpaperFlow.studioOpener =
          (context, {required url, thumbnailUrl, entryPoint, requestId, wallpaperId, wallpaperSource}) async {
            opened.add((url, thumbnailUrl, entryPoint));
            return null;
          };
      await pumpButton(tester, thumbnailUrl: thumbnailFilePath, entryPoint: 'wallpaper_detail');

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.coreAdjustPositionPreview));
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
      when(() => router.push<WallpaperSetResult>(any())).thenAnswer((invocation) async {
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

          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: Scaffold(
              body: SetWallpaperButton(
                url: '/tmp/wall.png',
                thumbnailUrl: thumbnailFilePath,
                entryPoint: 'download_screen',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.coreAdjustPositionPreview));
      await tester.pumpAndSettle();

      expect(pushed?.routeName, WallpaperPositionRoute.name);
      final WallpaperPositionRouteArgs args = pushed!.args! as WallpaperPositionRouteArgs;
      expect(
        (args.imageUrl, args.thumbnailUrl, args.entryPoint),
        ('/tmp/wall.png', thumbnailFilePath, 'download_screen'),
      );
    });
  });

  group('different wallpaper for lock screen', () {
    PairPick pick() => PairPick(
      source: PairSource.favourites,
      candidate: PairCandidate(fullUrl: '/tmp/lock.png', thumbnailUrl: lockFilePath),
    );

    Future<void> openPair(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.coreDifferentLockWallpaper));
      await tester.tap(find.text(l10n.coreDifferentLockWallpaper));
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

    testWidgets('the row is hidden when the device cannot set the lock screen', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await pumpButton(tester);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaper));
      await tester.pumpAndSettle();

      expect(find.text(l10n.coreDifferentLockWallpaper), findsNothing);
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
      await pumpButton(tester);

      await openPair(tester);

      expect(client.requests.where((r) => r.target == aw.WallpaperTarget.lock), isEmpty);
      expect(analytics.events.whereType<SetWallPairEvent>().single.result, 'failure');
      client.statusFor.clear();
      await tester.tap(find.text(l10n.coreTryAgain));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.last.target, aw.WallpaperTarget.lock);
    });
  });

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

  testWidgets('an unexpected error in the flow tells the user instead of failing silently', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    SetWallpaperFlow.studioOpener =
        (context, {required url, thumbnailUrl, entryPoint, requestId, wallpaperId, wallpaperSource}) async =>
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
    await tester.tap(find.text(l10n.coreAdjustPositionPreview));
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

    testWidgets('prepares before the sheet opens and opens the position studio on the prepared file', (tester) async {
      aw.AsyncWallpaper.debugSetClient(_Client());
      String? studioUrl;
      final String preparedPath = assets.createImageSync('tinted.png').path;
      SetWallpaperFlow.studioOpener =
          (context, {required url, thumbnailUrl, entryPoint, requestId, wallpaperId, wallpaperSource}) async {
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
      expect(find.byType(SetOptionsPanel), findsOneWidget);
      await tester.tap(find.text(l10n.coreAdjustPositionPreview));
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
      expect(find.byType(SetOptionsPanel), findsNothing);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);

      await tester.tap(find.bySemanticsLabel(l10n.coreSetWallpaperOn(l10n.coreHomeScreen)));
      await tester.pumpAndSettle();
      expect(prepared, 2);
      await tester.pump(const Duration(seconds: 5));
    });
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
