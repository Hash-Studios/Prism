import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';

abstract class DeepLinkRepository {
  Future<Result<DeepLinkActionEntity?>> getInitialAction();

  Stream<DeepLinkActionEntity> watchActions();

  Future<void> dispose();
}
