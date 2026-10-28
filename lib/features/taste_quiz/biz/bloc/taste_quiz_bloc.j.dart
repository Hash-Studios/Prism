import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'taste_quiz_event.j.dart';
part 'taste_quiz_state.j.dart';
part 'taste_quiz_bloc.j.freezed.dart';

/// Runs one "This or that" quiz over a ready [TasteQuizPlan]. The picks reach [TasteSignalStore] once, when the quiz
/// ends by the last pick or by a skip.
class TasteQuizBloc extends Bloc<TasteQuizEvent, TasteQuizState> {
  TasteQuizBloc({
    required TasteQuizPlan plan,
    required this.source,
    required TasteSignalStore tasteSignals,
    required PersonalizedFeedRepository feed,
    DateTime Function()? clock,
  }) : _tasteSignals = tasteSignals,
       _feed = feed,
       _clock = clock ?? DateTime.now,
       super(TasteQuizState.playing(plan: plan, picks: const <QuizPick>[])) {
    on<_Picked>(_onPicked);
    on<_Skipped>(_onSkipped);
    on<_TuningShown>(_onTuningShown);
    unawaited(analytics.track(TasteQuizStartedEvent(source: source)));
  }

  final TasteQuizSource source;
  final TasteSignalStore _tasteSignals;
  final PersonalizedFeedRepository _feed;
  final DateTime Function() _clock;
  bool _committed = false;

  static const int tuningMax = 6;

  /// How long Tuning waits for the real first page before it shows the summary line alone.
  static const Duration feedPreviewBudget = Duration(milliseconds: 2500);

  Future<void> _onPicked(_Picked event, Emitter<TasteQuizState> emit) async {
    final TasteQuizState current = state;
    if (current is! TasteQuizPlaying || _committed || event.round != current.picks.length) return;
    final QuizRound round = current.plan.rounds[event.round];
    unawaited(
      analytics.track(
        TasteQuizRoundPickedEvent(source: source, roundIndex: event.round, side: event.side, wildCard: round.wildCard),
      ),
    );
    final List<QuizPick> picks = <QuizPick>[...current.picks, QuizPick(round: round, side: event.side)];
    if (picks.length < current.plan.rounds.length) {
      emit(TasteQuizState.playing(plan: current.plan, picks: picks));
      return;
    }
    await _commit(picks);
    if (emit.isDone || state is! TasteQuizPlaying) return;
    unawaited(analytics.track(TasteQuizCompletedEvent(source: source)));
    final TasteSummary summary = summarizeTaste(picks);
    emit(TasteQuizState.tuning(summary: summary));
    // The timeout only stops the wait. The prime keeps running, so the feed still takes its page.
    final Stopwatch watch = Stopwatch()..start();
    List<FeedItemEntity> walls = const <FeedItemEntity>[];
    try {
      final PersonalizedFeedPage? page = await _feed.primeFirstPage().timeout(feedPreviewBudget);
      walls = page?.items.take(tuningMax).toList(growable: false) ?? walls;
    } catch (_) {}
    if (emit.isDone || state is! TasteQuizTuning) return;
    PerformanceProbe.mark(
      'tuning.feed_ready',
      extra: <String, Object?>{'ms': watch.elapsedMilliseconds, 'walls': walls.length},
    );
    emit(TasteQuizState.tuning(summary: summary, walls: walls));
  }

  Future<void> _onSkipped(_Skipped event, Emitter<TasteQuizState> emit) async {
    final TasteQuizState current = state;
    if (current is! TasteQuizPlaying) return;
    unawaited(analytics.track(TasteQuizSkippedEvent(source: source, roundIndex: current.picks.length)));
    emit(const TasteQuizState.finished(completed: false));
    await _commit(current.picks);
  }

  void _onTuningShown(_TuningShown event, Emitter<TasteQuizState> emit) {
    if (state is TasteQuizTuning) emit(const TasteQuizState.finished(completed: true));
  }

  /// Adds to the signals already stored. It never clears them, and it leaves the favourites seed flag alone.
  Future<void> _commit(List<QuizPick> picks) async {
    if (_committed || picks.isEmpty) return;
    _committed = true;
    final DateTime at = _clock();
    try {
      await _tasteSignals.recordAll(<TasteSignal>[for (final QuizPick pick in picks) ...pick.signals(at)]);
    } catch (error) {
      logger.w('[TasteQuiz] could not store the picks: $error');
    }
  }
}
