/// Holds the shared Firebase initialisation future.
///
/// [main] starts Firebase while persistence and monitoring initialize, then
/// awaits [readyFuture] before calling [runApp]. Startup bootstrap also awaits
/// the same future before accessing Firebase Remote Config.
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
