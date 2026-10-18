import 'dart:async';

import 'package:Prism/core/analytics/analytics_route_observer.dart';
import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:flutter/widgets.dart';

class AnalyticsRuntime {
  AnalyticsRuntime._();

  static final ValueNotifier<AppAnalytics> changes = ValueNotifier<AppAnalytics>(const NoopAppAnalytics());
  static BufferedAppAnalytics _buffer = BufferedAppAnalytics();

  static AppAnalytics get instance => _buffer;

  static set instance(AppAnalytics value) {
    _buffer.attach(value);
    changes.value = value;
  }

  static List<NavigatorObserver> buildNavigatorObservers() => <NavigatorObserver>[
    AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) =>
          instance.logScreenView(screenName: screenName, screenClass: screenClass, parameters: parameters),
    ),
  ];

  static void reset() {
    _buffer.dispose();
    _buffer = BufferedAppAnalytics();
    AnalyticsIdentitySync.resetDefault();
    changes.value = const NoopAppAnalytics();
  }
}

class BufferedAppAnalytics implements AppAnalytics {
  BufferedAppAnalytics({this.capacity = 256, this.maxAge = const Duration(minutes: 2)}) : assert(capacity >= 32);

  final int capacity;
  final Duration maxAge;
  final List<_BufferedCall> _calls = <_BufferedCall>[];
  final Map<String, String?> _properties = <String, String?>{};
  AppAnalytics? _target;
  Future<void>? _pending;
  String? _userId;
  bool _hasIdentity = false;
  bool _disposed = false;

  void attach(AppAnalytics target) {
    if (_disposed) return;
    final bool replacing = _target != null;
    _target = target;
    if (replacing) {
      final String? userId = _userId;
      if (_hasIdentity) _replay((AppAnalytics analytics) => analytics.setUserId(userId));
      for (final MapEntry<String, String?> entry in _properties.entries) {
        _replay((AppAnalytics analytics) => analytics.setUserProperty(name: entry.key, value: entry.value));
      }
    }
    final List<_BufferedCall> calls = List<_BufferedCall>.of(_calls);
    _calls.clear();
    if (calls.isNotEmpty && DateTime.now().difference(calls.first.createdAt) > maxAge) {
      final String? userId = _userId;
      if (_hasIdentity) _replay((AppAnalytics analytics) => analytics.setUserId(userId));
      for (final MapEntry<String, String?> entry in _properties.entries) {
        _replay((AppAnalytics analytics) => analytics.setUserProperty(name: entry.key, value: entry.value));
      }
      return;
    }
    for (final _BufferedCall call in calls) {
      _replay(call.apply);
    }
  }

  void _replay(Future<void> Function(AppAnalytics) apply) {
    unawaited(_enqueue(apply).catchError((Object _) {}));
  }

  Future<void> _enqueue(Future<void> Function(AppAnalytics) apply) {
    if (_disposed) return Future<void>.value();
    final AppAnalytics? target = _target;
    if (target == null) {
      if (_calls.length >= capacity) {
        _calls.clear();
        final String? userId = _userId;
        if (_hasIdentity) _calls.add(_BufferedCall((AppAnalytics analytics) => analytics.setUserId(userId)));
        for (final MapEntry<String, String?> entry in _properties.entries) {
          _calls.add(
            _BufferedCall((AppAnalytics analytics) => analytics.setUserProperty(name: entry.key, value: entry.value)),
          );
        }
      }
      _calls.add(_BufferedCall(apply));
      return Future<void>.value();
    }
    Future<void> dispatch() => _disposed ? Future<void>.value() : apply(target);
    final Future<void> operation = _pending?.then((_) => dispatch()) ?? Future<void>.sync(dispatch);
    _pending = operation.catchError((Object _) {});
    return _pending!;
  }

  void dispose() {
    _disposed = true;
    _calls.clear();
    _properties.clear();
  }

  @override
  Future<void> track(AnalyticsEvent event) => _enqueue((AppAnalytics analytics) => analytics.track(event));

  @override
  Future<void> setUserId(String? userId) {
    _userId = userId;
    _hasIdentity = true;
    return _enqueue((AppAnalytics analytics) => analytics.setUserId(userId));
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) {
    if (!_properties.containsKey(name) && _properties.length >= 16) return Future<void>.value();
    _properties[name] = value;
    return _enqueue((AppAnalytics analytics) => analytics.setUserProperty(name: name, value: value));
  }

  @override
  Future<void> logScreenView({required String screenName, String? screenClass, Map<String, Object?>? parameters}) {
    final Map<String, Object?>? snapshot = parameters == null ? null : Map<String, Object?>.of(parameters);
    return _enqueue(
      (AppAnalytics analytics) =>
          analytics.logScreenView(screenName: screenName, screenClass: screenClass, parameters: snapshot),
    );
  }

  @override
  Future<void> flush() => _enqueue((AppAnalytics analytics) => analytics.flush());
}

class _BufferedCall {
  _BufferedCall(this.apply) : createdAt = DateTime.now();

  final Future<void> Function(AppAnalytics) apply;
  final DateTime createdAt;
}
