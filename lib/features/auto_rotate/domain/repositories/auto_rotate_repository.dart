import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';

abstract class AutoRotateRepository {
  Future<Result<AutoRotateConfigEntity>> loadConfig();
  Future<Result<void>> saveConfig(AutoRotateConfigEntity config);
  Future<Result<void>> startRotation(AutoRotateConfigEntity config);
  Future<Result<void>> stopRotation();
  Future<Result<bool>> isRotationActive();
}
