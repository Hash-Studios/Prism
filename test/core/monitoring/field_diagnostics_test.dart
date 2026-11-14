import 'dart:ui';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/monitoring/field_diagnostics.dart';
import 'package:flutter/scheduler.dart';
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

void main() {
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
      final List<FieldJankEvent> events = <FieldJankEvent>[];
      final JankSampler sampler = JankSampler(
        sampled: () => false,
        addTimings: (_) {
          adds++;
        },
        removeTimings: (_) {},
        currentFrame: () => 0,
        refreshRate: () => 60,
        report: events.add,
      );

      sampler.begin(JankScreenValue.homeFeed);
      sampler.swiping(true);
      sampler.swiping(false);
      sampler.end(JankScreenValue.homeFeed);
      sampler.flush();
      sampler.resume();

      expect(adds, 0);
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

      sampler.begin(JankScreenValue.homeFeed);
      expect(adds, 1);
      deliver(<int>[1, 2, 3]);

      frameNow = 3;
      sampler.begin(JankScreenValue.wallDetail);
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
      sampler.end(JankScreenValue.wallDetail);
      deliver(<int>[9]);
      expect(events.map((FieldJankEvent e) => (e.screen, e.frames)).toList(), <(JankScreenValue, int)>[
        (JankScreenValue.homeFeed, 3),
        (JankScreenValue.wallDetail, 3),
        (JankScreenValue.detailSwipe, 2),
      ]);

      frameNow = 9;
      sampler.end(JankScreenValue.homeFeed);
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
}
