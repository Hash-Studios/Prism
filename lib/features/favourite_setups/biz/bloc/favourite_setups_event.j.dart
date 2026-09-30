part of 'favourite_setups_bloc.j.dart';

@freezed
abstract class FavouriteSetupsEvent with _$FavouriteSetupsEvent {
  const factory FavouriteSetupsEvent.started({required String userId}) = _Started;
  const factory FavouriteSetupsEvent.refreshRequested() = _RefreshRequested;
  const factory FavouriteSetupsEvent.toggleRequested({required SetupEntity setup}) = _ToggleRequested;
}
