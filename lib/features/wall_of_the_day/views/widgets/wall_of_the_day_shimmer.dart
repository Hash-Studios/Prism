import 'package:flutter/material.dart';

class WallOfTheDayShimmer extends StatefulWidget {
  const WallOfTheDayShimmer({super.key});

  @override
  State<WallOfTheDayShimmer> createState() => _WallOfTheDayShimmerState();
}

class _WallOfTheDayShimmerState extends State<WallOfTheDayShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);
    final highlightColor = isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          constraints: const BoxConstraints.expand(),
          color: Color.lerp(baseColor, highlightColor, _animation.value),
          child: Stack(
            children: [
              // Label placeholder
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  width: 130,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Text placeholders
              Positioned(
                bottom: 36,
                left: 14,
                right: 140,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 14,
                right: 180,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Button placeholder
              Positioned(
                bottom: 12,
                right: 14,
                child: Container(
                  width: 110,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
