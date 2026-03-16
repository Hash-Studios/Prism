import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadAutoRotateConfigUseCase implements UseCase<AutoRotateConfigEntity, NoParams> {
  LoadAutoRotateConfigUseCase(this._repository);

  final AutoRotateRepository _repository;

  @override
  Future<Result<AutoRotateConfigEntity>> call(NoParams params) => _repository.loadConfig();
}

@lazySingleton
class SaveAutoRotateConfigUseCase implements UseCase<void, AutoRotateConfigEntity> {
  SaveAutoRotateConfigUseCase(this._repository);

  final AutoRotateRepository _repository;

  @override
  Future<Result<void>> call(AutoRotateConfigEntity params) => _repository.saveConfig(params);
}

@lazySingleton
class StartAutoRotateUseCase implements UseCase<void, AutoRotateConfigEntity> {
  StartAutoRotateUseCase(this._repository);

  final AutoRotateRepository _repository;

  @override
  Future<Result<void>> call(AutoRotateConfigEntity params) => _repository.startRotation(params);
}

@lazySingleton
class StopAutoRotateUseCase implements UseCase<void, NoParams> {
  StopAutoRotateUseCase(this._repository);

  final AutoRotateRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.stopRotation();
}

@lazySingleton
class GetAutoRotateStatusUseCase implements UseCase<bool, NoParams> {
  GetAutoRotateStatusUseCase(this._repository);

  final AutoRotateRepository _repository;

  @override
  Future<Result<bool>> call(NoParams params) => _repository.isRotationActive();
}
