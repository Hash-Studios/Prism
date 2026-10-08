import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Checks hosts Prism already depends on, so a status check never sends the user's IP to a third-party mock API.
/// One reachable host is enough to count as online.
InternetConnectionChecker buildInternetConnectionChecker({http.Client? httpClient}) =>
    InternetConnectionChecker.createInstance(
      addresses: <AddressCheckOption>[
        AddressCheckOption(uri: Uri.parse('https://prismwalls.com/')),
        AddressCheckOption(uri: Uri.parse('https://firestore.googleapis.com/')),
      ],
      checkInterval: const Duration(seconds: 20),
      httpClient: httpClient,
    );

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
