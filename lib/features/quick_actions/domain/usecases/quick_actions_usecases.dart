import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/quick_actions/domain/entities/quick_action_entity.dart';
import 'package:Prism/features/quick_actions/domain/repositories/quick_actions_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class InitializeQuickActionsUseCase implements UseCase<void, NoParams> {
  InitializeQuickActionsUseCase(this._repository);

  final QuickActionsRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.initialize();
}

@lazySingleton
class SetQuickActionShortcutsUseCase implements UseCase<void, NoParams> {
  SetQuickActionShortcutsUseCase(this._repository);

  final QuickActionsRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) =>
      _repository.setDefaultShortcuts();
}

@lazySingleton
class ObserveQuickActionsUseCase {
  ObserveQuickActionsUseCase(this._repository);

  final QuickActionsRepository _repository;

  Stream<QuickActionEntity> call() => _repository.watchActions();
}
