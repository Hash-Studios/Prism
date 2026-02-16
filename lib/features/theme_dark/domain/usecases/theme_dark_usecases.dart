import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadThemeDarkUseCase implements UseCase<ThemeDarkEntity, NoParams> {
  LoadThemeDarkUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeDarkEntity>> call(NoParams params) =>
      _repository.getDarkTheme();
}

class UpdateThemeDarkParams {
  const UpdateThemeDarkParams({required this.themeId});

  final String themeId;
}

@lazySingleton
class UpdateThemeDarkUseCase
    implements UseCase<ThemeDarkEntity, UpdateThemeDarkParams> {
  UpdateThemeDarkUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeDarkEntity>> call(UpdateThemeDarkParams params) =>
      _repository.setDarkTheme(params.themeId);
}

class UpdateThemeDarkAccentParams {
  const UpdateThemeDarkAccentParams({required this.accentColorValue});

  final int accentColorValue;
}

@lazySingleton
class UpdateThemeDarkAccentUseCase
    implements UseCase<ThemeDarkEntity, UpdateThemeDarkAccentParams> {
  UpdateThemeDarkAccentUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeDarkEntity>> call(UpdateThemeDarkAccentParams params) =>
      _repository.setDarkAccent(params.accentColorValue);
}
