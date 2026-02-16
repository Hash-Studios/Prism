import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class BootstrapAppUseCase implements UseCase<StartupConfigEntity, NoParams> {
  BootstrapAppUseCase(this._repository);

  final StartupRepository _repository;

  @override
  Future<Result<StartupConfigEntity>> call(NoParams params) => _repository.bootstrap();
}
