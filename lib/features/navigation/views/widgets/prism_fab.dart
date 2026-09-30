import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/glint/glint_data.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/nav_bar_surface.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The round create button: a "+" inside a static rainbow ring. The ring turns a quarter once per tap.
class PrismFab extends StatefulWidget {
  const PrismFab({super.key});

  @override
  State<PrismFab> createState() => _PrismFabState();
}

class _PrismFabState extends State<PrismFab> {
  static const double _size = 60;

  int _quarterTurns = 0;

  void _openUploadSheet() {
    if (!mounted) return;
    showPrismSheet<void>(context: context, isScrollControlled: true, builder: (context) => const UploadBottomPanel());
  }

  void _onPressed() {
    HapticFeedback.selectionClick();
    if (!context.reduceMotion) setState(() => _quarterTurns++);
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadSheetOpened,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () {
        if (mounted) _openUploadSheet();
      });
      return;
    }
    _openUploadSheet();
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: 'Upload',
      excludeSemantics: true,
      onTap: _onPressed,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onPressed,
          child: DecoratedBox(
            decoration: navBarDecoration(context, circle: true),
            child: SizedBox.square(
              dimension: _size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedRotation(
                    turns: _quarterTurns / 4,
                    duration: context.motion(PrismDurations.slow),
                    curve: PrismCurves.move,
                    child: const CustomPaint(size: Size.square(_size), painter: _RainbowRingPainter()),
                  ),
                  Icon(Icons.add_rounded, size: 28, color: ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo's rainbow ring, in Glint's own colours.
class _RainbowRingPainter extends CustomPainter {
  const _RainbowRingPainter();

  static const double _width = 2.5;
  // Glint's ring colours, closed back to the first so the sweep has no seam.
  static const List<Color> _colors = <Color>[...glintRingNodeColors, glintPurple];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(_width / 2 + 1);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..shader = const SweepGradient(colors: _colors, transform: GradientRotation(-math.pi / 2)).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_RainbowRingPainter oldDelegate) => false;
}
