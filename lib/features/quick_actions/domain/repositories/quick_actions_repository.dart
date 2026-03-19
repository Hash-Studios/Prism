import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/quick_actions/domain/entities/quick_action_entity.dart';

abstract class QuickActionsRepository {
  Future<Result<void>> initialize();

  Future<Result<void>> setDefaultShortcuts();

  Stream<QuickActionEntity> watchActions();
}
