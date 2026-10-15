import 'dart:async';

import 'package:Prism/core/network/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasConnection() async => online;

  @override
  Stream<bool> get onConnectionChange => controller.stream;
}
