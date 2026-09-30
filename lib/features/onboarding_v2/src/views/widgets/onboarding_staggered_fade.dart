import 'dart:async';

import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

/// Fades [child] in [delay] after the first frame.
class OnboardingStaggeredFade extends StatefulWidget {
  const OnboardingStaggeredFade({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<OnboardingStaggeredFade> createState() => _OnboardingStaggeredFadeState();
}

class _OnboardingStaggeredFadeState extends State<OnboardingStaggeredFade> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(widget.delay, () => setState(() => _visible = true));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(opacity: _visible ? 1.0 : 0.0, duration: OnboardingMotion.fade, child: widget.child);
  }
}
