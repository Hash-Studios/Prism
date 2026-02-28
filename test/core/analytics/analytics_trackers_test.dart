import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScrollMilestoneTracker', () {
    FixedScrollMetrics metricsFor(double pixels) {
      return FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: pixels,
        viewportDimension: 300,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
    }

    test('emits p25/p50/p75/p100 only once per lifecycle', () async {
      final ScrollMilestoneTracker tracker = ScrollMilestoneTracker();
      final List<ScrollDepthPercentValue> emitted = <ScrollDepthPercentValue>[];

      Future<void> emit(ScrollDepthPercentValue depth, {required int itemCount}) async {
        emitted.add(depth);
      }

      tracker.onScroll(metrics: metricsFor(250), itemCount: 20, onMilestoneReached: emit);
      tracker.onScroll(metrics: metricsFor(260), itemCount: 20, onMilestoneReached: emit);
      tracker.onScroll(metrics: metricsFor(500), itemCount: 20, onMilestoneReached: emit);
      tracker.onScroll(metrics: metricsFor(750), itemCount: 20, onMilestoneReached: emit);
      tracker.onScroll(metrics: metricsFor(1000), itemCount: 20, onMilestoneReached: emit);
      tracker.onScroll(metrics: metricsFor(1000), itemCount: 20, onMilestoneReached: emit);

      await Future<void>.delayed(Duration.zero);

      expect(emitted, <ScrollDepthPercentValue>[
        ScrollDepthPercentValue.p25,
        ScrollDepthPercentValue.p50,
        ScrollDepthPercentValue.p75,
        ScrollDepthPercentValue.p100,
      ]);
    });

    test('reset allows milestones to be emitted again', () async {
      final ScrollMilestoneTracker tracker = ScrollMilestoneTracker();
      final List<ScrollDepthPercentValue> emitted = <ScrollDepthPercentValue>[];

      Future<void> emit(ScrollDepthPercentValue depth, {required int itemCount}) async {
        emitted.add(depth);
      }

      tracker.onScroll(metrics: metricsFor(1000), itemCount: 10, onMilestoneReached: emit);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, 4);

      tracker.reset();
      tracker.onScroll(metrics: metricsFor(1000), itemCount: 10, onMilestoneReached: emit);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 8);
    });
  });

  group('ContentLoadTracker', () {
    test('success emits once even if invoked multiple times', () async {
      final ContentLoadTracker tracker = ContentLoadTracker()..start();
      int callCount = 0;

      Future<void> onSuccess({required int loadTimeMs, int? itemCount}) async {
        callCount += 1;
      }

      tracker.success(onSuccess: onSuccess, itemCount: 5);
      tracker.success(onSuccess: onSuccess, itemCount: 5);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
    });

    test('failure emits once with canonical reason', () async {
      final ContentLoadTracker tracker = ContentLoadTracker()..start();
      int callCount = 0;
      AnalyticsReasonValue? capturedReason;

      Future<void> onFailure({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
        callCount += 1;
        capturedReason = reason;
      }

      tracker.failure(onFailure: onFailure, reason: AnalyticsReasonValue.error);
      tracker.failure(onFailure: onFailure, reason: AnalyticsReasonValue.unknown);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
      expect(capturedReason, AnalyticsReasonValue.error);
    });
  });
}
