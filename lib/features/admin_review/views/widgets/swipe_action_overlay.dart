import 'package:flutter/material.dart';

class SwipeActionOverlay extends StatelessWidget {
  final double swipeProgress;
  final bool isApprove;

  const SwipeActionOverlay({super.key, required this.swipeProgress, required this.isApprove});

  @override
  Widget build(BuildContext context) {
    if (swipeProgress.abs() < 0.1) {
      return const SizedBox.shrink();
    }

    final opacity = (swipeProgress.abs() * 2).clamp(0.0, 1.0);
    final isApproveDirection = swipeProgress > 0;

    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: (isApproveDirection ? Colors.green : Colors.red).withOpacity(opacity * 0.3),
          border: Border.all(color: (isApproveDirection ? Colors.green : Colors.red).withOpacity(opacity), width: 4),
        ),
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: isApproveDirection ? -0.3 : 0.3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: isApproveDirection ? Colors.green : Colors.red, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isApproveDirection ? 'APPROVE' : 'REJECT',
                  style: TextStyle(
                    color: isApproveDirection ? Colors.green : Colors.red,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SwipeHintIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double opacity;

  const SwipeHintIndicator({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
