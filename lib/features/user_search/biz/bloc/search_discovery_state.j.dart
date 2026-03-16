part of 'search_discovery_bloc.j.dart';

@freezed
abstract class SearchDiscoveryState with _$SearchDiscoveryState {
  const factory SearchDiscoveryState({
    required LoadStatus status,
    required List<WallhavenWallpaper> trendingWalls,
    Failure? failure,
  }) = _SearchDiscoveryState;

  factory SearchDiscoveryState.initial() => const SearchDiscoveryState(
    status: LoadStatus.initial,
    trendingWalls: [],
  );
}
