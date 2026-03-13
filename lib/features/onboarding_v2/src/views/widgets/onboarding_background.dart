import 'dart:math' as math;
import 'dart:ui';

import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

enum OnboardingBackgroundMode { clear, softened }

class OnboardingBackground extends StatefulWidget {
  const OnboardingBackground({
    super.key,
    required this.assetPath,
    required this.sx,
    required this.sy,
    this.imageLeft = -87,
    this.imageTop = 0,
    this.imageWidth = 567,
    this.imageHeight = 852,
    this.mode = OnboardingBackgroundMode.clear,
  });

  final String assetPath;
  final double sx;
  final double sy;
  final double imageLeft;
  final double imageTop;
  final double imageWidth;
  final double imageHeight;
  final OnboardingBackgroundMode mode;

  @override
  State<OnboardingBackground> createState() => _OnboardingBackgroundState();
}

class _OnboardingBackgroundState extends State<OnboardingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleReveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: OnboardingMotion.backgroundReveal,
      vsync: this,
    );
    _scaleReveal = Tween<double>(begin: 1.18, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: OnboardingMotion.reveal),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = OnboardingLayout.designWidth * widget.sx;
    final viewportHeight = OnboardingLayout.designHeight * widget.sy;
    final renderedImageWidth = widget.imageWidth * widget.sx;
    final renderedImageHeight = widget.imageHeight * widget.sy;
    final coverScale = math.max(
      viewportWidth / renderedImageWidth,
      viewportHeight / renderedImageHeight,
    );

    Positioned buildImage({double scale = 1}) => Positioned(
      left: widget.imageLeft * widget.sx,
      top: widget.imageTop * widget.sy,
      width: widget.imageWidth * widget.sx,
      height: widget.imageHeight * widget.sy,
      child: AnimatedBuilder(
        animation: _scaleReveal,
        child: Image.asset(widget.assetPath, fit: BoxFit.cover),
        builder: (context, child) {
          return Transform.scale(
            scale: coverScale * scale * _scaleReveal.value,
            child: child,
          );
        },
      ),
    );

    if (widget.mode == OnboardingBackgroundMode.clear) {
      return buildImage();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        buildImage(scale: 1.04),
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: OnboardingLayout.softenedBlurSigma * widget.sx,
                sigmaY: OnboardingLayout.softenedBlurSigma * widget.sy,
              ),
              child: ColoredBox(
                color: OnboardingColors.blurTint.withValues(
                  alpha: OnboardingOpacity.blurLayerTint,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: OnboardingLayout.bottomOverlayY * widget.sy,
          width: OnboardingLayout.bottomOverlayLeftWidth * widget.sx,
          height: OnboardingLayout.bottomOverlayHeight * widget.sy,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OnboardingColors.bottomOverlayLeft.withValues(alpha: 0),
                  OnboardingColors.bottomOverlayLeft,
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ),
        Positioned(
          left: OnboardingLayout.bottomOverlayLeftWidth * widget.sx,
          top: OnboardingLayout.bottomOverlayY * widget.sy,
          width: OnboardingLayout.bottomOverlayRightWidth * widget.sx,
          height: OnboardingLayout.bottomOverlayHeight * widget.sy,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OnboardingColors.bottomOverlayRight.withValues(alpha: 0),
                  OnboardingColors.bottomOverlayRight,
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
