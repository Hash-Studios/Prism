import 'dart:math';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/taste_quiz/biz/bloc/taste_quiz_bloc.j.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'taste_quiz_fixtures.dart';

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> names = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async => names.add(event.eventName);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void _pick(TasteQuizBloc bloc, int round, QuizSide side) => bloc.add(TasteQuizEvent.picked(round: round, side: side));

Future<void> _pickLeft(TasteQuizBloc bloc, int count) async {
  for (int round = 0; round < count; round++) {
    _pick(bloc, round, QuizSide.left);
  }
  await _settle();
}

void main() {
  late _RecordingAnalytics analytics;
  late TasteSignalStore store;

  setUp(() {
    analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() {
    AnalyticsRuntime.reset();
  });

  TasteQuizBloc buildBloc({TasteQuizPlan? plan}) => TasteQuizBloc(
    plan: plan ?? quizPlan(),
    source: TasteQuizSource.onboarding,
    interests: const <String>['Nature'],
    tasteSignals: store,
    random: Random(1),
    clock: () => DateTime.utc(2026, 10, 28),
  );

  test('starts on round 1 with no picks and tracks the start', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await _settle();

    expect(bloc.state, isA<TasteQuizPlaying>());
    expect((bloc.state as TasteQuizPlaying).picks, isEmpty);
    expect(analytics.names, contains('taste_quiz_started'));
  });

  test('six left picks finish in tuning and store the favourites and passes', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    expect(bloc.state, isA<TasteQuizTuning>());
    final TasteQuizTuning tuning = bloc.state as TasteQuizTuning;
    expect(tuning.summary.tone, QuizTone.dark);
    expect(tuning.summary.tag, 'neon');

    final List<TasteSignal> signals = store.read();
    expect(signals, hasLength(12));
    final List<TasteSignal> favourites = signals.where((s) => s.action == TasteAction.favourite).toList();
    final List<TasteSignal> passedOver = signals.where((s) => s.action == TasteAction.passedOver).toList();
    expect(favourites, hasLength(6));
    expect(passedOver, hasLength(6));
    for (final TasteSignal signal in favourites) {
      expect(signal.terms, contains('neon'));
    }

    expect(analytics.names.where((n) => n == 'taste_quiz_round_picked'), hasLength(6));
    expect(analytics.names.where((n) => n == 'taste_quiz_completed'), hasLength(1));
  });

  test('a stale or double tap is ignored', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    _pick(bloc, 0, QuizSide.left);
    _pick(bloc, 0, QuizSide.left);
    await _settle();
    expect((bloc.state as TasteQuizPlaying).picks, hasLength(1));

    _pick(bloc, 3, QuizSide.left);
    await _settle();
    expect((bloc.state as TasteQuizPlaying).picks, hasLength(1));
  });

  for (int k = 0; k < 6; k++) {
    test('skip at round $k', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await _pickLeft(bloc, k);
      bloc.add(const TasteQuizEvent.skipped());
      await _settle();

      expect(bloc.state, isA<TasteQuizFinished>());
      expect((bloc.state as TasteQuizFinished).completed, isFalse);
      expect(store.read(), hasLength(2 * k));
      expect(analytics.names.where((n) => n == 'taste_quiz_skipped'), hasLength(1));
    });
  }

  test('tuning shown after tuning finishes as completed', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await _pickLeft(bloc, 6);

    bloc.add(const TasteQuizEvent.tuningShown());
    await _settle();

    expect(bloc.state, isA<TasteQuizFinished>());
    expect((bloc.state as TasteQuizFinished).completed, isTrue);
  });

  test('tuning shown while playing does nothing', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const TasteQuizEvent.tuningShown());
    await _settle();

    expect(bloc.state, isA<TasteQuizPlaying>());
  });

  test('signals are written once when the quiz ends', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await _pickLeft(bloc, 6);
    expect(store.read(), hasLength(12));

    bloc.add(const TasteQuizEvent.skipped());
    _pick(bloc, 5, QuizSide.right);
    bloc.add(const TasteQuizEvent.tuningShown());
    bloc.add(const TasteQuizEvent.skipped());
    await _settle();

    expect(store.read(), hasLength(12));
  });

  test('existing signals are kept when the quiz completes', () async {
    await store.record(TasteSignal(action: TasteAction.set, at: DateTime.utc(2026), terms: const <String>['ocean']));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    final List<TasteSignal> signals = store.read();
    expect(signals, hasLength(13));
    expect(signals.where((s) => s.terms.length == 1 && s.terms.first == 'ocean'), hasLength(1));
  });

  test('the favourites seed flag is left alone', () async {
    expect(store.isSeeded, isFalse);
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    expect(store.isSeeded, isFalse);
  });

  test('tuning walls are picked from the leftover pool, not from the quiz walls', () async {
    final bloc = buildBloc(
      plan: quizPlan(
        pool: <QuizWall>[
          for (int i = 0; i < 8; i++)
            quizWall('p$i', tags: i.isEven ? <String>['dark', 'minimal'] : <String>['bright', 'city']),
        ],
      ),
    );
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    final TasteQuizTuning tuning = bloc.state as TasteQuizTuning;
    expect(tuning.walls.length, inInclusiveRange(4, 6));
    for (final wall in tuning.walls) {
      expect(wall.id.startsWith('l') || wall.id.startsWith('r'), isFalse);
    }
  });

  test('tuning walls fall back to the picked walls when the pool is empty', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    final TasteQuizTuning tuning = bloc.state as TasteQuizTuning;
    expect(tuning.walls.map((wall) => wall.id).toList(), <String>['l0', 'l1', 'l2', 'l3', 'l4', 'l5']);
  });
}
