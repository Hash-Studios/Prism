import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadThemeModeUseCase implements UseCase<ThemeModeEntity, NoParams> {
  LoadThemeModeUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeModeEntity>> call(NoParams params) => _repository.getThemeMode();
}

class UpdateThemeModeParams {
  const UpdateThemeModeParams({required this.mode});

  final String mode;
}

@lazySingleton
class UpdateThemeModeUseCase implements UseCase<ThemeModeEntity, UpdateThemeModeParams> {
  UpdateThemeModeUseCase(this._repository);

  final ThemeRepository _repository;

  @override
  Future<Result<ThemeModeEntity>> call(UpdateThemeModeParams params) => _repository.setThemeMode(params.mode);
}
