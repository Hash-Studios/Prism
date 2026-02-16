part of 'favourite_walls_bloc.j.dart';

@freezed
abstract class FavouriteWallsState with _$FavouriteWallsState {
  const factory FavouriteWallsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String userId,
    required List<FavouriteWallEntity> items,
    Failure? failure,
  }) = _FavouriteWallsState;

  factory FavouriteWallsState.initial() => const FavouriteWallsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        userId: '',
        items: <FavouriteWallEntity>[],
      );
}
