import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:flutter/widgets.dart';

/// Shows a small Glint over the screen for [duration], then removes it. Does nothing under reduce motion.
///
/// Use it for success moments (a wallpaper set, an upload sent). Show at most one Glint per screen.
void showGlintToast(
  BuildContext context, {
  GlintMood mood = GlintMood.happy,
  double size = 64,
  Duration duration = const Duration(milliseconds: 1600),
}) {
  if (context.reduceMotion) return;
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GlintToast(mood: mood, size: size, duration: duration, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _GlintToast extends StatefulWidget {
  const _GlintToast({required this.mood, required this.size, required this.duration, required this.onDone});

  final GlintMood mood;
  final double size;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_GlintToast> createState() => _GlintToastState();
}

class _GlintToastState extends State<_GlintToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: PrismDurations.fast,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: PrismCurves.enter,
    reverseCurve: PrismCurves.exit,
  );
  late final Animation<Offset> _position = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(_curve);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _controller.value = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.35),
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: _position,
            child: Glint(mood: widget.mood, size: widget.size),
          ),
        ),
      ),
    );
  }
}
