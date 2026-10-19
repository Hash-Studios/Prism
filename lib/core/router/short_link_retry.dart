import 'dart:async';

/// Keeps short codes until the device is back online, then hands each to [retry] once. The trigger is a connectivity
/// event or an app resume that finds a connection.
class ShortLinkRetryScheduler {
  ShortLinkRetryScheduler({
    required Stream<bool> Function() onlineChanges,
    required Future<bool> Function() hasConnection,
    required void Function(String code) retry,
  }) : _onlineChanges = onlineChanges,
       _hasConnection = hasConnection,
       _retry = retry;

  final Stream<bool> Function() _onlineChanges;
  final Future<bool> Function() _hasConnection;
  final void Function(String code) _retry;
  final Set<String> _codes = <String>{};
  StreamSubscription<bool>? _subscription;

  bool get hasPending => _codes.isNotEmpty;

  /// Keeps [code] and waits for the connection.
  void schedule(String code) {
    _codes.add(code);
    _subscription ??= _onlineChanges().listen((bool online) {
      if (online) _fire();
    });
  }

  Future<void> onResumed() async {
    if (_codes.isEmpty) return;
    if (await _hasConnection()) _fire();
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _codes.clear();
  }

  void _fire() {
    final List<String> codes = _codes.toList();
    if (codes.isEmpty) return;
    dispose();
    for (final String code in codes) {
      _retry(code);
    }
  }
}
