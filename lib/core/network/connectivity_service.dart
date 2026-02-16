import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class ConnectivityService {
  Future<bool> hasConnection();
  Stream<bool> watchConnection();
}

@LazySingleton(as: ConnectivityService)
class InternetConnectivityService implements ConnectivityService {
  InternetConnectivityService(this._checker);

  final InternetConnectionChecker _checker;

  @override
  Future<bool> hasConnection() => _checker.hasConnection;

  @override
  Stream<bool> watchConnection() {
    return _checker.onStatusChange
        .map((status) => status == InternetConnectionStatus.connected)
        .distinct();
  }
}
