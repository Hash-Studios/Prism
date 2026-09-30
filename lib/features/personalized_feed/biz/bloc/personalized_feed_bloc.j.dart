import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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

int _elapsedLoadMs(Stopwatch sw) {
  sw.stop();
  return sw.elapsedMilliseconds;
}

/// Dispatched when the blocked-creators stream emits a change, so the current
/// items can be re-filtered in place without a refetch. Hand-written (not a
/// case in the `@freezed` [PersonalizedFeedEvent] union) since that union
/// declares no abstract members beyond `Object`'s (freezed's `when`/`map`
/// live in a separate extension, unused by this bloc), so implementing it
/// directly here needs no `build_runner` regen.
// ignore: avoid_implementing_value_types
class _BlockedCreatorsChanged implements PersonalizedFeedEvent {
  const _BlockedCreatorsChanged(this.blocked);

  final Set<String> blocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _BlockedCreatorsChanged &&
          other.blocked.length == blocked.length &&
          other.blocked.containsAll(blocked));

  @override
  int get hashCode => Object.hashAllUnordered(blocked);
}

@injectable
class PersonalizedFeedBloc extends Bloc<PersonalizedFeedEvent, PersonalizedFeedState> {
  PersonalizedFeedBloc(this._fetchPersonalizedFeedUseCase, this._repository, this._userBlockRepository)
    : super(PersonalizedFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
    on<_LessLikeThisRequested>(_onLessLikeThisRequested);
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    // Blocking a creator removes their items from the on-screen feed instantly,
    // without waiting for the next fetch. skip(1) ignores the initial snapshot.
    _blockedCreatorsSub = _userBlockRepository
        .watchBlockedCreatorEmails()
        .skip(1)
        .listen((blocked) => add(_BlockedCreatorsChanged(blocked)));
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
    if (filtered.length == state.items.length) {
      return;
    }
    final counts = _resolveSourceCounts(filtered);
    emit(
      state.copyWith(
        items: filtered,
        sourcePrism: counts.prism,
        sourceWallhaven: counts.wallhaven,
        sourcePexels: counts.pexels,
      ),
    );
  }

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<PersonalizedFeedState> emit) => _load(emit, refresh: true);

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PersonalizedFeedState> emit) =>
      _load(emit, refresh: true);

  Future<void> _onLessLikeThisRequested(_LessLikeThisRequested event, Emitter<PersonalizedFeedState> emit) async {
    final String key = _itemKey(event.item);
    final List<FeedItemEntity> remaining = state.items.where((item) => _itemKey(item) != key).toList(growable: false);
    final _SourceCounts counts = _resolveSourceCounts(remaining);
    emit(
      state.copyWith(
        items: remaining,
        sourcePrism: counts.prism,
        sourceWallhaven: counts.wallhaven,
        sourcePexels: counts.pexels,
      ),
    );
    try {
      await _repository.lessLikeThis(event.item);
    } catch (e) {
      logger.w('[PersonalizedFeed] less-like-this failed: $e');
    }
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
    final loadMoreMs = _elapsedLoadMs(loadMoreStopwatch);

    result.fold(
      onSuccess: (page) {
        final merged = _mergeUnique(state.items, page.items);
        final nextSeen = _trimSeen([...state.seenKeys, ...page.usedKeys]);
        final counts = _resolveSourceCounts(merged);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            isFetchingMore: false,
            page: nextPage,
            items: merged,
            seenKeys: nextSeen,
            hasMore: page.hasMore,
            sourcePrism: counts.prism,
            sourceWallhaven: counts.wallhaven,
            sourcePexels: counts.pexels,
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

  Future<void> _load(Emitter<PersonalizedFeedState> emit, {required bool refresh}) async {
    final baseState = refresh
        ? state.copyWith(
            status: LoadStatus.loading,
            actionStatus: ActionStatus.inProgress,
            page: 1,
            items: const <FeedItemEntity>[],
            seenKeys: const <String>[],
            hasMore: true,
            isFetchingMore: false,
            failure: null,
          )
        : state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null);
    emit(baseState);

    final initialStopwatch = Stopwatch()..start();
    final result = await _fetchPersonalizedFeedUseCase(
      const FetchPersonalizedFeedRequest(
        page: 1,
        refresh: true,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );
    final initialLoadMs = _elapsedLoadMs(initialStopwatch);

    result.fold(
      onSuccess: (page) {
        final nextSeen = _trimSeen(page.usedKeys);
        final counts = _resolveSourceCounts(page.items);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            page: 1,
            items: page.items,
            seenKeys: nextSeen,
            hasMore: page.hasMore,
            isFetchingMore: false,
            sourcePrism: counts.prism,
            sourceWallhaven: counts.wallhaven,
            sourcePexels: counts.pexels,
            failure: null,
          ),
        );

        analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            result: page.items.isEmpty ? EventResultValue.empty : EventResultValue.success,
            loadTimeMs: initialLoadMs,
            sourceContext: refresh ? 'personalized_feed_refresh' : 'personalized_feed_initial',
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
            sourceContext: refresh ? 'personalized_feed_refresh' : 'personalized_feed_initial',
            reason: AnalyticsReasonValue.error,
          ),
        );
      },
    );
  }

  List<FeedItemEntity> _mergeUnique(List<FeedItemEntity> first, List<FeedItemEntity> second) {
    final merged = <String, FeedItemEntity>{
      for (final item in first) _itemKey(item): item,
      for (final item in second) _itemKey(item): item,
    };
    return merged.values.toList(growable: false);
  }

  String _itemKey(FeedItemEntity item) => item.when(
    prism: (_, wall) => wall.fullUrl.isNotEmpty ? wall.fullUrl : '${item.source.wireValue}:${item.id}',
    wallhaven: (_, wall) => wall.fullUrl.isNotEmpty ? wall.fullUrl : '${item.source.wireValue}:${item.id}',
    pexels: (_, wall) => wall.fullUrl.isNotEmpty ? wall.fullUrl : '${item.source.wireValue}:${item.id}',
  );

  List<String> _trimSeen(List<String> seen) {
    if (seen.length <= 300) {
      return seen;
    }
    return seen.sublist(seen.length - 300);
  }

  _SourceCounts _resolveSourceCounts(List<FeedItemEntity> items) {
    int prism = 0;
    int wallhaven = 0;
    int pexels = 0;
    for (final item in items) {
      switch (item.source) {
        case WallpaperSource.prism:
          prism += 1;
        case WallpaperSource.wallhaven:
          wallhaven += 1;
        case WallpaperSource.pexels:
          pexels += 1;
        case WallpaperSource.downloaded:
        case WallpaperSource.unknown:
          // Ignored in personalized source chips.
          {}
      }
    }
    return _SourceCounts(prism: prism, wallhaven: wallhaven, pexels: pexels);
  }
}

class _SourceCounts {
  const _SourceCounts({required this.prism, required this.wallhaven, required this.pexels});

  final int prism;
  final int wallhaven;
  final int pexels;
}
