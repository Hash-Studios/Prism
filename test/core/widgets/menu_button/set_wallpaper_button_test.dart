import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _MockStackRouter extends Mock implements StackRouter {}

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
  final studioOpener = SetWallpaperFlow.studioOpener;
  final pairPicker = SetWallpaperFlow.pairPicker;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() async {
    SetWallpaperFlow.studioOpener = studioOpener;
    SetWallpaperFlow.pairPicker = pairPicker;
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    VoidCallback? onSet,
    String? label,
    String? thumbnailUrl,
    String? entryPoint,
    List<String> notes = const <String>[],
    VoidCallback? onMatchAccent,
  }) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SetWallpaperButton(
              url: '/tmp/wall.png',
              thumbnailUrl: thumbnailUrl,
              onSet: onSet,
              label: label,
              entryPoint: entryPoint,
              notes: notes,
              onMatchAccent: onMatchAccent,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('with the default ask, tapping Set opens the sheet and applies the chosen target', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);

    await tester.tap(find.text('Lock Screen'));
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

    await tester.tap(find.text('Set'));
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(SetOptionsPanel), findsNothing);
    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(onSetCalls, 1);
  });

  testWidgets('long press opens the sheet even with a saved default', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'both');
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.longPress(find.bySemanticsLabel('Set as wallpaper on both screens'));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('a saved default the device cannot set falls back to the sheet', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
    final _Client client = _Client(
      capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
    );
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on lock screen'));
    await tester.pumpAndSettle();

    expect(find.byType(SetOptionsPanel), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('the sheet hides Lock and Both when the device does not support them', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);
    expect(find.text('Lock Screen'), findsNothing);
    expect(find.text('Both'), findsNothing);
  });

  testWidgets('Fit whole image changes the request, and Crop and position opens the system cropper', (tester) async {
    final _Client client = _Client(status: aw.WallpaperOperationStatus.awaitingUserConfirmation);
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fit whole image'));
    await tester.pump();
    await tester.tap(find.text('Home Screen'));
    await tester.pumpAndSettle();
    expect(client.requests.last.scaleMode, aw.WallpaperScaleMode.fitCenter);
    expect(client.requests.last.strategy, aw.WallpaperApplyStrategy.direct);
    expect(find.text('Confirm the wallpaper in the system preview.'), findsOneWidget);

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
    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop and position...'));
    await tester.pump();
    await tester.tap(find.text('Both'));
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.failure);
    final int before = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(client.requests.length, greaterThan(before));
  });

  testWidgets('a cancelled set stays silent', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client(status: aw.WallpaperOperationStatus.cancelled));
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
  });

  testWidgets('the sheet shows the wall, the low resolution note and the landscape note as chips', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(
      tester,
      thumbnailUrl: '/nonexistent/thumb.png',
      notes: const <String>['Low resolution for your screen', 'Landscape wallpaper: the sides will be cropped'],
    );

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();

    expect(find.text('Low resolution for your screen'), findsOneWidget);
    expect(find.text('Landscape wallpaper: the sides will be cropped'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Always use this saves the target the user picks as the default', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Always use this'));
    await tester.tap(find.text('Always use this'));
    await tester.pump();
    await tester.tap(find.text('Lock Screen'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(SetWallpaperFlow.defaultTarget(), WallpaperTarget.lock);
  });

  testWidgets('without Always use this the default stays on ask', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock Screen'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(SetWallpaperFlow.defaultTarget(), isNull);
  });

  testWidgets('the Both line shows only when Both is offered', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester);
    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    expect(find.text('Both sets it on your home screen and lock screen.'), findsOneWidget);
  });

  testWidgets('the Both line is hidden when the device cannot set both screens', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpButton(tester);
    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();

    expect(find.text('Both'), findsNothing);
    expect(find.text('Both sets it on your home screen and lock screen.'), findsNothing);
  });

  testWidgets('the set_wall event records the fit, the entry point and that the default was used', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    await pumpButton(tester, entryPoint: 'wallpaper_detail');

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
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
    await tester.pumpWidget(
      MaterialApp(
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
    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    Navigator.of(tester.element(find.byType(SetWallpaperButton))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.text('Try again'), findsOneWidget);

    final int before = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text('Try again'));
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
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

      await tester.tap(find.text('Set'));
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
    testWidgets('Adjust position and preview opens the studio with the wall and its entry point', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      final List<(String, String?, String?)> opened = <(String, String?, String?)>[];
      SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
        opened.add((url, thumbnailUrl, entryPoint));
        return null;
      };
      await pumpButton(tester, thumbnailUrl: '/tmp/thumb.png', entryPoint: 'wallpaper_detail');

      await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adjust position and preview'));
      await tester.pumpAndSettle();

      expect(opened, [('/tmp/wall.png', '/tmp/thumb.png', 'wallpaper_detail')]);
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
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const Scaffold(
              body: SetWallpaperButton(
                url: '/tmp/wall.png',
                thumbnailUrl: '/tmp/thumb.png',
                entryPoint: 'download_screen',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adjust position and preview'));
      await tester.pumpAndSettle();

      expect(pushed?.routeName, WallpaperPositionRoute.name);
      final WallpaperPositionRouteArgs args = pushed!.args! as WallpaperPositionRouteArgs;
      expect(
        (args.imageUrl, args.thumbnailUrl, args.entryPoint),
        ('/tmp/wall.png', '/tmp/thumb.png', 'download_screen'),
      );
    });
  });

  group('different wallpaper for lock screen', () {
    const PairPick pick = PairPick(
      source: PairSource.favourites,
      candidate: PairCandidate(fullUrl: '/tmp/lock.png', thumbnailUrl: '/tmp/lock-thumb.png'),
    );

    Future<void> openPair(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Different wallpaper for lock screen'));
      await tester.tap(find.text('Different wallpaper for lock screen'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('sets this wall on the home screen and the pick on the lock screen', (tester) async {
      final _Client client = _Client();
      aw.AsyncWallpaper.debugSetClient(client);
      String? excluded;
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async {
        excluded = excludeUrl;
        return pick;
      };
      await pumpButton(tester, entryPoint: 'wallpaper_detail');

      await openPair(tester);

      expect(excluded, '/tmp/wall.png');
      expect(client.requests.map((r) => (r.target, r.source.filePath)), [
        (aw.WallpaperTarget.home, '/tmp/wall.png'),
        (aw.WallpaperTarget.lock, '/tmp/lock.png'),
      ]);
      final SetWallPairEvent event = analytics.events.whereType<SetWallPairEvent>().single;
      expect(event.toWireParameters(), {
        'home_source': 'wallpaper_detail',
        'lock_source': 'favourites',
        'result': 'success',
      });
      expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
    });

    testWidgets('the row is hidden when the device cannot set the lock screen', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await pumpButton(tester);

      await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
      await tester.pumpAndSettle();

      expect(find.text('Different wallpaper for lock screen'), findsNothing);
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
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => pick;
      await pumpButton(tester);

      await openPair(tester);

      expect(find.text('Home screen set. Lock screen failed.'), findsOneWidget);
      expect(analytics.events.whereType<SetWallPairEvent>().single.result, 'partial');
      final int before = client.requests.length;
      client.statusFor.clear();
      await tester.tap(find.text('Retry lock screen'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.skip(before).map((r) => (r.target, r.source.filePath)), [
        (aw.WallpaperTarget.lock, '/tmp/lock.png'),
      ]);
      expect(analytics.events.whereType<SetWallPairEvent>().last.result, 'success');
    });

    testWidgets('a home screen failure sets nothing on the lock screen and retries the whole pair', (tester) async {
      final _Client client = _Client()
        ..statusFor[aw.WallpaperTarget.home] = aw.WallpaperOperationStatus.failed
        ..errorCode = 'timeout';
      aw.AsyncWallpaper.debugSetClient(client);
      SetWallpaperFlow.pairPicker = (context, {excludeUrl}) async => pick;
      await pumpButton(tester);

      await openPair(tester);

      expect(client.requests.where((r) => r.target == aw.WallpaperTarget.lock), isEmpty);
      expect(analytics.events.whereType<SetWallPairEvent>().single.result, 'failure');
      client.statusFor.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.requests.last.target, aw.WallpaperTarget.lock);
    });
  });

  testWidgets('Match accent shows on the success snackbar when the screen offers it', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    aw.AsyncWallpaper.debugSetClient(_Client());
    int matched = 0;
    await pumpButton(tester, onMatchAccent: () => matched++);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(client.requests.single.target, aw.WallpaperTarget.home);
  });

  testWidgets('an unexpected error in the flow tells the user instead of failing silently', (tester) async {
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust position and preview'));
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
