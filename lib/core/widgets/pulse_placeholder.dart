import 'package:Prism/core/utils/theme_utils.dart';
import 'package:flutter/material.dart';

/// Rebuilds [builder] with a pulsing skeleton colour for loading placeholders.
class PulsePlaceholder extends StatefulWidget {
  const PulsePlaceholder({super.key, required this.builder});

  final Widget Function(BuildContext context, Color color) builder;

  @override
  State<PulsePlaceholder> createState() => _PulsePlaceholderState();
}

class _PulsePlaceholderState extends State<PulsePlaceholder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color from, Color to) = context.isDarkMode
        ? (Colors.white10, const Color(0x22FFFFFF))
        : (Colors.black.withValues(alpha: .1), Colors.black.withValues(alpha: .14));
    final Animation<Color?> color = TweenSequence<Color?>(<TweenSequenceItem<Color?>>[
      TweenSequenceItem<Color?>(
        weight: 1,
        tween: ColorTween(begin: from, end: to),
      ),
      TweenSequenceItem<Color?>(
        weight: 1,
        tween: ColorTween(begin: to, end: from),
      ),
    ]).animate(_controller);
    return AnimatedBuilder(animation: color, builder: (context, _) => widget.builder(context, color.value ?? from));
  }
}
