import 'dart:async';

import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/pending_deep_link_queue.dart';
import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:auto_route/auto_route.dart';

/// Holds deep links and push taps until startup is over, then lets them through.
///
/// Startup is over when the config has loaded and neither the splash nor onboarding is on the router stack. Both
/// of those call `replaceAll` when they finish, which would drop a route pushed earlier. The gate re-checks on every
/// router change, so a long onboarding does not lose the link. A referral link pushes no route, so it only waits
/// for the config.
class DeepLinkStartupGate {
  DeepLinkStartupGate({
    required StackRouter router,
    required Future<void> Function(DeepLinkActionEntity action) handle,
    required void Function(DeepLinkActionEntity action, Object error, StackTrace stackTrace) onError,
  }) : _router = router,
       _handle = handle,
       _onError = onError {
    _router.addListener(_onRouterChanged);
  }

  final StackRouter _router;
  final Future<void> Function(DeepLinkActionEntity action) _handle;
  final void Function(DeepLinkActionEntity action, Object error, StackTrace stackTrace) _onError;
  final PendingDeepLinkQueue _held = PendingDeepLinkQueue();
  final List<ReferLinkIntent> _referrals = <ReferLinkIntent>[];
  final List<Completer<bool>> _waiters = <Completer<bool>>[];
  bool _bootstrapCompleted = false;
  bool _disposed = false;

  bool get isReady => _bootstrapCompleted && !isStartingUp(_router);

  void add(DeepLinkActionEntity action) {
    if (action is ReferLinkIntent) {
      _referrals.add(action);
    } else {
      _held.add(action);
    }
    _flush();
  }

  /// Call when the startup config has loaded. It stays false on the obsolete-version screen.
  void markBootstrapCompleted() {
    _bootstrapCompleted = true;
    _flush();
  }

  /// Completes with true once startup is over, or with false if the gate is disposed first.
  Future<bool> whenReady() {
    if (_disposed) return Future<bool>.value(false);
    if (isReady) return Future<bool>.value(true);
    final Completer<bool> waiter = Completer<bool>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void dispose() {
    _disposed = true;
    _router.removeListener(_onRouterChanged);
    for (final Completer<bool> waiter in _waiters) {
      waiter.complete(false);
    }
    _waiters.clear();
  }

  void _onRouterChanged() => scheduleMicrotask(_flush);

  void _flush() {
    if (_disposed || !_bootstrapCompleted) return;
    if (_referrals.isNotEmpty) {
      final List<ReferLinkIntent> referrals = List<ReferLinkIntent>.of(_referrals);
      _referrals.clear();
      for (final ReferLinkIntent referral in referrals) {
        unawaited(_runReferral(referral));
      }
    }
    if (!isReady) return;
    for (final Completer<bool> waiter in _waiters) {
      waiter.complete(true);
    }
    _waiters.clear();
    if (!_held.isEmpty) unawaited(_held.drain(_handle, onError: _onError));
  }

  Future<void> _runReferral(ReferLinkIntent referral) async {
    try {
      await _handle(referral);
    } catch (error, stackTrace) {
      _onError(referral, error, stackTrace);
    }
  }
}
