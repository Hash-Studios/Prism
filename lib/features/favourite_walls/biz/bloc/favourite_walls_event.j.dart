part of 'favourite_walls_bloc.j.dart';

@freezed
abstract class FavouriteWallsEvent with _$FavouriteWallsEvent {
  const factory FavouriteWallsEvent.started({required String userId}) = _Started;
  const factory FavouriteWallsEvent.refreshRequested() = _RefreshRequested;
  const factory FavouriteWallsEvent.toggleRequested({required FavouriteWallEntity wall}) = _ToggleRequested;
  const factory FavouriteWallsEvent.clearRequested() = _ClearRequested;
  const factory FavouriteWallsEvent.sortChanged({required FavouriteSort sort}) = _SortChanged;
  const factory FavouriteWallsEvent.sourceFilterChanged({WallpaperSource? source}) = _SourceFilterChanged;
  const factory FavouriteWallsEvent.queryChanged({required String query}) = _QueryChanged;
  const factory FavouriteWallsEvent.removeRequested({required List<String> wallIds, @Default(0) int operationId}) =
      _RemoveRequested;
  const factory FavouriteWallsEvent.restoreRequested({
    required List<FavouriteWallEntity> walls,
    @Default(0) int operationId,
  }) = _RestoreRequested;
}
