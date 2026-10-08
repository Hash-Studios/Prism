import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'paged_feed_event.j.dart';
part 'paged_feed_state.j.dart';
part 'paged_feed_bloc.j.freezed.dart';

/// A plain paged list of wallpapers for one chip of the home feed. A subclass says where a page comes from.
abstract class PagedFeedBloc extends Bloc<PagedFeedEvent, PagedFeedState> {
  PagedFeedBloc({required this.surface, required this.sourceContext}) : super(PagedFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
  }

  final AnalyticsSurfaceValue surface;
  final String sourceContext;
  int _loadVersion = 0;

  /// Page [page] of the list. Page 1 is a fresh load.
  Future<Result<PersonalizedFeedPage>> loadPage(int page);

  Future<void> _onStarted(_Started event, Emitter<PagedFeedState> emit) async {
    if (state.status == LoadStatus.initial) {
      await _load(emit);
    }
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<PagedFeedState> emit) => _load(emit);

  Future<void> _load(Emitter<PagedFeedState> emit) async {
    final int loadVersion = ++_loadVersion;
    final bool hadItems = state.items.isNotEmpty;
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        isFetchingMore: false,
        failure: null,
      ),
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    final Result<PersonalizedFeedPage> result = await loadPage(1);
    if (loadVersion != _loadVersion || emit.isDone) return;
    final int loadMs = (stopwatch..stop()).elapsedMilliseconds;
    result.fold(
      onSuccess: (page) {
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            page: 1,
            items: page.items,
            hasMore: page.hasMore,
            failure: null,
          ),
        );
        _trackLoad(page.items.isEmpty ? EventResultValue.empty : EventResultValue.success, loadMs, page.items.length);
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            status: hadItems ? LoadStatus.success : LoadStatus.failure,
            actionStatus: ActionStatus.failure,
            failure: failure,
          ),
        );
        _trackLoad(EventResultValue.failure, loadMs, null);
      },
    );
  }

  Future<void> _onFetchMoreRequested(_FetchMoreRequested event, Emitter<PagedFeedState> emit) async {
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }
    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress, failure: null));
    final int loadVersion = _loadVersion;
    final int nextPage = state.page + 1;
    final Stopwatch stopwatch = Stopwatch()..start();
    final Result<PersonalizedFeedPage> result = await loadPage(nextPage);
    if (loadVersion != _loadVersion || emit.isDone) return;
    final int loadMs = (stopwatch..stop()).elapsedMilliseconds;
    result.fold(
      onSuccess: (page) {
        final List<FeedItemEntity> merged = <String, FeedItemEntity>{
          for (final FeedItemEntity item in <FeedItemEntity>[...state.items, ...page.items]) item.id: item,
        }.values.toList(growable: false);
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            isFetchingMore: false,
            page: nextPage,
            items: merged,
            hasMore: page.hasMore,
            failure: null,
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(actionStatus: ActionStatus.failure, isFetchingMore: false, failure: failure));
        _trackLoad(EventResultValue.failure, loadMs, null);
      },
    );
  }

  void _trackLoad(EventResultValue result, int loadMs, int? itemCount) {
    unawaited(
      analytics.track(
        SurfaceContentLoadedEvent(
          surface: surface,
          result: result,
          loadTimeMs: loadMs,
          sourceContext: sourceContext,
          itemCount: itemCount,
          reason: result == EventResultValue.failure ? AnalyticsReasonValue.error : null,
        ),
      ),
    );
  }
}
