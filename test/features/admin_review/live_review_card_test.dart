import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/widgets/live_wall_video.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../../helpers/fake_video_controller.dart';
import '../../support/fake_app_analytics.dart';

final VideoPlayerController Function(Uri url) _defaultCreateController = LiveWallVideo.createController;

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? home) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: home!),
  home: Scaffold(body: SizedBox(width: 360, height: 640, child: child)),
);

SwipeWallpaperCard _card(Map<String, dynamic>? liveData) => SwipeWallpaperCard(
  imageUrl: '',
  title: 'Dune',
  category: 'Nature',
  authorName: 'Creator',
  authorPhoto: '',
  liveData: liveData,
);

Map<String, dynamic> _liveWall({bool? verified, int? durationMs = 4200}) => <String, dynamic>{
  'kind': 'live',
  'live': <String, dynamic>{
    'video': 'https://img.example.com/previews/x.img',
    'verified': ?verified,
    'durationMs': ?durationMs,
  },
};

void main() {
  setUp(() {
    LiveWallVideo.createController = (url) => FakeVideoController(url);
    FakeVideoController.created.clear();
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    LiveWallVideo.createController = _defaultCreateController;
    AnalyticsRuntime.reset();
  });

  testWidgets('a verified live wall plays its video and shows its length', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_card(_liveWall(verified: true))));
    await tester.pump();

    expect(find.byType(LiveWallVideo), findsOneWidget);
    expect(find.text('Live · 4.2 s'), findsOneWidget);
  });

  testWidgets('a live wall the server has not checked shows the checking pill and no video', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_card(_liveWall())));
    await tester.pump();

    expect(find.text('Checking the video'), findsOneWidget);
    expect(find.byType(LiveWallVideo), findsNothing);
  });

  testWidgets('a live wall the server refused shows the failed pill and no video', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_card(_liveWall(verified: false))));
    await tester.pump();

    expect(find.text('The video failed the server check'), findsOneWidget);
    expect(find.byType(LiveWallVideo), findsNothing);
  });

  testWidgets('a wall with no kind shows no video', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        _card(<String, dynamic>{
          'live': <String, dynamic>{'video': 'https://img.example.com/previews/x.img', 'verified': true},
        }),
      ),
    );
    await tester.pump();

    expect(find.byType(LiveWallVideo), findsNothing);
  });

  testWidgets('a verified live wall starts playing even with reduced motion on', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_card(_liveWall(verified: true))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(FakeVideoController.created.single.playCalls, greaterThanOrEqualTo(1));
  });
}
