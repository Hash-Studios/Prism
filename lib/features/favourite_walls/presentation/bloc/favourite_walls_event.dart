part of 'favourite_walls_bloc.dart';

@freezed
abstract class FavouriteWallsEvent with _$FavouriteWallsEvent {
  const factory FavouriteWallsEvent.started({required String userId}) =
      _Started;
  const factory FavouriteWallsEvent.refreshRequested() = _RefreshRequested;
  const factory FavouriteWallsEvent.toggleRequested({
    required FavouriteWallEntity wall,
  }) = _ToggleRequested;
  const factory FavouriteWallsEvent.removeRequested({required String wallId}) =
      _RemoveRequested;
  const factory FavouriteWallsEvent.clearRequested() = _ClearRequested;
}
