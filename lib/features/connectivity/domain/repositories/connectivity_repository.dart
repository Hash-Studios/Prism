import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/connectivity/domain/entities/connectivity_entity.dart';

abstract class ConnectivityRepository {
  Future<Result<ConnectivityEntity>> checkConnection();

  Stream<ConnectivityEntity> watchConnection();
}
