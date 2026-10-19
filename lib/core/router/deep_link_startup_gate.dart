import 'dart:async';

import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:auto_route/auto_route.dart';

/// Reports when startup permits destination resolution and navigation.
///
/// Startup is over when the config has loaded and neither the splash nor onboarding is on the router stack. Both
/// of those call `replaceAll` when they finish, which would drop a route pushed earlier. The gate re-checks on every
/// router change. Referral storage can wait only for bootstrap via [whenBootstrapped].
class DeepLinkStartupGate {
  DeepLinkStartupGate({required StackRouter router}) : _router = router {
    _router.addListener(_onRouterChanged);
  }

  final StackRouter _router;
  final List<Completer<bool>> _waiters = <Completer<bool>>[];
  final List<Completer<bool>> _bootstrapWaiters = <Completer<bool>>[];
  bool _bootstrapCompleted = false;
  bool _disposed = false;

  bool get isReady => _bootstrapCompleted && !isStartingUp(_router);

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

  Future<bool> whenBootstrapped() {
    if (_disposed) return Future<bool>.value(false);
    if (_bootstrapCompleted) return Future<bool>.value(true);
    final Completer<bool> waiter = Completer<bool>();
    _bootstrapWaiters.add(waiter);
    return waiter.future;
  }

  void dispose() {
    _disposed = true;
    _router.removeListener(_onRouterChanged);
    for (final Completer<bool> waiter in <Completer<bool>>[..._waiters, ..._bootstrapWaiters]) {
      waiter.complete(false);
    }
    _waiters.clear();
    _bootstrapWaiters.clear();
  }

  void _onRouterChanged() => scheduleMicrotask(_flush);

  void _flush() {
    if (_disposed || !_bootstrapCompleted) return;
    for (final Completer<bool> waiter in _bootstrapWaiters) {
      waiter.complete(true);
    }
    _bootstrapWaiters.clear();
    if (!isReady) return;
    for (final Completer<bool> waiter in _waiters) {
      waiter.complete(true);
    }
    _waiters.clear();
  }
}
