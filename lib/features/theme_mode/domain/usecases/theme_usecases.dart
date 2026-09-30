import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadThemeUseCase implements UseCase<ThemePreferences, NoParams> {
  LoadThemeUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemePreferences>> call(NoParams params) => _repository.load();
}

class UpdateThemeParams {
  const UpdateThemeParams({
    this.lightThemeId,
    this.lightAccentColorValue,
    this.darkThemeId,
    this.darkAccentColorValue,
    this.mode,
  });

  final String? lightThemeId;
  final int? lightAccentColorValue;
  final String? darkThemeId;
  final int? darkAccentColorValue;
  final ThemeMode? mode;
}

@lazySingleton
class UpdateThemeUseCase implements UseCase<ThemePreferences, UpdateThemeParams> {
  UpdateThemeUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemePreferences>> call(UpdateThemeParams params) => _repository.update(
    lightThemeId: params.lightThemeId,
    lightAccentColorValue: params.lightAccentColorValue,
    darkThemeId: params.darkThemeId,
    darkAccentColorValue: params.darkAccentColorValue,
    mode: params.mode,
  );
}
