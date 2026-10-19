@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_analytics.dart';
import 'home_render_support.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

DropEntity _drop({required Duration endsIn}) {
  final DateTime now = DateTime.now();
  return DropEntity(
    weekKey: '2026-W42',
    title: 'Neon Tides',
    startsAt: now.subtract(const Duration(days: 1)),
    endsAt: now.add(endsIn),
    priceWall: 30,
    pricePack: 100,
    count: 6,
    walls: <DropWall>[
      for (final String photo in <String>['w05.jpg', 'w11.jpg', 'w17.jpg'])
        DropWall(id: photo, title: photo, thumb: photoUrl(photo), resolution: '1080x2400', by: 'Ana', seriesId: 's1'),
    ],
  );
}

void main() {
  setUpAll(() async {
    if (homeRender) await loadAppFonts();
  });

  void scene(String name, ThemeData theme, Duration endsIn) {
    testWidgets(name, skip: !homeRender, (WidgetTester tester) async {
      final HomeShot shot = HomeShot(tester)..configureView();
      QaPhotoCache.install();
      AnalyticsRuntime.instance = FakeAppAnalytics();
      final _MockWotdBloc wotd = _MockWotdBloc();
      whenListen(wotd, const Stream<WotdState>.empty(), initialState: WotdState.initial());
      await tester.pumpWidget(
        shot.frame(
          brightness: theme.brightness,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: BlocProvider<WotdBloc>.value(
              value: wotd,
              child: Builder(
                builder: (BuildContext context) => Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: FeedCarousel(
                      previewWalls: const [],
                      liveDrop: _drop(endsIn: endsIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await shot.settle();
      await shot.save(name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
      QaPhotoCache.uninstall();
      AnalyticsRuntime.reset();
    });
  }

  scene('drop-carousel-amoled', kDarkTheme2, const Duration(days: 3, hours: 4, minutes: 30));
  scene('drop-carousel-light', kLightTheme, const Duration(days: 3, hours: 4, minutes: 30));
  scene('drop-carousel-last-call-amoled', kDarkTheme2, const Duration(hours: 5, minutes: 10));
}
