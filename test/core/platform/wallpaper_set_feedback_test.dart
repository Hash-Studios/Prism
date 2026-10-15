import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _Client implements WallpaperClient {
  _Client({this.status = aw.WallpaperOperationStatus.applied});

  aw.WallpaperOperationStatus status;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => const aw.WallpaperCapabilities();

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

AppliedWallpaper _row(String id, String url, String target) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: url,
  fullUrl: url,
  target: target,
  appliedAt: DateTime.utc(2026, 1, 1, int.parse(id.replaceAll(RegExp('[^0-9]'), ''))),
);

WallpaperSetResult _success({
  List<WallpaperRestore> restore = const <WallpaperRestore>[],
  List<String> ids = const [],
}) => WallpaperSetResult(WallpaperSetStatus.applied, 'Wallpaper set successfully!', restore: restore, historyIds: ids);

void main() {
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late WallpaperHistoryStore store;
  late List<MethodCall> toasts;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = WallpaperHistoryStore(settings);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<WallpaperHistoryStore>(store);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    toasts = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      toasts.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
  });

  bool toastSaid(String text) =>
      toasts.any((call) => call.method == 'showToast' && (call.arguments as Map<Object?, Object?>)['msg'] == text);

  Future<void> report(
    WidgetTester tester,
    WallpaperSetResult result, {
    WallpaperTarget target = WallpaperTarget.home,
    WallpaperSetContext setContext = const WallpaperSetContext(),
    ValueChanged<WallpaperTarget>? onRetry,
    VoidCallback? onMatchAccent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => reportWallpaperSetResult(
                context,
                result,
                target: target,
                setContext: setContext,
                onRetry: onRetry,
                onMatchAccent: onMatchAccent,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a success with a previous wall shows an 8 second snackbar with Undo', (tester) async {
    await report(
      tester,
      _success(restore: <WallpaperRestore>[WallpaperRestore(WallpaperTarget.home, _row('1', '/prev.png', 'home'))]),
    );

    expect(find.text('Wallpaper set'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Undo sets the previous wall without a new history row and removes the new row', (tester) async {
    final _Client client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    await store.record(_row('1', '/prev.png', 'home'));
    await store.record(_row('2', '/new.png', 'home'));
    await report(
      tester,
      _success(
        restore: <WallpaperRestore>[WallpaperRestore(WallpaperTarget.home, _row('1', '/prev.png', 'home'))],
        ids: <String>['2'],
      ),
    );

    await tester.tap(find.text('Undo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(client.requests.single.source.filePath, '/prev.png');
    expect(store.items().map((item) => item.id), ['1']);
    final SetWallUndoneEvent event = analytics.events.whereType<SetWallUndoneEvent>().single;
    expect(event.result, BinaryResultValue.success);
    expect(event.wallpaperTarget, WallpaperTarget.home);
    expect(toastSaid('Previous wallpaper restored'), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a failed Undo keeps the history row and tracks a failure', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(status: aw.WallpaperOperationStatus.failed));
    await store.record(_row('2', '/new.png', 'home'));
    await report(
      tester,
      _success(
        restore: <WallpaperRestore>[WallpaperRestore(WallpaperTarget.home, _row('1', '/prev.png', 'home'))],
        ids: <String>['2'],
      ),
    );

    await tester.tap(find.text('Undo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(store.items().map((item) => item.id), ['2']);
    expect(analytics.events.whereType<SetWallUndoneEvent>().single.result, BinaryResultValue.failure);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Undo is hidden while auto-rotate is on', (tester) async {
    await settings.set(PersistenceKeys.autoRotateEnabled, true);
    await report(
      tester,
      _success(restore: <WallpaperRestore>[WallpaperRestore(WallpaperTarget.home, _row('1', '/prev.png', 'home'))]),
    );

    expect(find.byType(SnackBar), findsNothing);
    expect(toastSaid('Wallpaper set successfully!'), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a first set with nothing to restore keeps the plain toast', (tester) async {
    await report(tester, _success());

    expect(find.byType(SnackBar), findsNothing);
    expect(toastSaid('Wallpaper set successfully!'), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Match accent shows beside the message, runs the callback and closes the snackbar', (tester) async {
    int matched = 0;
    await report(tester, _success(), onMatchAccent: () => matched++);

    expect(find.text('Wallpaper set'), findsOneWidget);
    expect(find.text('Match accent'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    expect(matched, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Wallpaper set'), findsNothing);
  });

  testWidgets('a failure that can be retried offers Try again for the same target', (tester) async {
    final List<WallpaperTarget> retried = <WallpaperTarget>[];
    await report(
      tester,
      const WallpaperSetResult(WallpaperSetStatus.failed, "Couldn't set the wallpaper.", errorCode: 'timeout'),
      target: WallpaperTarget.lock,
      onRetry: retried.add,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retried, [WallpaperTarget.lock]);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a partial set says which screen failed and retries only that screen', (tester) async {
    final List<WallpaperTarget> retried = <WallpaperTarget>[];
    await report(
      tester,
      const WallpaperSetResult(
        WallpaperSetStatus.failed,
        'Home screen set. Lock screen failed.',
        errorCode: 'partial-apply',
        appliedTarget: WallpaperTarget.home,
        failedTarget: WallpaperTarget.lock,
      ),
      target: WallpaperTarget.both,
      onRetry: retried.add,
    );

    expect(find.text('Home screen set. Lock screen failed.'), findsOneWidget);
    await tester.tap(find.text('Retry lock screen'));
    await tester.pump();

    expect(retried, [WallpaperTarget.lock]);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a permanent failure shows its message without a retry action', (tester) async {
    await report(
      tester,
      const WallpaperSetResult(
        WallpaperSetStatus.failed,
        'This image is too large for your device to set.',
        errorCode: 'image-too-large',
      ),
      onRetry: (_) {},
    );

    expect(find.byType(SnackBar), findsNothing);
    expect(toastSaid('This image is too large for your device to set.'), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the set_wall event carries the error code, fit, entry point and default use', (tester) async {
    await report(
      tester,
      const WallpaperSetResult(WallpaperSetStatus.failed, 'x', errorCode: 'out-of-memory'),
      target: WallpaperTarget.both,
      setContext: const WallpaperSetContext(fit: 'whole', entryPoint: 'wallpaper_detail', usedDefault: true),
      onRetry: (_) {},
    );

    final SetWallEvent event = analytics.events.whereType<SetWallEvent>().single;
    expect(event.result, BinaryResultValue.failure);
    expect(event.wallpaperTarget, WallpaperTarget.both);
    expect(event.toWireParameters(), containsPair('error_code', 'out-of-memory'));
    expect(event.toWireParameters(), containsPair('fit', 'whole'));
    expect(event.toWireParameters(), containsPair('entry_point', 'wallpaper_detail'));
    expect(event.toWireParameters(), containsPair('used_default', 1));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a success event has no error code', (tester) async {
    await report(tester, _success());

    expect(analytics.events.whereType<SetWallEvent>().single.toWireParameters().containsKey('error_code'), isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a cancelled set is silent and not tracked', (tester) async {
    await report(tester, const WallpaperSetResult(WallpaperSetStatus.cancelled, ''));

    expect(find.byType(SnackBar), findsNothing);
    expect(analytics.events.whereType<SetWallEvent>(), isEmpty);
    expect(toasts.where((call) => call.method == 'showToast'), isEmpty);
  });

  testWidgets('with no live context the snackbar still shows on the messenger taken earlier', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    reportWallpaperSetResult(
      null,
      const WallpaperSetResult(WallpaperSetStatus.failed, 'Timed out.', errorCode: 'timeout'),
      target: WallpaperTarget.home,
      messenger: messenger,
      onRetry: (_) {},
    );
    await tester.pump();

    expect(find.text('Timed out.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
