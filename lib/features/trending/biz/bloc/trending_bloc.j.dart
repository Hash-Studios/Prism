import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'trending_event.j.dart';
part 'trending_state.j.dart';
part 'trending_bloc.j.freezed.dart';

@injectable
class TrendingBloc extends Bloc<TrendingEvent, TrendingState> {
  TrendingBloc(this._fetchTrendingUseCase) : super(TrendingState.initial()) {
    on<_Started>((event, emit) => _load(TrendingRange.week, emit));
    on<_RangeSelected>(_onRangeSelected);
    on<_RefreshRequested>((event, emit) => _load(state.range, emit));
  }

  final FetchTrendingUseCase _fetchTrendingUseCase;
  final Map<TrendingRange, int> _latestRequestIds = <TrendingRange, int>{};

  Future<void> _onRangeSelected(_RangeSelected event, Emitter<TrendingState> emit) async {
    emit(state.copyWith(range: event.range));
    final LoadStatus status = state.section(event.range).status;
    if (status == LoadStatus.initial || status == LoadStatus.failure) {
      await _load(event.range, emit);
    }
  }

  /// Keeps the walls on screen while a refresh runs, and when it fails.
  Future<void> _load(TrendingRange range, Emitter<TrendingState> emit) async {
    final int requestId = (_latestRequestIds[range] ?? 0) + 1;
    _latestRequestIds[range] = requestId;
    emit(state.withSection(range, state.section(range).copyWith(status: LoadStatus.loading, failure: null)));
    final result = await _fetchTrendingUseCase(range);
    if (requestId != _latestRequestIds[range]) return;
    result.fold(
      onSuccess: (walls) =>
          emit(state.withSection(range, state.section(range).copyWith(status: LoadStatus.success, walls: walls))),
      onFailure: (failure) =>
          emit(state.withSection(range, state.section(range).copyWith(status: LoadStatus.failure, failure: failure))),
    );
  }
}
