import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
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

@injectable
class PersonalizedFeedBloc extends Bloc<PersonalizedFeedEvent, PersonalizedFeedState> {
  PersonalizedFeedBloc(this._fetchPersonalizedFeedUseCase, this._getPersistedSeenKeysUseCase)
    : super(PersonalizedFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
  }

  final FetchPersonalizedFeedUseCase _fetchPersonalizedFeedUseCase;
  final GetPersistedSeenKeysUseCase _getPersistedSeenKeysUseCase;

  Future<void> _onStarted(_Started event, Emitter<PersonalizedFeedState> emit) async {
    // Restore persisted seen keys so the feed shows wallpapers the user hasn't
    // seen before, rather than re-serving the same top-ranked items each time.
    List<String> persistedSeenKeys = const <String>[];
    try {
      persistedSeenKeys = await _getPersistedSeenKeysUseCase();
    } catch (e) {
      logger.w('[PersonalizedFeed] failed to load persisted seen keys: $e');
    }
    await _load(emit, refresh: true, initialSeenKeys: persistedSeenKeys);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PersonalizedFeedState> emit) async {
    // Manual pull-to-refresh intentionally clears seen keys — the user wants a
    // completely fresh set of content.
    await _load(emit, refresh: true);
  }

  Future<void> _onFetchMoreRequested(_FetchMoreRequested event, Emitter<PersonalizedFeedState> emit) async {
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress, failure: null));

    final nextPage = state.page + 1;
    final loadMoreStopwatch = Stopwatch()..start();
    final result = await _fetchPersonalizedFeedUseCase(
      FetchPersonalizedFeedParams(page: nextPage, refresh: false, seenKeys: state.seenKeys, existingItems: state.items),
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

  Future<void> _load(
    Emitter<PersonalizedFeedState> emit, {
    required bool refresh,
    List<String> initialSeenKeys = const <String>[],
  }) async {
    final baseState = refresh
        ? state.copyWith(
            status: LoadStatus.loading,
            actionStatus: ActionStatus.inProgress,
            page: 1,
            items: const <FeedItemEntity>[],
            seenKeys: initialSeenKeys,
            hasMore: true,
            isFetchingMore: false,
            failure: null,
          )
        : state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null);
    emit(baseState);

    final initialStopwatch = Stopwatch()..start();
    final result = await _fetchPersonalizedFeedUseCase(
      FetchPersonalizedFeedParams(
        page: 1,
        refresh: true,
        seenKeys: initialSeenKeys,
        existingItems: const <FeedItemEntity>[],
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
