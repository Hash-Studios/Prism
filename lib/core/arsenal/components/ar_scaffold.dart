import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/components/ar_app_bar.dart';
import 'package:Prism/core/arsenal/components/ar_bottom_nav.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/theme.dart';
import 'package:flutter/material.dart';

class ArScaffold extends StatelessWidget {
  const ArScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.navBar,
    this.bottomBar,
    this.padding = const EdgeInsets.all(ArsenalSpacing.md),
    this.gradient = true,
    this.showCornerBrackets = true,
  });

  /// Main scrollable / flexible body content.
  final Widget child;

  /// Optional transparent app bar rendered above [child].
  final ArAppBar? appBar;

  /// Optional bottom navigation bar rendered below [child], outside SafeArea.
  final ArBottomNav? navBar;

  /// Pinned above the bottom safe-area edge. Receives the same horizontal
  /// padding as [child]. Typical use: primary + ghost buttons.
  final Widget? bottomBar;

  /// Padding applied around [child] and [bottomBar].
  /// Defaults to [ArsenalSpacing.md] (16 px) on all sides.
  final EdgeInsets padding;

  /// Show the radial crimson-to-black background gradient.
  /// Set to false for full-screen media or custom backgrounds.
  final bool gradient;

  /// Show the ⌐ bracket top-left and ¬ bracket bottom-right.
  final bool showCornerBrackets;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: arsenalDarkTheme,
      child: Scaffold(
        backgroundColor: ArsenalColors.background,
        body: Stack(
          children: [
            // ── Background ─────────────────────────────────────────────────
            if (gradient) const _ArGradientBackground(),

            // ── Content + bottom bar ───────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: navBar == null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (appBar != null) appBar!,
                        Expanded(
                          child: Padding(padding: padding, child: child),
                        ),
                        if (bottomBar != null)
                          Padding(
                            padding: EdgeInsets.only(
                              left: padding.left,
                              right: padding.right,
                              bottom: padding.bottom,
                            ),
                            child: bottomBar,
                          ),
                      ],
                    ),
                  ),
                ),
                if (navBar != null) navBar!,
              ],
            ),

            // ── Corner brackets ────────────────────────────────────────────
            if (showCornerBrackets) const _ArCornerBrackets(),
          ],
        ),
      ),
    );
  }
}

// ── Background gradient ──────────────────────────────────────────────────────

class _ArGradientBackground extends StatelessWidget {
  const _ArGradientBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2), // upper-centre, ~40% from top
            radius: 0.85,
            colors: [ArsenalColors.gradientCenter, ArsenalColors.background],
            stops: [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ── Corner brackets ──────────────────────────────────────────────────────────

class _ArCornerBrackets extends StatelessWidget {
  const _ArCornerBrackets();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _BracketPainter())),
    );
  }
}

class _BracketPainter extends CustomPainter {
  static const double _size = 20;
  static const double _stroke = 1.5;
  static const double _margin = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ArsenalColors.border
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Top-left ⌐
    canvas.drawLine(const Offset(_margin, _margin + _size), const Offset(_margin, _margin), paint);
    canvas.drawLine(const Offset(_margin, _margin), const Offset(_margin + _size, _margin), paint);

    // Bottom-right ¬
    canvas.drawLine(
      Offset(size.width - _margin, size.height - _margin - _size),
      Offset(size.width - _margin, size.height - _margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - _margin, size.height - _margin),
      Offset(size.width - _margin - _size, size.height - _margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}
