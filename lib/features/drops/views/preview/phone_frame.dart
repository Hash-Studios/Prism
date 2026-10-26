import 'package:flutter/material.dart';

/// Width over height of the phone body.
const double dropPhoneAspect = 0.47;
const double _bezel = 7;

/// A black phone body with a dynamic island and a thin edge that shows on a dark page. [child] fills the screen.
class DropPhoneFrame extends StatelessWidget {
  const DropPhoneFrame({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double width = height * dropPhoneAspect;
    final double bodyRadius = width * 0.16;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_bezel),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(bodyRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(bodyRadius - _bezel),
        child: CustomPaint(foregroundPainter: const _IslandPainter(), child: child),
      ),
    );
  }
}

class _IslandPainter extends CustomPainter {
  const _IslandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width * 0.3;
    final double h = size.width * 0.08;
    final Rect pill = Rect.fromLTWH((size.width - w) / 2, size.width * 0.03, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(pill, Radius.circular(h / 2)), Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_IslandPainter oldDelegate) => false;
}
