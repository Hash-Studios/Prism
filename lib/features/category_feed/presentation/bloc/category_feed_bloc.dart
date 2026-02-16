import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/usecases/category_feed_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'category_feed_event.dart';
part 'category_feed_state.dart';
part 'category_feed_bloc.freezed.dart';

@injectable
class CategoryFeedBloc extends Bloc<CategoryFeedEvent, CategoryFeedState> {
  CategoryFeedBloc(
    this._loadCategoriesUseCase,
    this._fetchCategoryFeedUseCase,
  ) : super(CategoryFeedState.initial()) {
    on<_Started>(_onStarted);
    on<_CategorySelected>(_onCategorySelected);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
    on<_RefreshRequested>(_onRefreshRequested);
  }

  final LoadCategoriesUseCase _loadCategoriesUseCase;
  final FetchCategoryFeedUseCase _fetchCategoryFeedUseCase;

  Future<void> _onStarted(
      _Started event, Emitter<CategoryFeedState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    final categoriesResult = await _loadCategoriesUseCase(const NoParams());
    categoriesResult.fold(
      onSuccess: (categories) {
        if (categories.isEmpty) {
          emit(state.copyWith(
            status: LoadStatus.success,
            categories: categories,
            items: const <FeedItemEntity>[],
            selectedCategory: null,
            hasMore: false,
            nextCursor: null,
          ));
          return;
        }

        final selected = categories.first;
        emit(
            state.copyWith(categories: categories, selectedCategory: selected));
        add(CategoryFeedEvent.categorySelected(category: selected));
      },
      onFailure: (failure) {
        emit(state.copyWith(status: LoadStatus.failure, failure: failure));
      },
    );
  }

  Future<void> _onCategorySelected(
    _CategorySelected event,
    Emitter<CategoryFeedState> emit,
  ) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      actionStatus: ActionStatus.inProgress,
      selectedCategory: event.category,
      failure: null,
    ));

    final result = await _fetchCategoryFeedUseCase(
      FetchCategoryFeedParams(category: event.category, refresh: event.refresh),
    );

    result.fold(
      onSuccess: (page) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        items: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isFetchingMore: false,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        isFetchingMore: false,
        failure: failure,
      )),
    );
  }

  Future<void> _onFetchMoreRequested(
    _FetchMoreRequested event,
    Emitter<CategoryFeedState> emit,
  ) async {
    if (state.isFetchingMore ||
        !state.hasMore ||
        state.selectedCategory == null) {
      return;
    }

    emit(state.copyWith(
        isFetchingMore: true, actionStatus: ActionStatus.inProgress));

    final result = await _fetchCategoryFeedUseCase(
      FetchCategoryFeedParams(
          category: state.selectedCategory!, refresh: false),
    );

    result.fold(
      onSuccess: (page) {
        final merged = <FeedItemEntity>[...state.items, ...page.items];
        final uniqueById = <String, FeedItemEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: uniqueById,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          isFetchingMore: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        isFetchingMore: false,
        failure: failure,
      )),
    );
  }

  void _onRefreshRequested(
    _RefreshRequested event,
    Emitter<CategoryFeedState> emit,
  ) {
    final selected = state.selectedCategory;
    if (selected == null) {
      return;
    }
    add(CategoryFeedEvent.categorySelected(category: selected));
  }
}
