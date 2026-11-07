import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/power_saver_channel.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

const Color _ice = Color(0xFFE3EDF7);
const Color _gold = Color(0xFFFFD27A);

/// One flake. Its fixed fractions and rates are generated once and reused by the painter.
class _Flake {
  const _Flake(this.x, this.y, this.fallsPerLoop, this.radius, this.sway, this.phase);

  final double x;
  final double y;

  /// Whole falls per clock loop keep the motion continuous when the clock resets.
  final int fallsPerLoop;
  final double radius;
  final double sway;
  final double phase;
}

final List<_Flake> _flakes = () {
  final math.Random random = math.Random(2026);
  return List<_Flake>.generate(
    18,
    (_) => _Flake(
      random.nextDouble(),
      random.nextDouble(),
      3 + random.nextInt(4),
      0.9 + random.nextDouble() * 1.5,
      4 + random.nextDouble() * 8,
      random.nextDouble() * math.pi * 2,
    ),
  );
}();

class _SnowPainter extends CustomPainter {
  _SnowPainter({required this.clock, required this.color, required this.sparkles}) : super(repaint: clock);

  final Animation<double> clock;
  final Color color;

  /// Every third flake is a gold spark on New Year's Eve and New Year's Day.
  final bool sparkles;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = clock.value;
    final double fall = size.height + 8;
    for (int i = 0; i < _flakes.length; i++) {
      final _Flake flake = _flakes[i];
      final double y = ((flake.y + flake.fallsPerLoop * progress) % 1) * fall - 4;
      final double x = flake.x * size.width + math.sin(progress * math.pi * 12 + flake.phase) * flake.sway;
      final double fade = 1 - (y / size.height).clamp(0.0, 1.0);
      final bool spark = sparkles && i % 3 == 0;
      _paint.color = (spark ? _gold : color).withValues(alpha: (spark ? 0.9 : 0.7) * fade * fade);
      canvas.drawCircle(Offset(x, y), spark ? flake.radius + 0.6 : flake.radius, _paint);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter oldDelegate) => oldDelegate.color != color || oldDelegate.sparkles != sparkles;
}

/// A light snowfall over the header of [child] that fades out just below it, while Winter is the active theme. It ignores taps, stays out
/// of semantics, pauses while [child] scrolls, and is off with Reduce Motion, Low Power Mode, battery saver or a hidden
/// tab. From 31 December to 1 January it adds gold sparks and a short New Year greeting.
class WinterSnowfall extends StatefulWidget {
  const WinterSnowfall({required this.child, required this.headerHeight, this.powerSaver, super.key});

  /// How far below the header the flakes fade out.
  static const double fadeDepth = 96;

  final Widget child;
  final double headerHeight;

  /// Reads the phone's power saver. Tests pass their own.
  final Future<bool> Function()? powerSaver;

  @override
  State<WinterSnowfall> createState() => _WinterSnowfallState();
}

class _WinterSnowfallState extends State<WinterSnowfall> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _reducedMotionTracked = false;

  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  bool _scrolling = false;
  bool _lowPower = false;
  bool _newYear = false;
  Timer? _newYearTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readPowerSaver());
    _scheduleNewYear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newYearTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readPowerSaver());
      final bool wasNewYear = _newYear;
      _scheduleNewYear();
      if (_newYear != wasNewYear) setState(() {});
    }
  }

  Future<void> _readPowerSaver() async {
    final bool on = await (widget.powerSaver ?? const PowerSaverChannel().isOn)();
    if (mounted && on != _lowPower) setState(() => _lowPower = on);
  }

  /// Rebuilds when the New Year window opens or closes.
  void _scheduleNewYear() {
    _newYearTimer?.cancel();
    final DateTime now = seasonNow();
    _newYear = newYearWindow.contains(now);
    final DateTime next = newYearWindow.isUpcoming(now) ? newYearWindow.start : newYearWindow.end;
    if (newYearWindow.hasEnded(now)) return;
    _newYearTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(_scheduleNewYear);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final bool scrolling = switch (notification) {
      ScrollStartNotification() || ScrollUpdateNotification() => true,
      ScrollEndNotification() => false,
      _ => _scrolling,
    };
    if (scrolling != _scrolling) setState(() => _scrolling = scrolling);
    return false;
  }

  void _trackReducedMotion() {
    if (_reducedMotionTracked) return;
    _reducedMotionTracked = true;
    unawaited(
      analytics.track(
        SeasonalDecorDisabledEvent(season: winterSeason.name, reason: SeasonalDecorDisabledReasonValue.reducedMotion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool active = winterSeason.isActive(context);
    final bool reduceMotion = context.reduceMotion;
    if (active && reduceMotion) _trackReducedMotion();
    final bool snowing = active && !reduceMotion && !_lowPower;
    if (!snowing || _scrolling || !TickerMode.valuesOf(context).enabled) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      unawaited(_clock.repeat());
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color flake = colors.brightness == Brightness.dark ? _ice : colors.primary;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: <Widget>[
          widget.child,
          if (snowing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.headerHeight + WinterSnowfall.fadeDepth,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SnowPainter(clock: _clock, color: flake, sparkles: _newYear),
                    ),
                  ),
                ),
              ),
            ),
          if (active && _newYear)
            Positioned(
              top: widget.headerHeight + PrismSpace.xs,
              left: 0,
              right: 0,
              child: const WinterNewYearGreeting(),
            ),
        ],
      ),
    );
  }
}

/// "Happy New Year" in a small pill. It shows once for each time Home opens and leaves after a few seconds, so it never
/// sits on a wallpaper.
class WinterNewYearGreeting extends StatefulWidget {
  const WinterNewYearGreeting({super.key});

  static const Duration visibleFor = Duration(seconds: 6);

  @override
  State<WinterNewYearGreeting> createState() => _WinterNewYearGreetingState();
}

class _WinterNewYearGreetingState extends State<WinterNewYearGreeting> {
  bool _visible = true;
  late final Timer _hide;

  @override
  void initState() {
    super.initState();
    _hide = Timer(WinterNewYearGreeting.visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hide.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: context.motion(PrismDurations.base),
        child: Center(
          child: Semantics(
            liveRegion: _visible,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xxs + 2),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(PrismRadius.md),
              ),
              child: Text(
                context.l10n.winterNewYearGreeting,
                textAlign: TextAlign.center,
                style: PrismTextStyles.caption(context).copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The home card art: a night sky in cool blues with a few still flakes.
class WinterBannerArt extends StatelessWidget {
  const WinterBannerArt({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A1521), Color(0xFF16304A), Color(0xFF2A4F72)],
        ),
      ),
      child: CustomPaint(
        painter: _SnowPainter(clock: const AlwaysStoppedAnimation<double>(0.3), color: _ice, sparkles: false),
        child: const SizedBox.expand(),
      ),
    );
  }
}
