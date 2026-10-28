import 'dart:async';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
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
    required List<String> interests,
    required TasteSignalStore tasteSignals,
    PersonalizedRankingService ranker = const PersonalizedRankingService(),
    Random? random,
    DateTime Function()? clock,
  }) : _interests = interests,
       _tasteSignals = tasteSignals,
       _ranker = ranker,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now,
       super(TasteQuizState.playing(plan: plan, picks: const <QuizPick>[])) {
    on<_Picked>(_onPicked);
    on<_Skipped>(_onSkipped);
    on<_TuningShown>(_onTuningShown);
    unawaited(analytics.track(TasteQuizStartedEvent(source: source)));
  }

  final TasteQuizSource source;
  final List<String> _interests;
  final TasteSignalStore _tasteSignals;
  final PersonalizedRankingService _ranker;
  final Random _random;
  final DateTime Function() _clock;
  bool _committed = false;

  static const int tuningMin = 4;
  static const int tuningMax = 6;

  Future<void> _onPicked(_Picked event, Emitter<TasteQuizState> emit) async {
    final TasteQuizState current = state;
    if (current is! TasteQuizPlaying || event.round != current.picks.length) return;
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
    unawaited(analytics.track(TasteQuizCompletedEvent(source: source)));
    emit(TasteQuizState.tuning(walls: _tuningWalls(current.plan, picks), summary: summarizeTaste(picks)));
  }

  Future<void> _onSkipped(_Skipped event, Emitter<TasteQuizState> emit) async {
    final TasteQuizState current = state;
    if (current is! TasteQuizPlaying) return;
    unawaited(analytics.track(TasteQuizSkippedEvent(source: source, roundIndex: current.picks.length)));
    await _commit(current.picks);
    emit(const TasteQuizState.finished(completed: false));
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

  /// The leftover walls in the order the feed ranker now puts them, topped up with the picks when too few rank.
  List<FeedItemEntity> _tuningWalls(TasteQuizPlan plan, List<QuizPick> picks) {
    final DateTime now = _clock().toUtc();
    final PersonalizedRankingResult ranking = _ranker.rank(
      candidates: <RankingCandidate>[
        for (final QuizWall wall in plan.pool)
          RankingCandidate(item: wall.item, pool: _poolOf(wall.item.source), extraTerms: wall.terms),
      ],
      profile: TasteProfile.build(
        interests: _interests,
        following: const <String>[],
        signals: _tasteSignals.read(),
        now: now,
      ),
      recentShows: const <String, int>{},
      excludedKeys: const <String>{},
      mix: FeedMix.balanced,
      random: _random,
      now: now,
      limit: tuningMax,
    );
    if (ranking.items.length >= tuningMin) return ranking.items;
    return <FeedItemEntity>[
      ...ranking.items,
      ...picks.map((pick) => pick.picked.item),
    ].take(tuningMax).toList(growable: false);
  }

  static CandidatePool _poolOf(WallpaperSource source) => switch (source) {
    WallpaperSource.wallhaven => CandidatePool.wallhaven,
    WallpaperSource.pexels => CandidatePool.pexels,
    _ => CandidatePool.taste,
  };
}
