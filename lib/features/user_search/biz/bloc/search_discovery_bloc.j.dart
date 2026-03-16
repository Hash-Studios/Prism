import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'search_discovery_event.j.dart';
part 'search_discovery_state.j.dart';
part 'search_discovery_bloc.j.freezed.dart';

@injectable
class SearchDiscoveryBloc extends Bloc<SearchDiscoveryEvent, SearchDiscoveryState> {
  SearchDiscoveryBloc(this._wallhavenRepo) : super(SearchDiscoveryState.initial()) {
    on<_FetchRequested>(_onFetchRequested);
    on<_RefreshRequested>(_onRefreshRequested);
  }

  final WallhavenWallpaperRepository _wallhavenRepo;

  Future<void> _onFetchRequested(_FetchRequested event, Emitter<SearchDiscoveryState> emit) async {
    if (state.status == LoadStatus.success) return;
    await _fetch(emit);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<SearchDiscoveryState> emit) async {
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<SearchDiscoveryState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _wallhavenRepo.fetchToplist();
    result.fold(
      onSuccess: (walls) => emit(state.copyWith(status: LoadStatus.success, trendingWalls: walls)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }
}
