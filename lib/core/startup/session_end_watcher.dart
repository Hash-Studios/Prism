import 'dart:async';

/// Calls [onSessionEnded] when Firebase drops the signed-in user and the app did not ask for it.
///
/// A sign-out the user starts clears the app's signed-in flag before Firebase emits null, so it does not count. The
/// watcher waits [debounce] and checks again, so a token refresh or a sign-in in progress does not count either.
class SessionEndWatcher {
  SessionEndWatcher({
    required Stream<Object?> idTokenChanges,
    required bool Function() isLoggedIn,
    required Future<void> Function() onSessionEnded,
    Duration debounce = const Duration(seconds: 5),
  }) : _idTokenChanges = idTokenChanges,
       _isLoggedIn = isLoggedIn,
       _onSessionEnded = onSessionEnded,
       _debounce = debounce;

  final Stream<Object?> _idTokenChanges;
  final bool Function() _isLoggedIn;
  final Future<void> Function() _onSessionEnded;
  final Duration _debounce;
  StreamSubscription<Object?>? _subscription;
  Timer? _timer;
  bool _signedOut = false;
  bool _handling = false;

  void start() {
    _subscription ??= _idTokenChanges.listen(_onEvent);
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _onEvent(Object? user) {
    _signedOut = user == null;
    _timer?.cancel();
    if (!_signedOut || !_isLoggedIn()) return;
    _timer = Timer(_debounce, _confirm);
  }

  Future<void> _confirm() async {
    if (!_signedOut || !_isLoggedIn() || _handling) return;
    _handling = true;
    try {
      await _onSessionEnded();
    } finally {
      _handling = false;
    }
  }
}
