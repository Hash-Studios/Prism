import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

/// The welcome art, cropped to fill. [imageScale] is an extra zoom on top of the crop.
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({super.key, required this.assetPath, this.imageScale = 1.0});

  final String assetPath;
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: OnboardingAssets.fallbackFill),
        Positioned.fill(
          child: Transform.scale(
            scale: imageScale,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The welcome art with a slow settle from a slight zoom on mount. It fades out once [visible] turns false, so the
/// later steps sit on the themed page background.
class OnboardingStepBackground extends StatefulWidget {
  const OnboardingStepBackground({super.key, required this.visible});

  final bool visible;

  @override
  State<OnboardingStepBackground> createState() => _OnboardingStepBackgroundState();
}

class _OnboardingStepBackgroundState extends State<OnboardingStepBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: OnboardingMotion.backgroundReveal,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.12,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _reveal, curve: PrismCurves.enter));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _reveal.value = 1;
    } else if (!_reveal.isAnimating && _reveal.value == 0) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: context.motion(PrismDurations.base),
        curve: PrismCurves.exit,
        opacity: widget.visible ? 1 : 0,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, _) =>
              OnboardingBackground(assetPath: OnboardingAssets.wallpaperPrimary, imageScale: _scale.value),
        ),
      ),
    );
  }
}
