import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:flutter/material.dart';

/// Width over height of the phone body.
const double dropPhoneAspect = 0.47;
const double _bezel = 7;

/// A phone body in obsidian with a thin gold hairline and a dynamic island. [child] fills the screen.
class DropPhoneFrame extends StatelessWidget {
  const DropPhoneFrame({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double width = height * dropPhoneAspect;
    final double bodyRadius = width * 0.16;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: const _PhoneBodyPainter(),
        foregroundPainter: const _IslandPainter(),
        child: Padding(
          padding: const EdgeInsets.all(_bezel),
          child: ClipRRect(borderRadius: BorderRadius.circular(bodyRadius - _bezel), child: child),
        ),
      ),
    );
  }
}

class _PhoneBodyPainter extends CustomPainter {
  const _PhoneBodyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect body = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.16));
    canvas.drawRRect(
      body.shift(const Offset(0, 14)),
      Paint()
        ..color = DropPalette.gold.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[DropPalette.obsidianRaised, DropPalette.obsidian],
        ).createShader(rect),
    );
    final Paint button = Paint()..color = DropPalette.goldDeep.withValues(alpha: 0.7);
    for (final (double y, double h) in <(double, double)>[(0.17, 0.035), (0.24, 0.07), (0.33, 0.07)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-1.5, size.height * y, 2.5, size.height * h), const Radius.circular(1)),
        button,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 1, size.height * 0.26, 2.5, size.height * 0.1),
        const Radius.circular(1),
      ),
      button,
    );
    canvas.drawRRect(
      body.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = DropPalette.foil.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PhoneBodyPainter oldDelegate) => false;
}

class _IslandPainter extends CustomPainter {
  const _IslandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width * 0.28;
    final double h = size.width * 0.075;
    final Rect pill = Rect.fromLTWH((size.width - w) / 2, _bezel + size.width * 0.028, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(pill, Radius.circular(h / 2)), Paint()..color = DropPalette.obsidian);
  }

  @override
  bool shouldRepaint(_IslandPainter oldDelegate) => false;
}
