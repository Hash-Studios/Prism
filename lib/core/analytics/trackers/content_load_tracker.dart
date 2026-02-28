import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';

typedef ContentLoadSuccessCallback = Future<void> Function({required int loadTimeMs, int? itemCount});
typedef ContentLoadFailureCallback =
    Future<void> Function({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount});

class ContentLoadTracker {
  DateTime? _startedAt;
  bool _completed = false;

  void start() {
    _startedAt = DateTime.now().toUtc();
    _completed = false;
  }

  void reset() {
    _startedAt = null;
    _completed = false;
  }

  void success({required ContentLoadSuccessCallback onSuccess, int? itemCount}) {
    if (_completed) {
      return;
    }
    _completed = true;
    unawaited(onSuccess(loadTimeMs: _elapsedMs(), itemCount: itemCount));
  }

  void failure({required ContentLoadFailureCallback onFailure, AnalyticsReasonValue? reason, int? itemCount}) {
    if (_completed) {
      return;
    }
    _completed = true;
    unawaited(onFailure(loadTimeMs: _elapsedMs(), reason: reason, itemCount: itemCount));
  }

  int _elapsedMs() {
    final DateTime now = DateTime.now().toUtc();
    final DateTime started = _startedAt ?? now;
    final int millis = now.difference(started).inMilliseconds;
    if (millis < 0) {
      return 0;
    }
    return millis;
  }
}
