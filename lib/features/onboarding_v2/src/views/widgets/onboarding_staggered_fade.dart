import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/widgets.dart';

/// Fades [child] in with an 8 point rise, [delay] after the first frame. Under reduce motion it shows at once.
class OnboardingStaggeredFade extends StatefulWidget {
  const OnboardingStaggeredFade({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<OnboardingStaggeredFade> createState() => _OnboardingStaggeredFadeState();
}

class _OnboardingStaggeredFadeState extends State<OnboardingStaggeredFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: PrismDurations.base);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: PrismCurves.enter);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _timer?.cancel();
      _controller.value = 1;
    } else if (_timer == null && _controller.value == 0) {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(offset: Offset(0, 8 * (1 - _curve.value)), child: child),
      ),
    );
  }
}
