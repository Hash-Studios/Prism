import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/usecases/fetch_wall_of_the_day_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wotd_event.j.dart';
part 'wotd_state.j.dart';
part 'wotd_bloc.j.freezed.dart';

@injectable
class WotdBloc extends Bloc<WotdEvent, WotdState> {
  WotdBloc(this._fetchWallOfTheDayUseCase) : super(WotdState.initial()) {
    on<_Started>(_onStarted);
  }

  final FetchWallOfTheDayUseCase _fetchWallOfTheDayUseCase;

  Future<void> _onStarted(_Started event, Emitter<WotdState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _fetchWallOfTheDayUseCase(const NoParams());
    result.fold(
      onSuccess: (entity) => emit(state.copyWith(status: LoadStatus.success, entity: entity, failure: null)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }
}
