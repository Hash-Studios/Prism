import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class ConnectivityService {
  Future<bool> hasConnection();

  Stream<bool> get onConnectionChange;
}

@LazySingleton(as: ConnectivityService)
class InternetConnectivityService implements ConnectivityService {
  InternetConnectivityService(this._checker);

  final InternetConnectionChecker _checker;

  @override
  Future<bool> hasConnection() => _checker.hasConnection;

  @override
  Stream<bool> get onConnectionChange =>
      _checker.onStatusChange.map((InternetConnectionStatus status) => status == InternetConnectionStatus.connected);
}
