// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/live_wall_video.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart' as platform;

import '../../support/fake_app_analytics.dart';

final VideoPlayerController Function(Uri url) _defaultCreateController = LiveWallVideo.createController;

class _GatedVideoController extends VideoPlayerController {
  _GatedVideoController(super.url) : super.networkUrl() {
    created.add(this);
  }

  static final List<_GatedVideoController> created = <_GatedVideoController>[];
  final Completer<void> initializeGate = Completer<void>();
  final Completer<void> disposeGate = Completer<void>();
  bool disposeStarted = false;
  bool disposed = false;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> initialize() async {
    await initializeGate.future;
    value = value.copyWith(isInitialized: true, duration: const Duration(seconds: 3), size: const Size(1080, 1920));
  }

  @override
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeStarted = true;
    await disposeGate.future;
    disposed = true;
    await super.dispose();
  }
}

class _FailingCreatePlatform extends platform.VideoPlayerPlatform {
  @override
  Future<void> init() => Future<void>.value();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) => Future<void>.value();

  @override
  Future<int?> createWithOptions(platform.VideoCreationOptions options) =>
      Future<int?>.error(PlatformException(code: 'create-failed'));
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

LiveWallVideo _video(LiveSurface surface, {Key? key, String url = 'https://img.example.com/previews/v.img'}) =>
    LiveWallVideo(
      key: key,
      live: WallLive(videoUrl: url, durationMs: 3000, verified: true),
      poster: const ColoredBox(color: Colors.blue),
      surface: surface,
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Removes the players and opens their gates inside the test, so no release budget timer outlives it.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(_app(const SizedBox.shrink()));
  for (final _GatedVideoController controller in _GatedVideoController.created) {
    if (!controller.initializeGate.isCompleted) controller.initializeGate.complete();
    if (!controller.disposeGate.isCompleted) controller.disposeGate.complete();
  }
  await _pump(tester);
  await _pump(tester);
}

void _cleanUpAfterTest(WidgetTester tester) {
  addTearDown(() async {
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    for (final _GatedVideoController controller in _GatedVideoController.created) {
      if (!controller.initializeGate.isCompleted) controller.initializeGate.complete();
      if (!controller.disposeGate.isCompleted) controller.disposeGate.complete();
    }
    await _pump(tester);
    await _pump(tester);
  });
}

void main() {
  setUp(() {
    _GatedVideoController.created.clear();
    LiveWallVideo.createController = (url) => _GatedVideoController(url);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    LiveWallVideo.createController = _defaultCreateController;
    AnalyticsRuntime.reset();
  });

  testWidgets('feed handoff waits for disposal of an initializing controller', (WidgetTester tester) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(
      _app(
        ListView(
          children: <Widget>[
            SizedBox(height: 600, child: _video(LiveSurface.feed)),
            const SizedBox(height: 3000),
            SizedBox(height: 600, child: _video(LiveSurface.feed)),
          ],
        ),
      ),
    );
    await _pump(tester);

    expect(_GatedVideoController.created, hasLength(1));
    final _GatedVideoController first = _GatedVideoController.created.single;

    await tester.drag(find.byType(ListView), const Offset(0, -3500));
    await _pump(tester);

    expect(first.disposeStarted, isTrue);
    expect(_GatedVideoController.created, hasLength(1));

    first.initializeGate.complete();
    first.disposeGate.complete();
    await _pump(tester);

    expect(first.disposed, isTrue);
    expect(_GatedVideoController.created, hasLength(2));

    await _finish(tester);
  });

  testWidgets('changing a keyed feed surface to detail releases its feed player', (WidgetTester tester) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.feed, key: const Key('same'))),
        ),
      ),
    );
    await _pump(tester);
    final _GatedVideoController feedController = _GatedVideoController.created.single;
    feedController.initializeGate.complete();
    await _pump(tester);

    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail, key: const Key('same'))),
        ),
      ),
    );
    await _pump(tester);

    expect(feedController.disposeStarted, isTrue);
    expect(_GatedVideoController.created, hasLength(1));

    feedController.disposeGate.complete();
    await _pump(tester);

    expect(_GatedVideoController.created, hasLength(2));

    await _finish(tester);
  });

  testWidgets('feed URL replacement waits for disposal before another visible feed acquires a player', (
    WidgetTester tester,
  ) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            SizedBox(height: 300, child: _video(LiveSurface.feed, key: const Key('first'))),
            SizedBox(height: 300, child: _video(LiveSurface.feed, key: const Key('second'))),
          ],
        ),
      ),
    );
    await _pump(tester);
    final _GatedVideoController first = _GatedVideoController.created.single;
    first.initializeGate.complete();
    await _pump(tester);

    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            SizedBox(
              height: 300,
              child: _video(LiveSurface.feed, key: const Key('first'), url: 'https://img.example.com/updated.mp4'),
            ),
            SizedBox(height: 300, child: _video(LiveSurface.feed, key: const Key('second'))),
          ],
        ),
      ),
    );
    await _pump(tester);

    expect(first.disposeStarted, isTrue);
    expect(_GatedVideoController.created, hasLength(1));

    first.disposeGate.complete();
    await _pump(tester);

    expect(first.disposed, isTrue);
    expect(_GatedVideoController.created, hasLength(2));

    await _finish(tester);
  });

  testWidgets('late initialization after removal never starts playback', (WidgetTester tester) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _pump(tester);
    final _GatedVideoController controller = _GatedVideoController.created.single;

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await _pump(tester);
    expect(controller.disposeStarted, isTrue);

    controller.initializeGate.complete();
    controller.disposeGate.complete();
    await _pump(tester);

    expect(controller.playCalls, 0);
    expect(controller.disposed, isTrue);
  });

  testWidgets('backgrounding during initialization never starts playback', (WidgetTester tester) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _pump(tester);
    final _GatedVideoController controller = _GatedVideoController.created.single;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pump(tester);
    controller.initializeGate.complete();
    await _pump(tester);

    expect(controller.playCalls, 0);
    expect(controller.pauseCalls, greaterThan(0));

    await _finish(tester);
  });

  testWidgets('pushing another route pauses the detail player', (WidgetTester tester) async {
    _cleanUpAfterTest(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail))),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox.shrink()))),
            ),
          ),
        ),
      ),
    );
    await _pump(tester);
    final _GatedVideoController controller = _GatedVideoController.created.single;
    controller.initializeGate.complete();
    await _pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pump(tester);

    expect(controller.pauseCalls, greaterThan(0));
    expect(controller.disposed, isFalse);

    await _finish(tester);
  });

  testWidgets('video_player dispose stays pending after native creation fails', (WidgetTester tester) async {
    final platform.VideoPlayerPlatform previousPlatform = platform.VideoPlayerPlatform.instance;
    platform.VideoPlayerPlatform.instance = _FailingCreatePlatform();
    addTearDown(() => platform.VideoPlayerPlatform.instance = previousPlatform);

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse('https://img.example.com/previews/v.img'),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await expectLater(controller.initialize(), throwsA(isA<PlatformException>()));

    bool disposed = false;
    unawaited(controller.dispose().then((_) => disposed = true));
    await tester.pump();

    expect(disposed, isFalse);
  });
}
