import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/connectivity/domain/entities/connectivity_entity.dart';
import 'package:Prism/features/connectivity/domain/repositories/connectivity_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ConnectivityRepository)
class ConnectivityRepositoryImpl implements ConnectivityRepository {
  ConnectivityRepositoryImpl(this._connectivityService);

  final ConnectivityService _connectivityService;

  @override
  Future<Result<ConnectivityEntity>> checkConnection() async {
    try {
      final hasConnection = await _connectivityService.hasConnection();
      return Result.success(ConnectivityEntity(isConnected: hasConnection));
    } catch (error) {
      return Result.error(NetworkFailure('Unable to check connectivity: $error'));
    }
  }

  @override
  Stream<ConnectivityEntity> watchConnection() {
    return _connectivityService.watchConnection().map((isConnected) => ConnectivityEntity(isConnected: isConnected));
  }
}
