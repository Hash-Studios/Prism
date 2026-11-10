import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/live_wall_video.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../../helpers/fake_video_controller.dart';
import '../../support/fake_app_analytics.dart';

final VideoPlayerController Function(Uri url) _defaultCreateController = LiveWallVideo.createController;

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling, bool reducedMotion = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler, disableAnimations: reducedMotion),
    child: home!,
  ),
  home: Scaffold(body: child),
);

LiveWallVideo _video(LiveSurface surface) => LiveWallVideo(
  live: const WallLive(videoUrl: 'https://img.example.com/previews/v.img', durationMs: 3000, verified: true),
  poster: const ColoredBox(key: Key('poster'), color: Colors.blue),
  surface: surface,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    LiveWallVideo.createController = (url) => FakeVideoController(url);
    FakeVideoController.created.clear();
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    LiveWallVideo.createController = _defaultCreateController;
    AnalyticsRuntime.reset();
    LowDataMode.enabled.value = false;
  });

  testWidgets('detail plays muted and looping over the poster', (WidgetTester tester) async {
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    final FakeVideoController controller = FakeVideoController.created.single;
    expect(controller.playCalls, greaterThanOrEqualTo(1));
    expect(controller.value.volume, 0);
    expect(controller.value.isLooping, isTrue);
    expect(find.byKey(const Key('poster')), findsOneWidget);
  });

  testWidgets('detail pauses off screen and keeps its controller', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
          children: <Widget>[
            SizedBox(height: 600, child: _video(LiveSurface.detail)),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    );
    await _settle(tester);
    final FakeVideoController controller = FakeVideoController.created.single;
    final int playsBefore = controller.playCalls;

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await _settle(tester);

    expect(controller.pauseCalls, greaterThanOrEqualTo(1));
    expect(controller.disposed, isFalse);
    expect(FakeVideoController.created, hasLength(1));

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await _settle(tester);

    expect(controller.playCalls, greaterThan(playsBefore));
    expect(FakeVideoController.created, hasLength(1));
  });

  testWidgets('feed frees its player off screen and makes a new one on return', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
          children: <Widget>[
            SizedBox(height: 600, child: _video(LiveSurface.feed)),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(FakeVideoController.created, hasLength(1));
    final FakeVideoController first = FakeVideoController.created.single;

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await _settle(tester);

    expect(first.disposed, isTrue);
    expect(FakeVideoController.created, hasLength(1));

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(2));
    expect(FakeVideoController.created.last.playCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('a player that never finishes closing does not hold the feed slot', (WidgetTester tester) async {
    LiveWallVideo.createController = (url) => _StuckDisposeController(url);
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
    await _settle(tester);
    expect(FakeVideoController.created, hasLength(1));
    LiveWallVideo.createController = (url) => FakeVideoController(url);

    await tester.drag(find.byType(ListView), const Offset(0, -3500));
    await _settle(tester);
    await tester.pump(LiveWallVideo.releaseBudget);
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(2));
    expect(FakeVideoController.created.last.playCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('only one feed card plays at a time', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            SizedBox(height: 300, child: _video(LiveSurface.feed)),
            SizedBox(height: 300, child: _video(LiveSurface.feed)),
          ],
        ),
      ),
    );
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('reduced motion shows the detail poster and a play button, not a video', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail))), reducedMotion: true),
    );
    await _settle(tester);

    expect(FakeVideoController.created, isEmpty);
    expect(find.byTooltip('Play video'), findsOneWidget);

    await tester.tap(find.byTooltip('Play video'));
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
    expect(find.byTooltip('Pause video'), findsOneWidget);
  });

  testWidgets('reduced motion gives a feed card no controller and no button', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.feed))), reducedMotion: true),
    );
    await _settle(tester);

    expect(FakeVideoController.created, isEmpty);
    expect(find.byTooltip('Play video'), findsNothing);
    expect(find.byTooltip('Pause video'), findsNothing);
  });

  testWidgets('data saver waits for a tap on the detail screen', (WidgetTester tester) async {
    LowDataMode.enabled.value = true;
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);

    expect(FakeVideoController.created, isEmpty);
    expect(find.byTooltip('Play video'), findsOneWidget);

    await tester.tap(find.byTooltip('Play video'));
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('data saver turned off at runtime starts the video without a tap', (WidgetTester tester) async {
    LowDataMode.enabled.value = true;
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);

    expect(FakeVideoController.created, isEmpty);

    LowDataMode.enabled.value = false;
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
    expect(find.byTooltip('Pause video'), findsOneWidget);
  });

  testWidgets('review plays with reduced motion and data saver on, no tap', (WidgetTester tester) async {
    LowDataMode.enabled.value = true;
    await tester.pumpWidget(
      _app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.review))), reducedMotion: true),
    );
    await _settle(tester);

    expect(FakeVideoController.created, hasLength(1));
    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('pause button pauses a playing detail video', (WidgetTester tester) async {
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);
    final FakeVideoController controller = FakeVideoController.created.single;
    expect(controller.playCalls, greaterThanOrEqualTo(1));

    await tester.tap(find.byTooltip('Pause video'));
    await _settle(tester);

    expect(controller.pauseCalls, greaterThanOrEqualTo(1));
    expect(find.byTooltip('Play video'), findsOneWidget);
  });

  testWidgets('app background pauses the video and resume plays it again', (WidgetTester tester) async {
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);
    final FakeVideoController controller = FakeVideoController.created.single;
    final int playsBefore = controller.playCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _settle(tester);

    expect(controller.pauseCalls, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(controller.playCalls, greaterThan(playsBefore));
  });

  testWidgets('large text keeps the detail button without an exception', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        Center(child: SizedBox(width: 200, height: 300, child: _video(LiveSurface.detail))),
        textScaler: const TextScaler.linear(2.0),
      ),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    // The button names itself through its tooltip, which is the semantics tooltip, not the label.
    final SemanticsHandle handle = tester.ensureSemantics();
    final String name = find.byTooltip('Pause video').evaluate().isNotEmpty ? 'Pause video' : 'Play video';
    expect(tester.getSemantics(find.byTooltip(name)).tooltip, name);
    handle.dispose();
  });

  testWidgets('disposing a playing video throws nothing and frees its controller', (WidgetTester tester) async {
    await tester.pumpWidget(_app(Center(child: SizedBox(width: 300, height: 600, child: _video(LiveSurface.detail)))));
    await _settle(tester);
    final FakeVideoController controller = FakeVideoController.created.single;
    expect(controller.playCalls, greaterThanOrEqualTo(1));

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(controller.disposed, isTrue);
  });
}

/// video_player 2.x leaves dispose pending after a failed native create.
class _StuckDisposeController extends FakeVideoController {
  _StuckDisposeController(super.url);

  @override
  // ignore: must_call_super
  Future<void> dispose() {
    disposed = true;
    return Completer<void>().future;
  }
}
