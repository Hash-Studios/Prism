import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'search_discovery_event.j.dart';
part 'search_discovery_state.j.dart';
part 'search_discovery_bloc.j.freezed.dart';

@injectable
class SearchDiscoveryBloc extends Bloc<SearchDiscoveryEvent, SearchDiscoveryState> {
  SearchDiscoveryBloc(this._wallhavenRepo, this._prismSearch) : super(SearchDiscoveryState.initial()) {
    on<_FetchRequested>(_onFetchRequested);
    on<_RefreshRequested>(_onRefreshRequested);
  }

  final WallhavenWallpaperRepository _wallhavenRepo;
  final PrismWallSearch _prismSearch;

  Future<void> _onFetchRequested(_FetchRequested event, Emitter<SearchDiscoveryState> emit) async {
    if (state.status == LoadStatus.success) return;
    await _fetch(emit);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<SearchDiscoveryState> emit) async {
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<SearchDiscoveryState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final Future<bool> hasLiveWalls = _prismSearch
        .search('', limit: 1, kinds: const <PrismWallKind>{PrismWallKind.live})
        .then((walls) => walls.isNotEmpty);
    final result = await _wallhavenRepo.fetchToplist();
    final bool live = await hasLiveWalls;
    result.fold(
      onSuccess: (walls) => emit(state.copyWith(status: LoadStatus.success, trendingWalls: walls, hasLiveWalls: live)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure, hasLiveWalls: live)),
    );
  }
}
