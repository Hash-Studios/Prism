import 'dart:async';

import 'package:Prism/core/router/short_link_resolver.dart';

enum ShortLinkFailureAction { retryWhenOnline, showNotFound }

/// A link that failed because the network failed may still be valid, so it gets one retry. Any other failure means
/// the link is gone.
ShortLinkFailureAction shortLinkFailureAction(ShortLinkFailed failure, {required bool isRetry}) =>
    failure.isNetwork && !isRetry ? ShortLinkFailureAction.retryWhenOnline : ShortLinkFailureAction.showNotFound;

/// Keeps one short code until the device is back online, then hands it to [retry] once. The trigger is a connectivity
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
  String? _code;
  StreamSubscription<bool>? _subscription;

  bool get hasPending => _code != null;

  /// Keeps [code] and waits for the connection. A second code replaces the first.
  void schedule(String code) {
    _code = code;
    _subscription ??= _onlineChanges().listen((bool online) {
      if (online) _fire();
    });
  }

  Future<void> onResumed() async {
    if (_code == null) return;
    if (await _hasConnection()) _fire();
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _code = null;
  }

  void _fire() {
    final String? code = _code;
    if (code == null) return;
    dispose();
    _retry(code);
  }
}
