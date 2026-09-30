import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirebaseMessaging extends Fake implements FirebaseMessaging {
  Future<String?> Function()? getTokenHandler;
  Stream<String> tokenRefreshes = const Stream<String>.empty();

  @override
  Future<String?> getToken({String? vapidKey}) => getTokenHandler?.call() ?? Future<String?>.value();

  @override
  Stream<String> get onTokenRefresh => tokenRefreshes;
}
