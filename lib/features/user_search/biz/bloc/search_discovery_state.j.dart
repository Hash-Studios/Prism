part of 'search_discovery_bloc.j.dart';

@freezed
abstract class SearchDiscoveryState with _$SearchDiscoveryState {
  const factory SearchDiscoveryState({
    required LoadStatus status,
    required List<WallhavenWallpaper> trendingWalls,
    Failure? failure,

    /// At least one reviewed live wall exists, so discovery shows the Live walls row.
    @Default(false) bool hasLiveWalls,
  }) = _SearchDiscoveryState;

  factory SearchDiscoveryState.initial() => const SearchDiscoveryState(status: LoadStatus.initial, trendingWalls: []);
}
