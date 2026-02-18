import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_dark/domain/usecases/theme_dark_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'theme_dark_event.j.dart';
part 'theme_dark_state.j.dart';
part 'theme_dark_bloc.j.freezed.dart';

@injectable
class ThemeDarkBloc extends Bloc<ThemeDarkEvent, ThemeDarkState> {
  ThemeDarkBloc(this._loadThemeDarkUseCase, this._updateThemeDarkUseCase, this._updateThemeDarkAccentUseCase)
      : super(ThemeDarkState.initial()) {
    on<_Started>(_onStarted);
    on<_ThemeChanged>(_onThemeChanged);
    on<_AccentChanged>(_onAccentChanged);
    on<_Reloaded>(_onReloaded);
  }

  final LoadThemeDarkUseCase _loadThemeDarkUseCase;
  final UpdateThemeDarkUseCase _updateThemeDarkUseCase;
  final UpdateThemeDarkAccentUseCase _updateThemeDarkAccentUseCase;

  Future<void> _onStarted(_Started event, Emitter<ThemeDarkState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _loadThemeDarkUseCase(const NoParams());
    result.fold(
      onSuccess: (theme) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.idle, theme: theme, failure: null),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onThemeChanged(_ThemeChanged event, Emitter<ThemeDarkState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeDarkUseCase(UpdateThemeDarkParams(themeId: event.themeId));
    result.fold(
      onSuccess: (theme) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, theme: theme, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onAccentChanged(_AccentChanged event, Emitter<ThemeDarkState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeDarkAccentUseCase(
      UpdateThemeDarkAccentParams(accentColorValue: event.accentColorValue),
    );
    result.fold(
      onSuccess: (theme) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, theme: theme, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onReloaded(_Reloaded event, Emitter<ThemeDarkState> emit) {
    add(const ThemeDarkEvent.started());
    return Future<void>.value();
  }
}
