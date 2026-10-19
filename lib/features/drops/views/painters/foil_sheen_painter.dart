import 'package:flutter/material.dart';

/// A soft diagonal band of light. [progress] 0 puts it off the left edge and 1 off the right edge.
class FoilSheenPainter extends CustomPainter {
  const FoilSheenPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final double band = size.width * 0.45;
    final double start = -band + (size.width + band * 2) * progress;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(start, 0, band, size.height))
      ..blendMode = BlendMode.plus;
    canvas.save();
    canvas.translate(start + band / 2, size.height / 2);
    canvas.rotate(0.35);
    canvas.translate(-(start + band / 2), -size.height / 2);
    canvas.drawRect(Rect.fromLTWH(start, -size.height, band, size.height * 3), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FoilSheenPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Sweeps a [FoilSheenPainter] band across [child] every [period], or once when [once] is set. It holds still when
/// the system asks for fewer animations.
class FoilSheen extends StatefulWidget {
  const FoilSheen({super.key, required this.child, required this.color, this.once = false, this.period});

  final Widget child;
  final Color color;
  final bool once;
  final Duration? period;

  @override
  State<FoilSheen> createState() => _FoilSheenState();
}

class _FoilSheenState extends State<FoilSheen> with SingleTickerProviderStateMixin {
  static const double _sweepShare = 0.3;
  static const double _stillProgress = 0.4;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.once ? const Duration(milliseconds: 1100) : widget.period ?? const Duration(seconds: 6),
  );
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still && _running) {
      _controller.stop();
      _running = false;
    } else if (!still && !_running) {
      _running = true;
      widget.once ? _controller.forward(from: 0) : _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(double value) {
    if (!_running) return widget.once ? 0 : _stillProgress;
    if (widget.once) return Curves.easeInOut.transform(value);
    return value >= _sweepShare ? 0 : Curves.easeInOut.transform(value / _sweepShare);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: FoilSheenPainter(progress: _progress(_controller.value), color: widget.color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
