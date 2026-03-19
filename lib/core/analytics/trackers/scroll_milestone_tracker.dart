import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter/widgets.dart';

typedef ScrollMilestoneEmitCallback = Future<void> Function(ScrollDepthPercentValue depth, {required int itemCount});

class ScrollMilestoneTracker {
  final Set<ScrollDepthPercentValue> _emitted = <ScrollDepthPercentValue>{};

  void reset() {
    _emitted.clear();
  }

  bool onScroll({
    required ScrollMetrics metrics,
    required int itemCount,
    required ScrollMilestoneEmitCallback onMilestoneReached,
  }) {
    if (itemCount <= 0) {
      return false;
    }
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return false;
    }

    final double maxExtent = metrics.maxScrollExtent <= 0 ? 1 : metrics.maxScrollExtent;
    final double ratio = (metrics.pixels / maxExtent).clamp(0, 1);
    final List<ScrollDepthPercentValue> thresholds = <ScrollDepthPercentValue>[
      ScrollDepthPercentValue.p25,
      ScrollDepthPercentValue.p50,
      ScrollDepthPercentValue.p75,
      ScrollDepthPercentValue.p100,
    ];

    bool emitted = false;
    for (final ScrollDepthPercentValue threshold in thresholds) {
      if (_emitted.contains(threshold)) {
        continue;
      }
      if (ratio >= _valueFor(threshold)) {
        _emitted.add(threshold);
        emitted = true;
        unawaited(onMilestoneReached(threshold, itemCount: itemCount));
      }
    }
    return emitted;
  }

  double _valueFor(ScrollDepthPercentValue value) {
    switch (value) {
      case ScrollDepthPercentValue.p25:
        return 0.25;
      case ScrollDepthPercentValue.p50:
        return 0.5;
      case ScrollDepthPercentValue.p75:
        return 0.75;
      case ScrollDepthPercentValue.p100:
        return 0.98;
    }
  }
}
