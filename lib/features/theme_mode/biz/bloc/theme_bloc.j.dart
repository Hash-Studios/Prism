import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_usecases.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'theme_event.j.dart';
part 'theme_state.j.dart';
part 'theme_bloc.j.freezed.dart';

@injectable
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc(this._loadThemeUseCase, this._updateThemeUseCase) : super(ThemeState.initial()) {
    on<_Started>(_onStarted);
    on<_LightThemeChanged>((event, emit) => _update(UpdateThemeParams(lightThemeId: event.themeId), emit));
    on<_LightAccentChanged>(
      (event, emit) => _update(UpdateThemeParams(lightAccentColorValue: event.accentColorValue), emit),
    );
    on<_DarkThemeChanged>((event, emit) => _update(UpdateThemeParams(darkThemeId: event.themeId), emit));
    on<_DarkAccentChanged>(
      (event, emit) => _update(UpdateThemeParams(darkAccentColorValue: event.accentColorValue), emit),
    );
    on<_ModeChanged>((event, emit) => _update(UpdateThemeParams(mode: event.mode), emit));
  }

  final LoadThemeUseCase _loadThemeUseCase;
  final UpdateThemeUseCase _updateThemeUseCase;

  Future<void> _onStarted(_Started event, Emitter<ThemeState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _loadThemeUseCase(const NoParams());
    result.fold(
      onSuccess: (preferences) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.idle,
          light: preferences.light,
          dark: preferences.dark,
          mode: preferences.mode,
          failure: null,
        ),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _update(UpdateThemeParams params, Emitter<ThemeState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _updateThemeUseCase(params);
    result.fold(
      onSuccess: (preferences) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          light: preferences.light,
          dark: preferences.dark,
          mode: preferences.mode,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }
}
