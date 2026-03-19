import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';

abstract class StartupRepository {
  StartupConfigEntity? get currentConfig;

  Stream<StartupConfigEntity> watchConfig();

  Future<Result<StartupConfigEntity>> bootstrap();
}
