import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/monitoring/field_diagnostics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FrameTiming frame(int number, {required int buildUs, required int rasterUs}) => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: buildUs,
  rasterStart: buildUs,
  rasterFinish: buildUs + rasterUs,
  rasterFinishWallTime: buildUs + rasterUs,
  frameNumber: number,
);

void withTrackedTimers(void Function(List<Timer>) test) {
  final List<Timer> timers = <Timer>[];
  runZoned(
    () => test(timers),
    zoneSpecification: ZoneSpecification(
      createPeriodicTimer: (self, parent, zone, duration, callback) {
        final Timer timer = parent.createPeriodicTimer(zone, duration, callback);
        timers.add(timer);
        return timer;
      },
    ),
  );
}

class _TimingsTestBinding extends AutomatedTestWidgetsFlutterBinding {
  final Set<TimingsCallback> timingsCallbacks = <TimingsCallback>{};

  @override
  void addTimingsCallback(TimingsCallback callback) {
    timingsCallbacks.add(callback);
    super.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    timingsCallbacks.remove(callback);
    super.removeTimingsCallback(callback);
  }
}

void main() {
  final _TimingsTestBinding binding = _TimingsTestBinding();
  group('JankSummary', () {
    const Duration budget = Duration(microseconds: 16667);

    test('counts slow and frozen frames and reads p90 build and raster times', () {
      final List<FrameTiming> frames = <FrameTiming>[
        for (int n = 1; n <= 10; n++) frame(n, buildUs: n == 9 ? 20000 : n * 1000, rasterUs: n == 10 ? 800000 : 500),
      ];

      final JankSummary summary = JankSummary.of(frames, budget: budget);

      expect(summary.frames, 10);
      expect(summary.slow, 1);
      expect(summary.frozen, 1);
      expect(summary.buildP90Ms, 10.0);
      expect(summary.rasterP90Ms, 0.5);
    });

    test('a frame at the budget is not slow', () {
      final JankSummary summary = JankSummary.of(<FrameTiming>[frame(1, buildUs: 16667, rasterUs: 0)], budget: budget);

      expect(summary.slow, 0);
      expect(summary.frozen, 0);
    });

    test('a frame at 700 ms is slow but not frozen, and just over 700 ms is frozen', () {
      final JankSummary atLimit = JankSummary.of(<FrameTiming>[frame(1, buildUs: 0, rasterUs: 700000)], budget: budget);
      final JankSummary overLimit = JankSummary.of(<FrameTiming>[
        frame(1, buildUs: 700001, rasterUs: 0),
      ], budget: budget);

      expect(atLimit.slow, 1);
      expect(atLimit.frozen, 0);
      expect(overLimit.slow, 0);
      expect(overLimit.frozen, 1);
    });
  });

  group('JankSampler', () {
    test('sampling off adds no timings callback', () {
      int adds = 0;
      int reads = 0;
      final List<FieldJankEvent> events = <FieldJankEvent>[];
      final JankSampler sampler = JankSampler(
        sampled: () => false,
        addTimings: (_) {
          adds++;
        },
        removeTimings: (_) {},
        currentFrame: () => reads++,
        refreshRate: () => 60,
        report: events.add,
      );

      final JankVisit? home = sampler.begin(JankScreenValue.homeFeed);
      sampler.swiping(true);
      sampler.swiping(false);
      sampler.end(home);
      sampler.flush();
      sampler.resume();

      expect(adds, 0);
      expect(reads, 0);
      expect(events, isEmpty);
    });

    test('sampled visits split frames by screen and swipe, and report each visit once', () {
      TimingsCallback? timings;
      int frameNow = 0;
      int adds = 0;
      int removes = 0;
      final List<FieldJankEvent> events = <FieldJankEvent>[];
      final JankSampler sampler = JankSampler(
        sampled: () => true,
        addTimings: (TimingsCallback callback) {
          adds++;
          timings = callback;
        },
        removeTimings: (_) {
          removes++;
        },
        currentFrame: () => frameNow,
        refreshRate: () => 60,
        report: events.add,
      );
      void deliver(Iterable<int> numbers) {
        timings!(<FrameTiming>[for (final int n in numbers) frame(n, buildUs: 1000, rasterUs: 500)]);
      }

      final JankVisit? home = sampler.begin(JankScreenValue.homeFeed);
      expect(adds, 1);
      deliver(<int>[1, 2, 3]);

      frameNow = 3;
      final JankVisit? detail = sampler.begin(JankScreenValue.wallDetail);
      deliver(<int>[4, 5]);
      expect(events.map((FieldJankEvent e) => (e.screen, e.frames)).toList(), <(JankScreenValue, int)>[
        (JankScreenValue.homeFeed, 3),
      ]);

      frameNow = 5;
      sampler.swiping(true);
      deliver(<int>[6, 7]);

      frameNow = 7;
      sampler.swiping(false);
      deliver(<int>[8]);

      frameNow = 8;
      sampler.end(detail);
      deliver(<int>[9]);
      expect(events.map((FieldJankEvent e) => (e.screen, e.frames)).toList(), <(JankScreenValue, int)>[
        (JankScreenValue.homeFeed, 3),
        (JankScreenValue.wallDetail, 3),
        (JankScreenValue.detailSwipe, 2),
      ]);

      frameNow = 9;
      sampler.end(home);
      deliver(<int>[10]);

      expect(events.map((FieldJankEvent e) => (e.screen, e.frames)).toList(), <(JankScreenValue, int)>[
        (JankScreenValue.homeFeed, 3),
        (JankScreenValue.wallDetail, 3),
        (JankScreenValue.detailSwipe, 2),
        (JankScreenValue.homeFeed, 1),
      ]);
      expect(events.every((FieldJankEvent e) => e.refreshHz == 60), isTrue);
      expect(adds, 1);
      expect(removes, 1);
    });

    test('ending a covered visit with the same screen keeps the top visit active', () {
      TimingsCallback? timings;
      int frameNow = 0;
      final List<FieldJankEvent> events = <FieldJankEvent>[];
      final JankSampler sampler = JankSampler(
        sampled: () => true,
        addTimings: (callback) => timings = callback,
        removeTimings: (_) {},
        currentFrame: () => frameNow,
        refreshRate: () => 60,
        report: events.add,
      );
      final JankVisit? lower = sampler.begin(JankScreenValue.wallDetail);
      frameNow = 1;
      final JankVisit? upper = sampler.begin(JankScreenValue.wallDetail);
      sampler.swiping(true);
      sampler.end(lower);
      timings!(<FrameTiming>[frame(2, buildUs: 20000, rasterUs: 500)]);
      frameNow = 2;
      sampler.end(upper);
      timings!(<FrameTiming>[frame(3, buildUs: 1000, rasterUs: 500)]);
      expect(events.single.slowFrames, 1);
      expect(events.single.screen, JankScreenValue.detailSwipe);
    });

    test('flush reports open visits at once, and resume listens again', () {
      TimingsCallback? timings;
      int adds = 0;
      int removes = 0;
      final List<FieldJankEvent> events = <FieldJankEvent>[];
      final JankSampler sampler = JankSampler(
        sampled: () => true,
        addTimings: (TimingsCallback callback) {
          adds++;
          timings = callback;
        },
        removeTimings: (_) {
          removes++;
        },
        currentFrame: () => 0,
        refreshRate: () => 60,
        report: events.add,
      );

      sampler.begin(JankScreenValue.homeFeed);
      timings!(<FrameTiming>[frame(1, buildUs: 1000, rasterUs: 500), frame(2, buildUs: 1000, rasterUs: 500)]);
      sampler.flush();

      expect(events.map((FieldJankEvent e) => (e.screen, e.frames)).toList(), <(JankScreenValue, int)>[
        (JankScreenValue.homeFeed, 2),
      ]);
      expect(removes, 1);

      sampler.resume();

      expect(adds, 2);
    });
  });
  test('an old resume frame callback cannot finish a newer resume window', () {
    final List<FrameCallback> callbacks = <FrameCallback>[];
    final List<ResumeStallEvent> events = <ResumeStallEvent>[];
    final ResumeStallProbe probe = ResumeStallProbe(
      sampled: () => true,
      report: events.add,
      afterNextFrame: callbacks.add,
    );
    probe.paused();
    probe.resumed();
    probe.paused();
    probe.resumed();
    callbacks.first(Duration.zero);
    probe.paused();
    expect(events, hasLength(2));
    expect(events.last.firstFrameMs, isNull);
  });

  test('sampling waits for configuration and stays fixed for the session', () {
    FieldDiagnostics.resetSampling();
    addTearDown(FieldDiagnostics.resetSampling);
    expect(FieldDiagnostics.sampled, isFalse);
    FieldDiagnostics.configureSampling(1);
    expect(FieldDiagnostics.sampled, isTrue);
    FieldDiagnostics.configureSampling(0);
    expect(FieldDiagnostics.sampled, isTrue);
    FieldDiagnostics.resetSampling();
    FieldDiagnostics.configureSampling(0);
    expect(FieldDiagnostics.sampled, isFalse);
    FieldDiagnostics.configureSampling(1);
    expect(FieldDiagnostics.sampled, isFalse);
  });

  test('sampled-out resumes schedule neither timers nor frame callbacks', () {
    withTrackedTimers((List<Timer> timers) {
      final List<FrameCallback> callbacks = <FrameCallback>[];
      final List<ResumeStallEvent> events = <ResumeStallEvent>[];
      final ResumeStallProbe probe = ResumeStallProbe(
        sampled: () => false,
        report: events.add,
        afterNextFrame: callbacks.add,
      );
      probe.paused();
      probe.resumed();
      probe.resumed();
      probe.paused();
      expect(callbacks, isEmpty);
      expect(timers, isEmpty);
      expect(events, isEmpty);
    });
  });

  test('repeated resumes keep one window and pause reports it once', () {
    withTrackedTimers((List<Timer> timers) {
      final List<FrameCallback> callbacks = <FrameCallback>[];
      final List<ResumeStallEvent> events = <ResumeStallEvent>[];
      final ResumeStallProbe probe = ResumeStallProbe(
        sampled: () => true,
        report: events.add,
        afterNextFrame: callbacks.add,
      );
      probe.resumed();
      expect(callbacks, isEmpty);
      probe.paused();
      probe.resumed();
      probe.resumed();
      expect(callbacks, hasLength(1));
      expect(timers.where((timer) => timer.isActive), hasLength(1));
      probe.paused();
      callbacks.single(Duration.zero);
      probe.paused();
      expect(events, hasLength(1));
      expect(events.single.firstFrameMs, isNull);
      expect(timers.where((timer) => timer.isActive), isEmpty);
    });
  });

  test('late frame batches and pause flush report each bucket only once', () {
    TimingsCallback? timings;
    int frameNow = 0;
    final List<FieldJankEvent> events = <FieldJankEvent>[];
    final JankSampler sampler = JankSampler(
      sampled: () => true,
      addTimings: (callback) => timings = callback,
      removeTimings: (_) {},
      currentFrame: () => frameNow,
      refreshRate: () => 60,
      report: events.add,
    );
    final JankVisit? home = sampler.begin(JankScreenValue.homeFeed);
    frameNow = 2;
    final JankVisit? detail = sampler.begin(JankScreenValue.wallDetail);
    sampler.end(home);
    timings!(<FrameTiming>[
      frame(1, buildUs: 1000, rasterUs: 500),
      frame(2, buildUs: 1000, rasterUs: 500),
      frame(3, buildUs: 20000, rasterUs: 500),
    ]);
    frameNow = 3;
    sampler.flush();
    sampler.flush();
    sampler.resume();
    timings!(<FrameTiming>[frame(4, buildUs: 1000, rasterUs: 500)]);
    frameNow = 4;
    sampler.end(detail);
    timings!(<FrameTiming>[frame(5, buildUs: 1000, rasterUs: 500)]);
    sampler.flush();
    expect(events.map((e) => (e.screen, e.frames, e.slowFrames)).toList(), <(JankScreenValue, int, int)>[
      (JankScreenValue.homeFeed, 2, 0),
      (JankScreenValue.wallDetail, 1, 1),
      (JankScreenValue.wallDetail, 1, 0),
    ]);
    final JankVisit? empty = sampler.begin(JankScreenValue.homeFeed);
    sampler.end(empty);
    sampler.flush();
    expect(events, hasLength(3));
  });
  testWidgets('a scope mounted before Remote Config starts when sampling becomes ready', (tester) async {
    FieldDiagnostics.resetSampling();
    addTearDown(FieldDiagnostics.resetSampling);
    await tester.pumpWidget(const JankVisitScope(screen: JankScreenValue.homeFeed, child: SizedBox()));
    final int callbacksBeforeSampling = binding.timingsCallbacks.length;
    FieldDiagnostics.configureSampling(1);
    expect(binding.timingsCallbacks, hasLength(callbacksBeforeSampling + 1));
    await tester.pumpWidget(const SizedBox());
    JankSampler.instance.flush();
    expect(binding.timingsCallbacks, hasLength(callbacksBeforeSampling));
  });
}
