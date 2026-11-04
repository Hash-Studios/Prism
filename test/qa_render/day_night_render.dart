@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/pages/day_night_screen.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_guide_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

const DayNightWall _day = DayNightWall(
  id: 'day',
  source: WallpaperSource.wallhaven,
  fullUrl: 'https://example.com/day.jpg',
  thumbnailUrl: 'https://example.com/day-thumb.jpg',
);
const DayNightWall _night = DayNightWall(
  id: 'night',
  source: WallpaperSource.wallhaven,
  fullUrl: 'https://example.com/night.jpg',
  thumbnailUrl: 'https://example.com/night-thumb.jpg',
);

Widget _screen(DayNightState state, {double textScale = 1}) {
  final _MockDayNightBloc bloc = _MockDayNightBloc();
  when(() => bloc.state).thenReturn(state);
  return BlocProvider<DayNightBloc>.value(
    value: bloc,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: const DayNightScreen(),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    registerFallbackValue(const DayNightRoute());
    registerFallbackValue(const DayNightEvent.proLapseAcknowledged());
    await loadFonts();
  });

  final DayNightPair complete = DayNightPair(day: _day, night: _night, target: WallpaperTarget.lock, enabled: true);

  qaScreen('day night empty', (QaShot shot) async {
    await shot.pump(_screen(DayNightState(pair: DayNightPair(), loaded: true, isPro: true, userId: 'u')));
    await shot.save('day_night_empty');
  });

  qaScreen('day night complete', (QaShot shot) async {
    await shot.pump(_screen(DayNightState(pair: complete, loaded: true, isPro: true, userId: 'u')));
    await shot.save('day_night_complete');
  });

  qaScreen('day night free', (QaShot shot) async {
    await shot.pump(_screen(DayNightState(pair: complete.copyWith(enabled: false), loaded: true, userId: 'u')));
    await shot.save('day_night_free');
  });

  qaScreen('day night large text', height: 1600, (QaShot shot) async {
    await shot.pump(_screen(DayNightState(pair: complete, loaded: true, isPro: true, userId: 'u'), textScale: 2));
    await shot.save('day_night_large_text');
  });

  qaScreen('day night guide', height: 1200, (QaShot shot) async {
    await shot.pump(
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showDayNightGuideSheet(context, pair: complete),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await shot.tester.tap(find.text('open'));
    await shot.settle(frames: 10);
    await shot.save('day_night_guide');
  });
}
