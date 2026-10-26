import 'dart:math' as math;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// True when the theme in [context] is Diwali. It reads the page colour, so it needs no theme bloc above it.
bool isDiwaliActive(BuildContext context) => Theme.of(context).colorScheme.surface == kDarkTheme10.colorScheme.surface;

const Color _marigold = Color(0xFFFFB020);
const Color _rose = Color(0xFFFF5C8A);
const Color _teal = Color(0xFF52E0D4);

const String _bowlSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 36">
<path d="M2 6 Q8 9 14 9 L62 9 Q63 35 37 35 Q17 35 12 17 Q8 10 2 6 Z" fill="#C2571B"/>
<path d="M14 9 L62 9 Q60 14 38 14 Q20 14 14 9 Z" fill="#6E270A"/>
<path d="M16 20 Q38 29 60 17" stroke="#8E3510" stroke-width="1.4" fill="none"/>
<circle cx="24" cy="25" r="1.6" fill="#FFD27A"/><circle cx="32" cy="27.6" r="1.6" fill="#FFD27A"/>
<circle cx="40" cy="27.8" r="1.6" fill="#FFD27A"/><circle cx="48" cy="25.8" r="1.6" fill="#FFD27A"/>
<circle cx="55" cy="22" r="1.6" fill="#FFD27A"/>
</svg>''';

const String _flameSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 32">
<path d="M10 0 C14 8 19 14 19 21 C19 27 15 31 10 31 C5 31 1 27 1 21 C1 14 6 8 10 0 Z" fill="#FFB020"/>
<path d="M10 11 C12.5 16 15 18.5 15 22.5 C15 26 12.8 28.5 10 28.5 C7.2 28.5 5 26 5 22.5 C5 18.5 7.5 16 10 11 Z" fill="#FFF1B8"/>
</svg>''';

/// A firework burst: rays from the centre, each with a spark at its tip.
String _burstSvg(Color color) {
  final String hex = '#${(color.toARGB32() & 0x00ffffff).toRadixString(16).padLeft(6, '0')}';
  final StringBuffer rays = StringBuffer();
  for (int i = 0; i < 12; i++) {
    final double a = i * math.pi / 6;
    final double c = math.cos(a);
    final double s = math.sin(a);
    String p(double v) => v.toStringAsFixed(1);
    rays.write('<path d="M${p(50 + 16 * c)} ${p(50 + 16 * s)} L${p(50 + 38 * c)} ${p(50 + 38 * s)}"/>');
    rays.write('<circle cx="${p(50 + 45 * c)}" cy="${p(50 + 45 * s)}" r="2.6" fill="$hex" stroke="none"/>');
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="$hex" '
      'stroke-width="3" stroke-linecap="round">$rays<circle cx="50" cy="50" r="4" fill="$hex" stroke="none"/></svg>';
}

Widget _svg(String source, {required double width}) => SvgPicture.string(source, width: width);

/// A clay diya with its flame. The flame flickers when [flicker] is on.
class _Diya extends StatefulWidget {
  const _Diya({required this.size, required this.flicker});

  final double size;
  final bool flicker;

  @override
  State<_Diya> createState() => _DiyaState();
}

class _DiyaState extends State<_Diya> with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.flicker || context.reduceMotion || !TickerMode.valuesOf(context).enabled) {
      _flicker.stop();
    } else if (!_flicker.isAnimating) {
      _flicker.repeat(reverse: true);
    }
    final double s = widget.size;
    final double flameWidth = s * 0.3;
    const double flameLeft = 0;
    final double flameBottom = s * 0.4;
    final Widget bowl = _svg(_bowlSvg, width: s * 0.88);
    final Widget flame = _svg(_flameSvg, width: flameWidth);
    return SizedBox(
      width: s,
      height: s * 0.9,
      child: AnimatedBuilder(
        animation: _flicker,
        builder: (context, _) {
          final double t = Curves.easeInOut.transform(_flicker.value);
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: flameLeft + flameWidth / 2 - s * 0.3,
                bottom: flameBottom + flameWidth * 0.8 - s * 0.3,
                child: Container(
                  width: s * 0.6,
                  height: s * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        _marigold.withValues(alpha: 0.45 + 0.2 * t),
                        _marigold.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(left: s * 0.12, bottom: 0, child: bowl),
              Positioned(
                left: flameLeft,
                bottom: flameBottom,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1.04 - 0.08 * t, 0.9 + 0.16 * t, 1),
                  child: flame,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A lit diya that sits on the edge below it. Draws nothing unless Diwali is active.
class DiwaliDiya extends StatelessWidget {
  const DiwaliDiya({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isDiwaliActive(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(child: _Diya(size: size, flicker: true)),
    );
  }
}

/// Three firework bursts for a top corner. They bloom and fade in turn. Draws nothing unless Diwali is active.
class DiwaliFireworks extends StatefulWidget {
  const DiwaliFireworks({super.key, this.size = 96, this.right = false});

  final double size;

  /// Puts the largest burst near the right edge, for the top right corner.
  final bool right;

  @override
  State<DiwaliFireworks> createState() => _DiwaliFireworksState();
}

class _DiwaliFireworksState extends State<DiwaliFireworks> with SingleTickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isDiwaliActive(context)) {
      if (_bloom.isAnimating) _bloom.stop();
      return const SizedBox.shrink();
    }
    final bool tickerEnabled = TickerMode.valuesOf(context).enabled;
    final bool still = context.reduceMotion;
    if (!tickerEnabled || still) {
      _bloom.stop();
    } else if (!_bloom.isAnimating) {
      _bloom.repeat();
    }
    final double s = widget.size;
    final List<({double x, double y, double size, Color color, double phase})> bursts = [
      (x: 0.58, y: 0.08, size: 0.42, color: Theme.of(context).colorScheme.primary, phase: 0),
      (x: 0.12, y: 0.3, size: 0.3, color: _rose, phase: 0.33),
      (x: 0.5, y: 0.52, size: 0.24, color: _teal, phase: 0.66),
    ];
    final List<Widget> art = <Widget>[for (final b in bursts) _svg(_burstSvg(b.color), width: b.size * s)];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: s,
          height: s,
          child: AnimatedBuilder(
            animation: _bloom,
            builder: (context, _) => Stack(
              children: <Widget>[
                for (int i = 0; i < bursts.length; i++)
                  Positioned(
                    left: (widget.right ? bursts[i].x : 1 - bursts[i].x - bursts[i].size) * s,
                    top: bursts[i].y * s,
                    child: _bloomed(art[i], (_bloom.value + bursts[i].phase) % 1, still),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A burst [t] of the way through its cycle. It grows and fades for the first 60 percent, then waits unseen.
  Widget _bloomed(Widget burst, double t, bool still) {
    final double opacity = still ? 0.75 : (t < 0.12 ? t / 0.12 : (t < 0.6 ? 1 - (t - 0.12) / 0.48 : 0.0));
    final double scale = still ? 1 : 0.25 + 0.75 * Curves.easeOutCubic.transform(math.min(t / 0.6, 1));
    return Opacity(
      opacity: opacity * 0.8,
      child: Transform.scale(scale: scale, child: burst),
    );
  }
}

/// Artwork for the home carousel card that offers the Diwali theme. It does not depend on the active theme.
class DiwaliBannerArt extends StatelessWidget {
  const DiwaliBannerArt({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0D0718), Color(0xFF2A0F2E), Color(0xFF4A1A1F)],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: h * 0.62,
                top: h * 0.04,
                child: _svg(_burstSvg(_marigold), width: h * 0.46),
              ),
              Positioned(
                right: h * 1.12,
                top: h * 0.12,
                child: _svg(_burstSvg(_rose), width: h * 0.32),
              ),
              Positioned(
                right: h * 0.12,
                top: h * 0.02,
                child: _svg(_burstSvg(_teal), width: h * 0.26),
              ),
              Positioned(
                right: h * 1.36,
                top: h * 0.44,
                child: _svg(_burstSvg(_teal), width: h * 0.16),
              ),
              Positioned(
                right: h * 0.08,
                bottom: h * 0.3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _Diya(size: h * 0.22, flicker: false),
                    SizedBox(width: h * 0.03),
                    _Diya(size: h * 0.28, flicker: false),
                    SizedBox(width: h * 0.03),
                    _Diya(size: h * 0.22, flicker: false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
