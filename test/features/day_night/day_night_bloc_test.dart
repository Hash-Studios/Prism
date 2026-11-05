import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

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
const DayNightWall _newDay = DayNightWall(
  id: 'day-2',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/day-2.jpg',
  thumbnailUrl: 'https://example.com/day-2-thumb.jpg',
);

DayNightPair _complete({bool enabled = false}) => DayNightPair(day: _day, night: _night, enabled: enabled);

void main() {
  late _MockDayNightRepository repository;
  late FakeAppAnalytics analytics;
  late Completer<void> publishGate;
  late Completer<void> operationStarted;
  late Completer<DayNightPair> operationGate;

  setUpAll(() {
    registerFallbackValue(DayNightPair());
  });

  setUp(() async {
    repository = _MockDayNightRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = profileUser();
    await app_state.persistPrismUser();
    when(() => repository.save(any(), ownerId: any(named: 'ownerId'))).thenAnswer((_) async {});
    when(() => repository.publish(any())).thenAnswer((_) async {});
    when(() => repository.unpublish()).thenAnswer((_) async {});
    when(() => repository.runsOnDevice).thenReturn(false);
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await app_state.persistPrismUser();
    AnalyticsRuntime.reset();
  });

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
    'a failed save after publish removes the snapshot and offers retry',
    setUp: () {
      when(() => repository.save(_complete(enabled: true), ownerId: 'u1')).thenThrow(StateError('disk full'));
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) => bloc.add(const DayNightEvent.toggled(true)),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', preparing: true),
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', issue: DayNightIssue.offlineCopyFailed),
    ],
    verify: (_) {
      verify(() => repository.publish(_complete(enabled: true))).called(1);
      verify(() => repository.unpublish()).called(1);
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

  group('auto-rotate pass', () {
    final DateTime now = DateTime(2026, 11, 5, 12);
    final DateTime passEnd = DateTime(2026, 11, 8, 12);
    DayNightPair passPair({required DateTime until}) =>
        DayNightPair(day: _day, night: _night, enabled: true, passUntil: until);
    DayNightBloc build() => DayNightBloc(repository)..clock = () => now;

    blocTest<DayNightBloc, DayNightState>(
      'a stored pass keeps the mode on at launch before the passes load',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => passPair(until: passEnd));
      },
      build: build,
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(
          pair: passPair(until: passEnd),
          loaded: true,
          isPro: true,
          userId: 'u1',
        ),
      ],
      verify: (_) {
        verify(() => repository.publish(passPair(until: passEnd))).called(1);
        verifyNever(() => repository.save(any(), ownerId: any(named: 'ownerId')));
        expect(analytics.events, isEmpty);
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a stored pass that ended turns the mode off with the notice',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => passPair(until: DateTime(2026, 11, 5, 11)));
      },
      build: build,
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(
          pair: passPair(until: DateTime(2026, 11, 5, 11)),
          loaded: true,
          userId: 'u1',
        ),
        DayNightState(pair: _complete(), loaded: true, userId: 'u1', proLapsed: true),
      ],
      verify: (_) {
        verify(() => repository.save(_complete(), ownerId: 'u1')).called(1);
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a live pass stores its end with the pair',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
      },
      build: build,
      act: (bloc) => bloc.add(DayNightEvent.entitlementChanged(isPro: true, userId: 'u1', passUntil: passEnd)),
      expect: () => <DayNightState>[
        DayNightState(
          pair: passPair(until: passEnd),
          loaded: true,
          isPro: true,
          userId: 'u1',
        ),
      ],
      verify: (_) {
        verify(() => repository.save(passPair(until: passEnd), ownerId: 'u1')).called(1);
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'another account does not inherit a stored pass',
      setUp: () {
        when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => passPair(until: passEnd));
      },
      build: build,
      seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
      act: (bloc) async {
        app_state.prismUser = profileUser(id: 'u2');
        await app_state.persistPrismUser();
        bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
      },
      expect: () => <DayNightState>[
        DayNightState(
          pair: passPair(until: passEnd),
          loaded: true,
          userId: 'u2',
        ),
        DayNightState(pair: _complete(), loaded: true, userId: 'u2'),
      ],
    );
  });

  blocTest<DayNightBloc, DayNightState>(
    'a loaded enabled pair is disabled with a retry issue when its snapshot cannot be restored',
    setUp: () {
      when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
      when(
        () => repository.publish(any()),
      ).thenThrow(const DayNightPrepareException(DayNightPrepareFailure.needsDownload, slot: DayNightSlot.day));
    },
    build: () => DayNightBloc(repository),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', issue: DayNightIssue.needsDownloadDay),
    ],
    verify: (_) {
      verify(() => repository.unpublish()).called(2);
      verify(() => repository.save(_complete(), ownerId: 'u1')).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'an enabled Pro pair republishes its offline snapshot on session load',
    setUp: () {
      when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
    },
    build: () => DayNightBloc(repository),
    act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    ],
    verify: (_) => verify(() => repository.publish(_complete(enabled: true))).called(1),
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
    act: (bloc) async {
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
    },
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
    act: (bloc) async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: ''));
    },
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true)],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
      verifyNever(() => repository.load(ownerId: any(named: 'ownerId')));
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'a user switch removes a stale snapshot even when the stored pair is off',
    setUp: () {
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => DayNightPair());
    },
    build: () => DayNightBloc(repository),
    act: (bloc) {
      app_state.prismUser = profileUser(id: 'u2');
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
    },
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true, userId: 'u2')],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'initial signed-out session removes a stale snapshot',
    build: () => DayNightBloc(repository),
    act: (bloc) {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: ''));
    },
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true)],
    verify: (_) {
      verify(() => repository.unpublish()).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'an expired account reached after sign-out does not trigger an initial-session lapse notice',
    setUp: () {
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => _complete(enabled: true));
    },
    build: () => DayNightBloc(repository),
    act: (bloc) async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: ''));
      await bloc.stream.firstWhere((DayNightState state) => state.loaded && state.userId.isEmpty);
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
    },
    expect: () => <DayNightState>[
      DayNightState(pair: DayNightPair(), loaded: true),
      DayNightState(pair: _complete(enabled: true), loaded: true, userId: 'u2'),
      DayNightState(pair: _complete(), loaded: true, userId: 'u2'),
    ],
    verify: (_) {
      verify(() => repository.save(_complete(), ownerId: 'u2')).called(1);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'a queued edit from the previous account cannot publish after an account switch',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) async {
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.wallPicked(DayNightSlot.night, _newNight));
    },
    expect: () => <DayNightState>[],
    verify: (_) {
      verifyNever(() => repository.save(any(), ownerId: any(named: 'ownerId')));
      verifyNever(() => repository.publish(any()));
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'quick edits to an enabled pair serialize and publish the combined final selection in order',
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) {
      bloc.add(const DayNightEvent.wallPicked(DayNightSlot.day, _newDay));
      bloc.add(const DayNightEvent.wallPicked(DayNightSlot.night, _newNight));
    },
    expect: () => <DayNightState>[
      DayNightState(
        pair: DayNightPair(day: _newDay, night: _night, enabled: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
        preparing: true,
      ),
      DayNightState(
        pair: DayNightPair(day: _newDay, night: _night, enabled: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
      ),
      DayNightState(
        pair: DayNightPair(day: _newDay, night: _newNight, enabled: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
        preparing: true,
      ),
      DayNightState(
        pair: DayNightPair(day: _newDay, night: _newNight, enabled: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
      ),
    ],
    verify: (_) {
      verifyInOrder(<void Function()>[
        () => repository.publish(DayNightPair(day: _newDay, night: _night, enabled: true)),
        () => repository.publish(DayNightPair(day: _newDay, night: _newNight, enabled: true)),
      ]);
    },
  );

  blocTest<DayNightBloc, DayNightState>(
    'a user switch during pair loading cannot emit the old account pair',
    setUp: () {
      operationStarted = Completer<void>();
      operationGate = Completer<DayNightPair>();
      when(() => repository.load(ownerId: 'u1')).thenAnswer((_) {
        operationStarted.complete();
        return operationGate.future;
      });
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => DayNightPair());
    },
    build: () => DayNightBloc(repository),
    act: (bloc) async {
      bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1'));
      await operationStarted.future;
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
      operationGate.complete(_complete(enabled: true));
    },
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true, userId: 'u2')],
  );

  blocTest<DayNightBloc, DayNightState>(
    'a user switch during pair save cannot publish the old account selection',
    setUp: () {
      operationStarted = Completer<void>();
      operationGate = Completer<DayNightPair>();
      when(() => repository.save(any(), ownerId: 'u1')).thenAnswer((_) async {
        operationStarted.complete();
        await operationGate.future;
      });
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => DayNightPair());
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) async {
      bloc.add(const DayNightEvent.wallPicked(DayNightSlot.day, _newDay));
      await operationStarted.future;
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
      operationGate.complete(DayNightPair());
    },
    expect: () => <DayNightState>[DayNightState(pair: DayNightPair(), loaded: true, userId: 'u2')],
    verify: (_) => verifyNever(() => repository.publish(any())),
  );

  blocTest<DayNightBloc, DayNightState>(
    'account switch clears preparing after an in-flight publish is cancelled',
    setUp: () {
      publishGate = Completer<void>();
      when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => DayNightPair());
      when(() => repository.publish(any())).thenAnswer((_) => publishGate.future);
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) async {
      bloc.add(const DayNightEvent.toggled(true));
      await bloc.stream.firstWhere((DayNightState state) => state.preparing);
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      bloc.add(const DayNightEvent.entitlementChanged(isPro: false, userId: 'u2'));
      // The mock completes when the bloc first requests publication.
      await Future<void>.delayed(Duration.zero);
      publishGate.complete();
    },
    expect: () => <DayNightState>[
      DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1', preparing: true),
      DayNightState(pair: DayNightPair(), loaded: true, userId: 'u2'),
    ],
  );

  blocTest<DayNightBloc, DayNightState>(
    'turning off after an account switch during save does not emit for the old owner',
    setUp: () {
      operationStarted = Completer<void>();
      operationGate = Completer<DayNightPair>();
      when(() => repository.save(any(), ownerId: 'u1')).thenAnswer((_) async {
        operationStarted.complete();
        await operationGate.future;
      });
    },
    build: () => DayNightBloc(repository),
    seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
    act: (bloc) async {
      bloc.add(const DayNightEvent.toggled(false));
      await operationStarted.future;
      app_state.prismUser = profileUser(id: 'u2');
      await app_state.persistPrismUser();
      operationGate.complete(DayNightPair());
    },
    expect: () => <DayNightState>[],
    verify: (_) {
      verify(() => repository.save(_complete(), ownerId: 'u1')).called(1);
      expect(analytics.events, isEmpty);
    },
  );

  group('Android device schedule', () {
    setUp(() {
      when(() => repository.runsOnDevice).thenReturn(true);
      when(() => repository.applyOnOpen()).thenAnswer((_) async => (running: true, switched: null));
    });

    blocTest<DayNightBloc, DayNightState>(
      'initial session with an enabled Pro pair resumes the schedule without unpublishing',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenAnswer(
          (_) async => (running: true, switched: (slot: DayNightSlot.night, source: DayNightSwitchSource.appOpen)),
        );
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      ],
      verify: (_) {
        verify(() => repository.applyOnOpen()).called(1);
        verifyNever(() => repository.unpublish());
        verifyNever(() => repository.publish(any()));
        expect(
          analytics.events.single,
          isA<DayNightSwitchedEvent>()
              .having((e) => e.slot, 'slot', 'night')
              .having((e) => e.source, 'source', 'app_open'),
        );
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'an alarm switch to the day wall is tracked with slot day and source alarm',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenAnswer(
          (_) async => (running: true, switched: (slot: DayNightSlot.day, source: DayNightSwitchSource.alarm)),
        );
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      ],
      verify: (_) {
        verifyNever(() => repository.publish(any()));
        expect(
          analytics.events.single,
          isA<DayNightSwitchedEvent>().having((e) => e.slot, 'slot', 'day').having((e) => e.source, 'source', 'alarm'),
        );
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a schedule that is not running is published again with the stored pair and tracks no switch',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenAnswer((_) async => (running: false, switched: null));
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      ],
      verify: (_) {
        verify(() => repository.publish(_complete(enabled: true))).called(1);
        expect(analytics.events, isEmpty);
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a throwing applyOnOpen counts as not running and publishes the stored pair again',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenThrow(StateError('apply failed'));
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      ],
      verify: (_) {
        verify(() => repository.publish(_complete(enabled: true))).called(1);
        expect(analytics.events, isEmpty);
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a failed republish after the schedule stops turns the pair off with the offline copy issue',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenAnswer((_) async => (running: false, switched: null));
        when(
          () => repository.publish(any()),
        ).thenThrow(const DayNightPrepareException(DayNightPrepareFailure.offlineCopyFailed));
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
        DayNightState(
          pair: _complete(),
          loaded: true,
          isPro: true,
          userId: 'u1',
          issue: DayNightIssue.offlineCopyFailed,
        ),
      ],
      verify: (_) {
        verify(() => repository.save(_complete(), ownerId: 'u1')).called(1);
        verify(() => repository.unpublish()).called(1);
        expect(analytics.events.single, isA<DayNightDisabledEvent>());
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'Pro lapse at app start unpublishes once, never resumes, and sets proLapsed',
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
        verifyNever(() => repository.applyOnOpen());
        expect(analytics.events.single, isA<DayNightDisabledEvent>());
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a stored pair that is off unpublishes once and never resumes',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete());
      },
      build: () => DayNightBloc(repository),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1')],
      verify: (_) {
        verify(() => repository.unpublish()).called(1);
        verifyNever(() => repository.applyOnOpen());
        verifyNever(() => repository.publish(any()));
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a second entitlement event for the same Pro user resumes the schedule again',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete(enabled: true));
      },
      build: () => DayNightBloc(repository),
      act: (bloc) {
        bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1'));
        bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1'));
      },
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      ],
      verify: (_) {
        verify(() => repository.applyOnOpen()).called(2);
        verifyNever(() => repository.publish(any()));
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'an account switch replaces the old device schedule with the new enabled pair',
      setUp: () {
        when(() => repository.load(ownerId: 'u2')).thenAnswer((_) async => _complete(enabled: true));
        when(() => repository.applyOnOpen()).thenAnswer((_) async => (running: true, switched: null));
      },
      build: () => DayNightBloc(repository),
      seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      act: (bloc) async {
        app_state.prismUser = profileUser(id: 'u2');
        await app_state.persistPrismUser();
        bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u2'));
      },
      expect: () => <DayNightState>[
        DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u2'),
      ],
      verify: (_) {
        verify(() => repository.unpublish()).called(1);
        verify(() => repository.publish(_complete(enabled: true))).called(1);
        verifyNever(() => repository.applyOnOpen());
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'a same-user resume does not restart a pair cleared by another schedule mode',
      setUp: () {
        when(() => repository.load(ownerId: 'u1')).thenAnswer((_) async => _complete());
      },
      build: () => DayNightBloc(repository),
      seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      act: (bloc) => bloc.add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'u1')),
      expect: () => <DayNightState>[DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1')],
      verify: (_) {
        verify(() => repository.load(ownerId: 'u1')).called(1);
        verifyNever(() => repository.applyOnOpen());
        verifyNever(() => repository.publish(any()));
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'turning off on Android unpublishes the device schedule and disables the pair',
      build: () => DayNightBloc(repository),
      seed: () => DayNightState(pair: _complete(enabled: true), loaded: true, isPro: true, userId: 'u1'),
      act: (bloc) => bloc.add(const DayNightEvent.toggled(false)),
      expect: () => <DayNightState>[DayNightState(pair: _complete(), loaded: true, isPro: true, userId: 'u1')],
      verify: (_) {
        verify(() => repository.unpublish()).called(1);
        verifyNever(() => repository.applyOnOpen());
        expect(analytics.events.single, isA<DayNightDisabledEvent>());
      },
    );
  });
}
