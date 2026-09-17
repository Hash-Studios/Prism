import 'dart:ui';

import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({
    super.key,
    required this.assetPath,
    this.networkUrl,
    this.blurSigma = 0,
    this.imageScale = 1.0,
  });

  final String assetPath;

  /// If provided and non-empty, renders a network image instead of the asset.
  final String? networkUrl;

  /// 0 = no blur.
  final double blurSigma;

  /// Extra scale on top of BoxFit.cover, used by the reveal animation.
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    final resolvedNetworkUrl = networkUrl;
    Widget imageChild =
        (resolvedNetworkUrl != null && resolvedNetworkUrl.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: resolvedNetworkUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => Image.asset(
              assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            errorWidget: (_, _, _) => const SizedBox.expand(),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          );
    if (blurSigma > 0) {
      imageChild = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: imageChild,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: OnboardingColors.fallbackFill),
        Positioned.fill(
          child: Transform.scale(scale: imageScale, child: imageChild),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// OnboardingStepBackground — step-aware animated background.
//
// Responsibilities:
//   • Initial scale-reveal (1.18 → 1.0) on mount.
//   • Blur sigma animation per step:
//       auth → 0, interests → 40, starterPack → 70, firstWallpaper → 0.
//   • Cross-fade between wallpaperPrimary and wallpaperFinal on the
//     firstWallpaper step.
// ---------------------------------------------------------------------------
class OnboardingStepBackground extends StatefulWidget {
  const OnboardingStepBackground({
    super.key,
    required this.step,
    this.wallpaperUrl,
  });

  final OnboardingV2Step step;
  final String? wallpaperUrl;

  @override
  State<OnboardingStepBackground> createState() =>
      _OnboardingStepBackgroundState();
}

class _OnboardingStepBackgroundState extends State<OnboardingStepBackground>
    with TickerProviderStateMixin {
  // Scale-reveal — fires once on initial mount.
  late final AnimationController _revealCtrl;
  late final Animation<double> _revealAnim;

  // Blur sigma — animated on every step change.
  late final AnimationController _blurCtrl;
  late Animation<double> _blurAnim;
  double _blurTarget = 0;

  bool _showFinal = false;

  @override
  void initState() {
    super.initState();

    _revealCtrl = AnimationController(
      duration: OnboardingMotion.backgroundReveal,
      vsync: this,
    );
    _revealAnim = Tween<double>(begin: 1.18, end: 1.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: OnboardingMotion.reveal),
    );

    _blurCtrl = AnimationController(
      duration: OnboardingMotion.long,
      vsync: this,
    );
    _blurAnim = Tween<double>(begin: 0, end: 0).animate(_blurCtrl);

    _applyStep(widget.step, animate: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(OnboardingStepBackground old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) _applyStep(widget.step, animate: true);
  }

  void _applyStep(OnboardingV2Step step, {required bool animate}) {
    final target = _sigmaFor(step);
    final showFinal = step == OnboardingV2Step.firstWallpaper;

    if (showFinal != _showFinal) setState(() => _showFinal = showFinal);

    if (target != _blurTarget) {
      final from = animate ? _blurAnim.value : target;
      _blurTarget = target;
      _blurAnim = Tween<double>(begin: from, end: target).animate(
        CurvedAnimation(parent: _blurCtrl, curve: OnboardingMotion.emphasized),
      );
      if (animate) {
        _blurCtrl.forward(from: 0);
      } else {
        _blurCtrl.value = 1;
      }
    }
  }

  static double _sigmaFor(OnboardingV2Step step) => switch (step) {
    OnboardingV2Step.auth => 0,
    OnboardingV2Step.interests => 40,
    OnboardingV2Step.starterPack => 70,
    OnboardingV2Step.aiGenerate => 40,
    OnboardingV2Step.firstWallpaper => 0,
  };

  @override
  void dispose() {
    _revealCtrl.dispose();
    _blurCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_revealAnim, _blurAnim]),
      child: OnboardingBackground(
        assetPath: OnboardingAssets.wallpaperFinal,
        networkUrl: widget.wallpaperUrl,
      ),
      builder: (context, child) {
        final revealScale = _revealAnim.value;
        final sigma = _blurAnim.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              duration: OnboardingMotion.normal,
              opacity: _showFinal ? 0.0 : 1.0,
              child: OnboardingBackground(
                assetPath: OnboardingAssets.wallpaperPrimary,
                blurSigma: sigma,
                imageScale: revealScale * (sigma > 0 ? 1.04 : 1.0),
              ),
            ),
            AnimatedOpacity(
              duration: OnboardingMotion.normal,
              opacity: _showFinal ? 1.0 : 0.0,
              child: child,
            ),
          ],
        );
      },
    );
  }
}
