import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/usecases/theme_light_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'theme_light_event.j.dart';
part 'theme_light_state.j.dart';
part 'theme_light_bloc.j.freezed.dart';

@injectable
class ThemeLightBloc extends Bloc<ThemeLightEvent, ThemeLightState> {
  ThemeLightBloc(
    this._loadThemeLightUseCase,
    this._updateThemeLightUseCase,
    this._updateThemeLightAccentUseCase,
  ) : super(ThemeLightState.initial()) {
    on<_Started>(_onStarted);
    on<_ThemeChanged>(_onThemeChanged);
    on<_AccentChanged>(_onAccentChanged);
    on<_Reloaded>(_onReloaded);
  }

  final LoadThemeLightUseCase _loadThemeLightUseCase;
  final UpdateThemeLightUseCase _updateThemeLightUseCase;
  final UpdateThemeLightAccentUseCase _updateThemeLightAccentUseCase;

  Future<void> _onStarted(_Started event, Emitter<ThemeLightState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _loadThemeLightUseCase(const NoParams());
    result.fold(
      onSuccess: (theme) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.idle,
        theme: theme,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onThemeChanged(
    _ThemeChanged event,
    Emitter<ThemeLightState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeLightUseCase(
      UpdateThemeLightParams(themeId: event.themeId),
    );
    result.fold(
      onSuccess: (theme) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        theme: theme,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onAccentChanged(
    _AccentChanged event,
    Emitter<ThemeLightState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeLightAccentUseCase(
      UpdateThemeLightAccentParams(accentColorValue: event.accentColorValue),
    );
    result.fold(
      onSuccess: (theme) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        theme: theme,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onReloaded(_Reloaded event, Emitter<ThemeLightState> emit) {
    add(const ThemeLightEvent.started());
    return Future<void>.value();
  }
}
