import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/connectivity/domain/entities/connectivity_entity.dart';
import 'package:Prism/features/connectivity/domain/repositories/connectivity_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CheckConnectionUseCase implements UseCase<ConnectivityEntity, NoParams> {
  CheckConnectionUseCase(this._repository);

  final ConnectivityRepository _repository;

  @override
  Future<Result<ConnectivityEntity>> call(NoParams params) =>
      _repository.checkConnection();
}

@lazySingleton
class WatchConnectionUseCase {
  WatchConnectionUseCase(this._repository);

  final ConnectivityRepository _repository;

  Stream<ConnectivityEntity> call() => _repository.watchConnection();
}
