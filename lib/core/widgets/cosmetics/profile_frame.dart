import 'dart:math' as math;

import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Draws the equipped frame around a profile picture. [size] is the whole footprint, ring included, so a framed and an
/// unframed picture take the same room. An unknown id, or a Pro frame on a profile that is not premium, draws no ring.
class ProfileFrame extends StatelessWidget {
  const ProfileFrame({
    super.key,
    required this.frameId,
    required this.premium,
    required this.size,
    required this.child,
  });

  static const Key ringKey = ValueKey<String>('profile_frame_ring');
  static const double _gap = 2;

  final String? frameId;
  final bool premium;
  final double size;
  final Widget child;

  /// Whether [frameId] draws a ring for this profile.
  static bool draws(String? frameId, {required bool premium}) {
    final ShopItem? item = frameId == null ? null : shopItem(frameId);
    return item != null && item.kind == ShopItemKind.frame && (premium || !item.proOnly);
  }

  @override
  Widget build(BuildContext context) {
    final String? id = frameId;
    if (id == null || !draws(id, premium: premium)) {
      return SizedBox.square(dimension: size, child: child);
    }
    final FrameStyle style = frameStyle(id, accent: Theme.of(context).colorScheme.primary);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        key: ringKey,
        foregroundPainter: _RingPainter(style),
        child: Padding(padding: EdgeInsets.all(style.width + _gap), child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.style);

  final FrameStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.width
      ..isAntiAlias = true;
    final List<Color> colors = style.colors;
    if (colors.length == 1 || colors.every((Color c) => c == colors.first)) {
      paint.color = colors.first;
    } else {
      final List<Color> loop = colors.first == colors.last ? colors : <Color>[...colors, colors.first];
      paint.shader = SweepGradient(colors: loop, transform: const GradientRotation(-math.pi / 2)).createShader(rect);
    }
    canvas.drawOval(rect.deflate(style.width / 2), paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.style.width != style.width || !listEquals(oldDelegate.style.colors, style.colors);
}
