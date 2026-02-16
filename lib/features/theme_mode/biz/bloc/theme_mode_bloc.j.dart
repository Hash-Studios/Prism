import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_mode_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'theme_mode_event.j.dart';
part 'theme_mode_state.j.dart';
part 'theme_mode_bloc.j.freezed.dart';

@injectable
class ThemeModeBloc extends Bloc<ThemeModeEvent, ThemeModeState> {
  ThemeModeBloc(
    this._loadThemeModeUseCase,
    this._updateThemeModeUseCase,
  ) : super(ThemeModeState.initial()) {
    on<_Started>(_onStarted);
    on<_ModeChanged>(_onModeChanged);
  }

  final LoadThemeModeUseCase _loadThemeModeUseCase;
  final UpdateThemeModeUseCase _updateThemeModeUseCase;

  Future<void> _onStarted(_Started event, Emitter<ThemeModeState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _loadThemeModeUseCase(const NoParams());
    result.fold(
      onSuccess: (mode) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.idle,
        mode: mode,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onModeChanged(
    _ModeChanged event,
    Emitter<ThemeModeState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeModeUseCase(
      UpdateThemeModeParams(mode: event.mode),
    );
    result.fold(
      onSuccess: (mode) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        mode: mode,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }
}
