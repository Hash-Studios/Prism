part of 'wotd_bloc.j.dart';

@freezed
abstract class WotdState with _$WotdState {
  const factory WotdState({required LoadStatus status, WallOfTheDayEntity? entity, Failure? failure}) = _WotdState;

  factory WotdState.initial() => const WotdState(status: LoadStatus.initial);
}
