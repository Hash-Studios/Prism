part of 'trending_bloc.j.dart';

/// The walls trending this week.
@freezed
abstract class TrendingState with _$TrendingState {
  const factory TrendingState({required LoadStatus status, required List<PrismWallpaper> walls, Failure? failure}) =
      _TrendingState;

  factory TrendingState.initial() => const TrendingState(status: LoadStatus.initial, walls: <PrismWallpaper>[]);
}
