import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/usecases/category_feed_usecases.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'category_feed_event.j.dart';
part 'category_feed_state.j.dart';
part 'category_feed_bloc.j.freezed.dart';

@injectable
class CategoryFeedBloc extends Bloc<CategoryFeedEvent, CategoryFeedState> {
  CategoryFeedBloc(this._loadCategoriesUseCase, this._fetchCategoryFeedUseCase, this._userBlockRepository)
    : super(CategoryFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_CategorySelected>(_onCategorySelected);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    // Blocking a creator removes their walls from the home feed at once (App Review 1.2).
    _blockedCreatorsSub = _userBlockRepository
        .watchBlockedCreatorUids()
        .skip(1)
        .listen((blocked) => add(CategoryFeedEvent.blockedCreatorsChanged(blocked: blocked)));
  }

  final LoadCategoriesUseCase _loadCategoriesUseCase;
  final FetchCategoryFeedUseCase _fetchCategoryFeedUseCase;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<Set<String>>? _blockedCreatorsSub;
  int _generation = 0;

  static const int _maxEmptyPages = 5;

  void _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<CategoryFeedState> emit) {
    if (event.blocked.isEmpty) return;
    final filtered = BlockedCreatorsFilter.filterFeedItems(state.items, event.blocked);
    if (filtered.length != state.items.length) emit(state.copyWith(items: filtered));
  }

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<CategoryFeedState> emit) async {
    final categoriesResult = await _loadCategoriesUseCase(const NoParams());
    categoriesResult.fold(
      onSuccess: (categories) => emit(state.copyWith(categories: categories)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }

  Future<void> _onCategorySelected(_CategorySelected event, Emitter<CategoryFeedState> emit) async {
    final int generation = ++_generation;
    final CategoryEntity? previous = state.selectedCategory;
    final bool sameCategory =
        previous != null && previous.name == event.category.name && previous.source == event.category.source;
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        isFetchingMore: false,
        selectedCategory: event.category,
        items: sameCategory ? state.items : const <FeedItemEntity>[],
        hasMore: sameCategory && state.hasMore,
        failure: null,
      ),
    );

    final result = await _fetchPage(event.category, refresh: true, generation: generation);
    if (generation != _generation || emit.isDone) return;

    result.fold(
      onSuccess: (page) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: page.items,
          hasMore: page.hasMore,
          isFetchingMore: false,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          isFetchingMore: false,
          failure: failure,
        ),
      ),
    );
  }

  Future<void> _onFetchMoreRequested(_FetchMoreRequested event, Emitter<CategoryFeedState> emit) async {
    if (state.isFetchingMore ||
        state.status == LoadStatus.loading ||
        !state.hasMore ||
        state.selectedCategory == null) {
      return;
    }

    final CategoryEntity selected = state.selectedCategory!;
    final int generation = _generation;
    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchPage(selected, refresh: false, generation: generation);
    if (generation != _generation || emit.isDone) return;

    result.fold(
      onSuccess: (page) {
        final merged = <FeedItemEntity>[...state.items, ...page.items];
        final uniqueById = <String, FeedItemEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            items: uniqueById,
            hasMore: page.hasMore,
            isFetchingMore: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) =>
          emit(state.copyWith(actionStatus: ActionStatus.failure, isFetchingMore: false, failure: failure)),
    );
  }

  /// Hidden AI or anime walls can empty a whole page, so an empty page with more behind it fetches the next one.
  /// It stops after [_maxEmptyPages] empty pages in a row.
  Future<Result<CategoryFeedPage>> _fetchPage(
    CategoryEntity category, {
    required bool refresh,
    required int generation,
  }) async {
    Result<CategoryFeedPage> result = await _fetchCategoryFeedUseCase(
      FetchCategoryFeedParams(category: category, refresh: refresh),
    );
    for (int empty = 1; empty < _maxEmptyPages; empty++) {
      final CategoryFeedPage? page = result.data;
      if (page == null || page.items.isNotEmpty || !page.hasMore || generation != _generation || isClosed) break;
      result = await _fetchCategoryFeedUseCase(FetchCategoryFeedParams(category: category, refresh: false));
    }
    return result;
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<CategoryFeedState> emit) async {
    final selected = state.selectedCategory;
    if (selected == null) {
      return;
    }
    await _onCategorySelected(_CategorySelected(category: selected), emit);
  }
}
