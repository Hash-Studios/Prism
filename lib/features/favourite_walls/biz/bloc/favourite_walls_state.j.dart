part of 'favourite_walls_bloc.j.dart';

@freezed
abstract class FavouriteWallsState with _$FavouriteWallsState {
  const factory FavouriteWallsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String userId,
    required List<FavouriteWallEntity> items,
    @Default(FavouriteSort.recentlyAdded) FavouriteSort sort,
    WallpaperSource? sourceFilter,
    @Default('') String query,
    Failure? failure,
  }) = _FavouriteWallsState;

  const FavouriteWallsState._();

  factory FavouriteWallsState.initial() => const FavouriteWallsState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    userId: '',
    items: <FavouriteWallEntity>[],
  );

  bool get hasActiveFilter => sourceFilter != null || query.trim().isNotEmpty;

  List<FavouriteWallEntity> get visibleItems =>
      applyFavouritesView(items, sort: sort, source: sourceFilter, query: query);
}
