import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockDayNightRepository extends Mock implements DayNightRepository {}

const DayNightWall _day = DayNightWall(
  id: 'day',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/day.jpg',
  thumbnailUrl: 'https://example.com/day-thumb.jpg',
);

const DayNightWall _night = DayNightWall(
  id: 'night',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/night.jpg',
  thumbnailUrl: 'https://example.com/night-thumb.jpg',
);

const DayNightWall _newNight = DayNightWall(
  id: 'night-2',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/night-2.jpg',
  thumbnailUrl: 'https://example.com/night-2-thumb.jpg',
);

DayNightPair _complete({bool enabled = false}) => DayNightPair(day: _day, night: _night, enabled: enabled);

void main() {
  late _MockDayNightRepository repository;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(DayNightPair());
  });

  setUp(() {
    repository = _MockDayNightRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    when(() => repository.save(any(), ownerId: any(named: 'ownerId'))).thenAnswer((_) async {});
    when(() => repository.publish(any())).thenAnswer((_) async {});
    when(() => repository.unpublish()).thenAnswer((_) async {});
  });

  tearDown(AnalyticsRuntime.reset);

  blocTest<DayNightBloc, DayNightState>(
    'turning on with a complete pair as Pro publishes and enables',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.toggled(true)),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', preparing: true),
      DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    ],
    verify: (_) {
      verify(() => repository.publish(_complete(enabled: true))).called(1);
      verify(() => repository.save(_complete(enabled: true), ownerId: 'u1')).called(1);
      expect(analytics.events.single, isA<DayNightEnabledEvent>());
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'turning on without both walls sets needsBothWalls and never publishes',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(
      pair: DayNightPair(day: _day),
      loaded: true,
      isPro: true,
      userId: 'u1',
    ),
    act: (bloc) => bloc.add(const DayNightEvent.toggled(true)),
    expect: () => <DayNightState>[
      DayNightState(
        pair: DayNightPair(day: _day),
        loaded: true,
        isPro: true,
        userId: 'u1',
        issue: DayNightIssue.needsBothWalls,
      ),
    ],
    verify: (_) {
      verifyNever(() => repository.publish(any()));
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'turning on as a free user does nothing',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.toggled(true)),
    expect: () => <DayNightState>[],
    verify: (_) {
      verifyNever(() => repository.publish(any()));
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'turning off unpublishes and disables',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.toggled(false)),
    expect: () => <DayNightState>[DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1')],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
      expect(analytics.events.single, isA<DayNightDisabledEvent>());
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'equal times set timesEqual and keep the old times',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(DayNightEvent.timesChanged(dayStart: DayTime.hm(7, 0), nightStart: DayTime.hm(7, 0))),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', issue: DayNightIssue.timesEqual),
    ],
    verify: (_) {
      verifyNever(() => repository.save(any(), ownerId: any(named: 'ownerId')));
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'a publish failure on wall change while enabled turns it off with the right issue',
    setUp: () {
      when(
        () => repository.publish(any()),
      ).thenThrow(const DayNightPrepareException(DayNightPrepareFailure.needsDownload, slot: DayNightSlot.night));
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.wallPicked(DayNightSlot.night, _newNight)),
    expect: () => <DayNightState>[
      DayNightState(
        pair: DayNightPair(day: _day, night: _newNight, enabled: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
        preparing: true,
      ),
      DayNightState(
        pair: DayNightPair(day: _day, night: _newNight),
        loaded: true,
        isPro: true,
        userId: 'u1',
        issue: DayNightIssue.needsDownloadNight,
      ),
    ],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
      expect(analytics.events.single, isA<DayNightDisabledEvent>());
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'Pro lapse at app start unpublishes, disables and sets proLapsed',
    setUp: () {
      when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
    },
    build: () => DayNightBloc(repository),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u1')),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(enabled: true), loaded: true, userId: 'u1'),
      DayNightState(pair: _complete(), loaded: true, userId: 'u1', proLapsed: true),
    ],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
      verify(() => repository.save(_complete(), ownerId: 'u1')).called(1);
      expect(analytics.events.single, isA<DayNightDisabledEvent>());
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'Pro lapse for the same user sets proLapsed',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u1')),
    expect: () => <DayNightState>[DayNightState(pair: _complete(), loaded: true, userId: 'u1', proLapsed: true)],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'account switch unpublishes and does not set proLapsed',
    setUp: () {
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => _complete(enabled: true));
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2')),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(enabled: true), loaded: true, userId: 'u2'),
      DayNightState(pair: _complete(), loaded: true, userId: 'u2'),
    ],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'sign-out unpublishes and does not set proLapsed',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: '')),
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true)],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
      verifyNever(() => repository.load(ownerId: any(named: 'ownerId')));
    },
  );
}
