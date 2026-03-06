import 'package:flutter/material.dart';

class DecoratedBackground extends StatelessWidget {
  const DecoratedBackground({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.secondary.withValues(alpha: 0.10),
            colorScheme.secondary.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.7],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(color: colorScheme.secondary.withValues(alpha: 0.18), size: 180),
          ),
          Positioned(
            top: 220,
            left: -70,
            child: _GlowOrb(color: colorScheme.secondary.withValues(alpha: 0.10), size: 140),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)], stops: const [0.1, 1]),
        ),
      ),
    );
  }
}
