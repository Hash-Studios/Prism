import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Field diagnostics for bugs we cannot reproduce: jank (#533) and resume stalls (#551). Remote Config
/// [sampleRateKey] picks the sampled sessions, once per process. 0 turns both off.
class FieldDiagnostics {
  FieldDiagnostics._();

  static const String sampleRateKey = 'field_diagnostics_sample_rate';
  static const double defaultSampleRate = 0.05;

  @visibleForTesting
  static bool? sampledOverride;
  static bool? _sampled;

  /// False until Remote Config is ready, so the rate it holds decides.
  static bool get sampled {
    if (sampledOverride case final bool forced) return forced;
    if (_sampled case final bool decided) return decided;
    final double? rate = FirebaseInit.remoteConfigIfInitialized?.getDouble(sampleRateKey);
    if (rate == null) return false;
    return _sampled = Random().nextDouble() < rate;
  }

  static final ResumeStallProbe _resume = ResumeStallProbe();

  static void onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resume.resumed();
        JankSampler.instance.resume();
      case AppLifecycleState.paused:
        _resume.paused();
        JankSampler.instance.flush();
      case AppLifecycleState.inactive || AppLifecycleState.hidden || AppLifecycleState.detached:
    }
  }

  static void track(AnalyticsEvent event) {
    PerformanceProbe.emit(kind: 'field', name: event.eventName, durationMs: 0, extra: event.toWireParameters());
    unawaited(analytics.track(event));
  }
}

/// Frame stats of one screen visit. A frame is slow when its build or raster time is over the display's frame
/// budget, and frozen when it is over 700 ms, as in Sentry. A frozen frame is not also slow.
@immutable
class JankSummary {
  const JankSummary({
    required this.frames,
    required this.slow,
    required this.frozen,
    required this.buildP90Ms,
    required this.rasterP90Ms,
  });

  factory JankSummary.of(List<FrameTiming> timings, {required Duration budget}) {
    int slow = 0;
    int frozen = 0;
    for (final FrameTiming t in timings) {
      final Duration cost = t.buildDuration > t.rasterDuration ? t.buildDuration : t.rasterDuration;
      if (cost > frozenAfter) {
        frozen++;
      } else if (cost > budget) {
        slow++;
      }
    }
    double p90Ms(Duration Function(FrameTiming) of) {
      final List<int> us = timings.map((FrameTiming t) => of(t).inMicroseconds).toList()..sort();
      return (us[((us.length - 1) * 0.9).round()] / 100).round() / 10;
    }

    return JankSummary(
      frames: timings.length,
      slow: slow,
      frozen: frozen,
      buildP90Ms: p90Ms((FrameTiming t) => t.buildDuration),
      rasterP90Ms: p90Ms((FrameTiming t) => t.rasterDuration),
    );
  }

  static const Duration frozenAfter = Duration(milliseconds: 700);

  final int frames;
  final int slow;
  final int frozen;
  final double buildP90Ms;
  final double rasterP90Ms;
}

class _Bucket {
  _Bucket(this.screen);

  final JankScreenValue screen;
  final List<FrameTiming> frames = <FrameTiming>[];
}

class _Visit {
  _Visit(this.screen);

  final JankScreenValue screen;
  bool swiping = false;
  _Bucket? main;
  _Bucket? swipe;
}

/// Sends one [FieldJankEvent] per screen visit in sampled sessions. Visits stack: the top one gets the frames, and a
/// visit covered by another ends there and starts again when it is on top once more. Frames go to visits by frame
/// number, because the engine reports them in batches up to a second late.
///
/// Not sampled: no timings callback, no work.
class JankSampler {
  JankSampler({
    bool Function()? sampled,
    void Function(TimingsCallback)? addTimings,
    void Function(TimingsCallback)? removeTimings,
    int Function()? currentFrame,
    double Function()? refreshRate,
    void Function(FieldJankEvent)? report,
  }) : _sampled = sampled ?? (() => FieldDiagnostics.sampled),
       _addTimings = addTimings ?? SchedulerBinding.instance.addTimingsCallback,
       _removeTimings = removeTimings ?? SchedulerBinding.instance.removeTimingsCallback,
       _currentFrame = currentFrame ?? (() => PlatformDispatcher.instance.frameData.frameNumber),
       _refreshRate = refreshRate ?? _displayRefreshRate,
       _report = report ?? FieldDiagnostics.track;

  static final JankSampler instance = JankSampler();

  // ponytail: p90 covers the first 3600 frames (a minute of rendering) of a visit.
  static const int maxFrames = 3600;

  final bool Function() _sampled;
  final void Function(TimingsCallback) _addTimings;
  final void Function(TimingsCallback) _removeTimings;
  final int Function() _currentFrame;
  final double Function() _refreshRate;
  final void Function(FieldJankEvent) _report;

  final List<_Visit> _stack = <_Visit>[];

  /// Frames numbered above `from` go to `bucket`, until the next mark.
  final List<({int from, _Bucket? bucket})> _marks = <({int from, _Bucket? bucket})>[];

  /// Ended buckets. Each reports once a frame numbered above `after` arrives, so its own late frames are in.
  final List<({int after, _Bucket bucket})> _ending = <({int after, _Bucket bucket})>[];
  bool _listening = false;

  void begin(JankScreenValue screen) {
    if (!_sampled()) return;
    if (_stack.isNotEmpty) _end(_stack.last);
    _stack.add(_Visit(screen));
    _route();
  }

  void end(JankScreenValue screen) {
    final int index = _stack.lastIndexWhere((_Visit v) => v.screen == screen);
    if (index < 0) return;
    final bool top = index == _stack.length - 1;
    _end(_stack.removeAt(index));
    if (top) _route();
  }

  /// Frames of the top visit go to [JankScreenValue.detailSwipe] while [on].
  void swiping(bool on) {
    if (_stack.isEmpty || _stack.last.swiping == on) return;
    _stack.last.swiping = on;
    _route();
  }

  /// The app goes to the background: no more frames come, so every open visit reports now.
  void flush() {
    if (_stack.isNotEmpty) _end(_stack.last);
    for (final ({int after, _Bucket bucket}) ending in _ending) {
      _emit(ending.bucket);
    }
    _ending.clear();
    _marks.clear();
    _stopListening();
  }

  void resume() {
    if (_stack.isNotEmpty) _route();
  }

  void _end(_Visit visit) {
    final int frame = _currentFrame();
    for (final _Bucket? bucket in <_Bucket?>[visit.main, visit.swipe]) {
      if (bucket != null) _ending.add((after: frame, bucket: bucket));
    }
    visit
      ..main = null
      ..swipe = null;
  }

  void _route() {
    final _Visit? top = _stack.isEmpty ? null : _stack.last;
    final _Bucket? bucket = switch (top) {
      null => null,
      _Visit(swiping: true) => top.swipe ??= _Bucket(JankScreenValue.detailSwipe),
      _ => top.main ??= _Bucket(top.screen),
    };
    _marks.add((from: _currentFrame(), bucket: bucket));
    if (!_listening && (top != null || _ending.isNotEmpty)) {
      _listening = true;
      _addTimings(_onTimings);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    for (final FrameTiming timing in timings) {
      final int mark = _marks.lastIndexWhere((m) => m.from < timing.frameNumber);
      final _Bucket? bucket = mark < 0 ? null : _marks[mark].bucket;
      if (bucket != null && bucket.frames.length < maxFrames) bucket.frames.add(timing);
    }
    final int newest = timings.last.frameNumber;
    _ending.removeWhere((ending) {
      if (newest <= ending.after) return false;
      _emit(ending.bucket);
      return true;
    });
    while (_marks.length > 1 && _marks[1].from <= newest) {
      _marks.removeAt(0);
    }
    if (_stack.isEmpty && _ending.isEmpty) {
      _marks.clear();
      _stopListening();
    }
  }

  void _emit(_Bucket bucket) {
    if (bucket.frames.isEmpty) return;
    final double hz = _refreshRate();
    final JankSummary summary = JankSummary.of(
      bucket.frames,
      budget: Duration(microseconds: (Duration.microsecondsPerSecond / hz).round()),
    );
    _report(
      FieldJankEvent(
        screen: bucket.screen,
        frames: summary.frames,
        slowFrames: summary.slow,
        frozenFrames: summary.frozen,
        buildP90Ms: summary.buildP90Ms,
        rasterP90Ms: summary.rasterP90Ms,
        refreshHz: hz.round(),
      ),
    );
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    _removeTimings(_onTimings);
  }

  static double _displayRefreshRate() {
    final double rate = PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 0;
    return rate > 0 ? rate : 60;
  }
}

/// In a sampled session, sends one [ResumeStallEvent] per resume from the background: the time to the first frame,
/// and the longest time the main thread did not answer a 50 ms timer in the 3 s after resume, when that is over 700 ms.
/// It reports after the first frame and the 3 s, or at the next pause without a first frame.
class ResumeStallProbe {
  ResumeStallProbe({
    bool Function()? sampled,
    void Function(ResumeStallEvent)? report,
    void Function(FrameCallback)? afterNextFrame,
  }) : _sampled = sampled ?? (() => FieldDiagnostics.sampled),
       _report = report ?? FieldDiagnostics.track,
       _afterNextFrame = afterNextFrame ?? ((FrameCallback f) => SchedulerBinding.instance.addPostFrameCallback(f));

  static const Duration tick = Duration(milliseconds: 50);
  static const Duration window = Duration(seconds: 3);
  static const Duration stallAfter = Duration(milliseconds: 700);

  final bool Function() _sampled;
  final void Function(ResumeStallEvent) _report;
  final void Function(FrameCallback) _afterNextFrame;
  DateTime? _pausedAt;
  void Function()? _finish;

  void paused() {
    _finish?.call();
    _pausedAt = DateTime.now();
  }

  void resumed() {
    final DateTime? pausedAt = _pausedAt;
    _pausedAt = null;
    if (_finish != null || pausedAt == null || !_sampled()) return;
    final int backgroundS = DateTime.now().difference(pausedAt).inSeconds;
    final Stopwatch clock = Stopwatch()..start();
    int? firstFrameMs;
    int longest = 0;
    int last = 0;
    late final Timer timer;
    void finish() {
      if (_finish == null) return;
      _finish = null;
      timer.cancel();
      _report(
        ResumeStallEvent(
          firstFrameMs: firstFrameMs,
          longestTaskMs: longest > stallAfter.inMilliseconds ? longest : null,
          backgroundS: backgroundS,
        ),
      );
    }

    _finish = finish;
    timer = Timer.periodic(tick, (Timer timer) {
      final int now = clock.elapsedMilliseconds;
      longest = max(longest, now - last - tick.inMilliseconds);
      last = now;
      if (now < window.inMilliseconds) return;
      timer.cancel();
      if (firstFrameMs != null) finish();
    });
    _afterNextFrame((_) {
      firstFrameMs = clock.elapsedMilliseconds;
      if (!timer.isActive) finish();
    });
  }
}

/// A [JankSampler] visit to [screen] while [active] and its route is the current one.
class JankVisitScope extends StatefulWidget {
  const JankVisitScope({required this.screen, required this.child, this.active = true, super.key});

  final JankScreenValue screen;
  final bool active;
  final Widget child;

  @override
  State<JankVisitScope> createState() => _JankVisitScopeState();
}

class _JankVisitScopeState extends State<JankVisitScope> {
  bool _visiting = false;

  void _sync() {
    final bool visiting = widget.active && (ModalRoute.isCurrentOf(context) ?? true);
    if (visiting == _visiting) return;
    _visiting = visiting;
    visiting ? JankSampler.instance.begin(widget.screen) : JankSampler.instance.end(widget.screen);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(JankVisitScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_visiting) JankSampler.instance.end(widget.screen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
