import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/taste_quiz/biz/bloc/taste_quiz_bloc.j.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'taste_quiz_fixtures.dart';

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> names = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async => names.add(event.eventName);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _DelayedTasteSignalStore extends TasteSignalStore {
  _DelayedTasteSignalStore(super.settingsLocal);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();
  int writeCount = 0;

  @override
  Future<void> recordAll(List<TasteSignal> signals) async {
    writeCount++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await allowWrite.future;
    await super.recordAll(signals);
  }
}

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

  TasteQuizBloc buildBloc({TasteQuizPlan? plan, PersonalizedFeedRepository? feed}) => TasteQuizBloc(
    plan: plan ?? quizPlan(),
    source: TasteQuizSource.onboarding,
    tasteSignals: store,
    feed: feed ?? quizFeed(),
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

  test('measured looks beat the tags in the summary', () async {
    final TasteQuizPlan plan = quizPlan();
    final bloc = buildBloc(plan: plan);
    addTearDown(bloc.close);
    // The right walls are tagged bright. Their pixels say dark.
    for (final QuizRound round in plan.rounds) {
      bloc.add(TasteQuizEvent.looked(key: round.right.key, look: const WallLook(luma: 0.1, edges: 0.02)));
    }
    for (int round = 0; round < plan.rounds.length; round++) {
      _pick(bloc, round, QuizSide.right);
    }
    await _settle();

    final TasteQuizTuning tuning = bloc.state as TasteQuizTuning;
    expect(tuning.summary.tone, QuizTone.dark);
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

  test('a duplicate final tap cannot finish before the pending signal write', () async {
    final delayedStore = _DelayedTasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    final bloc = TasteQuizBloc(
      plan: quizPlan(),
      source: TasteQuizSource.onboarding,
      tasteSignals: delayedStore,
      feed: quizFeed(),
      clock: () => DateTime.utc(2026, 10, 28),
    );
    addTearDown(() async {
      if (!delayedStore.allowWrite.isCompleted) delayedStore.allowWrite.complete();
      await bloc.close();
    });

    await _pickLeft(bloc, 5);
    _pick(bloc, 5, QuizSide.left);
    await delayedStore.writeStarted.future;
    _pick(bloc, 5, QuizSide.right);
    await _settle();

    expect(bloc.state, isA<TasteQuizPlaying>());
    expect(delayedStore.writeCount, 1);

    delayedStore.allowWrite.complete();
    await _settle();
    await _settle();
    expect(bloc.state, isA<TasteQuizTuning>());
  });

  test('skip during the final write cannot be followed by tuning', () async {
    final delayedStore = _DelayedTasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    final bloc = TasteQuizBloc(
      plan: quizPlan(),
      source: TasteQuizSource.onboarding,
      tasteSignals: delayedStore,
      feed: quizFeed(),
      clock: () => DateTime.utc(2026, 10, 28),
    );
    addTearDown(() async {
      if (!delayedStore.allowWrite.isCompleted) delayedStore.allowWrite.complete();
      await bloc.close();
    });

    await _pickLeft(bloc, 5);
    _pick(bloc, 5, QuizSide.left);
    await delayedStore.writeStarted.future;
    bloc.add(const TasteQuizEvent.skipped());
    await _settle();
    expect(bloc.state, isA<TasteQuizFinished>());
    expect((bloc.state as TasteQuizFinished).completed, isFalse);

    delayedStore.allowWrite.complete();
    await _settle();
    await _settle();
    expect(bloc.state, isA<TasteQuizFinished>());
    expect((bloc.state as TasteQuizFinished).completed, isFalse);
    expect(delayedStore.writeCount, 1);
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

  test('tuning shows no walls while the feed loads, then the first six of the real page in order', () async {
    final Completer<PersonalizedFeedPage?> page = Completer<PersonalizedFeedPage?>();
    final QuizFeedMock feed = QuizFeedMock();
    when(feed.primeFirstPage).thenAnswer((_) => page.future);
    final bloc = buildBloc(feed: feed);
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);
    expect((bloc.state as TasteQuizTuning).walls, isNull);

    page.complete(
      PersonalizedFeedPage(items: <FeedItemEntity>[for (int i = 0; i < 9; i++) quizItem('f$i')], hasMore: true),
    );
    await _settle();

    expect((bloc.state as TasteQuizTuning).walls!.map((wall) => wall.id), <String>['f0', 'f1', 'f2', 'f3', 'f4', 'f5']);
    verify(feed.primeFirstPage).called(1);
  });

  test('tuning shows no walls when the feed has none', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);

    expect((bloc.state as TasteQuizTuning).walls, isEmpty);
  });

  testWidgets('tuning gives up on a prime that never finishes after 2.5 s', (tester) async {
    final QuizFeedMock feed = QuizFeedMock();
    when(feed.primeFirstPage).thenAnswer((_) => Completer<PersonalizedFeedPage?>().future);
    final bloc = buildBloc(feed: feed);
    addTearDown(bloc.close);
    for (int round = 0; round < 6; round++) {
      _pick(bloc, round, QuizSide.left);
    }
    await tester.pump(const Duration(milliseconds: 2400));
    expect((bloc.state as TasteQuizTuning).walls, isNull);

    await tester.pump(const Duration(milliseconds: 200));
    expect((bloc.state as TasteQuizTuning).walls, isEmpty);
  });

  test('a prime that finishes after the user left tuning changes nothing', () async {
    final Completer<PersonalizedFeedPage?> page = Completer<PersonalizedFeedPage?>();
    final QuizFeedMock feed = QuizFeedMock();
    when(feed.primeFirstPage).thenAnswer((_) => page.future);
    final bloc = buildBloc(feed: feed);
    addTearDown(bloc.close);

    await _pickLeft(bloc, 6);
    bloc.add(const TasteQuizEvent.tuningShown());
    await _settle();
    page.complete(null);
    await _settle();

    expect(bloc.state, isA<TasteQuizFinished>());
  });
}
