import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/repositories/deep_link_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetInitialDeepLinkActionUseCase implements UseCase<DeepLinkActionEntity?, NoParams> {
  GetInitialDeepLinkActionUseCase(this._repository);

  final DeepLinkRepository _repository;

  @override
  Future<Result<DeepLinkActionEntity?>> call(NoParams params) => _repository.getInitialAction();
}

@lazySingleton
class ObserveDeepLinkActionsUseCase {
  ObserveDeepLinkActionsUseCase(this._repository);

  final DeepLinkRepository _repository;

  Stream<DeepLinkActionEntity> call() => _repository.watchActions();
}
