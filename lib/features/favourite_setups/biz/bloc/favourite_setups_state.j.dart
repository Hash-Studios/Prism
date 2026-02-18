part of 'favourite_setups_bloc.j.dart';

@freezed
abstract class FavouriteSetupsState with _$FavouriteSetupsState {
  const factory FavouriteSetupsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String userId,
    required List<FavouriteSetupEntity> items,
    Failure? failure,
  }) = _FavouriteSetupsState;

  factory FavouriteSetupsState.initial() => const FavouriteSetupsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        userId: '',
        items: <FavouriteSetupEntity>[],
      );
}
