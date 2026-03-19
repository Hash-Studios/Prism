/// Holds the Firebase initialisation future so that code running after
/// [runApp] (specifically [StartupRepositoryImpl.bootstrap]) can await
/// Firebase being ready without blocking the UI thread.
///
/// [main] kicks off initialisation and calls [setFuture] immediately.
/// [StartupRepositoryImpl.bootstrap] awaits [readyFuture] before touching
/// FirebaseRemoteConfig, so the splash screen renders immediately while
/// Firebase boots in the background.
class FirebaseInit {
  FirebaseInit._();

  static Future<bool>? _future;

  /// Called once from main(), before Firebase initialisation begins.
  static void setFuture(Future<bool> future) {
    assert(_future == null, 'FirebaseInit.setFuture must only be called once.');
    _future = future;
  }

  /// Awaitable by any code that needs Firebase to be ready.
  /// Returns true if Firebase initialised successfully, false otherwise.
  /// Never throws.
  static Future<bool> get readyFuture {
    assert(_future != null, 'FirebaseInit.setFuture must be called before accessing readyFuture.');
    return _future!;
  }
}
