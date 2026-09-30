import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'personalized_feed_event.j.dart';
part 'personalized_feed_state.j.dart';
part 'personalized_feed_bloc.j.freezed.dart';

@injectable
class PersonalizedFeedBloc extends Bloc<PersonalizedFeedEvent, PersonalizedFeedState> {
  PersonalizedFeedBloc(this._fetchPersonalizedFeedUseCase, this._repository, this._userBlockRepository)
    : super(PersonalizedFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    // Blocking a creator removes their items from the on-screen feed instantly,
    // without waiting for the next fetch. skip(1) ignores the initial snapshot.
    _blockedCreatorsSub = _userBlockRepository
        .watchBlockedCreatorEmails()
        .skip(1)
        .listen((blocked) => add(PersonalizedFeedEvent.blockedCreatorsChanged(blocked: blocked)));
  }

  final FetchPersonalizedFeedUseCase _fetchPersonalizedFeedUseCase;
  final PersonalizedFeedRepository _repository;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<Set<String>>? _blockedCreatorsSub;

  void _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<PersonalizedFeedState> emit) {
    if (event.blocked.isEmpty) {
      return;
    }
    final filtered = BlockedCreatorsFilter.filterFeedItems(state.items, event.blocked);
    if (filtered.length != state.items.length) {
      emit(state.copyWith(items: filtered));
    }
  }

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<PersonalizedFeedState> emit) async {
    // Restore persisted seen keys so the feed shows wallpapers the user hasn't
    // seen before, rather than re-serving the same top-ranked items each time.
    List<String> persistedSeenKeys = const <String>[];
    try {
      persistedSeenKeys = await _repository.readPersistedSeenKeys();
    } catch (e) {
      logger.w('[PersonalizedFeed] failed to load persisted seen keys: $e');
    }
    await _load(emit, sourceContext: 'personalized_feed_initial', initialSeenKeys: persistedSeenKeys);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PersonalizedFeedState> emit) async {
    // Manual pull-to-refresh intentionally clears seen keys — the user wants a
    // completely fresh set of content.
    await _load(emit, sourceContext: 'personalized_feed_refresh');
  }

  Future<void> _onFetchMoreRequested(_FetchMoreRequested event, Emitter<PersonalizedFeedState> emit) async {
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress, failure: null));

    final nextPage = state.page + 1;
    final loadMoreStopwatch = Stopwatch()..start();
    final result = await _fetchPersonalizedFeedUseCase(
      FetchPersonalizedFeedRequest(
        page: nextPage,
        refresh: false,
        seenKeys: state.seenKeys,
        existingItems: state.items,
      ),
    );
    final loadMoreMs = (loadMoreStopwatch..stop()).elapsedMilliseconds;

    result.fold(
      onSuccess: (page) {
        final merged = <String, FeedItemEntity>{
          for (final item in [...state.items, ...page.items]) PersonalizedRankingService.canonicalKey(item): item,
        }.values.toList(growable: false);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            isFetchingMore: false,
            page: nextPage,
            items: merged,
            seenKeys: trimSeenKeys([...state.seenKeys, ...page.usedKeys]),
            hasMore: page.hasMore,
            failure: null,
          ),
        );

        analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            result: page.items.isEmpty ? EventResultValue.empty : EventResultValue.success,
            loadTimeMs: loadMoreMs,
            sourceContext: 'personalized_feed_more',
            itemCount: merged.length,
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(actionStatus: ActionStatus.failure, isFetchingMore: false, failure: failure));
        analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            result: EventResultValue.failure,
            loadTimeMs: loadMoreMs,
            sourceContext: 'personalized_feed_more',
            reason: AnalyticsReasonValue.error,
          ),
        );
      },
    );
  }

  Future<void> _load(
    Emitter<PersonalizedFeedState> emit, {
    required String sourceContext,
    List<String> initialSeenKeys = const <String>[],
  }) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        page: 1,
        items: const <FeedItemEntity>[],
        seenKeys: initialSeenKeys,
        hasMore: true,
        isFetchingMore: false,
        failure: null,
      ),
    );

    final initialStopwatch = Stopwatch()..start();
    final result = await _fetchPersonalizedFeedUseCase(
      FetchPersonalizedFeedRequest(
        page: 1,
        refresh: true,
        seenKeys: initialSeenKeys,
        existingItems: const <FeedItemEntity>[],
      ),
    );
    final initialLoadMs = (initialStopwatch..stop()).elapsedMilliseconds;

    result.fold(
      onSuccess: (page) {
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            page: 1,
            items: page.items,
            seenKeys: trimSeenKeys(page.usedKeys),
            hasMore: page.hasMore,
            isFetchingMore: false,
            failure: null,
          ),
        );

        analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            result: page.items.isEmpty ? EventResultValue.empty : EventResultValue.success,
            loadTimeMs: initialLoadMs,
            sourceContext: sourceContext,
            itemCount: page.items.length,
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure));
        analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            result: EventResultValue.failure,
            loadTimeMs: initialLoadMs,
            sourceContext: sourceContext,
            reason: AnalyticsReasonValue.error,
          ),
        );
      },
    );
  }
}
