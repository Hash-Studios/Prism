import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _Client implements WallpaperClient {
  _Client({this.capabilities = const aw.WallpaperCapabilities(), this.status = aw.WallpaperOperationStatus.applied});

  final aw.WallpaperCapabilities capabilities;
  aw.WallpaperOperationStatus status;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => capabilities;

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    return aw.WallpaperOperationResult(status: status, requestedTarget: request.target);
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

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() async {
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
  });

  Future<void> pumpButton(WidgetTester tester, {VoidCallback? onSet, String? label}) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SetWallpaperButton(url: '/tmp/wall.png', onSet: onSet, label: label),
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

  testWidgets('Fit whole image and Crop and position change the request', (tester) async {
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

    await tester.tap(find.bySemanticsLabel('Set as wallpaper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop and position...'));
    await tester.pump();
    await tester.tap(find.text('Both'));
    await tester.pumpAndSettle();
    expect(client.requests.last.strategy, aw.WallpaperApplyStrategy.systemCropper);
    expect(client.requests.last.target, aw.WallpaperTarget.both);
  });

  testWidgets('a failed set shows Retry and tracks a failure', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    final _Client client = _Client(status: aw.WallpaperOperationStatus.failed);
    aw.AsyncWallpaper.debugSetClient(client);
    await pumpButton(tester);

    await tester.tap(find.bySemanticsLabel('Set as wallpaper on home screen'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(analytics.events.whereType<SetWallEvent>().single.result, BinaryResultValue.failure);
    final int before = client.requests.length;
    client.status = aw.WallpaperOperationStatus.applied;
    await tester.tap(find.text('Retry'));
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
