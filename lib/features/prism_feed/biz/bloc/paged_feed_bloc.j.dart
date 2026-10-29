import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'paged_feed_event.j.dart';
part 'paged_feed_state.j.dart';
part 'paged_feed_bloc.j.freezed.dart';

class _VisiblePageLoad {
  const _VisiblePageLoad({required this.result, required this.page, this.partialPage});

  final Result<PersonalizedFeedPage> result;
  final int page;
  final PersonalizedFeedPage? partialPage;
}

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
  bool _isClosing = false;

  static const int _maxHiddenPages = 5;
  static const int _minVisibleItems = 12;

  /// Page [page] of the list. Page 1 is a fresh load.
  Future<Result<PersonalizedFeedPage>> loadPage(int page);

  @override
  Future<void> close() {
    _isClosing = true;
    return super.close();
  }

  bool get _hidesAi =>
      getIt.isRegistered<SettingsLocalDataSource>() && !AiContentFilter.showsAi(getIt<SettingsLocalDataSource>());

  bool _hides(FeedItemEntity item) =>
      _hidesAi &&
      AiContentFilter.hidesFeedItem(item, showAi: AiContentFilter.showsAi(getIt<SettingsLocalDataSource>()));

  List<FeedItemEntity> _uniqueItems(Iterable<FeedItemEntity> items) =>
      <String, FeedItemEntity>{for (final FeedItemEntity item in items) item.id: item}.values.toList(growable: false);

  /// Hidden AI walls can thin out or empty whole pages. While they leave fewer than [_minVisibleItems] visible walls,
  /// the request fetches the next page too, up to [_maxHiddenPages] pages. A later page that fails keeps what loaded.
  Future<_VisiblePageLoad> _loadVisiblePage(int first, int loadVersion) async {
    final bool hideAiAtStart = _hidesAi;
    final Result<PersonalizedFeedPage> firstResult = await loadPage(first);
    final PersonalizedFeedPage? firstPage = firstResult.data;
    if (firstPage == null) return _VisiblePageLoad(result: firstResult, page: first);
    PersonalizedFeedPage merged = PersonalizedFeedPage(
      items: _uniqueItems(firstPage.items),
      hasMore: firstPage.hasMore,
    );
    int page = first;
    for (int fetched = 1; fetched < _maxHiddenPages; fetched++) {
      if (!merged.hasMore || loadVersion != _loadVersion || _isClosing) break;
      if (!hideAiAtStart || !_hidesAi || merged.items.where((item) => !_hides(item)).length >= _minVisibleItems) break;
      final Result<PersonalizedFeedPage> nextResult = await loadPage(page + 1);
      final PersonalizedFeedPage? next = nextResult.data;
      if (next == null) {
        return _VisiblePageLoad(result: nextResult, page: page, partialPage: merged);
      }
      page += 1;
      merged = PersonalizedFeedPage(
        items: _uniqueItems(<FeedItemEntity>[...merged.items, ...next.items]),
        hasMore: next.hasMore,
      );
    }
    return _VisiblePageLoad(result: Result.success<PersonalizedFeedPage>(merged), page: page, partialPage: merged);
  }

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
    final _VisiblePageLoad visiblePage = await _loadVisiblePage(1, loadVersion);
    if (loadVersion != _loadVersion || _isClosing || emit.isDone) return;
    final int loadMs = (stopwatch..stop()).elapsedMilliseconds;
    visiblePage.result.fold(
      onSuccess: (page) {
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            page: visiblePage.page,
            items: page.items,
            hasMore: page.hasMore,
            failure: null,
          ),
        );
        _trackLoad(page.items.isEmpty ? EventResultValue.empty : EventResultValue.success, loadMs, page.items.length);
      },
      onFailure: (failure) {
        final PersonalizedFeedPage? partialPage = visiblePage.partialPage;
        emit(
          state.copyWith(
            status: hadItems || partialPage != null ? LoadStatus.success : LoadStatus.failure,
            actionStatus: ActionStatus.failure,
            page: partialPage == null ? state.page : visiblePage.page,
            items: partialPage?.items ?? state.items,
            hasMore: partialPage?.hasMore ?? state.hasMore,
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
    final Stopwatch stopwatch = Stopwatch()..start();
    final _VisiblePageLoad visiblePage = await _loadVisiblePage(state.page + 1, loadVersion);
    if (loadVersion != _loadVersion || _isClosing || emit.isDone) return;
    final int loadMs = (stopwatch..stop()).elapsedMilliseconds;
    visiblePage.result.fold(
      onSuccess: (page) {
        final List<FeedItemEntity> merged = <String, FeedItemEntity>{
          for (final FeedItemEntity item in <FeedItemEntity>[...state.items, ...page.items]) item.id: item,
        }.values.toList(growable: false);
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            isFetchingMore: false,
            page: visiblePage.page,
            items: merged,
            hasMore: page.hasMore,
            failure: null,
          ),
        );
      },
      onFailure: (failure) {
        final PersonalizedFeedPage? partialPage = visiblePage.partialPage;
        final List<FeedItemEntity> merged = partialPage == null
            ? state.items
            : _uniqueItems(<FeedItemEntity>[...state.items, ...partialPage.items]);
        emit(
          state.copyWith(
            status: merged.isEmpty ? state.status : LoadStatus.success,
            actionStatus: ActionStatus.failure,
            isFetchingMore: false,
            page: partialPage == null ? state.page : visiblePage.page,
            items: merged,
            hasMore: partialPage?.hasMore ?? state.hasMore,
            failure: failure,
          ),
        );
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
