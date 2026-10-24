import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirebaseMessaging extends Fake implements FirebaseMessaging {
  Future<String?> Function()? getTokenHandler;
  Stream<String> tokenRefreshes = const Stream<String>.empty();
  Future<void> Function()? deleteTokenHandler;
  int deleteTokenCalls = 0;

  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) =>
      getTokenHandler?.call() ?? Future<String?>.value();

  @override
  Future<void> deleteToken() {
    deleteTokenCalls++;
    return deleteTokenHandler?.call() ?? Future<void>.value();
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefreshes;
}
