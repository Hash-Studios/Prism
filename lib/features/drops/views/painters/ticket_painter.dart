import 'package:flutter/material.dart';

/// A ticket outline. A perforated tear line with a notch at each end sits at [dividerX] when it is set.
class TicketPainter extends CustomPainter {
  const TicketPainter({required this.fill, required this.stroke, this.dividerX, this.radius = 14});

  final Color fill;
  final Color stroke;
  final double? dividerX;
  final double radius;

  static const double _notch = 7;

  @override
  void paint(Canvas canvas, Size size) {
    Path shape = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final double? x = dividerX;
    if (x != null) {
      final Path notches = Path()
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: _notch))
        ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: _notch));
      shape = Path.combine(PathOperation.difference, shape, notches);
    }
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = stroke,
    );
    if (x != null) {
      final Paint dash = Paint()
        ..strokeWidth = 1
        ..color = stroke;
      for (double y = _notch + 4; y < size.height - _notch - 2; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 2.5), dash);
      }
    }
  }

  @override
  bool shouldRepaint(TicketPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.dividerX != dividerX ||
      oldDelegate.radius != radius;
}
