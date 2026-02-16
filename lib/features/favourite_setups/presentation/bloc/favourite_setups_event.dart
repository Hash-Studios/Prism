part of 'favourite_setups_bloc.dart';

@freezed
abstract class FavouriteSetupsEvent with _$FavouriteSetupsEvent {
  const factory FavouriteSetupsEvent.started({required String userId}) =
      _Started;
  const factory FavouriteSetupsEvent.refreshRequested() = _RefreshRequested;
  const factory FavouriteSetupsEvent.toggleRequested({
    required FavouriteSetupEntity setup,
  }) = _ToggleRequested;
  const factory FavouriteSetupsEvent.removeRequested(
      {required String setupId}) = _RemoveRequested;
  const factory FavouriteSetupsEvent.clearRequested() = _ClearRequested;
}
