import 'dart:async';

import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/scheduler.dart';

/// Keeps the matched destination across onboarding's replacement of the router stack.
class AuthNavigationContinuation {
  AuthNavigationContinuation._(this._router) {
    _router.addListener(_onRouterChanged);
  }

  static final Expando<AuthNavigationContinuation> _instances = Expando<AuthNavigationContinuation>();

  factory AuthNavigationContinuation.of(StackRouter router) =>
      _instances[router.root] ??= AuthNavigationContinuation._(router.root);

  final StackRouter _router;
  _PendingNavigation? _pending;
  _PendingNavigation? _resuming;
  bool _bootstrapCompleted = false;
  bool _authWasVisible = false;
  bool _disposed = false;
  NavigationFailure? _lastNavigationFailure;
  final Set<Object> _cancelledRouteIds = <Object>{};

  /// True means the destination became visible; false means it was cancelled or refused by a guard.
  Future<bool>? get pendingNavigation => (_pending ?? _resuming)?.completion.future;

  bool get isResuming => _resuming != null;

  NavigationFailure? get lastNavigationFailure => _lastNavigationFailure;

  bool isCancelled(RouteMatch route) => _cancelledRouteIds.contains(route.id);

  void defer(NavigationResolver resolver, {required StackRouter router}) {
    if (_disposed || isResuming) return;
    final bool alreadySigningIn = _hasOnboarding;
    cancel();
    _lastNavigationFailure = null;
    List<PageRouteInfo> routes = [
      resolver.route.toPageRouteInfo(),
      ...resolver.pendingRoutes.map((route) => route.toPageRouteInfo()),
    ];
    RoutingController scope = router;
    while (!scope.isRoot) {
      routes = [scope.routeData.route.toPageRouteInfo().copyWith(children: routes)];
      scope = scope.parent<RoutingController>()!;
    }
    final pending = _PendingNavigation(routes);
    _pending = pending;
    _authWasVisible = alreadySigningIn;
    if (!alreadySigningIn) unawaited(_openSignIn(pending));
  }

  void markBootstrapCompleted() {
    _bootstrapCompleted = true;
    _flush();
  }

  /// Logout and account deletion must discard the previous session's destination.
  void cancel() {
    _pending?.complete(false);
    final resuming = _resuming;
    if (resuming != null) {
      resuming.cancelled = true;
      _cancelledRouteIds.addAll(resuming.routeIds);
      resuming.complete(false);
      if (resuming.dispatchCompleted) _discardCancelledNavigation(resuming);
    }
    _pending = null;
    _authWasVisible = false;
  }

  void dispose() {
    if (_disposed) return;
    cancel();
    _disposed = true;
    _router.removeListener(_onRouterChanged);
    _instances[_router] = null;
  }

  bool get _hasOnboarding => _router.stackData.any((route) => route.name == 'OnboardingV2ShellRoute');

  Future<void> _openSignIn(_PendingNavigation pending) async {
    try {
      // Pages match by route name. A sign-in pushed in the frame that removed the previous one would reuse its
      // finished state, so wait for that frame first.
      final scheduler = SchedulerBinding.instance;
      if (scheduler.schedulerPhase == SchedulerPhase.postFrameCallbacks) scheduler.scheduleFrame();
      await scheduler.endOfFrame;
      if (!identical(_pending, pending) || _disposed) return;
      if (_hasOnboarding) {
        _authWasVisible = true;
        return;
      }
      if (app_state.prismUser.loggedIn) {
        _authWasVisible = true;
        _flush();
        return;
      }
      await _router.pushPath('/onboarding/v2', onFailure: (_) => _cancelIfCurrent(pending));
      if (!_authWasVisible) _cancelIfCurrent(pending);
      _onRouterChanged();
    } catch (_) {
      _cancelIfCurrent(pending);
    }
  }

  void _cancelIfCurrent(_PendingNavigation pending) {
    if (identical(_pending, pending) || identical(_resuming, pending)) cancel();
  }

  void _onRouterChanged() => scheduleMicrotask(_flush);

  void _flush() {
    if (_disposed) return;
    _discardCancelledRoutes();
    final resuming = _resuming;
    if (resuming != null) {
      if (resuming.cancelled) return;
      final target = resuming.routes.last.flattened.last;
      final top = _router.topRoute;
      final visible = top.route.toPageRouteInfo();
      // AutoRoute can represent a leaf's children as either null or empty after reusing the dashboard.
      if (visible.copyWith(children: const []) == target.copyWith(children: const []) &&
          identical(top.args, target.args)) {
        _resuming = null;
        resuming.complete(true);
      }
      return;
    }
    final pending = _pending;
    if (pending == null) return;
    if (_hasOnboarding) {
      _authWasVisible = true;
      return;
    }
    if (!_authWasVisible || isStartingUp(_router)) return;
    if (!app_state.prismUser.loggedIn) {
      cancel();
      return;
    }
    if (!_bootstrapCompleted) return;
    _pending = null;
    _resuming = pending;
    unawaited(_resume(pending));
  }

  Future<void> _resume(_PendingNavigation pending) async {
    try {
      final matches = pending.routes.map((route) => _router.matcher.matchByRoute(route)!).toList();
      pending.routeIds.addAll(matches.expand(_matchTree).map((route) => route.id));
      await _router.navigateAll(
        matches,
        onFailure: (failure) {
          if (!identical(_resuming, pending)) return;
          _lastNavigationFailure = failure;
          cancel();
        },
      );
    } catch (_) {
      _cancelIfCurrent(pending);
    } finally {
      pending.dispatchCompleted = true;
      if (pending.cancelled) _discardCancelledNavigation(pending);
    }
  }

  void _discardCancelledNavigation(_PendingNavigation pending) {
    _discardCancelledRoutes();
    if (identical(_resuming, pending)) _resuming = null;
  }

  void _discardCancelledRoutes() {
    if (_cancelledRouteIds.isEmpty) return;
    for (final scope in _stackRouters(_router).toList().reversed) {
      scope.removeWhere((route) => _cancelledRouteIds.contains(route.matchId), notify: false);
    }
  }

  Iterable<StackRouter> _stackRouters(RoutingController controller) sync* {
    if (controller is StackRouter) yield controller;
    for (final child in controller.childControllers) {
      yield* _stackRouters(child);
    }
  }

  Iterable<RouteMatch> _matchTree(RouteMatch route) sync* {
    yield route;
    for (final child in route.children ?? const <RouteMatch>[]) {
      yield* _matchTree(child);
    }
  }
}

class _PendingNavigation {
  _PendingNavigation(this.routes);

  final List<PageRouteInfo> routes;
  final Completer<bool> completion = Completer<bool>();
  final Set<Object> routeIds = <Object>{};
  bool cancelled = false;
  bool dispatchCompleted = false;

  void complete(bool visible) {
    if (!completion.isCompleted) completion.complete(visible);
  }
}
