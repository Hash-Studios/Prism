import 'dart:math' as math;
import 'dart:ui';

import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// OnboardingBackground — pure stateless render widget.
// No animation logic here; all animation is owned by OnboardingStepBackground.
// ---------------------------------------------------------------------------
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({
    super.key,
    required this.assetPath,
    required this.sx,
    required this.sy,
    this.networkUrl,
    this.imageLeft = -87,
    this.imageTop = 0,
    this.imageWidth = 567,
    this.imageHeight = 852,
    this.blurSigma = 0,
    this.imageScale = 1.0,
    this.bottomOverlayOpacity = 0.0,
  });

  final String assetPath;

  /// If provided and non-empty, renders a network image instead of the asset.
  final String? networkUrl;
  final double sx;
  final double sy;
  final double imageLeft;
  final double imageTop;
  final double imageWidth;
  final double imageHeight;

  /// 0 = no blur.
  final double blurSigma;

  /// Multiplied on top of the cover-fit scale.
  final double imageScale;

  /// 0 = hidden, 1 = fully visible bottom gradient overlay.
  final double bottomOverlayOpacity;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = OnboardingLayout.designWidth * sx;
    final viewportHeight = OnboardingLayout.designHeight * sy;
    final renderedW = imageWidth * sx;
    final renderedH = imageHeight * sy;
    final coverScale = math.max(viewportWidth / renderedW, viewportHeight / renderedH);

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final resolvedNetworkUrl = networkUrl;
    Widget imageChild = (resolvedNetworkUrl != null && resolvedNetworkUrl.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: resolvedNetworkUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => Image.asset(assetPath, fit: BoxFit.cover),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.cover,
            cacheWidth: (imageWidth * sx * dpr).toInt(),
            cacheHeight: (imageHeight * sy * dpr).toInt(),
          );
    if (blurSigma > 0) {
      // ImageFiltered blurs its own subtree, unlike BackdropFilter which blurs
      // whatever is behind it. This is safe inside Opacity layers.
      imageChild = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma, tileMode: TileMode.clamp),
        child: imageChild,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: imageLeft * sx,
          top: imageTop * sy,
          width: imageWidth * sx,
          height: imageHeight * sy,
          child: Transform.scale(scale: coverScale * imageScale, child: imageChild),
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
  const OnboardingStepBackground({super.key, required this.step, this.wallpaperUrl});

  final OnboardingV2Step step;
  final String? wallpaperUrl;

  @override
  State<OnboardingStepBackground> createState() => _OnboardingStepBackgroundState();
}

class _OnboardingStepBackgroundState extends State<OnboardingStepBackground> with TickerProviderStateMixin {
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

    _revealCtrl = AnimationController(duration: OnboardingMotion.backgroundReveal, vsync: this);
    _revealAnim = Tween<double>(
      begin: 1.18,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _revealCtrl, curve: OnboardingMotion.reveal));

    _blurCtrl = AnimationController(duration: OnboardingMotion.long, vsync: this);
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
      _blurAnim = Tween<double>(
        begin: from,
        end: target,
      ).animate(CurvedAnimation(parent: _blurCtrl, curve: OnboardingMotion.emphasized));
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / OnboardingLayout.designWidth;
        final sy = constraints.maxHeight / OnboardingLayout.designHeight;

        return AnimatedBuilder(
          animation: Listenable.merge([_revealAnim, _blurAnim]),
          // wallpaperFinal has no animated params — extracted so it isn't
          // rebuilt on every animation tick of _revealAnim / _blurAnim.
          child: OnboardingBackground(
            assetPath: OnboardingAssets.wallpaperFinal,
            networkUrl: widget.wallpaperUrl,
            sx: sx,
            sy: sy,
            imageLeft: -88,
            imageTop: -1,
            imageWidth: 569,
            imageHeight: 854,
          ),
          builder: (context, child) {
            final revealScale = _revealAnim.value;
            final sigma = _blurAnim.value;
            // Bottom overlay fades in with blur, reaching full opacity at sigma=70.
            final overlayOpacity = (sigma / 70).clamp(0.0, 1.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Primary image — shown on auth / interests / starterPack.
                AnimatedOpacity(
                  duration: OnboardingMotion.normal,
                  opacity: _showFinal ? 0.0 : 1.0,
                  child: OnboardingBackground(
                    assetPath: OnboardingAssets.wallpaperPrimary,
                    sx: sx,
                    sy: sy,
                    blurSigma: sigma,
                    // Slight scale-up when blurred, matching the original softened style.
                    imageScale: revealScale * (sigma > 0 ? 1.04 : 1.0),
                    bottomOverlayOpacity: overlayOpacity,
                  ),
                ),
                // Final image — shown on firstWallpaper step.
                AnimatedOpacity(duration: OnboardingMotion.normal, opacity: _showFinal ? 1.0 : 0.0, child: child),
              ],
            );
          },
        );
      },
    );
  }
}
