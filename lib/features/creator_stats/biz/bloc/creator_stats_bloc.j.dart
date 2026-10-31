import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/get_creator_stats.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'creator_stats_bloc.j.freezed.dart';

@freezed
abstract class CreatorStatsState with _$CreatorStatsState {
  const factory CreatorStatsState({
    @Default(false) bool loading,
    @Default(false) bool failed,
    CreatorStats? data,
    @Default(StatsMetric.views) StatsMetric metric,
  }) = _CreatorStatsState;
}

@freezed
sealed class CreatorStatsEvent with _$CreatorStatsEvent {
  const factory CreatorStatsEvent.load() = LoadCreatorStats;
  const factory CreatorStatsEvent.select(StatsMetric metric) = SelectStatsMetric;
}

@injectable
class CreatorStatsBloc extends Bloc<CreatorStatsEvent, CreatorStatsState> {
  CreatorStatsBloc(this._get) : super(const CreatorStatsState()) {
    on<LoadCreatorStats>((event, emit) async {
      emit(state.copyWith(loading: true, failed: false));
      try {
        final data = await _get();
        emit(state.copyWith(data: data, loading: false));
      } on Exception {
        emit(state.copyWith(loading: false, failed: true));
      }
    });
    on<SelectStatsMetric>((event, emit) => emit(state.copyWith(metric: event.metric)));
  }
  final GetCreatorStats _get;
}
