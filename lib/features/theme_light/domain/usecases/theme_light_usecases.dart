import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadThemeLightUseCase implements UseCase<ThemeLightEntity, NoParams> {
  LoadThemeLightUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeLightEntity>> call(NoParams params) =>
      _repository.getLightTheme();
}

class UpdateThemeLightParams {
  const UpdateThemeLightParams({required this.themeId});

  final String themeId;
}

@lazySingleton
class UpdateThemeLightUseCase
    implements UseCase<ThemeLightEntity, UpdateThemeLightParams> {
  UpdateThemeLightUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeLightEntity>> call(UpdateThemeLightParams params) =>
      _repository.setLightTheme(params.themeId);
}

class UpdateThemeLightAccentParams {
  const UpdateThemeLightAccentParams({required this.accentColorValue});

  final int accentColorValue;
}

@lazySingleton
class UpdateThemeLightAccentUseCase
    implements UseCase<ThemeLightEntity, UpdateThemeLightAccentParams> {
  UpdateThemeLightAccentUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeLightEntity>> call(UpdateThemeLightAccentParams params) =>
      _repository.setLightAccent(params.accentColorValue);
}
