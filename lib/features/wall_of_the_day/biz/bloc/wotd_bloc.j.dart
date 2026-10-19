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
  int _latestRequestId = 0;

  Future<void> _onStarted(_Started event, Emitter<WotdState> emit) async {
    final requestId = ++_latestRequestId;
    WallOfTheDayEntity? cached;
    if (state.entity == null) {
      try {
        cached = await _fetchWallOfTheDayUseCase.readCachedToday();
      } catch (_) {}
      if (emit.isDone || requestId != _latestRequestId) return;
    }
    final bool paintedCached = cached != null && state.entity == null;
    if (paintedCached) {
      emit(state.copyWith(status: LoadStatus.success, entity: cached));
    } else {
      emit(state.copyWith(status: LoadStatus.loading));
    }
    final result = await _fetchWallOfTheDayUseCase(const NoParams());
    if (requestId != _latestRequestId) return;

    result.fold(
      onSuccess: (entity) => emit(state.copyWith(status: LoadStatus.success, entity: entity)),
      onFailure: (failure) {
        if (const <String>{'permission-denied', 'unauthenticated', 'not-found'}.contains(failure.code)) {
          emit(state.copyWith(status: LoadStatus.failure, entity: null));
        } else if (!paintedCached) {
          emit(state.copyWith(status: LoadStatus.failure));
        }
      },
    );
  }
}
