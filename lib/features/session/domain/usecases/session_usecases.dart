import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetSessionUseCase implements UseCase<SessionEntity, NoParams> {
  GetSessionUseCase(this._repository);

  final SessionRepository _repository;

  @override
  Future<Result<SessionEntity>> call(NoParams params) => _repository.getSession();
}

@lazySingleton
class RefreshPremiumUseCase implements UseCase<SessionEntity, NoParams> {
  RefreshPremiumUseCase(this._repository);

  final SessionRepository _repository;

  @override
  Future<Result<SessionEntity>> call(NoParams params) => _repository.refreshPremium();
}

@lazySingleton
class SignOutUseCase implements UseCase<SessionEntity, NoParams> {
  SignOutUseCase(this._repository);

  final SessionRepository _repository;

  @override
  Future<Result<SessionEntity>> call(NoParams params) => _repository.signOut();
}
