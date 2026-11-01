import 'package:Prism/env/env.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class FirebaseInit {
  FirebaseInit._();

  static Future<bool>? _future;
  static bool _initialized = false;

  /// Called once from main(), before Firebase initialisation begins.
  static void setFuture(Future<bool> future) {
    assert(_future == null, 'FirebaseInit.setFuture must only be called once.');
    _future = future.then<bool>(
      (initialized) {
        _initialized = initialized;
        return initialized;
      },
      onError: (Object _, StackTrace _) {
        _initialized = false;
        return false;
      },
    );
  }

  /// Awaitable by any code that needs Firebase to be ready.
  /// Returns true if Firebase initialised successfully, false otherwise.
  /// Never throws.
  static Future<bool> get readyFuture {
    assert(_future != null, 'FirebaseInit.setFuture must be called before accessing readyFuture.');
    return _future!;
  }

  static Future<bool> waitUntilReady({Duration timeout = const Duration(seconds: 3)}) =>
      readyFuture.timeout(timeout, onTimeout: () => false);

  /// The default app exists. False while startup is still initializing Firebase, and after init failed or was skipped.
  static bool get hasDefaultApp => Firebase.apps.isNotEmpty;

  /// True at once when the default app exists, otherwise waits for startup like [waitUntilReady].
  static Future<bool> defaultAppReady() async => hasDefaultApp || await waitUntilReady();

  static FirebaseRemoteConfig? get remoteConfigIfInitialized {
    if (!_initialized || Env.localQa) return null;
    try {
      return FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }
}
